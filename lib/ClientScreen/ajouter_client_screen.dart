import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/Client.dart';
import '../service/client_service.dart';

class AjoutClientScreen extends StatefulWidget {
  const AjoutClientScreen({super.key});

  @override
  State<AjoutClientScreen> createState() => _AjoutClientScreenState();
}

class _AjoutClientScreenState extends State<AjoutClientScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _emailController = TextEditingController();
  final _iceController = TextEditingController();

  bool _isLoading = false;
  final _service = ClientService();

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
    _emailController.dispose();
    _iceController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _ajouterClient() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      _showValidationError();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final client = Client(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        nom: _nomController.text.trim(),
        email: _emailController.text.trim(),
        ice: int.parse(_iceController.text.trim()),
      );

      await _service.ajouterClient(client);

      if (mounted) {
        setState(() => _isLoading = false);
        await _showSuccessDialog(client.nom);
        Navigator.of(context).pop(); // retour à l'écran précédent
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Erreur: $e');
      }
    }
  }

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
            const Text('Succès !', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        content: Text('Le client "$nom" a été ajouté avec succès.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Terminer', style: TextStyle(color: Colors.white)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Nouveau Client',style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
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
                        'Nom du client *',
                        _nomController,
                        hint: 'Ex: Société XYZ',
                        icon: Icons.person_outline,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Nom requis';
                          } else if (v.trim().length < 2) {
                            return 'Minimum 2 caractères';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildTextField(
                        'Email *',
                        _emailController,
                        type: TextInputType.emailAddress,
                        hint: 'Ex: client@email.com',
                        icon: Icons.email_outlined,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email requis';
                          } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
                            return 'Email invalide';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildTextField(
                        'ICE *',
                        _iceController,
                        type: TextInputType.number,
                        hint: 'Ex: 123456789',
                        icon: Icons.confirmation_number_outlined,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'ICE requis';
                          }
                          if (int.tryParse(v.trim()) == null) {
                            return 'ICE doit être un nombre';
                          }
                          return null;
                        },
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
                          onPressed: _ajouterClient,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.person_add_alt_1),
                              SizedBox(width: 8),
                              Text('Ajouter le client', style: TextStyle(fontWeight: FontWeight.w600)),
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
}
