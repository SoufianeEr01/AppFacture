class LigneFacture {
  final String produitId;
  final String nomProduit;
  final String reference; // Ajouter cette propriété
  double prixHT;
  int quantite;

  LigneFacture({
    required this.produitId,
    required this.nomProduit,
    required this.reference, // Ajouter ici
    required this.prixHT,
    required this.quantite,
  });

  double get totalLigne => prixHT * quantite;

  Map<String, dynamic> toMap() {
    return {
      'produitId': produitId,
      'nomProduit': nomProduit,
      'reference': reference, // Ajouter ici
      'prixHT': prixHT,
      'quantite': quantite,
      'totalLigne': totalLigne,
    };
  }

  factory LigneFacture.fromMap(Map<String, dynamic> map) {
    return LigneFacture(
      produitId: map['produitId'] ?? '',
      nomProduit: map['nomProduit'] ?? '',
      reference: map['reference'] ?? '',
      prixHT: map['prixHT'] is num
          ? (map['prixHT'] as num).toDouble()
          : double.tryParse(map['prixHT'].toString()) ?? 0.0,
      quantite: map['quantite'] is int
          ? map['quantite']
          : int.tryParse(map['quantite'].toString()) ?? 0,
    );
  }
}