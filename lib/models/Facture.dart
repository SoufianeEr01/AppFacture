import 'LigneFacture.dart';

class Facture {
  final String id;
  final String clientId;
  final String nomClient;
  final String emailClient;
  final String iceClient;
  final DateTime date;
  final List<LigneFacture> lignes;
  final double totalHT;
  final double totalTTC;
  final int numero;
  final String? pdfUrl;

  Facture({
    required this.id,
    required this.clientId,
    required this.nomClient,
    required this.emailClient,
    required this.iceClient,
    required this.date,
    required this.lignes,
    required this.totalHT,
    required this.totalTTC,
    required this.numero,
    this.pdfUrl,
  });

  Map<String, dynamic> toMap() {
  return {
    'id': id,
    'clientId': clientId,
    'nomClient': nomClient,
    'emailClient': emailClient,
    'iceClient': iceClient,
    'date': date.toIso8601String(),
    'lignes': lignes.map((l) => l.toMap()).toList(),
    'totalHT': totalHT.toString(),
    'totalTTC': totalTTC.toString(),
    'numero': numero.toString(),
    'pdfUrl': pdfUrl,
  };
}


  factory Facture.fromMap(Map<String, dynamic> map) {
  print("Map reçue dans Facture.fromMap: $map");

  return Facture(
    id: map['id'],
    clientId: map['clientId'],
    nomClient: map['nomClient'],
    emailClient: map['emailClient'],
    iceClient: map['iceClient'],
    date: DateTime.parse(map['date']),
    lignes: (map['lignes'] as List)
        .map((item) => LigneFacture.fromMap(Map<String, dynamic>.from(item)))
        .toList(),
    totalHT: map['totalHT'] is num
        ? (map['totalHT'] as num).toDouble()
        : double.tryParse(map['totalHT'].toString()) ?? 0.0,
    totalTTC: map['totalTTC'] is num
        ? (map['totalTTC'] as num).toDouble()
        : double.tryParse(map['totalTTC'].toString()) ?? 0.0,
    numero: map['numero'] is int
        ? map['numero']
        : int.tryParse(map['numero'].toString()) ?? 0,
    pdfUrl: map['pdfUrl'],
  );
}
}
