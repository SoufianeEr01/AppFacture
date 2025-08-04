import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/Facture.dart';
import '../models/Client.dart';
import '../models/Produit.dart';
import '../service/facture_service.dart';
import '../service/client_service.dart';
import '../service/produit_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String selectedYear = DateTime.now().year.toString();
  String searchClient = "";

  Future<Map<String, dynamic>> _loadAllData() async {
    try {
      final factures = await FactureService().getAllFactures();
      final clients = await ClientService().obtenirTousLesClients();
      final produits = await ProduitService().obtenirTousLesProduits();

      return {
        'factures': factures,
        'clients': clients,
        'produits': produits,
      };
    } catch (e) {
      debugPrint('Erreur de chargement des données: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text("Nouvelle facture"),
        onPressed: () {
          // TODO: Naviguer vers l'ajout de facture
        },
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFe3f2fd), Color(0xFFbbdefb)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _loadAllData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      "Erreur de chargement des données",
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      child: const Text("Réessayer"),
                    ),
                  ],
                ),
              );
            } else if (!snapshot.hasData) {
              return const Center(child: Text("Aucune donnée disponible."));
            }

            final factures = snapshot.data!['factures'] as List<Facture>;
            final clients = snapshot.data!['clients'] as List<Client>;
            final produits = snapshot.data!['produits'] as List<Produit>;

            // Filtres
            final filteredFactures = factures.where((f) {
              try {
                final yearOk = f.date.year.toString() == selectedYear;
                final clientOk = searchClient.isEmpty ||
                    (f.nomClient?.toLowerCase().contains(searchClient.toLowerCase()) ?? false);
                return yearOk && clientOk;
              } catch (e) {
                debugPrint('Erreur lors du filtrage de la facture ${f.numero}: $e');
                return false;
              }
            }).toList();

            // Calculs sécurisés avec gestion d'erreur
            double totalTTC = 0;
            double totalHT = 0;
            int totalProduitsVendus = 0;

            for (var f in filteredFactures) {
              try {
                // Use parseDouble and parseInt to safely handle numeric values
                totalTTC += parseDouble(f.totalTTC);
                totalHT += parseDouble(f.totalHT);

                for (var ligne in f.lignes) {
                  totalProduitsVendus += parseInt(ligne.quantite);
                }
              } catch (e) {
                debugPrint('Erreur lors du calcul pour la facture ${f.numero}: $e');
              }
            }

            final totalFactures = filteredFactures.length;
            final totalClients = clients.length;

            // CA par client avec gestion d'erreur
            final caParClient = <String, double>{};
            for (var f in filteredFactures) {
              try {
                final nom = f.nomClient ?? "Inconnu";
                final ttc = parseDouble(f.totalTTC);
                caParClient[nom] = (caParClient[nom] ?? 0) + ttc;
              } catch (e) {
                debugPrint('Erreur CA par client pour facture ${f.numero}: $e');
              }
            }

            // CA par produit avec gestion d'erreur
            final caParProduit = <String, double>{};
            for (var f in filteredFactures) {
              try {
                for (var l in f.lignes) {
                  final nom = l.nomProduit ?? "Produit";
                  final prix = parseDouble(l.prixHT);
                  final qte = parseInt(l.quantite);
                  caParProduit[nom] = (caParProduit[nom] ?? 0) + prix * qte;
                }
              } catch (e) {
                debugPrint('Erreur CA par produit pour facture ${f.numero}: $e');
              }
            }

            // Ventes par mois avec gestion d'erreur
            final ventesParMois = <String, double>{};
            for (var f in filteredFactures) {
              try {
                final key = "${f.date.year}-${f.date.month.toString().padLeft(2, '0')}";
                final ttc = parseDouble(f.totalTTC);
                ventesParMois[key] = (ventesParMois[key] ?? 0) + ttc;
              } catch (e) {
                debugPrint('Erreur ventes par mois pour facture ${f.numero}: $e');
              }
            }
            final moisTries = ventesParMois.keys.toList()..sort();

            // Factures récentes (max 5)
            final recentFactures = List<Facture>.from(filteredFactures)
              ..sort((a, b) => b.date.compareTo(a.date));
            final lastFactures = recentFactures.take(5).toList();

            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 110,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text('Statistiques', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.download),
                      tooltip: "Exporter",
                      onPressed: () {
                        // TODO: Exporter les stats
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.brightness_6),
                      tooltip: "Mode sombre",
                      onPressed: () {
                        // TODO: Gérer le dark mode
                      },
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Filtres rapides
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedYear,
                                items: [
                                  ...{...factures.map((f) => f.date.year.toString())}.toList()
                                    ..sort((a, b) => b.compareTo(a))
                                ].map((y) =>
                                  DropdownMenuItem(value: y, child: Text("Année $y"))
                                ).toList(),
                                onChanged: (v) {
                                  if (v != null) setState(() => selectedYear = v);
                                },
                                decoration: const InputDecoration(
                                  labelText: "Filtrer par année",
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  labelText: "Recherche client",
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.search),
                                ),
                                onChanged: (txt) {
                                  setState(() => searchClient = txt);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Statistiques globales
                        SizedBox(
                          height: 200,
                          child: GridView.count(
                            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _StatCard(
                                label: "Chiffre d'affaires TTC",
                                value: "${totalTTC.toStringAsFixed(2)} DH",
                                icon: Icons.attach_money_rounded,
                                color: Colors.green.shade600,
                              ),
                              _StatCard(
                                label: "Chiffre d'affaires HT",
                                value: "${totalHT.toStringAsFixed(2)} DH",
                                icon: Icons.money_off_csred_rounded,
                                color: Colors.teal.shade600,
                              ),
                              _StatCard(
                                label: "Factures émises",
                                value: "$totalFactures",
                                icon: Icons.receipt_long_rounded,
                                color: Colors.blue.shade600,
                              ),
                              _StatCard(
                                label: "Clients",
                                value: "$totalClients",
                                icon: Icons.people_alt_rounded,
                                color: Colors.indigo.shade600,
                              ),
                              _StatCard(
                                label: "Produits vendus",
                                value: "$totalProduitsVendus",
                                icon: Icons.shopping_bag_rounded,
                                color: Colors.orange.shade600,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Graphique ventes par mois
                        Text("Ventes par mois (TTC)", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: SizedBox(
                              height: 220,
                              child: moisTries.isEmpty
                                  ? const Center(child: Text("Aucune donnée"))
                                  : BarChart(
                                BarChartData(
                                  borderData: FlBorderData(show: false),
                                  gridData: FlGridData(show: false),
                                  titlesData: FlTitlesData(
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          final idx = value.toInt();
                                          if (idx < 0 || idx >= moisTries.length) return const SizedBox();
                                          final m = moisTries[idx].split('-');
                                          return Text("${m[1]}/${m[0]}", style: const TextStyle(fontSize: 10));
                                        },
                                      ),
                                    ),
                                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  ),
                                  barGroups: List.generate(moisTries.length, (i) {
                                    return BarChartGroupData(
                                      x: i,
                                      barRods: [
                                        BarChartRodData(
                                          toY: ventesParMois[moisTries[i]] ?? 0,
                                          color: Colors.blue.shade700,
                                          width: 18,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ],
                                    );
                                  }),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Chiffre d'affaires par client
                        Text("CA par client", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: SizedBox(
                              height: 180,
                              child: caParClient.isEmpty
                                  ? const Center(child: Text("Aucun client"))
                                  : PieChart(
                                PieChartData(
                                  sections: caParClient.entries.map((e) {
                                    final idx = caParClient.keys.toList().indexOf(e.key);
                                    final color = Colors.primaries[idx % Colors.primaries.length];
                                    return PieChartSectionData(
                                      value: e.value,
                                      title: e.key.length > 10 ? '${e.key.substring(0, 10)}…' : e.key,
                                      color: color,
                                      radius: 60,
                                      titleStyle: const TextStyle(fontSize: 12, color: Colors.white),
                                    );
                                  }).toList(),
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 30,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Chiffre d'affaires par produit
                        Text("CA par produit", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: caParProduit.isEmpty
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(20),
                                      child: Text("Aucun produit vendu"),
                                    ),
                                  )
                                : Column(
                                    children: caParProduit.entries.map((e) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 120, 
                                            child: Text(
                                              e.key, 
                                              style: const TextStyle(fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            )
                                          ),
                                          Expanded(
                                            child: LinearProgressIndicator(
                                              value: totalHT == 0 ? 0 : (e.value / totalHT).clamp(0.0, 1.0),
                                              color: Colors.purple,
                                              backgroundColor: Colors.purple.shade100,
                                              minHeight: 10,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text("${e.value.toStringAsFixed(2)} DH", style: const TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                    )).toList(),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Factures récentes
                        Text("Factures récentes", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: lastFactures.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Center(child: Text("Aucune facture récente")),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: lastFactures.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (context, i) {
                                    final f = lastFactures[i];
                                    return ListTile(
                                      leading: const Icon(Icons.receipt_long_rounded),
                                      title: Text("Facture n°${f.numero} - ${f.nomClient ?? 'Client non spécifié'}"),
                                      subtitle: Text("Date: ${f.date.day}/${f.date.month}/${f.date.year} - TTC: ${parseDouble(f.totalTTC).toStringAsFixed(2)} DH"),
                                      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
                                      onTap: () {
                                        // TODO: Afficher le détail de la facture
                                      },
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 10),
          Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: Colors.black87)),
        ],
      ),
    );
  }
}

// Fonction améliorée pour parser les doubles
double parseDouble(dynamic value) {
  if (value == null) return 0.0;
  
  // Si c'est déjà un nombre
  if (value is num) return value.toDouble();
  
  // Si c'est une chaîne
  if (value is String) {
    // Nettoyer la chaîne : enlever les espaces et caractères non numériques sauf . , -
    String cleaned = value.trim().replaceAll(RegExp(r'[^\d\-,\.]'), '');
    
    // Remplacer les virgules par des points pour la notation décimale
    cleaned = cleaned.replaceAll(',', '.');
    
    // Tenter de parser
    final result = double.tryParse(cleaned);
    if (result != null) return result;
    
    // Si échec, essayer de parser comme int puis convertir
    final intResult = int.tryParse(cleaned.split('.')[0]);
    return intResult?.toDouble() ?? 0.0;
  }
  
  return 0.0;
}

// Fonction améliorée pour parser les entiers
int parseInt(dynamic value) {
  if (value == null) return 0;
  
  // Si c'est déjà un entier
  if (value is int) return value;
  
  // Si c'est un nombre à virgule, le convertir
  if (value is num) return value.toInt();
  
  // Si c'est une chaîne
  if (value is String) {
    // Nettoyer la chaîne
    String cleaned = value.trim().replaceAll(RegExp(r'[^\d\-]'), '');
    
    // Tenter de parser
    final result = int.tryParse(cleaned);
    if (result != null) return result;
    
    // Si échec, essayer de parser comme double puis convertir
    final doubleResult = double.tryParse(value.trim().replaceAll(',', '.'));
    return doubleResult?.toInt() ?? 0;
  }
  
  return 0;
}