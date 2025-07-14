import 'package:flutter/material.dart';
import '../models/Client.dart';
import '../service/client_service.dart';
import 'ajouter_client_screen.dart';

class ClientScreen extends StatefulWidget {
  const ClientScreen({super.key});

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> {
  final ClientService _service = ClientService();
  String _searchQuery = '';

  void _showClientDetails(Client client) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.person, size: 28, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                client.nom,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            )
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow(Icons.email_outlined, 'Email', client.email),
            const SizedBox(height: 12),
            _infoRow(Icons.business_outlined, 'ICE', client.ice.toString()),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _confirmDelete(client);
                },
                icon: const Icon(Icons.delete_outline, size: 20),
                label: const Text(
                  'Supprimer le client',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Client client) {
    showDialog(
      context: context,
    
      builder: (context) => AlertDialog(
        backgroundColor :Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirmer la suppression',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer "${client.nom}" ?',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Annuler',
              style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await _service.supprimerClient(client.id!);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${client.nom} supprimé avec succès'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Erreur lors de la suppression : $e'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blue),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.black87),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Mes Clients',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue.shade600,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),

      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AjoutClientScreen()));
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Ajouter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.blue.shade600,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un client...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.black, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Client>>(
              stream: _service.ecouterClients(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                }

                final clients = snapshot.data ?? [];
                final filtered = clients.where((c) {
                  final q = _searchQuery.toLowerCase();
                  return c.nom.toLowerCase().contains(q) ||
                      c.email.toLowerCase().contains(q) ||
                      c.ice.toString().contains(q);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('Aucun client trouvé'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (context, index) {
                    final client = filtered[index];
                    return ListTile(
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.person, color: Colors.white, size: 28),
                      ),
                      title: Text(client.nom, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(client.email, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Text('ICE: ${client.ice}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      onTap: () => _showClientDetails(client),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
