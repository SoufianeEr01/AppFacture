import 'dart:io';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/facture.dart';

class FactureService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  dynamic convertIntsToStrings(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(
        value.map((k, v) => MapEntry(k.toString(), convertIntsToStrings(v))),
      );
    } else if (value is List) {
      return value.map(convertIntsToStrings).toList();
    } else if (value is int) {
      return value.toString();
    } else {
      return value;
    }
  }

  Future<int> getNextFactureNumber() async {
    final docRef = _db.collection('numerotation').doc('factures');
    return _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      int current = snapshot.exists && snapshot.data()!.containsKey('dernierNumero')
          ? snapshot.get('dernierNumero')
          : 0;
      transaction.set(docRef, {'dernierNumero': current + 1}, SetOptions(merge: true));
      return current + 1;
    });
  }

  Future<String> saveFactureAndGeneratePDF(Facture facture) async {
    try {
      final docId = const Uuid().v4();
      final docRef = _db.collection('factures').doc(docId);
      final pdfFile = await generatePdf(facture);
      final pdfDriveId = await uploadPdfToGoogleDrive(pdfFile);
      
      // Générer l'URL de visualisation Google Drive
      final pdfUrl = 'https://drive.google.com/file/d/$pdfDriveId/view';

      // Récupérer le Map de la facture et ajouter les nouveaux champs
      final factureMap = facture.toMap();
      factureMap['id'] = docId;
      factureMap['pdfDriveId'] = pdfDriveId;
      factureMap['pdfUrl'] = pdfUrl;

      await docRef.set(convertIntsToStrings(factureMap));
      
      print("Facture sauvegardée avec succès ");
  
      
      return pdfUrl; // Retourner l'URL au lieu de l'ID
    } catch (e) {
      print("Erreur dans saveFactureAndGeneratePDF: $e");
      rethrow;
    }
  }

  Future<File> generatePdf(Facture facture) async {
    final pdf = pw.Document();
    final logoBytes = await rootBundle.load('assets/logo.png');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/facture_${facture.numero}.pdf');

    final montantEnLettres = convertirMontantEnLettres(facture.totalTTC.toInt()) + ' dirhams';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Padding(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(logoImage, width: 80, height: 80),
                  pw.Text('FACTURE N°${facture.numero}',
                      style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Mon Entreprise ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Adresse : 123 Rue , Casablanca'),
                        pw.Text('Téléphone : +212 6 12 34 56 78'),
                        pw.Text('Email : contact@entreprise.com'),
                        pw.Text('ICE : 001234567890123'),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Client', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Nom : ${facture.nomClient}'),
                        pw.Text('Email : ${facture.emailClient}'),
                        pw.Text('ICE : ${facture.iceClient}'),
                        pw.Text('Date : ${DateFormat('dd/MM/yyyy').format(facture.date)}'),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
              
              // Tableau modifié avec la référence
              pw.Table.fromTextArray(
                headers: ['Produit','Référence', 'Prix HT', 'Quantité', 'Total HT'],
                data: facture.lignes.map((l) => [
                   // Utiliser la référence de la ligne
                  l.nomProduit,
                  l.reference,
                  '${l.prixHT.toStringAsFixed(2)} MAD',
                  '${l.quantite}',
                  '${l.totalLigne.toStringAsFixed(2)} MAD',
                ]).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                border: pw.TableBorder.all(),
                cellStyle: const pw.TextStyle(fontSize: 10),
                headerDecoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                cellAlignment: pw.Alignment.centerLeft,
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),   // Produit
                  1: const pw.FlexColumnWidth(2.5), // Référence
                  2: const pw.FlexColumnWidth(1.5), // Prix HT
                  3: const pw.FlexColumnWidth(1.5),   // Quantité
                  4: const pw.FlexColumnWidth(1.5), // Total HT
                },
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Total HT : ${facture.totalHT.toStringAsFixed(2)} MAD'),
                      pw.Text('TVA (20%) : ${(facture.totalHT * 0.2).toStringAsFixed(2)} MAD'),
                      pw.Text('Total TTC : ${facture.totalTTC.toStringAsFixed(2)} MAD',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 8),
                      pw.Text('Montant en lettres :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(montantEnLettres),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    await file.writeAsBytes(await pdf.save());
    return file;
  }

  String convertirMontantEnLettres(int n) {
    final unites = [
      '', 'un', 'deux', 'trois', 'quatre', 'cinq', 'six', 'sept', 'huit', 'neuf',
      'dix', 'onze', 'douze', 'treize', 'quatorze', 'quinze', 'seize',
      'dix-sept', 'dix-huit', 'dix-neuf'
    ];
    final dizaines = [
      '', '', 'vingt', 'trente', 'quarante', 'cinquante', 'soixante',
      'soixante', 'quatre-vingt', 'quatre-vingt'
    ];

    if (n == 0) return 'zéro';
    String resultat = '';

    if (n >= 1000) {
      final milliers = n ~/ 1000;
      if (milliers == 1) {
        resultat += 'mille';
      } else if (milliers < 20) {
        resultat += unites[milliers] + ' mille';
      } else {
        resultat += convertirMontantEnLettres(milliers) + ' mille';
      }
      n %= 1000;
      if (n > 0) resultat += ' ';
    }

    if (n >= 100) {
      final centaines = n ~/ 100;
      if (centaines == 1) {
        resultat += 'cent';
      } else if (centaines < 20) {
        resultat += unites[centaines] + ' cent';
      } else {
        resultat += convertirMontantEnLettres(centaines) + ' cent';
      }
      n %= 100;
      if (n > 0) resultat += ' ';
    }

    if (n >= 20) {
      final dix = n ~/ 10;
      var unite = n % 10;
      if (dix == 7) { // soixante-dix
        resultat += 'soixante';
        if (unite == 0) {
          resultat += '-dix';
        } else {
          resultat += '-${unites[10 + unite]}';
        }
      } else if (dix == 9) { // quatre-vingt-dix
        resultat += 'quatre-vingt';
        if (unite == 0) {
          resultat += '-dix';
        } else {
          resultat += '-${unites[10 + unite]}';
        }
      } else {
        resultat += dizaines[dix];
        if (unite == 1 && dix != 8) {
          resultat += '-et-un';
        } else if (unite > 0) {
          resultat += '-${unites[unite]}';
        }
      }
    } else if (n > 0) {
      resultat += unites[n];
    }

    return resultat.trim();
  }

  Future<String> uploadPdfToGoogleDrive(File pdfFile) async {
    final googleSignIn = GoogleSignIn(scopes: [drive.DriveApi.driveFileScope]);
    GoogleSignInAccount? account;
    try {
      account = await googleSignIn.signIn();
      if (account == null) throw Exception("Authentification Google annulée");
    } catch (e) {
      print("Erreur Google Sign-In: $e");
      rethrow;
    }

    final authHeaders = await account.authHeaders;
    if (authHeaders == null) throw Exception("Erreur d'authentification Google");

    final driveApi = drive.DriveApi(GoogleAuthClient(authHeaders));
    final fileToUpload = drive.File()
      ..name = pdfFile.path.split(Platform.pathSeparator).last;

    final media = drive.Media(pdfFile.openRead(), await pdfFile.length());
    final uploadedFile = await driveApi.files.create(fileToUpload, uploadMedia: media);

    return uploadedFile.id ?? '';
  }

  Future<String> uploadPdfToStorage(File file, int numeroFacture) async {
    try {
      final fileName = 'facture_$numeroFacture.pdf';
      final ref = _storage.ref().child('factures/$fileName');
      final uploadTask = ref.putFile(file);
      await uploadTask;
      return await ref.getDownloadURL();
    } catch (e) {
      print("❌ Erreur Firebase Storage: $e");
      rethrow;
    }
  }

  Future<List<Facture>> getAllFactures() async {
    final snapshot = await _db.collection('factures').get();
    return snapshot.docs.map((doc) => Facture.fromMap(doc.data() as Map<String, dynamic>)).toList();
  }
}

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();
  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}
