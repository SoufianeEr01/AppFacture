class LigneFacture {
  final String produitId;
  final String nomProduit;
  double prixHT;
  int quantite;

  LigneFacture({
    required this.produitId,
    required this.nomProduit,
    required this.prixHT,
    required this.quantite,
  });

  double get totalLigne => prixHT * quantite;

  Map<String, dynamic> toMap() {
  return {
    'produitId': produitId,
    'nomProduit': nomProduit,
    'prixHT': prixHT,
    'quantite': quantite,
  };
}

factory LigneFacture.fromMap(Map<String, dynamic> map) {
  return LigneFacture(
    produitId: map['produitId'],
    nomProduit: map['nomProduit'],
    prixHT: (map['prixHT'] is String)
        ? double.tryParse(map['prixHT']) ?? 0.0
        : (map['prixHT'] as num).toDouble(),
    quantite: (map['quantite'] is String)
        ? int.tryParse(map['quantite']) ?? 0
        : map['quantite'],
  );
}
}