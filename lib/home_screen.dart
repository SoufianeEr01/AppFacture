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
            _Header(onLogout: () => _showLogoutConfirmation(context)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WelcomeCard(),
                    const SizedBox(height: 32),
                    _QuickActionsGrid(
                      actions: [
                        _ActionData(
                          title: 'Nouvelle\nfacture',
                          icon: Icons.receipt_long_rounded,
                          colors: [Colors.green.shade400, Colors.green.shade600],
                          route: '/factures',
                        ),
                        _ActionData(
                          title: 'Gérer\nproduits',
                          icon: Icons.inventory_2_rounded,
                          colors: [Colors.orange.shade400, Colors.orange.shade600],
                          route: '/produits',
                        ),
                        _ActionData(
                          title: 'Historique\nfactures',
                          icon: Icons.history_rounded,
                          colors: [Colors.purple.shade400, Colors.purple.shade600],
                          route: '/historiqueFacture',
                        ),
                        _ActionData(
                          title: 'Gérer\nclients',
                          icon: Icons.person,
                          colors: [Colors.indigo.shade400, Colors.indigo.shade600],
                          route: '/clients',
                        ),
                        _ActionData(
                          title: 'Statistiques',
                          icon: Icons.bar_chart_rounded,
                          colors: [Colors.blue.shade400, Colors.blue.shade700],
                          route: '/statistiques',
                        ),
                        _ActionData(
                          title: 'Traiter\nbon de commande',
                          icon: Icons.assignment_turned_in_rounded,
                          colors: [Colors.teal.shade400, Colors.teal.shade700],
                          route: '/bonCommande',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Icon(Icons.logout_rounded, color: Colors.red, size: 40),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            child: const Text('Annuler'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Déconnexion'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (shouldLogout == true) {
      Navigator.of(context).pushReplacementNamed('/auth');
    }
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onLogout;
  const _Header({required this.onLogout});

  @override
  Widget build(BuildContext context) {
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
              Text('Tableau de bord', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700)),
              Text('Gérez votre activité', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600)),
            ],
          ),
          IconButton(
            icon: Icon(Icons.logout_rounded, color: Colors.red.shade600),
            onPressed: onLogout,
          ),
        ],
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [const Color(0xFF1E88E5), Colors.blue.shade700]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bienvenue !', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 8),
                Text('Prêt à gérer vos factures et produits', style: GoogleFonts.inter(fontSize: 16, color: Colors.white.withOpacity(0.9))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.dashboard_rounded, size: 32, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _ActionData {
  final String title;
  final IconData icon;
  final List<Color> colors;
  final String route;
  _ActionData({required this.title, required this.icon, required this.colors, required this.route});
}

class _QuickActionsGrid extends StatelessWidget {
  final List<_ActionData> actions;
  const _QuickActionsGrid({required this.actions});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Actions rapides', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1,
          ),
          itemBuilder: (context, i) => _ActionCard(data: actions[i]),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final _ActionData data;
  const _ActionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).pushNamed(data.route),
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
                  gradient: LinearGradient(colors: data.colors),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: data.colors.first.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: Icon(data.icon, size: 28, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                data.title,
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
