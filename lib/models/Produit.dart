class Produit {
  final String id;
  final String reference; // ✅ Nouveau champ
  final String nom;
  final String description;
  final double prixHT;

  Produit({
    required this.id,
    required this.reference, // ✅ Ajouté ici
    required this.nom,
    this.description = '',
    required this.prixHT,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reference': reference, // ✅ Ajouté ici
      'nom': nom,
      'description': description,
      'prixHT': prixHT,
    };
  }

  factory Produit.fromMap(Map<String, dynamic> map) {
    return Produit(
      id: map['id'] ?? '',
      reference: map['reference'] ?? '', // ✅ Ajouté ici
      nom: map['nom'] ?? '',
      description: map['description'] ?? '',
      prixHT: (map['prixHT'] as num).toDouble(),
    );
  }
}
