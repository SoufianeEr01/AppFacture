import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/Client.dart';

class ClientService {
  final CollectionReference clientsRef=FirebaseFirestore.instance.collection('clients');

  Future<void> ajouterClient(Client client) async {
  await clientsRef.doc(client.id).set(client.toMap());
  }

  Future<void> modifierClient(Client client) async {
  await clientsRef.doc(client.id).update(client.toMap());
  }

  Future<void> supprimerClient(String id) async {
    await clientsRef.doc(id).delete();
  }

  Future<List<Client>> obtenirTousLesClients() async {
    final snapshot = await clientsRef.get();
    return snapshot.docs.map((doc) {
      return Client.fromMap(doc.data() as Map<String, dynamic>);
    }).toList();
  }

  Stream<List<Client>> ecouterClients() {
    return clientsRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Client.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }
}