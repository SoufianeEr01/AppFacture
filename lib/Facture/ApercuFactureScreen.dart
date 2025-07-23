import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/facture.dart';
import '../service/facture_service.dart';

class ApercuFactureScreen extends StatefulWidget {
  final Facture facture;

  const ApercuFactureScreen({super.key, required this.facture});

  @override
  State<ApercuFactureScreen> createState() => _ApercuFactureScreenState();
}

class _ApercuFactureScreenState extends State<ApercuFactureScreen> {
  bool isLoading = false;
  final FactureService _factureService = FactureService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Méthode pour décrémenter le numéro de facture
  Future<void> _decrementFactureNumber() async {
  
      final docRef = _db.collection('numerotation').doc('factures');
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (snapshot.exists && snapshot.data()!.containsKey('dernierNumero')) {
          int current = snapshot.get('dernierNumero');
          if (current > 0) {
            transaction.update(docRef, {'dernierNumero': current - 1});
          }
        }
      });
  }

  // Méthode modifiée pour annuler
  Future<void> _annulerFacture() async {
    await _decrementFactureNumber();
    Navigator.pop(context, false);
  }

  Future<void> confirmerEnregistrement() async {
    setState(() => isLoading = true);

    try {
      final url = await _factureService.saveFactureAndGeneratePDF(widget.facture);

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Facture enregistrée avec succès \n$url'),
        backgroundColor: Colors.green,
      ));

      // Retourner 2 fois en arrière (aperçu + création)
      Navigator.pop(context, true); // Fermer l'aperçu
      Navigator.pop(context); // Fermer la création
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'enregistrement :\n$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Aperçu de la facture',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF3B82F6),
        elevation: 0,
        shadowColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFF3B82F6),
          statusBarIconBrightness: Brightness.light,
        ),
        // Gérer le bouton retour de l'AppBar
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _annulerFacture,
        ),
      ),
      body: WillPopScope(
        // Gérer le bouton retour système
        onWillPop: () async {
          await _decrementFactureNumber();
          return true;
        },
        child: isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xFF3B82F6),
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Génération de la facture...',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Carte principale de la facture
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            spreadRadius: 0,
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // En-tête simple et élégant
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: const BoxDecoration(
                              color: Color(0xFF3B82F6),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'FACTURE',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white70,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'N°${widget.facture.numero}',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${widget.facture.date.day}/${widget.facture.date.month}/${widget.facture.date.year}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Informations client simplifiées
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Client',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    widget.facture.nomClient,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.facture.emailClient,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'ICE: ${widget.facture.iceClient}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Section produits avec référence
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Produits',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                
                                // Tableau modifié avec référence
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    children: [
                                      // En-tête du tableau avec référence
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(8),
                                            topRight: Radius.circular(8),
                                          ),
                                        ),
                                        child: const Row(
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                'Produit',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF475569),
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                'Référence',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF475569),
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                'Prix',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF475569),
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: Text(
                                                'Qté',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF475569),
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                'Total',
                                                textAlign: TextAlign.right,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF475569),
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Lignes de produits avec référence
                                      ...widget.facture.lignes.asMap().entries.map((entry) {
                                        final ligne = entry.value;
                                        final isLast = entry.key == widget.facture.lignes.length - 1;
                                        
                                        return Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            border: !isLast
                                                ? const Border(
                                                    bottom: BorderSide(color: Color(0xFFE2E8F0)),
                                                  )
                                                : null,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 3,
                                                child: Text(
                                                  ligne.nomProduit,
                                                  style: const TextStyle(
                                                    color: Color(0xFF1E293B),
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  ligne.reference.isNotEmpty ? ligne.reference : '-',
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    color: Color(0xFF64748B),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  '${ligne.prixHT.toStringAsFixed(2)} MAD',
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    color: Color(0xFF64748B),
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Text(
                                                  '${ligne.quantite}',
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    color: Color(0xFF64748B),
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  '${ligne.totalLigne.toStringAsFixed(2)} MAD',
                                                  textAlign: TextAlign.right,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(0xFF1E293B),
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Totaux simplifiés
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Total HT',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      Text(
                                        '${widget.facture.totalHT.toStringAsFixed(2)} MAD',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'TVA (20%)',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      Text(
                                        '${(widget.facture.totalHT * 0.2).toStringAsFixed(2)} MAD',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Divider(color: Color(0xFFE2E8F0)),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Total TTC',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                      Text(
                                        '${widget.facture.totalTTC.toStringAsFixed(2)} MAD',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF3B82F6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Boutons d'action modifiés
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: _annulerFacture, // Utiliser la nouvelle méthode
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                            ),
                            child: const Text(
                              'Annuler',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: confirmerEnregistrement,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Confirmer',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
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
  }
}
