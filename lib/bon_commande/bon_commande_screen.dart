// lib/bon_commande/bon_commande_screen.dart
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

// OCR + image + PDF
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as imglib;
import 'package:pdfx/pdfx.dart';

// === Domain/Services
import '../models/facture.dart';
import '../models/LigneFacture.dart';
import '../models/Client.dart';
import '../models/Produit.dart';
import '../service/client_service.dart';
import '../service/produit_service.dart';
import '../service/facture_service.dart';

/// =============== Modèle de token OCR (top-level !) ===============
class OcrToken {
  final String text;
  final double x, y, w, h;
  OcrToken(this.text, this.x, this.y, this.w, this.h);
  double get xc => x + w / 2;
  double get yc => y + h / 2;
}

class BonCommandeScreen extends StatefulWidget {
  const BonCommandeScreen({super.key});
  @override
  State<BonCommandeScreen> createState() => _BonCommandeScreenState();
}

class _BonCommandeScreenState extends State<BonCommandeScreen> {
  final ClientService _clientService = ClientService();
  final ProduitService _produitService = ProduitService();
  final FactureService _factureService = FactureService();

  bool _loading = false;
  File? _pickedFile;

  // Données éditables
  Map<String, String> _clientData = {'nom': '', 'email': '', 'ice': ''};
  List<Map<String, dynamic>> _lignesData = [];

  // logs debug visibles via bouton
  String _debug = '';
  void _log(String m) {
    _debug += '${DateTime.now().toIso8601String().substring(11, 19)}  $m\n';
    // ignore: avoid_print
    print(m);
  }

  final _formKey = GlobalKey<FormState>();

