import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/Produit.dart';
import '../service/produit_service.dart';

class AjoutProduitScreen extends StatefulWidget {
  const AjoutProduitScreen({super.key});

  @override
  State<AjoutProduitScreen> createState() => _AjoutProduitScreenState();
}

class _AjoutProduitScreenState extends State<AjoutProduitScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _referenceController = TextEditingController(); // Nouveau contrôleur
  final _prixController = TextEditingController();
  final _descController = TextEditingController();

  bool _isLoading = false;
  bool _isScanning = false;
  final _service = ProduitService();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _nomController.dispose();
    _referenceController.dispose();
    _prixController.dispose();
    _descController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // Nouvelle méthode pour scanner le code-barres
  Future<void> _scannerCodeBarre() async {
    // Vérifier les permissions de caméra
    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) {
      _showErrorSnackBar('Permission caméra requise pour scanner');
      return;
    }

    setState(() => _isScanning = true);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _ScannerScreen(
          onCodeScanned: (code) {
            setState(() {
              _referenceController.text = code;
              _isScanning = false;
            });
            Navigator.of(context).pop();
          },
        ),
      ),
    );

    setState(() => _isScanning = false);
  }

  Future<void> _ajouterProduit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      _showValidationError();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final produit = Produit(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        nom: _nomController.text.trim(),
        reference: _referenceController.text.trim(), // Ajouter la référence
        prixHT: double.parse(_prixController.text.trim()),
        description: _descController.text.trim(),
      );

      await _service.ajouterProduit(produit);

      if (mounted) {
        setState(() => _isLoading = false);
        await _showSuccessDialog(produit.nom);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Erreur: $e');
      }
    }
  }

  // Nouveau widget pour le champ référence avec scanner
  Widget _buildReferenceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Référence *',
            style: TextStyle(
                fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _referenceController,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Référence requise';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: 'Ex: REF001, CODE123',
                  prefixIcon: const Icon(Icons.qr_code, color: Colors.blue),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.blue.shade600,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: _isScanning ? null : _scannerCodeBarre,
                icon: _isScanning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.qr_code_scanner, color: Colors.white),
                tooltip: 'Scanner code-barres',
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ... garder toutes les autres méthodes existantes (_showSuccessDialog, _showErrorSnackBar, etc.)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Nouveau Produit',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildTextField(
                          'Nom du produit *',
                          _nomController,
                          hint: 'Ex: iPhone 14',
                          icon: Icons.shopping_bag_outlined,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Nom requis';
                            } else if (v.trim().length < 2) {
                              return 'Min 2 caractères';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        
                        // Nouveau champ référence avec scanner
                        _buildReferenceField(),
                        const SizedBox(height: 24),
                        
                        _buildTextField(
                          'Prix HT (DH) *',
                          _prixController,
                          type: TextInputType.numberWithOptions(decimal: true),
                          hint: 'Ex: 1299.99',
                          icon: Icons.attach_money_outlined,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Prix requis';
                            }
                            final val = double.tryParse(v.trim());
                            if (val == null || val <= 0) {
                              return 'Prix invalide';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        _buildTextField(
                          'Description',
                          _descController,
                          maxLines: 4,
                          hint: 'Caractéristiques du produit...',
                          icon: Icons.description_outlined,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: _isLoading
                        ? Container(
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                const SizedBox(width: 12),
                                Text('Ajout en cours...',
                                    style: TextStyle(
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          )
                        : ElevatedButton(
                            onPressed: _ajouterProduit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_circle_outline),
                                SizedBox(width: 8),
                                Text('Ajouter le produit',
                                    style: TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ... garder les autres méthodes existantes
  Future<void> _showSuccessDialog(String nom) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            const Text('Succès !',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        content: Text('Le produit "$nom" a été ajouté avec succès.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Terminer',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showValidationError() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.warning_outlined, color: Colors.white),
            SizedBox(width: 12),
            Text('Veuillez corriger les erreurs du formulaire'),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    IconData? icon,
    TextInputType? type,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: type,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null ? Icon(icon, color: Colors.blue) : null,
            filled: true,
            fillColor: Colors.grey.shade100,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

// Écran de scanner séparé
class _ScannerScreen extends StatefulWidget {
  final Function(String) onCodeScanned;

  const _ScannerScreen({required this.onCodeScanned});

  @override
  State<_ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<_ScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scanner Code-barres'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: cameraController.torchState,
              builder: (context, state, child) {
                switch (state) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off, color: Colors.grey);
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.yellow);
                }
              },
            ),
            onPressed: () => cameraController.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) async {
              if (_isProcessing) return;
              
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  setState(() => _isProcessing = true);
                  HapticFeedback.mediumImpact();
                  widget.onCodeScanned(barcode.rawValue!);
                  return;
                }
              }
            },
          ),
          // Overlay avec cadre de scan
          Container(
            decoration: ShapeDecoration(
              shape: QrScannerOverlayShape(
                borderColor: Colors.blue,
                borderRadius: 10,
                borderLength: 30,
                borderWidth: 8,
                cutOutSize: 250,
              ),
            ),
          ),
          // Instructions
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Placez le code-barres dans le cadre pour le scanner',
                style: TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}

