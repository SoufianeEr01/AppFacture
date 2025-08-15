import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DetailCAClientScreen extends StatefulWidget {
  final Map<String, double> caParClient;
  const DetailCAClientScreen({required this.caParClient, super.key});

  @override
  State<DetailCAClientScreen> createState() => _DetailCAClientScreenState();
}

class _DetailCAClientScreenState extends State<DetailCAClientScreen> {
  late List<MapEntry<String, double>> _entries;
  late List<MapEntry<String, double>> _filtered;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _entries = widget.caParClient.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    _filtered = List.from(_entries);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = List.from(_entries);
      } else {
        _filtered = _entries
            .where((e) => e.key.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  String _formatCurrency(double v) => '${v.toStringAsFixed(2)} DH';

  double _totalCA() =>
      widget.caParClient.values.fold(0.0, (prev, e) => prev + e);

  @override
  Widget build(BuildContext context) {
    final total = _totalCA();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue.shade700,
        centerTitle: true,
        automaticallyImplyLeading: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'CA par client',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          children: [
            // Résumé
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.people_outline,
                        color: Colors.blue.shade700, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total CA clients',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatCurrency(total),
                          style: GoogleFonts.inter(
                              fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${widget.caParClient.length} client(s)',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Recherche
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher un client...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                isDense: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Liste
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off,
                              size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'Aucun client trouvé',
                            style: GoogleFonts.inter(
                                fontSize: 14, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) =>
                          Divider(color: Colors.grey.shade200),
                      itemBuilder: (context, index) {
                        final e = _filtered[index];
                        final percent = total == 0 ? 0.0 : (e.value / total);
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          leading: CircleAvatar(
                            radius: 26,
                            backgroundColor:
                                Colors.primaries[index % Colors.primaries.length]
                                    .shade100,
                            child: Text(
                              _initials(e.key),
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87),
                            ),
                          ),
                          title: Text(
                            e.key,
                            style: GoogleFonts.inter(
                                fontSize: 14, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatCurrency(e.value),
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    minHeight: 8,
                                    value: percent.clamp(0.0, 1.0),
                                    backgroundColor: Colors.grey.shade200,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.blue),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: Text(
                            '${(percent * 100).toStringAsFixed(1)}%',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                          onTap: () {
                            // TODO: navigation vers détail du client si nécessaire
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}