  // -------------------- UI SOURCE CHOIX --------------------
  Future<void> _showSourceChoice() async {
    final choice = await showModalBottomSheet<String?>(
      context: context,
      builder: (c) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text("Scanner (caméra)"),
            onTap: () => Navigator.pop(c, 'camera'),
          ),
          ListTile(
            leading: const Icon(Icons.image),
            title: const Text("Image (galerie)"),
            onTap: () => Navigator.pop(c, 'image'),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf),
            title: const Text("PDF"),
            onTap: () => Navigator.pop(c, 'pdf'),
          ),
        ]),
      ),
    );

    if (choice == 'camera') {
      await _takePhoto();
    } else if (choice == 'image') {
      await _pickImage();
    } else if (choice == 'pdf') {
      await _pickPdf();
    }
  }

  Future<void> _takePhoto() async {
    final st = await Permission.camera.request();
    if (!st.isGranted) {
      _toast("Permission caméra refusée");
      return;
    }
    final picker = ImagePicker();
    final shot = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 95,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (shot == null) return;
    final f = File(shot.path);
    setState(() => _pickedFile = f);
    await _processFile(f);
  }

  Future<void> _pickImage() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
    );
    if (res == null || res.files.single.path == null) return;
    final f = File(res.files.single.path!);
    setState(() => _pickedFile = f);
    await _processFile(f);
  }

  Future<void> _pickPdf() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (res == null || res.files.single.path == null) return;
    final f = File(res.files.single.path!);
    setState(() => _pickedFile = f);
    await _processFile(f);
  }

  // -------------------- PIPELINE --------------------
  Future<void> _processFile(File file) async {
    setState(() => _loading = true);
    _debug = '';
    try {
      _log('Fichier: ${file.path}');
      final ext = file.path.toLowerCase().split('.').last;

      // 1) Constituer la liste d’images à OCR
      final images = <File>[];
      if (ext == 'pdf') {
        _log('PDF détecté → conversion PDF → PNG');
        images.addAll(await _pdfToImages(file));
      } else {
        images.add(file);
      }

      if (images.isEmpty) {
        _toast("Impossible de lire le document");
        return;
      }

      // 2) OCR ML Kit (conserve la géométrie)
      final tokens = await _runOcrTokens(images);
      _log('Tokens OCR: ${tokens.length}');
      if (tokens.isEmpty) {
        _toast("Aucun texte détecté (modèle non prêt ou image illisible).");
        return;
      }

      // 3) Parsing + normalisations (basé géométrie + colonnes)
      final parsed = _parseFromTokens(tokens);
      _postValidate(parsed);

      // 4) Remplir l'UI
      final client = (parsed['client'] ?? {}) as Map<String, dynamic>;
      final lignes = (parsed['lignes'] ?? []) as List;

      _clientData = {
        'nom': (client['nom'] ?? '').toString(),
        'email': (client['email'] ?? '').toString(),
        'ice': (client['ice'] ?? '').toString(),
      };

      _lignesData = lignes.map<Map<String, dynamic>>((l) {
        final m = Map<String, dynamic>.from(l as Map);
        return {
          'produitId': (m['produitId'] ?? '').toString(),
          'nomProduit': (m['nomProduit'] ?? '').toString(),
          'reference': (m['reference'] ?? '').toString(),
          'prixHT': (m['prixHT'] is num)
              ? (m['prixHT'] as num).toDouble()
              : double.tryParse('${m['prixHT']}') ?? 0.0,
          'quantite': (m['quantite'] is num)
              ? (m['quantite'] as num).toInt()
              : int.tryParse('${m['quantite']}') ?? 1,
        };
      }).toList();

      // 5) Rapprochement avec la base + vérifications
      await _snapToKnownProducts();
      await _verifyExistence();

      _toast('Extraction OK — ${_lignesData.length} ligne(s)');
      setState(() {});
    } catch (e) {
      _log('Erreur: $e');
      _toast('Erreur extraction: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // --- PDF → Images (conversion robuste) ---
  Future<List<File>> _pdfToImages(File pdfFile) async {
    final out = <File>[];
    PdfDocument? doc;
    try {
      _log('[PDF] Ouverture du fichier PDF: ${pdfFile.path}');
      doc = await PdfDocument.openFile(pdfFile.path);
      final tmp = await getTemporaryDirectory();

      _log('[PDF] Nombre de pages: ${doc.pagesCount}');

      for (int i = 1; i <= doc.pagesCount; i++) {
        _log('[PDF] Traitement page $i/${doc.pagesCount}');
        final page = await doc.getPage(i);

        // 300–350 DPI
        final double dw = page.width * 3.5;
        final double dh = page.height * 3.5;

        PdfPageImage? pageImage;
        try {
          pageImage = await page.render(
            width: dw,
            height: dh,
            format: PdfPageImageFormat.png,
          );
        } catch (_) {
          pageImage = await page.render(width: dw, height: dh);
        }

        await page.close();

        if (pageImage == null || pageImage.bytes.isEmpty) {
          _log('[PDF] Erreur: impossible de rendre la page $i');
          continue;
        }

        File outFile;

        if (pageImage.format == PdfPageImageFormat.png) {
          outFile = File('${tmp.path}/ocr_page_$i.png');
          await outFile.writeAsBytes(pageImage.bytes, flush: true);
        } else {
          // RGBA → PNG
          final rgba = pageImage.bytes;
          final img = imglib.Image.fromBytes(
            width: dw.round(),
            height: dh.round(),
            bytes: rgba.buffer,
            numChannels: 4,
            order: imglib.ChannelOrder.rgba,
          );
          final pngBytes = imglib.encodePng(img);
          outFile = File('${tmp.path}/ocr_page_$i.png');
          await outFile.writeAsBytes(pngBytes, flush: true);
        }

        out.add(outFile);
        _log('[PDF] Page $i convertie: ${outFile.path}');
      }
    } catch (e) {
      _log('[PDF] Erreur conversion: $e');
      return [pdfFile];
    }
    _log('[PDF] Conversion terminée: ${out.length} image(s) générée(s)');
    return out;
  }

  // ================= OCR avancé (tokens avec géométrie) =================

  // OCR → tokens (avec fallback: pré-traitement + rotations)
  Future<List<OcrToken>> _runOcrTokens(List<File> images) async {
    final rec = TextRecognizer(script: TextRecognitionScript.latin);
    final tokens = <OcrToken>[];

    Future<List<OcrToken>> processOne(File f) async {
      final local = <OcrToken>[];
      final res = await rec.processImage(InputImage.fromFile(f));
      for (final b in res.blocks) {
        for (final l in b.lines) {
          for (final e in l.elements) {
            final r = e.boundingBox;
            final txt = e.text.trim();
            if (r == null || txt.isEmpty) continue;
            local.add(OcrToken(
              txt,
              r.left.toDouble(),
              r.top.toDouble(),
              r.width.toDouble(),
              r.height.toDouble(),
            ));
          }
        }
      }
      return local;
    }

    try {
      for (final f in images) {
        _log('OCR image: ${f.path}');
        // 1) direct
        var loc = await processOne(f);
        _log('  tokens: ${loc.length}');
        if (loc.isEmpty) {
          // 2) pré-traitement
          final prep = await _preprocessForOcr(f, aggressive: true);
          loc = await processOne(prep);
          _log('  tokens après preprocess: ${loc.length}');
        }
        if (loc.isEmpty) {
          // 3) rotations 90/270
          for (final deg in [90, 270]) {
            try {
              final src = imglib.decodeImage(await f.readAsBytes());
              if (src == null) continue;
              final rot = imglib.copyRotate(src, angle: deg);
              final tmp = File(
                f.path.replaceFirst(RegExp(r'\.(png|jpg|jpeg)$', caseSensitive: false), '_rot$deg.png'),
              );
              await tmp.writeAsBytes(imglib.encodePng(rot), flush: true);
              loc = await processOne(tmp);
              _log('  tokens après rotation $deg°: ${loc.length}');
              if (loc.isNotEmpty) break;
            } catch (e) {
              _log('  rotation $deg KO: $e');
            }
          }
        }
        tokens.addAll(loc);
      }
    } finally {
      await rec.close();
    }

    tokens.sort((a, b) => a.y.compareTo(b.y)); // tri vertical global
    return tokens;
  }

  // ===== Helpers de proximité / formats =====
  OcrToken? _nearestToX(List<OcrToken> list, double? targetX) {
    if (list.isEmpty || targetX == null) return null;
    OcrToken best = list.first;
    double bestD = (best.xc - targetX).abs();
    for (final t in list.skip(1)) {
      final d = (t.xc - targetX).abs();
      if (d < bestD) {
        best = t;
        bestD = d;
      }
    }
    return best;
  }

  bool _isIntegerLike(String s) {
    final t = s.replaceAll('\u00A0', '').replaceAll(' ', '');
    return RegExp(r'^\d+$').hasMatch(t);
  }

  // ===== Parse robuste basé sur la géométrie + colonnes =====
  Map<String, dynamic> _parseFromTokens(List<OcrToken> toks) {
    if (toks.isEmpty) {
      return {
        'client': {'nom': '', 'email': 'client@example.com', 'ice': '000000000000000'},
        'lignes': []
      };
    }

    // métriques de regroupement
    final heights = toks.map((t) => t.h).toList()..sort();
    final rowH = heights[heights.length ~/ 2]; // médiane
    final yTol = rowH * 0.6;

    // groupage en lignes (par y)
    final rows = <List<OcrToken>>[];
    var current = <OcrToken>[];
    double? yRef;
    for (final t in toks..sort((a, b) => a.y.compareTo(b.y))) {
      if (yRef == null || (t.y - yRef).abs() <= yTol) {
        current.add(t);
        yRef = (yRef == null) ? t.y : (yRef + t.y) / 2;
      } else {
        current.sort((a, b) => a.x.compareTo(b.x));
        rows.add(current);
        current = [t];
        yRef = t.y;
      }
    }
    if (current.isNotEmpty) {
      current.sort((a, b) => a.x.compareTo(b.x));
      rows.add(current);
    }

    // Chercher ligne d’en-tête (mots-clés)
    int headerIdx = rows.indexWhere((r) {
      final s = r.map((t) => t.text.toLowerCase()).join(' ');
      return s.contains('réf') ||
          s.contains('ref') ||
          s.contains('désignation') ||
          s.contains('designation') ||
          s.contains('article') ||
          s.contains('quant') ||
          s.contains('qté') ||
          s.contains('qty') ||
          s.contains('pu') ||
          s.contains('p.u') ||
          s.contains('prix') ||
          s.contains('ht') ||
          s.contains('montant') ||
          s.contains('total');
    });

    // bornes horizontales
    final minX = toks.map((t) => t.x).reduce((a, b) => a < b ? a : b);
    final maxX = toks.map((t) => t.x + t.w).reduce((a, b) => a > b ? a : b);
    final wAll = maxX - minX;

    // centres de colonnes (déduits du header si possible)
    double? colPrixX, colQteX, colMontantX, colRefX;
    if (headerIdx >= 0) {
      final hrow = rows[headerIdx];
      final prixXs = <double>[];
      final qteXs = <double>[];
      final montXs = <double>[];
      final refXs = <double>[];
      for (final t in hrow) {
        final s = t.text.toLowerCase();
        if (s.contains('réf') || s.contains('ref')) refXs.add(t.xc);
        if (s.contains('prix') || s.contains('unitaire') || s.contains('pu') || s.contains('p.u')) prixXs.add(t.xc);
        if (s.contains('quant') || s.contains('qté') || s.contains('qty')) qteXs.add(t.xc);
        if (s.contains('montant') || s.contains('total')) montXs.add(t.xc);
      }
      if (prixXs.isNotEmpty) colPrixX = prixXs.reduce((a, b) => a + b) / prixXs.length;
      if (qteXs.isNotEmpty) colQteX = qteXs.reduce((a, b) => a + b) / qteXs.length;
      if (montXs.isNotEmpty) colMontantX = montXs.reduce((a, b) => a + b) / montXs.length;
      if (refXs.isNotEmpty) colRefX = refXs.reduce((a, b) => a + b) / refXs.length;
    }
    // fallback raisonnable
    colRefX ??= minX + wAll * 0.18;
    colPrixX ??= minX + wAll * 0.70;
    colQteX ??= minX + wAll * 0.80;
    colMontantX ??= minX + wAll * 0.90;

    // bloc client
    final clientTokens = (headerIdx > 0)
        ? rows.take(headerIdx).expand((r) => r).toList()
        : rows.take(rows.length ~/ 3).expand((r) => r).toList();
    final clientTxt = clientTokens.map((t) => t.text).join('\n');
    final emailRx =
        RegExp(r'\b[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}\b');
    final iceRx = RegExp(r'(?:\bICE\s*Client\b|\bICE\b)\s*[:\-]?\s*(\d{9,15})',
        caseSensitive: false);

    String email =
        emailRx.firstMatch(clientTxt)?.group(0) ?? 'client@example.com';
    String ice = iceRx.firstMatch(clientTxt)?.group(1) ?? '000000000000000';
    String nom = _guessClientName(clientTxt, email, ice);

    // rows produits
    final startIdx = (headerIdx >= 0) ? headerIdx + 1 : (rows.length ~/ 3);
    final items = <Map<String, dynamic>>[];
    final priceRx = RegExp(r'(?<!\d)(\d{1,3}(?:[ \u00A0,]\d{3})*|\d+)(?:[.,]\d{1,2})?(?!\d)');

    // ---- Fallback par clustering numérique (si header absent/peu fiable) ----
    if (headerIdx < 0 || (colPrixX == null || colQteX == null || colMontantX == null)) {
      final numericTokensAll = toks.where((t) => priceRx.hasMatch(t.text)).toList();
      final xs = numericTokensAll.map((t) => t.xc).toList();
      if (xs.length >= 6) {
        final centers = _kmeans1D(xs, k: 3); // gauche..droite
        // hypothèse initiale
        colPrixX     = centers[0];
        colQteX      = centers[1];
        colMontantX  = centers[2];
        // affine: colonne centrale devrait avoir majorité d'entiers
        final mids = numericTokensAll.where((t) =>
          (t.xc - colQteX!).abs() < (t.xc - colPrixX!).abs() &&
          (t.xc - colQteX!).abs() < (t.xc - colMontantX!).abs()
        ).toList();
        final intScore = mids.where((t) => _isIntegerLike(t.text)).length / (mids.isEmpty ? 1 : mids.length);
        if (intScore < 0.35) {
          final tmp = colPrixX; colPrixX = colQteX; colQteX = tmp;
        }
      }
    }

    for (int i = startIdx; i < rows.length; i++) {
      final r = rows[i];
      final lineTxt = r.map((t) => t.text).join(' ').toLowerCase();
      // stop si c'est clairement une zone totaux/tva et plus de 2 nombres
      if ((lineTxt.contains('total') || lineTxt.contains('tva')) &&
          r.where((t) => priceRx.hasMatch(t.text)).length >= 2) {
        break;
      }

      // ref = token le plus proche de la colonne ref contenant au moins 1 chiffre
      final leftCandidates =
          r.where((t) => RegExp(r'[A-Z0-9].*\d').hasMatch(t.text)).toList();
      final refTok = _nearestToX(leftCandidates, colRefX);
      String ref = _cleanRef(refTok?.text ?? '');
      if (ref.isEmpty) {
        ref = 'REF-${(items.length + 1).toString().padLeft(3, '0')}';
      }

      // --- NUMÉRIQUES ---
      final numToks = r.where((t) => priceRx.hasMatch(t.text)).toList();
      final intToks = r.where((t) => _isIntegerLike(t.text)).toList();

      // Associer par proximité
      final tokPrix    = _nearestToX(numToks, colPrixX);
      final tokQte     = _nearestToX(intToks.isNotEmpty ? intToks : numToks, colQteX);
      final tokMontant = _nearestToX(numToks, colMontantX);

      double? pu = tokPrix != null ? _numFrom(tokPrix.text) : null;
      int? qte;
      if (tokQte != null) {
        final qRaw = tokQte.text.replaceAll('\u00A0', '').replaceAll(' ', '');
        qte = int.tryParse(qRaw);
        if (qte == null) {
          final qd = _numFrom(tokQte.text);
          if (qd != null && (qd - qd.round()).abs() < 1e-6) qte = qd.round();
        }
      }
      double? montant = tokMontant != null ? _numFrom(tokMontant.text) : null;

      // Corrections croisées
      if ((qte == null || qte <= 0 || qte > 99999) && pu != null && pu > 0 && montant != null && montant > 0) {
        final qq = montant / pu;
        if ((qq - qq.round()).abs() < 0.02) qte = qq.round();
      }
      if ((pu == null || pu <= 0) && montant != null && montant > 0 && qte != null && qte > 0) {
        pu = montant / qte;
      }
      if ((montant == null || montant <= 0) && pu != null && qte != null && qte > 0) {
        montant = pu * qte;
      }

      // garde-fous
      qte ??= 1;
      pu  ??= 0.0;

      // Désignation: entre ref et prix
      final leftEdge = refTok?.xc ?? (minX + wAll * 0.25);
      final rightEdge = (colPrixX ?? (minX + wAll * 0.70)) - (wAll * 0.02);
      final midTokens = r
          .where((t) => t.xc > leftEdge && t.xc < rightEdge)
          .map((t) => t.text)
          .toList();
      String designation = midTokens.join(' ').trim();

      // description multi-lignes éventuelle
      if (designation.isEmpty && i + 1 < rows.length) {
        final next = rows[i + 1];
        final hasNums = next.any((t) => priceRx.hasMatch(t.text));
        final mostlyLeft = next.any((t) => t.xc < rightEdge);
        if (!hasNums && mostlyLeft) {
          designation = next.map((t) => t.text).join(' ').trim();
          i += 1; // consommer la ligne de description
        }
      }
      if (designation.isEmpty) designation = 'Produit ${items.length + 1}';

      items.add({
        'reference': ref,
        'nomProduit': designation,
        'quantite': qte,
        'prixHT': pu,
      });
    }

    // Fallback permissif si rien trouvé
    if (items.isEmpty) {
      for (final r in rows.skip(startIdx)) {
        final all = r.map((t) => t.text).join(' ');
        final ms = priceRx.allMatches(all).toList();
        if (ms.isEmpty) continue;
        final p = _numFrom(all.substring(ms.last.start, ms.last.end)) ?? 0.0;
        if (p <= 0) continue;
        items.add({
          'reference': 'REF-${(items.length + 1).toString().padLeft(3, '0')}',
          'nomProduit': all.substring(0, ms.last.start).trim().isEmpty
              ? 'Produit ${items.length + 1}'
              : all.substring(0, ms.last.start).trim(),
          'quantite': 1,
          'prixHT': p,
        });
      }
    }

    return {
      'client': {'nom': nom, 'email': email, 'ice': ice},
      'lignes': _dedupeLines(items),
    };
  }

  // ================= Helpers parsing / corrections =================
  String _guessClientName(String blob, String email, String ice) {
    final lines =
        blob.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    for (int i = 0; i < lines.length; i++) {
      final l = lines[i].toLowerCase();
      if (l.startsWith('client')) {
        final after = lines[i].replaceFirst(
            RegExp(r'^\s*client\s*[:\-]?\s*', caseSensitive: false), '');
        if (after.isNotEmpty) return after;
        if (i + 1 < lines.length) return lines[i + 1];
      }
    }
    for (final l in lines) {
      if (l.contains(email) || l.contains(ice)) continue;
      if (l.length >= 3) return l;
    }
    return 'Client OCR';
  }

  String _cleanRef(String s) {
    var t = (s).trim();
    if (t.isEmpty) return t;
    t = t.replaceAll('—', '-').replaceAll('–', '-');
    // corrections fréquentes OCR
    t = t.replaceAll('O', '0').replaceAll('o', '0');
    t = t.replaceAll(RegExp(r'\bI\b'), '1').replaceAll(RegExp(r'\bl\b'), '1');
    t = t.replaceAll('S', '5').replaceAll('B', '8').replaceAll('Z', '2').replaceAll('G', '6');
    return t;
  }

  double? _numFrom(String s) {
    var t = s
        .replaceAll('MAD', '')
        .replaceAll('DHS', '')
        .replaceAll('Dh', '')
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'[^\d,.\- ]'), '')
        .replaceAll(' ', '')
        .replaceAll(',', '.');

    t = t
        .replaceAll('O', '0').replaceAll('o', '0')
        .replaceAll('I', '1').replaceAll('l', '1')
        .replaceAll('S', '5').replaceAll('B', '8')
        .replaceAll('Z', '2').replaceAll('G', '6');

    // "1.234.56" -> garde la dernière comme décimale
    final lastDot = t.lastIndexOf('.');
    if (lastDot > 0) {
      final head = t.substring(0, lastDot).replaceAll('.', '');
      final tail = t.substring(lastDot);
      t = head + tail;
    }
    return double.tryParse(t);
  }

  // ================= Pré-traitement image =================
  Future<File> _preprocessForOcr(File file, {bool aggressive = false}) async {
    try {
      final bytes = await file.readAsBytes();
      final src = imglib.decodeImage(bytes);
      if (src == null) return file;

      var img = src;

      // Upscale
      final scale = aggressive ? 2.0 : (img.width < 1400 ? 1.6 : 1.2);
      img = imglib.copyResize(
        img,
        width: (img.width * scale).round(),
        height: (img.height * scale).round(),
        interpolation: imglib.Interpolation.average,
      );

      // Niveaux de gris
      img = imglib.grayscale(img);

      // Deskew léger (±1.5°)
      img = _autoDeskew(img);

      // Contraste & luminosité
      img = imglib.adjustColor(
        img,
        contrast: aggressive ? 2.0 : 1.4,
        brightness: aggressive ? 0.12 : 0.08,
        gamma: 0.95,
      );

      // Binarisation adaptative
      img = _sauvolaBinarize(img, window: 31, k: 0.32);

      // Légère netteté
      img = _sharpenCompat(img, radius: 1);

      final out = File(
        file.path.replaceFirst(RegExp(r'\.(png|jpg|jpeg)$', caseSensitive: false), '_prep.png'),
      );
      await out.writeAsBytes(imglib.encodePng(img), flush: true);
      return out;
    } catch (_) {
      return file;
    }
  }

  // ---- Binarisation adaptative (approx Sauvola) ----
  imglib.Image _sauvolaBinarize(imglib.Image src, {int window = 25, double k = 0.34}) {
    final w = src.width, h = src.height;
    var g = imglib.grayscale(src);
    final out = imglib.Image.from(g);
    final int half = (window / 2).floor();
    for (int y = 0; y < h; y++) {
      final y0 = (y - half).clamp(0, h - 1);
      final y1 = (y + half).clamp(0, h - 1);
      for (int x = 0; x < w; x++) {
        final x0 = (x - half).clamp(0, w - 1);
        final x1 = (x + half).clamp(0, w - 1);
        // moyenne & variance locales approximées (sous-échantillonnées)
        int count = 0, sum = 0;
        double sum2 = 0;
        for (int yy = y0; yy <= y1; yy += half) {
          for (int xx = x0; xx <= x1; xx += half) {
            final p = g.getPixel(xx, yy).r.toInt();
            sum += p; sum2 += p * p; count++;
          }
        }
        final mean = sum / count;
        final varv = (sum2 / count) - (mean * mean);
        final std = varv <= 0 ? 0.0 : math.sqrt(varv);
        final R = 128.0;
        final thr = mean * (1 + k * ((std / R) - 1));
        final v = g.getPixel(x, y).r.toInt() >= thr ? 255 : 0;
        out.setPixelRgb(x, y, v, v, v);
      }
    }
    return out;
  }

  // ---- Deskew léger ----
  imglib.Image _autoDeskew(imglib.Image src) {
    imglib.Image best = src;
    double bestScore = _sharpenScore(src);
    for (final angle in [-1.5, 1.5]) {
      final rot = imglib.copyRotate(src, angle: angle);
      final sc = _sharpenScore(rot);
      if (sc > bestScore) { bestScore = sc; best = rot; }
    }
    return best;
  }

  double _sharpenScore(imglib.Image img) {
    var acc = 0.0;
    for (int y = 1; y < img.height - 1; y += 3) {
      for (int x = 1; x < img.width - 1; x += 3) {
        final c = img.getPixel(x, y).r.toInt();
        final rx = img.getPixel(x+1, y).r.toInt() - img.getPixel(x-1, y).r.toInt();
        final ry = img.getPixel(x, y+1).r.toInt() - img.getPixel(x, y-1).r.toInt();
        acc += (rx.abs() + ry.abs()) * (c > 0 ? 1 : 0.5);
      }
    }
    return acc;
  }

  imglib.Image _sharpenCompat(imglib.Image src, {int radius = 1}) {
    final blurred = imglib.gaussianBlur(imglib.Image.from(src), radius: radius);
    final out = imglib.Image.from(src);
    for (int y = 0; y < out.height; y++) {
      for (int x = 0; x < out.width; x++) {
        final o = out.getPixel(x, y);
        final b = blurred.getPixel(x, y);
        int clamp(int v) => v < 0 ? 0 : (v > 255 ? 255 : v);
        final rr = clamp((o.r + (o.r - b.r)).round());
        final gg = clamp((o.g + (o.g - b.g)).round());
        final bb = clamp((o.b + (o.b - b.b)).round());
        out.setPixelRgb(x, y, rr, gg, bb);
      }
    }
    return out;
  }

  // ================= Normalisation + dédoublonnage =================
  void _postValidate(Map<String, dynamic> parsed) {
    final client = parsed['client'] as Map<String, dynamic>;
    client['ice'] = _normalizeICE('${client['ice'] ?? ''}');
    client['email'] = _normalizeEmail('${client['email'] ?? ''}');

    final lignes = (parsed['lignes'] as List).cast<Map<String, dynamic>>();
    for (final l in lignes) {
      l['quantite'] = (l['quantite'] is num)
          ? (l['quantite'] as num).toInt()
          : int.tryParse('${l['quantite']}') ?? 1;
      l['prixHT'] = (l['prixHT'] is num)
          ? (l['prixHT'] as num).toDouble()
          : double.tryParse('${l['prixHT']}'.replaceAll(',', '.')) ?? 0.0;
      if ((l['quantite'] as int) <= 0) l['quantite'] = 1;
      if ((l['prixHT'] as double) < 0) l['prixHT'] = 0.0;
    }
    parsed['lignes'] = _dedupeLines(lignes);
  }

  String _normalizeICE(String raw) {
    final d = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.length >= 15) return d.substring(0, 15);
    return d.padRight(15, '0');
  }

  String _normalizeEmail(String raw) {
    final r = raw.trim();
    if (!r.contains('@') || r.endsWith('.')) return 'client@example.com';
    return r;
  }

  List<Map<String, dynamic>> _dedupeLines(List<Map<String, dynamic>> lines) {
    final uniq = <String, Map<String, dynamic>>{};
    for (final l in lines) {
      final key = '${l['reference']}|${l['nomProduit']}|${l['prixHT']}';
      if (!uniq.containsKey(key)) {
        uniq[key] = Map<String, dynamic>.from(l);
      } else {
        uniq[key]!['quantite'] =
            (uniq[key]!['quantite'] as int) + (l['quantite'] as int);
      }
    }
    return uniq.values.toList();
  }

  // ================= Fuzzy match produits =================
  int _lev(String a, String b) {
    final m = a.length, n = b.length;
    final d = List.generate(m + 1, (_) => List.filled(n + 1, 0));
    for (var i = 0; i <= m; i++) d[i][0] = i;
    for (var j = 0; j <= n; j++) d[0][j] = j;
    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        final del = d[i - 1][j] + 1;
        final ins = d[i][j - 1] + 1;
        final sub = d[i - 1][j - 1] + cost;
        d[i][j] = del < ins ? (del < sub ? del : sub) : (ins < sub ? ins : sub);
      }
    }
    return d[m][n];
  }

  double _sim(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final aa = a.toUpperCase(), bb = b.toUpperCase();
    final len = aa.length > bb.length ? aa.length : bb.length;
    final dist = _lev(aa, bb);
    return 1.0 - (dist / len);
  }

  Future<void> _snapToKnownProducts() async {
    final produits = await _produitService.obtenirTousLesProduits();
    for (final l in _lignesData) {
      String r = (l['reference'] as String).trim();
      String n = (l['nomProduit'] as String).trim();
      Produit? best;
      double bestScore = 0;

      for (final p in produits) {
        double s = 0;
        if (r.isNotEmpty && p.reference.isNotEmpty) {
          s = _sim(r, p.reference);
        }
        if (s < 0.7 && n.isNotEmpty && p.nom.isNotEmpty) {
          s = s * 0.6 + _sim(n, p.nom) * 0.7;
        }
        if (s > bestScore) {
          bestScore = s;
          best = p;
        }
      }

      if (best != null && bestScore >= 0.82) {
        l['reference'] = best.reference;
        if (n.length < 5) l['nomProduit'] = best.nom;
        if ((l['prixHT'] as double) <= 0 && best.prixHT > 0) l['prixHT'] = best.prixHT;
        l['produitId'] = best.id;
      }
    }
  }

  // -------------------- DB & APERÇU --------------------
  Future<void> _verifyExistence() async {
    // produits
    final produits = await _produitService.obtenirTousLesProduits();
    final manquants = <Map<String, dynamic>>[];
    for (final l in _lignesData) {
      final found = produits.any((p) =>
          p.reference == l['reference'] ||
          p.nom.toLowerCase() == (l['nomProduit'] as String).toLowerCase());
      if (!found) manquants.add(l);
    }
    if (manquants.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Produits manquants'),
          content:
              Text('${manquants.length} produit(s) non trouvé(s). Les ajouter ?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Non')),
            ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Oui')),
          ],
        ),
      );
      if (ok == true) {
        for (final m in manquants) {
          final id = '${DateTime.now().millisecondsSinceEpoch}${m['reference']}';
          await _produitService.ajouterProduit(Produit(
            id: id,
            reference: m['reference'] as String,
            nom: m['nomProduit'] as String,
            description: 'Ajouté via OCR',
            prixHT: m['prixHT'] as double,
          ));
        }
      }
    }

    // client
    final clients = await _clientService.obtenirTousLesClients();
    final foundClient = clients.any((c) =>
        c.nom.trim().toLowerCase() == (_clientData['nom'] ?? '').trim().toLowerCase() ||
        c.email.trim().toLowerCase() == (_clientData['email'] ?? '').trim().toLowerCase() ||
        '${c.ice}' == (_clientData['ice'] ?? ''));

    if (!foundClient) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Client introuvable'),
          content: Text('Créer le client "${_clientData['nom']}" ?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Non')),
            ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Oui')),
          ],
        ),
      );
      if (ok == true) {
        final id = DateTime.now().millisecondsSinceEpoch.toString();
        await _clientService.ajouterClient(Client(
          id: id,
          nom: _clientData['nom'] ?? '',
          email: _clientData['email'] ?? '',
          ice: int.tryParse(_clientData['ice'] ?? '') ?? 0,
        ));
      }
    }
  }

  Future<void> _showPreviewAndConfirm() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
          builder: (_) =>
              _PreviewPage(clientData: _clientData, lignesData: _lignesData)),
    );
    if (ok == true) await _generateAndUpload();
  }

  Future<void> _generateAndUpload() async {
    setState(() => _loading = true);
    try {
      final lignes = _lignesData
          .map((m) => LigneFacture(
                produitId: (m['produitId'] ?? '') as String,
                nomProduit: m['nomProduit'] as String,
                reference: m['reference'] as String,
                prixHT: m['prixHT'] as double,
                quantite: m['quantite'] as int,
              ))
          .toList();

      final numero = await _factureService.getNextFactureNumber();
      final totalHT = lignes.fold<double>(0.0, (s, l) => s + l.totalLigne);
      final facture = Facture(
        id: '',
        clientId: '',
        nomClient: _clientData['nom'] ?? '',
        emailClient: _clientData['email'] ?? '',
        iceClient: _clientData['ice'] ?? '',
        date: DateTime.now(),
        lignes: lignes,
        totalHT: totalHT,
        totalTTC: totalHT * 1.20,
        numero: numero,
      );

      await _factureService.saveFactureAndGeneratePDF(facture);
      _toast('Facture générée');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _toast('Erreur génération: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // -------------------- UI --------------------
  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  void _showLogs() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Logs OCR'),
        content: SizedBox(
          width: double.maxFinite,
          height: 420,
          child: SingleChildScrollView(
              child: Text(_debug,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Fermer'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasData = _clientData['nom']!.isNotEmpty || _lignesData.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Traiter bon de commande (OCR)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(
                child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Traitement OCR…'),
                ],
              ))
            : SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                ElevatedButton.icon(
                  onPressed: _showSourceChoice,
                  icon: const Icon(Icons.play_circle_fill),
                  label: const Text('Commencer'),
                ),
                const SizedBox(height: 10),
                if (_pickedFile != null)
                  Text('Fichier: ${_pickedFile!.path.split(Platform.pathSeparator).last}'),
                const SizedBox(height: 10),
                if (hasData)
                  Form(
                    key: _formKey,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Client',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          TextFormField(
                              initialValue: _clientData['nom'],
                              decoration:
                                  const InputDecoration(labelText: 'Nom'),
                              onChanged: (v) => _clientData['nom'] = v),
                          TextFormField(
                              initialValue: _clientData['email'],
                              decoration:
                                  const InputDecoration(labelText: 'Email'),
                              onChanged: (v) => _clientData['email'] = v),
                          TextFormField(
                              initialValue: _clientData['ice'],
                              decoration:
                                  const InputDecoration(labelText: 'ICE'),
                              onChanged: (v) => _clientData['ice'] = v),
                          const SizedBox(height: 12),
                          const Text('Lignes',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          ..._lignesData.asMap().entries.map((e) {
                            final i = e.key;
                            final l = e.value;
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(children: [
                                  TextFormField(
                                      initialValue: l['nomProduit'] as String,
                                      decoration: const InputDecoration(
                                          labelText: 'Désignation'),
                                      onChanged: (v) =>
                                          _lignesData[i]['nomProduit'] = v),
                                  TextFormField(
                                      initialValue: l['reference'] as String,
                                      decoration: const InputDecoration(
                                          labelText: 'Référence'),
                                      onChanged: (v) =>
                                          _lignesData[i]['reference'] = v),
                                  TextFormField(
                                      initialValue:
                                          (l['prixHT'] as double).toStringAsFixed(2),
                                      decoration: const InputDecoration(
                                          labelText: 'Prix HT'),
                                      keyboardType: TextInputType.number,
                                      onChanged: (v) => _lignesData[i]['prixHT'] =
                                          double.tryParse(
                                                  v.replaceAll(',', '.')) ??
                                              l['prixHT']),
                                  TextFormField(
                                      initialValue:
                                          (l['quantite'] as int).toString(),
                                      decoration: const InputDecoration(
                                          labelText: 'Quantité'),
                                      keyboardType: TextInputType.number,
                                      onChanged: (v) =>
                                          _lignesData[i]['quantite'] =
                                              int.tryParse(v) ??
                                                  l['quantite']),
                                ]),
                              ),
                            );
                          }),
                          const SizedBox(height: 12),
                          Row(children: [
                            ElevatedButton(
                                onPressed: _lignesData.isNotEmpty
                                    ? _showPreviewAndConfirm
                                    : null,
                                child: const Text('Aperçu & confirmer')),
                            const SizedBox(width: 8),
                            OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _pickedFile = null;
                                    _clientData = {
                                      'nom': '',
                                      'email': '',
                                      'ice': ''
                                    };
                                    _lignesData.clear();
                                    _debug = '';
                                  });
                                },
                                child: const Text('Réinitialiser')),
                            const SizedBox(width: 8),
                            TextButton.icon(
                                onPressed:
                                    _debug.isNotEmpty ? _showLogs : null,
                                icon: const Icon(Icons.bug_report),
                                label: const Text('Logs')),
                          ]),
                        ]),
                  ),
              ]),
              ),
      ),
    );
  }

  // ======================= K-means 1D pour colonnes =======================
  List<double> _kmeans1D(List<double> xs, {int k = 3, int iters = 15}) {
    if (xs.isEmpty) return [];
    xs.sort();
    final min = xs.first, max = xs.last;
    var centers = List.generate(k, (i) => min + (max - min) * (i / (k - 1)));
    for (int it = 0; it < iters; it++) {
      final buckets = List.generate(k, (_) => <double>[]);
      for (final x in xs) {
        int bi = 0; double bd = (x - centers[0]).abs();
        for (int i = 1; i < k; i++) {
          final d = (x - centers[i]).abs();
          if (d < bd) { bd = d; bi = i; }
        }
        buckets[bi].add(x);
      }
      for (int i = 0; i < k; i++) {
        if (buckets[i].isNotEmpty) {
          centers[i] = buckets[i].reduce((a, b) => a + b) / buckets[i].length;
        }
      }
    }
    centers.sort();
    return centers;
  }
}