// Classe pour l'overlay du scanner
class QrScannerOverlayShape extends ShapeBorder {
  const QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path _getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top + borderRadius)
        ..quadraticBezierTo(rect.left, rect.top, rect.left + borderRadius, rect.top)
        ..lineTo(rect.right, rect.top);
    }

    return _getLeftTopPath(rect)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.top);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final borderWidthSize = width / 2;
    final height = rect.height;
    final borderOffset = borderWidth / 2;
    final _borderLength = borderLength > borderWidthSize / 2 ? borderWidthSize / 2 : borderLength;
    final _cutOutSize = cutOutSize < width ? cutOutSize : width - borderOffset;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final boxPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut;

    final cutOutRect = Rect.fromLTWH(
      rect.left + width / 2 - _cutOutSize / 2 + borderOffset,
      rect.top + height / 2 - _cutOutSize / 2 + borderOffset,
      _cutOutSize - borderOffset * 2,
      _cutOutSize - borderOffset * 2,
    );

    canvas
      ..saveLayer(
        rect,
        backgroundPaint,
      )
      ..drawRect(rect, backgroundPaint)
      ..drawRRect(
        RRect.fromRectAndRadius(
          cutOutRect,
          Radius.circular(borderRadius),
        ),
        boxPaint,
      )
      ..restore();

    final path = Path()
      ..moveTo(cutOutRect.left - borderOffset, cutOutRect.top + _borderLength)
      ..lineTo(cutOutRect.left - borderOffset, cutOutRect.top + borderRadius)
      ..quadraticBezierTo(cutOutRect.left - borderOffset, cutOutRect.top - borderOffset,
          cutOutRect.left + borderRadius, cutOutRect.top - borderOffset)
      ..lineTo(cutOutRect.left + _borderLength, cutOutRect.top - borderOffset);

    canvas.drawPath(path, borderPaint);

    final path2 = Path()
      ..moveTo(cutOutRect.right + borderOffset, cutOutRect.top + _borderLength)
      ..lineTo(cutOutRect.right + borderOffset, cutOutRect.top + borderRadius)
      ..quadraticBezierTo(cutOutRect.right + borderOffset, cutOutRect.top - borderOffset,
          cutOutRect.right - borderRadius, cutOutRect.top - borderOffset)
      ..lineTo(cutOutRect.right - _borderLength, cutOutRect.top - borderOffset);

    canvas.drawPath(path2, borderPaint);

    final path3 = Path()
      ..moveTo(cutOutRect.right + borderOffset, cutOutRect.bottom - _borderLength)
      ..lineTo(cutOutRect.right + borderOffset, cutOutRect.bottom - borderRadius)
      ..quadraticBezierTo(cutOutRect.right + borderOffset, cutOutRect.bottom + borderOffset,
          cutOutRect.right - borderRadius, cutOutRect.bottom + borderOffset)
      ..lineTo(cutOutRect.right - _borderLength, cutOutRect.bottom + borderOffset);

    canvas.drawPath(path3, borderPaint);

    final path4 = Path()
      ..moveTo(cutOutRect.left - borderOffset, cutOutRect.bottom - _borderLength)
      ..lineTo(cutOutRect.left - borderOffset, cutOutRect.bottom - borderRadius)
      ..quadraticBezierTo(cutOutRect.left - borderOffset, cutOutRect.bottom + borderOffset,
          cutOutRect.left + borderRadius, cutOutRect.bottom + borderOffset)
      ..lineTo(cutOutRect.left + _borderLength, cutOutRect.bottom + borderOffset);

    canvas.drawPath(path4, borderPaint);
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
    );
  }
}
