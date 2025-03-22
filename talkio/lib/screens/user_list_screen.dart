import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'chat_screen.dart';

class UserListScreen extends StatefulWidget {
  final String token;

  const UserListScreen({super.key, required this.token});

  @override
  _UserListScreenState createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  List<Map<String, dynamic>> _users = [];
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _getUserIdFromToken();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    final url = Uri.parse('http://10.0.2.2:5000/api/users');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer ${widget.token}'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success']) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(data['users'])
              .where((user) => user['_id'] != _currentUserId)
              .toList();
        });
      }
    } else {
      print('Failed to fetch users: ${response.body}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchUsers,
          ),
        ],
      ),
      body: _users.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return ListTile(
                  title: Text(user['username']), // Only show username
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          token: widget.token,
                          receiverId: user['_id'],
                          receiverUsername: user['username'],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  String? _getUserIdFromToken() {
    final parts = widget.token.split('.');
    if (parts.length != 3) return null;
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final decoded = jsonDecode(payload);
    return decoded['id'];
  }
}