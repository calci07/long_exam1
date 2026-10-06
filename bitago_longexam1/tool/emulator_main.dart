// Local browser verification only: flutter run -d chrome -t tool/emulator_main.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:bitago_longexam1/main.dart' as app;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'demo-key',
      appId: '1:123:web:demo',
      messagingSenderId: '123',
      projectId: 'demo-bitago',
      authDomain: 'demo-bitago.firebaseapp.com',
    ),
  );
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );
  FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8088);
  await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
  runApp(const app.MyApp());
}
