import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import '../Produit/produit_screen.dart';
import '../ClientScreen/client_screen.dart';
import '../Facture/CreerFactureScreen.dart';
import '../Facture/FactureDriveScreen.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Facturation App',
      debugShowCheckedModeBanner: false,

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'),
        Locale('en', 'US'),
      ],

      home: const AuthScreen(),

      routes: {
        '/home': (context) => const HomeScreen(),
        '/produits': (context) => const ProduitScreen(),
        '/clients': (context) => const ClientScreen(),
        '/factures': (context) => const CreerFactureScreen(),
        '/auth': (context) => const AuthScreen(),
        '/historiqueFacture': (context) => const FactureDriveScreen(),

      },
    );
  }
}