// ======================= Aperçu =======================
class _PreviewPage extends StatelessWidget {
  final Map<String, String> clientData;
  final List<Map<String, dynamic>> lignesData;
  const _PreviewPage({required this.clientData, required this.lignesData});

  @override
  Widget build(BuildContext context) {
    final totalHT = lignesData.fold<double>(
        0.0, (s, l) => s + (l['prixHT'] as double) * (l['quantite'] as int));
    final totalTTC = totalHT * 1.20;
    return Scaffold(
      appBar: AppBar(title: const Text('Aperçu de la facture')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Client: ${clientData['nom']}'),
          Text('Email: ${clientData['email']}'),
          Text('ICE: ${clientData['ice']}'),
          const SizedBox(height: 12),
          const Text('Lignes:', style: TextStyle(fontWeight: FontWeight.bold)),
          ...lignesData.map((l) => ListTile(
                title: Text(l['nomProduit'] as String),
                subtitle: Text(
                    'Réf: ${l['reference']} - ${(l['quantite'] as int)} × ${(l['prixHT'] as double).toStringAsFixed(2)}'),
              )),
          const Divider(),
          Text('Total HT: ${totalHT.toStringAsFixed(2)} MAD'),
          Text('Total TTC: ${totalTTC.toStringAsFixed(2)} MAD'),
          const Spacer(),
          Row(children: [
            OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Modifier')),
            const SizedBox(width: 12),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirmer')),
          ])
        ]),
      ),
    );
  }
}
