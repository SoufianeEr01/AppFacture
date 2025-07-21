import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/Produit.dart';
import 'produit_service.dart';

class ImportExportService {
  final ProduitService _produitService = ProduitService();

  // Importation des produits depuis un fichier CSV ou Excel
  Future<Map<String, dynamic>> importerProduits() async {
    try {
      // Sélectionner le fichier
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return {
          'success': false,
          'message': 'Aucun fichier sélectionné',
          'count': 0,
        };
      }

      final file = File(result.files.single.path!);
      final extension = result.files.single.extension?.toLowerCase();

      List<List<dynamic>> rows = [];

      if (extension == 'csv') {
        // Lecture du fichier CSV
        final csvData = await file.readAsString();
        rows = const CsvToListConverter().convert(csvData);
      } else if (extension == 'xlsx' || extension == 'xls') {
        // Lecture du fichier Excel
        final bytes = await file.readAsBytes();
        final excel = Excel.decodeBytes(bytes);
        
        // Prendre la première feuille
        final sheet = excel.tables.values.first;
        rows = sheet.rows.map((row) => row.map((cell) => cell?.value).toList()).toList();
      }

      if (rows.isEmpty) {
        return {
          'success': false,
          'message': 'Le fichier est vide ou illisible',
          'count': 0,
        };
      }

      // Valider et importer les produits
      return await _traiterDonneesImportees(rows);

    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur lors de l\'importation: $e',
        'count': 0,
      };
    }
  }

  // Traitement des données importées
  Future<Map<String, dynamic>> _traiterDonneesImportees(List<List<dynamic>> rows) async {
    int compteurReussi = 0;
    List<String> erreurs = [];

    // Ignorer la première ligne si c'est un en-tête
    final bool hasHeader = _detecterEnTete(rows.first);
    final startIndex = hasHeader ? 1 : 0;

    for (int i = startIndex; i < rows.length; i++) {
      try {
        final row = rows[i];
        
        // Vérifier que la ligne a au moins 3 colonnes (nom, référence, prix)
        if (row.length < 3) {
          erreurs.add('Ligne ${i + 1}: Données insuffisantes (nom, référence, prix requis)');
          continue;
        }

        // Extraire les données selon le nouveau format
        final nom = row[0]?.toString().trim() ?? '';
        final reference = row[1]?.toString().trim() ?? '';
        final prixString = row[2]?.toString().trim() ?? '';
        final description = row.length > 3 ? row[3]?.toString().trim() ?? '' : '';

        // Valider les données
        if (nom.isEmpty) {
          erreurs.add('Ligne ${i + 1}: Nom du produit manquant');
          continue;
        }

        if (reference.isEmpty) {
          erreurs.add('Ligne ${i + 1}: Référence du produit manquante');
          continue;
        }

        // Vérifier l'unicité de la référence
        final produits = await _produitService.obtenirTousLesProduits();
        final referenceExists = produits.any((p) => p.reference.toLowerCase() == reference.toLowerCase());
        if (referenceExists) {
          erreurs.add('Ligne ${i + 1}: Référence "$reference" déjà existante');
          continue;
        }

        double? prix;
        try {
          prix = double.parse(prixString.replaceAll(',', '.'));
        } catch (e) {
          erreurs.add('Ligne ${i + 1}: Prix invalide ($prixString)');
          continue;
        }

        if (prix <= 0) {
          erreurs.add('Ligne ${i + 1}: Le prix doit être positif');
          continue;
        }

        // Créer le produit
        final produit = Produit(
          id: const Uuid().v4(),
          nom: nom,
          reference: reference, // Utiliser la référence fournie
          description: description,
          prixHT: prix,
        );

        // Ajouter le produit
        await _produitService.ajouterProduit(produit);
        compteurReussi++;

      } catch (e) {
        erreurs.add('Ligne ${i + 1}: Erreur - $e');
      }
    }

    return {
      'success': compteurReussi > 0,
      'message': _genererMessageResultat(compteurReussi, erreurs),
      'count': compteurReussi,
      'errors': erreurs,
    };
  }

  // Détecter si la première ligne est un en-tête
  bool _detecterEnTete(List<dynamic> premiereLigne) {
    if (premiereLigne.isEmpty) return false;
    
    final premiereValeur = premiereLigne[0]?.toString().toLowerCase() ?? '';
    final deuxiemeValeur = premiereLigne.length > 1 ? premiereLigne[1]?.toString().toLowerCase() ?? '' : '';
    final troisiemeValeur = premiereLigne.length > 2 ? premiereLigne[2]?.toString().toLowerCase() ?? '' : '';
    
    return premiereValeur.contains('nom') || 
           premiereValeur.contains('produit') ||
           deuxiemeValeur.contains('ref') ||
           deuxiemeValeur.contains('référence') ||
           troisiemeValeur.contains('prix') ||
           troisiemeValeur.contains('price');
  }

  // Générer le message de résultat
  String _genererMessageResultat(int compteurReussi, List<String> erreurs) {
    if (compteurReussi == 0) {
      return 'Aucun produit importé. ${erreurs.length} erreur(s) détectée(s).';
    }
    
    String message = '$compteurReussi produit(s) importé(s) avec succès';
    if (erreurs.isNotEmpty) {
      message += ', ${erreurs.length} erreur(s) ignorée(s)';
    }
    return message;
  }

  // Exportation des produits vers un fichier CSV
  Future<Map<String, dynamic>> exporterProduitsCSV() async {
    try {
      // Récupérer tous les produits
      final produits = await _produitService.obtenirTousLesProduits();
      
      if (produits.isEmpty) {
        return {
          'success': false,
          'message': 'Aucun produit à exporter',
        };
      }

      // Préparer les données CSV avec la référence
      List<List<dynamic>> rows = [
        ['Nom', 'Référence', 'Prix HT (DH)', 'Description'], // En-tête mis à jour
      ];

      for (final produit in produits) {
        rows.add([
          produit.nom,
          produit.reference, // Ajouter la référence
          produit.prixHT.toStringAsFixed(2),
          produit.description,
        ]);
      }

      // Convertir en CSV
      final csvData = const ListToCsvConverter().convert(rows);

      // Créer le fichier
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'produits_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csvData);

      // Partager le fichier
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Export des produits',
        subject: 'Liste des produits',
      );

      return {
        'success': true,
        'message': '${produits.length} produit(s) exporté(s) avec succès',
        'filePath': file.path,
      };

    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur lors de l\'exportation: $e',
      };
    }
  }

  // Exportation des produits vers un fichier Excel
  Future<Map<String, dynamic>> exporterProduitsExcel() async {
    try {
      // Récupérer tous les produits
      final produits = await _produitService.obtenirTousLesProduits();
      
      if (produits.isEmpty) {
        return {
          'success': false,
          'message': 'Aucun produit à exporter',
        };
      }

      // Créer le fichier Excel
      final excel = Excel.createExcel();
      final sheet = excel['Produits'];

      // Supprimer la feuille par défaut
      excel.delete('Sheet1');

      // Ajouter l'en-tête avec la référence
      sheet.appendRow([
        TextCellValue('Nom'),
        TextCellValue('Référence'), // Ajouter la référence
        TextCellValue('Prix HT (DH)'),
        TextCellValue('Description'),
      ]);

      // Ajouter les données
      for (final produit in produits) {
        sheet.appendRow([
          TextCellValue(produit.nom),
          TextCellValue(produit.reference), // Ajouter la référence
          DoubleCellValue(produit.prixHT),
          TextCellValue(produit.description),
        ]);
      }

      // Sauvegarder le fichier
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'produits_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File('${directory.path}/$fileName');
      
      final bytes = excel.encode();
      if (bytes != null) {
        await file.writeAsBytes(bytes);

        // Partager le fichier
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Export des produits',
          subject: 'Liste des produits',
        );

        return {
          'success': true,
          'message': '${produits.length} produit(s) exporté(s) avec succès',
          'filePath': file.path,
        };
      } else {
        return {
          'success': false,
          'message': 'Erreur lors de la création du fichier Excel',
        };
      }

    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur lors de l\'exportation: $e',
      };
    }
  }

  // Télécharger un modèle CSV
  Future<Map<String, dynamic>> telechargerModeleCSV() async {
    try {
      // Créer un fichier modèle avec la référence
      List<List<dynamic>> rows = [
        ['Nom', 'Référence', 'Prix HT (DH)', 'Description'], // Ordre mis à jour
        ['Exemple Produit 1', 'REF-001', '25.50', 'Description du produit 1'],
        ['Exemple Produit 2', 'REF-002', '45.00', 'Description du produit 2'],
        ['Exemple Produit 3', 'REF-003', '12.75', ''], // Description optionnelle
      ];

      final csvData = const ListToCsvConverter().convert(rows);

      // Créer le fichier
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'modele_import_produits.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csvData);

      // Partager le fichier
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Modèle d\'importation des produits',
        subject: 'Modèle CSV',
      );

      return {
        'success': true,
        'message': 'Modèle téléchargé avec succès',
        'filePath': file.path,
      };

    } catch (e) {
      return {
        'success': false,
        'message': 'Erreur lors du téléchargement du modèle: $e',
      };
    }
  }
}
