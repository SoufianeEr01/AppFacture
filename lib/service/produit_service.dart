import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/Produit.dart';

class ProduitService {
  final CollectionReference produitsRef =
      FirebaseFirestore.instance.collection('produits');

  Future<void> ajouterProduit(Produit produit) async {
    // Utilisation de doc(produit.id) pour fixer un ID custom, sinon .add() génère un ID auto.
    await produitsRef.doc(produit.id).set(produit.toMap());
  }

  Future<void> modifierProduit(Produit produit) async {
    await produitsRef.doc(produit.id).update(produit.toMap());
  }

  Future<void> supprimerProduit(String id) async {
    await produitsRef.doc(id).delete();
  }

  Future<List<Produit>> obtenirTousLesProduits() async {
    final snapshot = await produitsRef.get();
    return snapshot.docs.map((doc) {
      return Produit.fromMap(doc.data() as Map<String, dynamic>);
    }).toList();
  }

  Stream<List<Produit>> ecouterProduits() {
    return produitsRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Produit.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }
}
