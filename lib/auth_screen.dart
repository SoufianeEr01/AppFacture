import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  final _emailController = TextEditingController(text: '');
  final _passwordController = TextEditingController(text: '');
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez saisir votre email';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Format d\'email invalide';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez saisir votre mot de passe';
    }
    if (value.length < 6) {
      return 'Le mot de passe doit contenir au moins 6 caractères';
    }
    return null;
  }

  Future<void> _signInWithEmailPassword() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage = 'Une erreur est survenue';
        switch (e.code) {
          case 'user-not-found':
            errorMessage = 'Aucun utilisateur trouvé avec cet email';
            break;
          case 'wrong-password':
            errorMessage = 'Mot de passe incorrect';
            break;
          case 'invalid-email':
            errorMessage = 'Format d\'email invalide';
            break;
          case 'too-many-requests':
            errorMessage = 'Trop de tentatives. Réessayez plus tard';
            break;
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.indigo.shade100,
              Colors.blue.shade200,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth > 600 ? 48 : 24,
                vertical: 24,
              ),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Card(
                      elevation: 12,
                      shadowColor: Colors.blue.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Logo et titre
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.blue.shade600, Colors.indigo.shade600],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.3),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.receipt_long,
                                  size: 48,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 24),
                              
                              Text(
                                'InvoiceManager',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Gestion professionnelle de factures',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 32),
                              
                              Text(
                                'Connexion Administrateur',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Champ Email
                              TextFormField(
                                controller: _emailController,
                                validator: _validateEmail,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: 'Adresse email',
                                  hintText: 'admin@example.com',
                                  prefixIcon: Icon(Icons.email_outlined, color: Colors.blue.shade600),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.red.shade400),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Champ Mot de passe
                              TextFormField(
                                controller: _passwordController,
                                validator: _validatePassword,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: 'Mot de passe',
                                  hintText: 'Saisissez votre mot de passe',
                                  prefixIcon: Icon(Icons.lock_outline, color: Colors.blue.shade600),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                      color: Colors.grey.shade600,
                                    ),
                                    onPressed: () {
                                      setState(() => _obscurePassword = !_obscurePassword);
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.red.shade400),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Bouton de connexion
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: _isLoading
                                    ? Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [Colors.blue.shade400, Colors.indigo.shade500],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Center(
                                          child: SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          ),
                                        ),
                                      )
                                    : ElevatedButton(
                                        onPressed: _signInWithEmailPassword,
                                        style: ElevatedButton.styleFrom(
                                          elevation: 8,
                                          shadowColor: Colors.blue.withOpacity(0.4),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          padding: EdgeInsets.zero,
                                        ),
                                        child: Ink(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [Colors.blue.shade600, Colors.indigo.shade600],
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Container(
                                            alignment: Alignment.center,
                                            child: const Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.login, color: Colors.white, size: 20),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Se connecter',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 24),
                              
                              // Informations de version
                              Text(
                                'Version 1.0.0',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}