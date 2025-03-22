
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;

class ChatScreen extends StatefulWidget {
  final String token;
  final String receiverId;
  final String receiverUsername;

  const ChatScreen({
    super.key,
    required this.token,
    required this.receiverId,
    required this.receiverUsername,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late io.Socket socket;
  final _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _getUserIdFromToken();
    _connectSocket();
    _fetchChatHistory();
    _markMessagesAsSeen();
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
      if (data['sender'] == widget.receiverId || data['receiver'] == widget.receiverId) {
        setState(() {
          _messages.add(data);
        });
      }
    });

    socket.on('messageSeen', (data) {
      final messageId = data['messageId'];
      setState(() {
        final messageIndex = _messages.indexWhere((msg) => msg['_id'] == messageId);
        if (messageIndex != -1) {
          _messages[messageIndex]['seen'] = true;
        }
      });
    });

    socket.on('error', (error) {
      print('Socket error: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error['error'] ?? 'An error occurred')),
      );
    });

    socket.onDisconnect((_) {
      print('Disconnected from Socket.IO');
    });
  }

  Future<void> _fetchChatHistory() async {
    final url = Uri.parse('http://10.0.2.2:5000/api/messages/${widget.receiverId}');
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch chat history')),
      );
    }
  }

  void _markMessagesAsSeen() {
    socket.emit('markMessagesAsSeen', {'senderId': widget.receiverId});
  }

  void _sendMessage() {
    if (_messageController.text.isEmpty) return;

    final message = {
      'receiverId': widget.receiverId,
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

  String _formatTimestamp(String utcTimestamp) {
    final utcDateTime = DateTime.parse(utcTimestamp);
    final istDateTime = utcDateTime.add(const Duration(hours: 5, minutes: 30));
    return '${istDateTime.hour.toString().padLeft(2, '0')}:${istDateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with ${widget.receiverUsername}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchChatHistory,
          ),
        ],
      ),
      body: Column(
        children: [
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
                          isSentByMe ? 'You' : widget.receiverUsername,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSentByMe ? Colors.blue[800] : Colors.grey[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              message['content'],
                              style: const TextStyle(fontSize: 16),
                            ),
                            if (isSentByMe) ...[
                              const SizedBox(width: 5),
                              Icon(
                                Icons.done_all,
                                size: 16,
                                color: Colors.grey, // Always grey ticks
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTimestamp(message['timestamp']),
                              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                            ),
                            if (isSentByMe && message['seen'] == true) ...[
                              const SizedBox(width: 5),
                              Text(
                                'Seen',
                                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                              ),
                            ],
                          ],
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