import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/facture.dart';
import '../models/LigneFacture.dart';
import '../service/facture_service.dart';
import 'ApercuFactureScreen.dart';

class CreerFactureScreen extends StatefulWidget {
  const CreerFactureScreen({super.key});

  @override
  State<CreerFactureScreen> createState() => _CreerFactureScreenState();
}

class _CreerFactureScreenState extends State<CreerFactureScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FactureService _factureService = FactureService();

  List<Map<String, dynamic>> clients = [];
  List<Map<String, dynamic>> produits = [];

  Map<String, dynamic>? clientSelectionne;
  List<LigneFacture> lignesFacture = [];

  bool isLoading = false;

  static const double tva = 0.20;

  double get totalHT => lignesFacture.fold(0, (sum, l) => sum + l.totalLigne);
  double get totalTTC => totalHT * (1 + tva);

  @override
  void initState() {
    super.initState();
    fetchClientsEtProduits();
  }

  Future<void> fetchClientsEtProduits() async {
    final clientsSnap = await _db.collection('clients').get();
    final produitsSnap = await _db.collection('produits').get();

    setState(() {
      clients = clientsSnap.docs.map((d) => d.data()).toList();
      produits = produitsSnap.docs.map((d) => d.data()).toList();
    });
  }

  void ajouterProduit(Map<String, dynamic> produit) {
    setState(() {
      lignesFacture.add(LigneFacture(
        produitId: produit['id'].toString(),
        nomProduit: produit['nom'],
        prixHT: (produit['prixHT'] as num).toDouble(),
        quantite: 1,
      ));
    });
  }

  void supprimerLigne(int index) => setState(() => lignesFacture.removeAt(index));

  void modifierPrix(int index, String value) {
    final parsed = double.tryParse(value);
    if (parsed != null) {
      setState(() => lignesFacture[index].prixHT = parsed);
    }
  }

  void modifierQuantite(int index, String value) {
    final parsed = int.tryParse(value);
    if (parsed != null && parsed > 0) {
      setState(() => lignesFacture[index].quantite = parsed);
    }
  }

  // Méthode pour afficher le dialog de sélection de client
  Future<void> _showClientSelectionDialog() async {
    final client = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3498DB).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_outline, color: Color(0xFF3498DB), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Choisir un client',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF95A5A6), size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFFE0E0E0)),
              const SizedBox(height: 16),
              Flexible(
                child: clients.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 48, color: Color(0xFFBDC3C7)),
                            SizedBox(height: 16),
                            Text(
                              'Aucun client disponible',
                              style: TextStyle(color: Color(0xFF7F8C8D), fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: clients.length,
                        separatorBuilder: (context, index) => const Divider(color: Color(0xFFF5F5F5)),
                        itemBuilder: (context, index) {
                          final client = clients[index];
                          final isSelected = clientSelectionne != null && 
                              clientSelectionne!['id'] == client['id'];
                          
                          return InkWell(
                            onTap: () => Navigator.of(context).pop(client),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFF8F9FA) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: isSelected 
                                    ? Border.all(color: const Color(0xFF3498DB), width: 1)
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: const Color(0xFFF8F9FA),
                                    radius: 20,
                                    child: Text(
                                      client['nom'][0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Color(0xFF2C3E50),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          client['nom'],
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF2C3E50),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'ICE: ${client['ice']}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF7F8C8D),
                                          ),
                                        ),
                                        if (client['email'] != null && client['email'].isNotEmpty)
                                          Text(
                                            client['email'],
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF95A5A6),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF3498DB),
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
    
    if (client != null) {
      setState(() => clientSelectionne = client);
    }
  }

  // Méthode pour afficher le dialog de sélection de produit
  Future<void> _showProductSelectionDialog() async {
    final produit = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF27AE60).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF27AE60), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Choisir un produit',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF95A5A6), size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFFE0E0E0)),
              const SizedBox(height: 16),
              Flexible(
                child: produits.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_outlined, size: 48, color: Color(0xFFBDC3C7)),
                            SizedBox(height: 16),
                            Text(
                              'Aucun produit disponible',
                              style: TextStyle(color: Color(0xFF7F8C8D), fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: produits.length,
                        separatorBuilder: (context, index) => const Divider(color: Color(0xFFF5F5F5)),
                        itemBuilder: (context, index) {
                          final produit = produits[index];
                          
                          return InkWell(
                            onTap: () => Navigator.of(context).pop(produit),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8F9FA),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.inventory_2_outlined,
                                      color: Color(0xFF2C3E50),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          produit['nom'],
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF2C3E50),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${produit['prixHT']} MAD HT',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF27AE60),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.add_circle_outline,
                                    color: Color(0xFF27AE60),
                                    size: 24,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
    
    if (produit != null) {
      ajouterProduit(produit);
    }
  }

  Future<void> validerFacture() async {
    print("🔵 Début de validerFacture");
    
    if (clientSelectionne == null || lignesFacture.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sélectionnez un client et au moins un produit.'),
      ));
      return;
    }

    print("🔵 Validation OK, début du traitement");
    setState(() => isLoading = true);

    try {
      print("🔵 Récupération du numéro de facture...");
      final numero = await _factureService.getNextFactureNumber();
      print("🔵 Numéro récupéré : $numero");
      
      print("🔵 Création de l'objet Facture...");
      print("🔵 clientSelectionne: $clientSelectionne");
      print("🔵 lignesFacture: $lignesFacture");
      print("🔵 totalHT: $totalHT");
      print("🔵 totalTTC: $totalTTC");
      
      final facture = Facture(
        id: '',
        clientId: clientSelectionne!['id'].toString(),
        nomClient: clientSelectionne!['nom'],
        emailClient: clientSelectionne!['email'],
        iceClient: clientSelectionne!['ice'].toString(),
        date: DateTime.now(),
        lignes: lignesFacture,
        totalHT: totalHT,
        totalTTC: totalTTC,
        numero: numero,
        pdfUrl: null,
      );
      print("🔵 Objet Facture créé avec succès");

      setState(() => isLoading = false);

      // Naviguer vers l'écran d'aperçu
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ApercuFactureScreen(facture: facture),
        ),
      );

      // Si l'utilisateur a confirmé l'enregistrement, l'aperçu s'occupe de fermer les écrans
      // Sinon on ne fait rien, l'utilisateur reste sur l'écran de création
      if (result == false) {
        // L'utilisateur a annulé, on peut optionnellement afficher un message
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Création de facture annulée'),
          backgroundColor: Colors.orange,
        ));
      }
    } catch (e) {
      setState(() => isLoading = false);
      print("❌ ERREUR COMPLÈTE : $e");
      print("❌ TYPE D'ERREUR : ${e.runtimeType}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la création de la facture :\n$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      resizeToAvoidBottomInset: true, 
      appBar: AppBar(
        title: const Text(
          'Créer une facture',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color.fromARGB(255, 255, 255, 255),
            
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color.fromARGB(255, 255, 255, 255)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2C3E50)))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dropdown client
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                      ),
                      child: InkWell(
                        onTap: () => _showClientSelectionDialog(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            children: [
                              const Icon(Icons.person_outline, color: Color(0xFF7F8C8D), size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  clientSelectionne != null 
                                    ? '${clientSelectionne!['nom']} (ICE: ${clientSelectionne!['ice']})'
                                    : 'Sélectionner un client',
                                  style: TextStyle(
                                    color: clientSelectionne != null 
                                      ? const Color(0xFF2C3E50)
                                      : const Color(0xFF7F8C8D),
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, color: Color(0xFF7F8C8D)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Lignes facture
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                      ),
                      constraints: const BoxConstraints(
                        minHeight: 100,
                        maxHeight: 300, // Limite la hauteur pour éviter l'overflow
                      ),
                      child: lignesFacture.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFFBDC3C7)),
                                  SizedBox(height: 16),
                                  Text(
                                    'Aucun produit ajouté',
                                    style: TextStyle(color: Color(0xFF7F8C8D), fontSize: 16),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(12),
                              itemCount: lignesFacture.length,
                              separatorBuilder: (context, index) => const Divider(color: Color(0xFFF5F5F5)),
                              itemBuilder: (context, index) {
                                final ligne = lignesFacture[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          ligne.nomProduit,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF2C3E50),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: TextFormField(
                                          initialValue: ligne.prixHT.toStringAsFixed(2),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          style: const TextStyle(fontSize: 14),
                                          decoration: const InputDecoration(
                                            labelText: 'Prix',
                                            labelStyle: TextStyle(color: Color(0xFF95A5A6), fontSize: 12),
                                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            border: OutlineInputBorder(
                                              borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderSide: BorderSide(color: Color(0xFF2C3E50)),
                                            ),
                                          ),
                                          onChanged: (val) => modifierPrix(index, val),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: TextFormField(
                                          initialValue: ligne.quantite.toString(),
                                          keyboardType: TextInputType.number,
                                          style: const TextStyle(fontSize: 14),
                                          decoration: const InputDecoration(
                                            labelText: 'Qté',
                                            labelStyle: TextStyle(color: Color(0xFF95A5A6), fontSize: 12),
                                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            border: OutlineInputBorder(
                                              borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderSide: BorderSide(color: Color(0xFF2C3E50)),
                                            ),
                                          ),
                                          onChanged: (val) => modifierQuantite(index, val),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.close, color: Color(0xFF95A5A6), size: 20),
                                        onPressed: () => supprimerLigne(index),
                                      )
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),

                    // Ajouter produit
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add, color: Colors.green,size: 18),
                        label: const Text(
                          'Ajouter un produit',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color.fromARGB(255, 210, 210, 210)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _showProductSelectionDialog,
                      ),
                    ),

                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total HT',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF7F8C8D),
                                ),
                              ),
                              Text(
                                '${totalHT.toStringAsFixed(2)} MAD',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'TVA (20%)',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF7F8C8D),
                                ),
                              ),
                              Text(
                                '${(totalHT * tva).toStringAsFixed(2)} MAD',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(color: Color(0xFFE0E0E0)),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total TTC',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                              Text(
                                '${totalTTC.toStringAsFixed(2)} MAD',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: validerFacture,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Aperçu de la facture',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,

                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
