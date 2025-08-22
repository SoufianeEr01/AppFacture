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

  // ----------------- Helpers -----------------
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

  // ----------------- Save + PDF + Drive -----------------
  Future<String> saveFactureAndGeneratePDF(Facture facture) async {
    try {
      final docId = const Uuid().v4();
      final docRef = _db.collection('factures').doc(docId);

      final pdfFile = await generatePdf(facture);

      final pdfDriveId = await uploadPdfToGoogleDrive(pdfFile);
      final pdfUrl = 'https://drive.google.com/file/d/$pdfDriveId/view';

      final factureMap = facture.toMap();
      factureMap['id'] = docId;
      factureMap['pdfDriveId'] = pdfDriveId;
      factureMap['pdfUrl'] = pdfUrl;

      await docRef.set(convertIntsToStrings(factureMap));
      return pdfUrl;
    } catch (e) {
      print("Erreur dans saveFactureAndGeneratePDF: $e");
      rethrow;
    }
  }

  // ----------------- Génération PDF (modèle Innovpal) -----------------
  Future<File> generatePdf(Facture facture) async {
    // Thème sans polices externes (évite RangeError)
    final theme = pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
    );

    // Logo (assure-toi que ce chemin existe)
    final logoBytes = await rootBundle.load('assets/logo_Innovpal.png');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    // Formats & couleurs
    final money = NumberFormat.currency(locale: 'fr_FR', symbol: '', decimalDigits: 2);
    String formatMoney(num v) => '${money.format(v)} DH';
    final cHeader = PdfColors.black;
    final cDivider = PdfColors.grey600;
    final cTableHead = PdfColors.grey300;
    final cTotalBox = PdfColor.fromInt(0xFFB57B45); // brun TOTAL TTC
    final cLight = PdfColors.grey800;
    final PdfColor cBrandBar = PdfColor.fromInt(0xFF8B5E2A);
    final borderAll = pw.TableBorder.all(color: PdfColors.black, width: 1.2);
