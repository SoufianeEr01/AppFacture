import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/facture.dart';
import '../models/Client.dart'; 
import '../models/Produit.dart';


import '../service/facture_service.dart';
import '../service/client_service.dart';
import '../service/produit_service.dart';
import 'detail_ca_produit_screen.dart';
import 'detail_ca_client_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadAllData() async {
    try {
      final factures = await FactureService().getAllFactures();
      final clients = await ClientService().obtenirTousLesClients();
      final produits = await ProduitService().obtenirTousLesProduits();

      return {
        'factures': factures,
        'clients': clients,
        'produits': produits,
      };
    } catch (e) {
      debugPrint('Erreur de chargement des données: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0E27) : const Color(0xFFF8FAFC),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadAllData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text("Aucune donnée disponible."));
          }

          final allFactures = snapshot.data!['factures'] as List<Facture>;
          final clients = snapshot.data!['clients'] as List<Client>;
          final produits = snapshot.data!['produits'] as List<Produit>;

          // Calculs sur la totalité des factures (filtres supprimés)
          final stats = _calculateStats(allFactures, clients);

          return FadeTransition(
            opacity: _fadeAnimation,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildModernAppBar(),
                SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Cartes statistiques
                      _buildStatsGrid(stats),
                      const SizedBox(height: 32),
                      // Section Top Produits uniquement
                      _buildProductChart(stats['caParProduit'], stats['totalHT']),
                      const SizedBox(height: 32),
                      // Boutons professionnels : CA Produit et CA Client
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DetailCAProduitScreen(
                                      caParProduit: stats['caParProduit']),
                                ),
                              );
                            },
                            icon: const Icon(Icons.pie_chart),
                            label: const Text("CA Produit"),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 14),
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              elevation: 4,
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DetailCAClientScreen(
                                      caParClient: _calculateClientCA(allFactures)),
                                ),
                              );
                            },
                            icon: const Icon(Icons.people_outline),
                            label: const Text("CA Client"),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 14),
                              backgroundColor: Colors.blueGrey.shade800,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              elevation: 2,
                            ),
                          ),
                        ],
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.shade100),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Erreur de chargement",
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Réessayer"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildModernAppBar() {
    return SliverAppBar(
      // hauteur quand déroulé et quand réduit
      expandedHeight: 120,
      collapsedHeight: 64,
      // hauteur de la toolbar (utile si vous voulez forcer une valeur)
      toolbarHeight: 64,
      pinned: true,
      floating: false,
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      // icône retour en blanc
      leading: BackButton(color: Colors.white),
      title: Text(
        'Suivi Activité',
        style: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade600,
              Colors.blue.shade700,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> stats) {
    final statItems = [
      {
        'label': 'CA Total TTC',
        'value': '${(stats['totalTTC'] as double).toStringAsFixed(2)} DH',
        'icon': Icons.trending_up_rounded,
        'gradient': [const Color(0xFF10B981), const Color(0xFF059669)],
      },
      {
        'label': 'CA Total HT',
        'value': '${(stats['totalHT'] as double).toStringAsFixed(2)} DH',
        'icon': Icons.account_balance_wallet_rounded,
        'gradient': [const Color(0xFF3B82F6), const Color(0xFF1E40AF)],
      },
      {
        'label': 'Factures',
        'value': '${stats['totalFactures']}',
        'icon': Icons.receipt_long_rounded,
        'gradient': [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
      },
      {
        'label': 'Clients',
        'value': '${stats['totalClients']}',
        'icon': Icons.people_alt_rounded,
        'gradient': [const Color(0xFFF59E0B), const Color(0xFFD97706)],
      },
      // 'Produits Vendus' card removed as requested
    ];

    final width = MediaQuery.of(context).size.width;
    final crossCount = width > 1200
        ? 4
        : width > 800
            ? 2
            : 1;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 2.5,
      ),
      itemCount: statItems.length,
      itemBuilder: (context, index) {
        final item = statItems[index];
        return _ModernStatCard(
          label: item['label'] as String,
          value: item['value'] as String,
          icon: item['icon'] as IconData,
          gradient: item['gradient'] as List<Color>,
        );
      },
    );
  }

  Widget _buildProductChart(Map<String, double> caParProduit, double totalHT) {
    final entries = caParProduit.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.inventory_rounded,
                    color: Colors.green.shade600, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Top Produits',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 320,
            child: entries.isEmpty
                ? _buildEmptyChart('Aucun produit vendu')
                : SingleChildScrollView(
                    child: Column(
                      children: entries.take(5).map((e) {
                        final percentage =
                            totalHT == 0 ? 0.0 : (e.value / totalHT);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      e.key,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '${e.value.toStringAsFixed(0)} DH',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: percentage.clamp(0.0, 1.0),
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.green.shade600,
                                  ),
                                  minHeight: 8,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChart(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.bar_chart_rounded,
              size: 48,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _calculateStats(
      List<Facture> factures, List<Client> clients) {
    double totalTTC = 0;
    double totalHT = 0;
    int totalProduitsVendus = 0;
    final caParProduit = <String, double>{};

    for (var f in factures) {
      try {
        totalTTC += parseDouble(f.totalTTC);
        totalHT += parseDouble(f.totalHT);

        for (var ligne in f.lignes) {
          totalProduitsVendus += parseInt(ligne.quantite);
        }

        // CA par produit
        for (var l in f.lignes) {
          final nomProduit = l.nomProduit;
          final prix = parseDouble(l.prixHT);
          final qte = parseInt(l.quantite);
          caParProduit[nomProduit] =
              (caParProduit[nomProduit] ?? 0) + prix * qte;
        }
      } catch (e) {
        debugPrint('Erreur lors du calcul pour la facture ${f.numero}: $e');
      }
    }

    return {
      'totalTTC': totalTTC,
      'totalHT': totalHT,
      'totalProduitsVendus': totalProduitsVendus,
      'totalFactures': factures.length,
      'totalClients': clients.length,
      'caParProduit': caParProduit,
    };
  }

  Map<String,double> _calculateClientCA(List<Facture> factures){
    final caParClient = <String,double>{};
    for(var f in factures){
      try{
        final nom = f.nomClient;
        final t = parseDouble(f.totalTTC);
        caParClient[nom] = (caParClient[nom] ?? 0) + t;
      }catch(_){}
    }
    return caParClient;
  }
}

class _ModernStatCard extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final List<Color> gradient;

  const _ModernStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
  });

  @override
  State<_ModernStatCard> createState() => _ModernStatCardState();
}

class _ModernStatCardState extends State<_ModernStatCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(duration: const Duration(milliseconds: 200), vsync: this);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _controller.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: widget.gradient.first.withOpacity(0.25),
                    blurRadius: _isHovered ? 18 : 8,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.value,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.label,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.95),
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
  }
}

// --- Helpers de parsing ---

double parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();

  if (value is String) {
    String cleaned = value.trim().replaceAll(RegExp(r'[^\d\-,\.]'), '');
    cleaned = cleaned.replaceAll(',', '.'); // 1,23 -> 1.23
    final d = double.tryParse(cleaned);
    if (d != null) return d;

    final i = int.tryParse(cleaned.split('.').first);
    return i?.toDouble() ?? 0.0;
  }
  return 0.0;
}

int parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();

  if (value is String) {
    String cleaned = value.trim().replaceAll(RegExp(r'[^\d\-]'), '');
    final i = int.tryParse(cleaned);
    if (i != null) return i;

    final d = double.tryParse(value.trim().replaceAll(',', '.'));
    return d?.toInt() ?? 0;
  }
  return 0;
}
