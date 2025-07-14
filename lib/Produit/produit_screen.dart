import 'package:flutter/material.dart';
import '../models/Produit.dart';
import '../service/produit_service.dart';
import '../service/import_export_service.dart';
import 'ajouter_produit_screen.dart';

class ProduitScreen extends StatefulWidget {
  const ProduitScreen({super.key});

  @override
  State<ProduitScreen> createState() => _ProduitScreenState();
}

class _ProduitScreenState extends State<ProduitScreen> {
  final ProduitService _service = ProduitService();
  final ImportExportService _importExportService = ImportExportService();

  void _showProductDetails(Produit produit) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 8,
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.grey.shade50],
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.inventory_2, size: 32, color: Colors.blue.shade600),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        produit.nom,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Description
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Description',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                      const SizedBox(height: 8),
                      Text(
                        produit.description.isNotEmpty ? produit.description : 'Aucune description disponible',
                        style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Prix
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Prix HT',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
                      Text(
                        '${produit.prixHT.toStringAsFixed(2)} DH',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Supprimer bouton
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _confirmDelete(produit);
                    },
                    icon: const Icon(Icons.delete_outline, size: 20),
                    label: const Text('Supprimer le produit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(Produit produit) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmer la suppression', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Êtes-vous sûr de vouloir supprimer "${produit.nom}" ?', style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Annuler', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await _service.supprimerProduit(produit.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${produit.nom} supprimé avec succès'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Erreur lors de la suppression: $e'),
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

  // Méthodes d'importation et d'exportation
  Future<void> _importerProduits() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final result = await _importExportService.importerProduits();
      
      if (mounted) {
        Navigator.of(context).pop(); // Fermer le dialogue de chargement
        
        final snackBar = SnackBar(
          content: Row(
            children: [
              Icon(
                result['success'] ? Icons.check_circle : Icons.error,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(result['message'])),
            ],
          ),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
        );
        
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
        
        // Afficher les détails des erreurs si nécessaire
        if (!result['success'] && result['errors'] != null && result['errors'].isNotEmpty) {
          _afficherDetailsErreurs(result['errors']);
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'importation: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _afficherDetailsErreurs(List<String> erreurs) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Détails des erreurs'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: erreurs.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                erreurs[index],
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _exporterProduits() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Exporter les produits',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.table_chart, color: Colors.green.shade600),
              ),
              title: const Text('Exporter en CSV'),
              subtitle: const Text('Format compatible avec Excel'),
              onTap: () {
                Navigator.of(context).pop();
                _exporterCSV();
              },
            ),
            
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.grid_on, color: Colors.blue.shade600),
              ),
              title: const Text('Exporter en Excel'),
              subtitle: const Text('Format Excel natif'),
              onTap: () {
                Navigator.of(context).pop();
                _exporterExcel();
              },
            ),
            
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _exporterCSV() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await _importExportService.exporterProduitsCSV();
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  result['success'] ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(result['message'])),
              ],
            ),
            backgroundColor: result['success'] ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'exportation: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _exporterExcel() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await _importExportService.exporterProduitsExcel();
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  result['success'] ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(result['message'])),
              ],
            ),
            backgroundColor: result['success'] ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'exportation: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _telechargerModele() async {
    try {
      final result = await _importExportService.telechargerModeleCSV();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  result['success'] ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(result['message'])),
              ],
            ),
            backgroundColor: result['success'] ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Mes Produits', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        backgroundColor: Colors.blue.shade600,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              switch (value) {
                case 'import':
                  _importerProduits();
                  break;
                case 'export':
                  _exporterProduits();
                  break;
                case 'template':
                  _telechargerModele();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.upload_file, color: Colors.blue),
                    SizedBox(width: 12),
                    Text('Importer des produits'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download, color: Colors.green),
                    SizedBox(width: 12),
                    Text('Exporter les produits'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'template',
                child: Row(
                  children: [
                    Icon(Icons.file_download, color: Colors.orange),
                    SizedBox(width: 12),
                    Text('Télécharger modèle'),
                  ],
                ),
              ),
            ],
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade600, Colors.blue.shade700],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AjoutProduitScreen()));
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Ajouter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.blue.shade600,
        elevation: 4,
      ),
      body: StreamBuilder<List<Produit>>(
        stream: _service.ecouterProduits(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.blue.shade600)),
                const SizedBox(height: 16),
                Text('Chargement des produits...', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
              ]),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text('Erreur de chargement',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red.shade600)),
                const SizedBox(height: 8),
                Text('${snapshot.error}', style: TextStyle(fontSize: 14, color: Colors.grey.shade600), textAlign: TextAlign.center),
              ]),
            );
          }

          final produits = snapshot.data ?? [];

          if (produits.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade400),
                const SizedBox(height: 20),
                Text('Aucun produit disponible',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                Text('Appuyez sur + pour ajouter votre premier produit',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
              ]),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListView.builder(
              itemCount: produits.length,
              itemBuilder: (context, index) {
                final produit = produits[index];
                return GestureDetector(
                  onTap: () => _showProductDetails(produit),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade300,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.inventory_2, size: 32, color: Colors.blue.shade600),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                produit.nom,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.shade200),
                                ),
                                child: Text(
                                  '${produit.prixHT.toStringAsFixed(2)} DH',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