final tableBorder = pw.TableBorder.all(color: PdfColors.black, width: 1.2);


    // Calculs (si ton modèle calcule déjà les totaux, tu peux substituer)
    final lignes = facture.lignes;
    final totalHT = lignes.fold<double>(0, (s, l) => s + (l.prixHT * l.quantite));
    const tvaRate = 0.20;
    final tva = totalHT * tvaRate;
    final totalTTC = totalHT + tva;

    final montantEnLettres = '${convertirMontantEnLettres(totalTTC.round())} DH TTC';

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18),
        header: (ctx) => pw.Container(
  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  color: PdfColors.black, // fond noir
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      // Bloc gauche (infos société)
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'INNOVPAL',
            style: pw.TextStyle(
              color: PdfColor.fromInt(0xFF8B5E2A), // marron du modèle
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            'Adresse: Résidence Almanzeh, GH20 IMM F ETG 1, APP3\nCasablanca',
            style: pw.TextStyle(color: PdfColors.white, fontSize: 8),
          ),
          pw.Text(
            'ICE: 003443138000074',
            style: pw.TextStyle(color: PdfColors.white, fontSize: 8),
          ),
          pw.Text(
            'Tél : 06 61 52 51 66',
            style: pw.TextStyle(color: PdfColors.white, fontSize: 8),
          ),
          pw.Text(
            '@ : contact@innovpal.com',
            style: pw.TextStyle(color: PdfColors.white, fontSize: 8),
          ),
          pw.Text(
            'www.innovpal.com',
            style: pw.TextStyle(color: PdfColors.white, fontSize: 8),
          ),
        ],
      ),

      // Bloc centre : logo
      pw.Image(logoImage, width: 60, height: 60),

      // Bloc droite : titre FACTURE
      pw.Text(
        'FACTURE',
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 26,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    ],
  ),
),

        footer: (ctx) => pw.Container(
  color: cBrandBar, // ton brun (#8B5E2A)
  padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      pw.Text(
        'INNOVPAL',
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
        textAlign: pw.TextAlign.center,
      ),
      pw.SizedBox(height: 3),
      pw.Text(
        'Adresse : Résidence Almanzeh, GH20 IMM F ETG 1, APP3 Casablanca. ICE : 003443138000074  IF : 60270306',
        style: const pw.TextStyle(fontSize: 7, color: PdfColors.white),
        textAlign: pw.TextAlign.center,
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        'Patente : 32758154  RC (Casablanca) : 616953  Tél : 06 61 52 51 66  '
        'Dépôt : innovpal Sidi Hajjaj Tit Mellil Casablanca  '
        'Email : contact@innovpal.com  Website : innovpal.com',
        style: const pw.TextStyle(fontSize: 7, color: PdfColors.white),
        textAlign: pw.TextAlign.center,
      ),
    ],
  ),
),

        build: (ctx) => [
          pw.SizedBox(height: 14),
          // ----- En-têtes -----
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Client : ${facture.nomClient}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  if ((facture.iceClient ?? '').isNotEmpty) pw.Text('ICE : ${facture.iceClient}'),
                ],
              ),
              pw.SizedBox(width: 12),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: cDivider, width: 0.8),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(children: [
                      pw.Text('N° de facture : ',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Fa-${facture.numero}')
                    ]),
                    pw.SizedBox(height: 4),
                    pw.Row(children: [
                      pw.Text('Date de facturation : ',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text(DateFormat('dd/MM/yyyy').format(facture.date))
                    ]),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),

          // ----- Tableau lignes -----
// ==== TABLEAU ====


// ---- Tableau principal (entête + lignes + sous‑totaux)
// ==== Tableau Produits + Totaux ====
// ==== TABLEAU FACTURE ====
// ==== TABLEAU FACTURE (identique au visuel) ====

pw.Table(
  border: tableBorder,
  columnWidths: const {
    0: pw.FlexColumnWidth(1.1), // QTE
    1: pw.FlexColumnWidth(3.2), // DESIGNATION
    2: pw.FlexColumnWidth(1.6), // PRIX UNIT HT
    3: pw.FlexColumnWidth(1.7), // MONTANT HT
  },
  children: [
    // ===== ENTÊTE =====
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.black),
      children: [
        buildCell('QTE', bold: true, align: pw.Alignment.center, color: PdfColors.white, height: 30),
        buildCell('DESIGNATION', bold: true, align: pw.Alignment.center, color: PdfColors.white, height: 30),
        buildCell('PRIX UNIT HT', bold: true, align: pw.Alignment.center, color: PdfColors.white, height: 30),
        buildCell('MONTANT HT', bold: true, align: pw.Alignment.center, color: PdfColors.white, height: 30),
      ],
    ),

    // ===== LIGNES PRODUITS =====
    ...lignes.map((l) {
      final montant = l.prixHT * l.quantite;
      return pw.TableRow(
        children: [
          buildCell('${l.quantite}', bold: true, align: pw.Alignment.center, height: 46),
          pw.Container(
            height: 46,
            padding: const pw.EdgeInsets.symmetric(horizontal: 6),
            alignment: pw.Alignment.center,
            child: pw.Text(
              l.nomProduit + ((l.reference ?? '').isNotEmpty ? ' (${l.reference})' : ''),
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
          ),
          buildCell(formatMoney(l.prixHT), align: pw.Alignment.center, height: 46),
          buildCell(formatMoney(montant), align: pw.Alignment.center, height: 46),
        ],
      );
    }),

    // ===== SOUS-TOTAL : MONTANT HT (sous-ligne couvrant les 4 colonnes avec séparation) =====
   // ==== SOUS-TOTAL : MONTANT HT ====
pw.TableRow(
  children: [
    // colonnes 1 & 2 -> invisibles (pas de bordure)
    pw.SizedBox(), 
    pw.SizedBox(), 

    // Colonne 3 : libellé "MONTANT HT"
    pw.Container(
      height: 30,
      alignment: pw.Alignment.center,
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.black, width: 1.2),
          bottom: pw.BorderSide(color: PdfColors.black, width: 1.2),
          left: pw.BorderSide(color: PdfColors.black, width: 1.2),
        ),
      ),
      child: pw.Text('MONTANT HT',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
    ),

    // Colonne 4 : valeur du total HT
    pw.Container(
      height: 30,
      alignment: pw.Alignment.center,
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.black, width: 1.2),
          bottom: pw.BorderSide(color: PdfColors.black, width: 1.2),
          right: pw.BorderSide(color: PdfColors.black, width: 1.2),
        ),
      ),
      child: pw.Text(formatMoney(totalHT),
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
    ),
  ],
),

