import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'volunteer_home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 INITIALIZE FIREBASE
  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kumbh Volunteer App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD9822B),
        ),
        useMaterial3: true,
      ),
      home: const VolunteerHomePage(),
    );
  }
}
