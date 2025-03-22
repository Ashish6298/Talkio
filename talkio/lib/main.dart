



import 'package:flutter/material.dart';
import 'screens/register_screen.dart';

void main() {
  runApp(const ConvoFlowApp());
}

class ConvoFlowApp extends StatelessWidget {
  const ConvoFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Talkio', // Updated to match app name
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true, // Optional: Enable Material 3 for modern design
      ),
      home: const RegisterScreen(),
      debugShowCheckedModeBanner: false, // Optional: Remove debug banner
    );
  }
}