// ==== TVA ====
pw.TableRow(
  children: [
    pw.SizedBox(),
    pw.SizedBox(),

    // Colonne 3 : sous-table TVA | 20%
    pw.Container(
      height: 30,
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.black, width: 1.2),
          bottom: pw.BorderSide(color: PdfColors.black, width: 1.2),
          left: pw.BorderSide(color: PdfColors.black, width: 1.2),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Container(
              alignment: pw.Alignment.center,
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  right: pw.BorderSide(color: PdfColors.black, width: 1.2),
                ),
              ),
              child: pw.Text('TVA',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            ),
          ),
          pw.Expanded(
            child: pw.Container(
              alignment: pw.Alignment.center,
              child: pw.Text('20%',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            ),
          ),
        ],
      ),
    ),

    // Colonne 4 : montant TVA
    pw.Container(
      height: 30,
      alignment: pw.Alignment.center,
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.black, width: 1.2),
          bottom: pw.BorderSide(color: PdfColors.black, width: 1.2),
          right: pw.BorderSide(color: PdfColors.black, width: 1.2),
        ),
      ),
      child: pw.Text(formatMoney(tva),
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
    ),
  ],
),  
  ],
),

// ===== BANDEAU TOTAL TTC (exactement aligné sur les 2 dernières colonnes) =====
pw.Row(
  children: [
    // Masquer visuellement les 2 premières colonnes par des espaces de même flex
    pw.Expanded(flex: 11, child: pw.SizedBox()),
    pw.Expanded(flex: 32, child: pw.SizedBox()),

    // Colonne 3 : libellé TOTAL TTC (fond marron + bordures haut/gauche/bas)
    pw.Expanded(
      flex: 16,
      child: pw.Container(
        height: 44,
        decoration: pw.BoxDecoration(
          color: cTotalBox,
          border: const pw.Border(
            top: pw.BorderSide(color: PdfColors.black, width: 1.2),
            left: pw.BorderSide(color: PdfColors.black, width: 1.2),
            bottom: pw.BorderSide(color: PdfColors.black, width: 1.2),
          ),
        ),
        padding: const pw.EdgeInsets.symmetric(horizontal: 10),
        alignment: pw.Alignment.centerLeft,
        child: pw.Text(
          'TOTAL TTC',
          style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 18),
        ),
      ),
    ),

    // Colonne 4 : valeur TTC (fond marron + bordure complète)
    pw.Expanded(
      flex: 17,
      child: pw.Container(
        height: 44,
        decoration: pw.BoxDecoration(
          color: cTotalBox,
          border: pw.Border.all(color: PdfColors.black, width: 1.2),
        ),
        padding: const pw.EdgeInsets.symmetric(horizontal: 10),
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          formatMoney(totalTTC),
          style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 18),
        ),
      ),
    ),
  ],
),



          pw.SizedBox(height: 16),

          // ----- Montant en lettres & signature -----
          pw.Text(
            'La présente facture est arrêtée à la somme de: $montantEnLettres',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 24),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.SizedBox(width: 1),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Signature'),
                  pw.SizedBox(height: 28),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    // Écriture
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/facture_${facture.numero}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // Cellule standard du tableau
  pw.Widget buildCell(
    String text, {
    bool bold = false,
    pw.Alignment align = pw.Alignment.centerLeft,
    double height = 28,
    PdfColor color = PdfColors.black, // ✅ nouveau paramètre

  }) {
    return pw.Container(
      alignment: align,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8),
      height: height,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          color: color, // ✅ utilisation du paramètre couleur
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  // Montant en lettres (FR simplifié)
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
    String res = '';
    int x = n;

    if (x >= 1000) {
      final milliers = x ~/ 1000;
      if (milliers == 1) {
        res += 'mille';
      } else if (milliers < 20) {
        res += '${unites[milliers]} mille';
      } else {
        res += '${convertirMontantEnLettres(milliers)} mille';
      }
      x %= 1000;
      if (x > 0) res += ' ';
    }

    if (x >= 100) {
      final centaines = x ~/ 100;
      if (centaines == 1) {
        res += 'cent';
      } else if (centaines < 20) {
        res += '${unites[centaines]} cent';
      } else {
        res += '${convertirMontantEnLettres(centaines)} cent';
      }
      x %= 100;
      if (x > 0) res += ' ';
    }

    if (x >= 20) {
      final dix = x ~/ 10;
      final unite = x % 10;
      if (dix == 7) {
        res += 'soixante';
        res += unite == 0 ? '-dix' : '-${unites[10 + unite]}';
      } else if (dix == 9) {
        res += 'quatre-vingt';
        res += unite == 0 ? '-dix' : '-${unites[10 + unite]}';
      } else {
        res += dizaines[dix];
        if (unite == 1 && dix != 8) {
          res += '-et-un';
        } else if (unite > 0) {
          res += '-${unites[unite]}';
        }
      }
    } else if (x > 0) {
      res += unites[x];
    }
    return res.trim();
  }

  // ----------------- Upload Drive -----------------
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

  // ----------------- (Optionnel) Upload Firebase Storage -----------------
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
    return snapshot.docs
        .map((doc) => Facture.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }
}

// Client HTTP Google
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
