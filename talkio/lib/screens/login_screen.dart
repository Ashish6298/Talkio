



import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'user_list_screen.dart'; // Import the new UserListScreen

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;

  Future<void> _login() async {
    final url = Uri.parse('http://10.0.2.2:5000/api/auth/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': _usernameController.text,
        'password': _passwordController.text,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success']) {
      final token = data['token'];
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => UserListScreen(token: token), // Navigate to UserListScreen
        ),
      );
    } else {
      setState(() {
        _errorMessage = data['message'] ?? 'Login failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _login,
              child: const Text('Login'),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}