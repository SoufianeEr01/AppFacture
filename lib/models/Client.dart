class Client{
  final String id;
  final String nom ;
  final String email;
  final int ice;

Client ({
  required this.id,
  required this.nom,
  required this.email,
  required this.ice,
});

Map<String, dynamic> toMap() {
  return {
    'id':id,
    'nom':nom,
    'email':email,
    'ice':ice,
  };
}

factory Client.fromMap(Map<String, dynamic> map){
  return Client(
    id: map['id'] ?? '',
    nom: map['nom'] ?? '',
    email: map['email'] ?? '',
    ice: map['ice'] ?? 0,

  );
}
}