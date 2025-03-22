import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;

class ChatScreen extends StatefulWidget {
  final String token;

  const ChatScreen({super.key, required this.token});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late io.Socket socket;
  final _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _users = [];
  String? _selectedUserId;
  String? _currentUserId;
  String? _selectedUsername; // To store the username of the selected user

  @override
  void initState() {
    super.initState();
    _currentUserId = _getUserIdFromToken();
    _fetchUsers();
    _connectSocket();
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

  void _connectSocket() {
    socket = io.io('http://10.0.2.2:5000', {
      'transports': ['websocket'],
      'autoConnect': false,
      'auth': {'token': widget.token},
    });

    socket.connect();

    socket.onConnect((_) {
      print('Connected to Socket.IO');
    });

    socket.on('messageSent', (data) {
      setState(() {
        _messages.add(data);
      });
    });

    socket.on('receiveMessage', (data) {
      setState(() {
        _messages.add(data);
      });
    });

    socket.on('error', (error) {
      print('Socket error: $error');
    });

    socket.onDisconnect((_) {
      print('Disconnected from Socket.IO');
    });
  }

  Future<void> _fetchChatHistory() async {
    if (_selectedUserId == null) return;

    final url = Uri.parse('http://10.0.2.2:5000/api/messages/$_selectedUserId');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer ${widget.token}'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success']) {
        setState(() {
          _messages.clear();
          _messages.addAll(List<Map<String, dynamic>>.from(data['messages']));
        });
      }
    } else {
      print('Failed to fetch chat history: ${response.body}');
    }
  }

  void _sendMessage() {
    if (_selectedUserId == null || _messageController.text.isEmpty) return;

    final message = {
      'receiverId': _selectedUserId,
      'content': _messageController.text,
    };

    socket.emit('sendMessage', message);
    _messageController.clear();
  }

  @override
  void dispose() {
    socket.disconnect();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedUsername != null ? 'Chat with $_selectedUsername' : 'Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchChatHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButton<String>(
              hint: const Text('Select a user to chat with'),
              value: _selectedUserId,
              isExpanded: true,
              items: _users.map((user) {
                return DropdownMenuItem<String>(
                  value: user['_id'],
                  child: Text(user['username']),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedUserId = value;
                  _selectedUsername = _users.firstWhere((user) => user['_id'] == value)['username'];
                  _fetchChatHistory();
                });
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isSentByMe = message['sender'] == _currentUserId;
                return Align(
                  alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSentByMe ? Colors.blue[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSentByMe ? 'You' : _selectedUsername ?? 'Other',
                          style: TextStyle(
                            fontSize: 12,
                            color: isSentByMe ? Colors.blue[800] : Colors.grey[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          message['content'],
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          message['timestamp'].toString().substring(11, 16),
                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
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