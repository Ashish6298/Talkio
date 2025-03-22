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
      title: 'Talkio',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const RegisterScreen(),
    );
  }
}