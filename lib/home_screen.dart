import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeSection(),
                    const SizedBox(height: 32),
                    _buildQuickActionsSection(context),
                    // Section statistiques supprimée ici
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tableau de bord',
                style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.grey.shade800),
              ),
              Text(
                'Gérez votre activité',
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.logout_rounded, color: Colors.red.shade600),
            onPressed: () => _showLogoutConfirmation(context),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [const Color(0xFF1E88E5), Colors.blue.shade700], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bienvenue !', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 8),
                Text(
                  'Prêt à gérer vos factures et produits',
                  style: GoogleFonts.inter(fontSize: 16, color: Colors.white.withOpacity(0.9)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
            child: Icon(Icons.dashboard_rounded, size: 32, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection(BuildContext context) {
    final actions = [
      _QuickAction(
        title: 'Nouvelle\nfacture',
        icon: Icons.receipt_long_rounded,
        colors: [Colors.green.shade400, Colors.green.shade600],
        onTap: () =>Navigator.of(context).pushNamed('/factures'),

      ),
      _QuickAction(
        title: 'Gérer\nproduits',
        icon: Icons.inventory_2_rounded,
        colors: [Colors.orange.shade400, Colors.orange.shade600],
        onTap: () => Navigator.of(context).pushNamed('/produits'),
      ),
      _QuickAction(
        title: 'Historique\nfactures',
        icon: Icons.history_rounded,
        colors: [Colors.purple.shade400, Colors.purple.shade600],
        onTap: () => Navigator.of(context).pushNamed('/historiqueFacture'),
      ),
      _QuickAction(
        title: 'Gérer\nclients',
        icon: Icons.person,
        colors: [Colors.indigo.shade400, Colors.indigo.shade600],
        onTap: () =>Navigator.of(context).pushNamed('/clients'),
        
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Actions rapides', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.1,
          children: actions.map((action) {
            return _ProfessionalCard(
              title: action.title,
              icon: action.icon,
              gradient: action.colors,
              onTap: action.onTap,
            );
          }).toList(),
        ),
      ],
    );
  }

  // Méthode pour afficher la confirmation de déconnexion
  Future<void> _showLogoutConfirmation(BuildContext context) async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 350),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icône d'avertissement
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Icon(
                  Icons.logout_rounded,
                  color: Colors.red.shade600,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              
              // Titre
              Text(
                'Confirmer la déconnexion',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // Message
              Text(
                'Êtes-vous sûr de vouloir vous déconnecter ?',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Boutons
              Row(
                children: [
                  // Bouton Annuler
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(false),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Annuler',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Bouton Déconnexion
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.red.shade500, Colors.red.shade600],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(true),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Déconnexion',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    // Si l'utilisateur confirme, procéder à la déconnexion
    if (shouldLogout == true) {
      Navigator.of(context).pushReplacementNamed('/auth');
    }
  }
}

class _QuickAction {
  final String title;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  _QuickAction({required this.title, required this.icon, required this.colors, required this.onTap});
}

class _ProfessionalCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _ProfessionalCard({
    required this.title,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: gradient.first.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: Icon(icon, size: 28, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700, height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
