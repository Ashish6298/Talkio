
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:socket_io_client/socket_io_client.dart' as io;

// class ChatScreen extends StatefulWidget {
//   final String token;
//   final String receiverId;
//   final String receiverUsername;

//   const ChatScreen({
//     super.key,
//     required this.token,
//     required this.receiverId,
//     required this.receiverUsername,
//   });

//   @override
//   _ChatScreenState createState() => _ChatScreenState();
// }

// class _ChatScreenState extends State<ChatScreen> {
//   late io.Socket socket;
//   final _messageController = TextEditingController();
//   final List<Map<String, dynamic>> _messages = [];
//   String? _currentUserId;

//   @override
//   void initState() {
//     super.initState();
//     _currentUserId = _getUserIdFromToken();
//     _connectSocket();
//     _fetchChatHistory();
//     _markMessagesAsSeen();
//   }

//   void _connectSocket() {
//     socket = io.io('http://10.0.2.2:5000', {
//       'transports': ['websocket'],
//       'autoConnect': false,
//       'auth': {'token': widget.token},
//     });

//     socket.connect();

//     socket.onConnect((_) {
//       print('Connected to Socket.IO');
//     });

//     socket.on('messageSent', (data) {
//       setState(() {
//         _messages.add(data);
//       });
//     });

//     socket.on('receiveMessage', (data) {
//       if (data['sender'] == widget.receiverId || data['receiver'] == widget.receiverId) {
//         setState(() {
//           _messages.add(data);
//         });
//       }
//     });

//     socket.on('messageDelivered', (data) {
//       final messageId = data['messageId'];
//       setState(() {
//         final messageIndex = _messages.indexWhere((msg) => msg['_id'] == messageId);
//         if (messageIndex != -1) {
//           _messages[messageIndex]['deliveredAt'] = data['deliveredAt'];
//         }
//       });
//     });

//     socket.on('messageSeen', (data) {
//       final messageId = data['messageId'];
//       setState(() {
//         final messageIndex = _messages.indexWhere((msg) => msg['_id'] == messageId);
//         if (messageIndex != -1) {
//           _messages[messageIndex]['seen'] = true;
//           _messages[messageIndex]['seenAt'] = data['seenAt'];
//         }
//       });
//     });

//     socket.on('error', (error) {
//       print('Socket error: $error');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(error['error'] ?? 'An error occurred')),
//       );
//     });

//     socket.onDisconnect((_) {
//       print('Disconnected from Socket.IO');
//     });
//   }

//   Future<void> _fetchChatHistory() async {
//     final url = Uri.parse('http://10.0.2.2:5000/api/messages/${widget.receiverId}');
//     final response = await http.get(
//       url,
//       headers: {'Authorization': 'Bearer ${widget.token}'},
//     );

//     if (response.statusCode == 200) {
//       final data = jsonDecode(response.body);
//       if (data['success']) {
//         setState(() {
//           _messages.clear();
//           _messages.addAll(List<Map<String, dynamic>>.from(data['messages']));
//         });
//       }
//     } else {
//       print('Failed to fetch chat history: ${response.body}');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to fetch chat history')),
//       );
//     }
//   }

//   void _markMessagesAsSeen() {
//     socket.emit('markMessagesAsSeen', {'senderId': widget.receiverId});
//   }

//   void _sendMessage() {
//     if (_messageController.text.isEmpty) return;

//     final message = {
//       'receiverId': widget.receiverId,
//       'content': _messageController.text,
//     };

//     socket.emit('sendMessage', message);
//     _messageController.clear();
//   }

//   @override
//   void dispose() {
//     socket.disconnect();
//     _messageController.dispose();
//     super.dispose();
//   }

//   String _formatTimestampForMessage(String utcTimestamp) {
//     final utcDateTime = DateTime.parse(utcTimestamp);
//     final istDateTime = utcDateTime.add(const Duration(hours: 5, minutes: 30));
//     return '${istDateTime.hour.toString().padLeft(2, '0')}:${istDateTime.minute.toString().padLeft(2, '0')}';
//   }

//   String _formatTimestampForDialog(String? utcTimestamp) {
//     if (utcTimestamp == null) return 'N/A';
//     final utcDateTime = DateTime.parse(utcTimestamp);
//     final istDateTime = utcDateTime.add(const Duration(hours: 5, minutes: 30));
//     return '${istDateTime.day}/${istDateTime.month}/${istDateTime.year} ${istDateTime.hour.toString().padLeft(2, '0')}:${istDateTime.minute.toString().padLeft(2, '0')}';
//   }

//   void _showMessageInfo(Map<String, dynamic> message) {
//     final isSentByMe = message['sender'] == _currentUserId;
//     if (!isSentByMe) return; // Only show info for messages sent by the user

//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Message Info'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Delivered: ${_formatTimestampForDialog(message['deliveredAt'])}'),
//             Text('Seen: ${_formatTimestampForDialog(message['seenAt'])}'),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(' ${widget.receiverUsername}'),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.refresh),
//             onPressed: _fetchChatHistory,
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           Expanded(
//             child: ListView.builder(
//               itemCount: _messages.length,
//               itemBuilder: (context, index) {
//                 final message = _messages[index];
//                 final isSentByMe = message['sender'] == _currentUserId;
//                 return GestureDetector(
//                   onLongPress: () => _showMessageInfo(message),
//                   child: Align(
//                     alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
//                     child: Container(
//                       margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
//                       padding: const EdgeInsets.all(10),
//                       decoration: BoxDecoration(
//                         color: isSentByMe ? Colors.blue[100] : Colors.grey[200],
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       child: Column(
//                         crossAxisAlignment: isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             isSentByMe ? 'You' : widget.receiverUsername,
//                             style: TextStyle(
//                               fontSize: 12,
//                               color: isSentByMe ? Colors.blue[800] : Colors.grey[800],
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           const SizedBox(height: 5),
//                           Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               Text(
//                                 message['content'],
//                                 style: const TextStyle(fontSize: 16),
//                               ),
//                               if (isSentByMe) ...[
//                                 const SizedBox(width: 5),
//                                 Icon(
//                                   Icons.done_all,
//                                   size: 16,
//                                   color: Colors.grey,
//                                 ),
//                               ],
//                             ],
//                           ),
//                           const SizedBox(height: 5),
//                           Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               Text(
//                                 _formatTimestampForMessage(message['timestamp']),
//                                 style: TextStyle(fontSize: 10, color: Colors.grey[600]),
//                               ),
//                               if (isSentByMe && message['seen'] == true) ...[
//                                 const SizedBox(width: 5),
//                                 Text(
//                                   'Seen',
//                                   style: TextStyle(fontSize: 10, color: Colors.grey[600]),
//                                 ),
//                               ],
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//           Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     controller: _messageController,
//                     decoration: const InputDecoration(
//                       hintText: 'Type a message',
//                       border: OutlineInputBorder(),
//                     ),
//                   ),
//                 ),
//                 IconButton(
//                   icon: const Icon(Icons.send),
//                   onPressed: _sendMessage,
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   String? _getUserIdFromToken() {
//     final parts = widget.token.split('.');
//     if (parts.length != 3) return null;
//     final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
//     final decoded = jsonDecode(payload);
//     return decoded['id'];
//   }
// }







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

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  late io.Socket socket;
  final _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  String? _currentUserId;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentUserId = _getUserIdFromToken();
    _connectSocket();
    _fetchChatHistory();
    _markMessagesAsSeen();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();
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
        _scrollToBottom();
      });
    });

    socket.on('receiveMessage', (data) {
      if (data['sender'] == widget.receiverId || data['receiver'] == widget.receiverId) {
        setState(() {
          _messages.add(data);
          _scrollToBottom();
        });
      }
    });

    socket.on('messageDelivered', (data) {
      final messageId = data['messageId'];
      setState(() {
        final messageIndex = _messages.indexWhere((msg) => msg['_id'] == messageId);
        if (messageIndex != -1) {
          _messages[messageIndex]['deliveredAt'] = data['deliveredAt'];
        }
      });
    });

    socket.on('messageSeen', (data) {
      final messageId = data['messageId'];
      setState(() {
        final messageIndex = _messages.indexWhere((msg) => msg['_id'] == messageId);
        if (messageIndex != -1) {
          _messages[messageIndex]['seen'] = true;
          _messages[messageIndex]['seenAt'] = data['seenAt'];
        }
      });
    });

    socket.on('error', (error) {
      print('Socket error: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error['error'] ?? 'An error occurred',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent.withOpacity(0.8),
        ),
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
          _scrollToBottom();
        });
      }
    } else {
      print('Failed to fetch chat history: ${response.body}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to fetch chat history',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent.withOpacity(0.8),
        ),
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    socket.disconnect();
    _messageController.dispose();
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatTimestampForMessage(String utcTimestamp) {
    final utcDateTime = DateTime.parse(utcTimestamp);
    final istDateTime = utcDateTime.add(const Duration(hours: 5, minutes: 30));
    return '${istDateTime.hour.toString().padLeft(2, '0')}:${istDateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatTimestampForDialog(String? utcTimestamp) {
    if (utcTimestamp == null) return 'N/A';
    final utcDateTime = DateTime.parse(utcTimestamp);
    final istDateTime = utcDateTime.add(const Duration(hours: 5, minutes: 30));
    return '${istDateTime.day}/${istDateTime.month}/${istDateTime.year} ${istDateTime.hour.toString().padLeft(2, '0')}:${istDateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showMessageInfo(Map<String, dynamic> message) {
    final isSentByMe = message['sender'] == _currentUserId;
    if (!isSentByMe) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          'Message Info',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delivered: ${_formatTimestampForDialog(message['deliveredAt'])}',
              style: const TextStyle(color: Colors.black54),
            ),
            Text(
              'Seen: ${_formatTimestampForDialog(message['seenAt'])}',
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Colors.cyanAccent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with receiver's username and actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.cyanAccent),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            widget.receiverUsername,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.0,
                              shadows: [
                                Shadow(
                                  color: Colors.cyanAccent,
                                  blurRadius: 5,
                                  offset: Offset(0, 0),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.cyanAccent),
                      onPressed: _fetchChatHistory,
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ),
              // Chat messages
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final isSentByMe = message['sender'] == _currentUserId;
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: GestureDetector(
                        onLongPress: () => _showMessageInfo(message),
                        child: Align(
                          alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            padding: const EdgeInsets.all(12),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.7,
                            ),
                            decoration: BoxDecoration(
                              color: isSentByMe
                                  ? Colors.cyanAccent.withOpacity(0.2)
                                  : Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: isSentByMe
                                      ? Colors.cyanAccent.withOpacity(0.3)
                                      : Colors.black.withOpacity(0.2),
                                  blurRadius: 5,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isSentByMe ? 'You' : widget.receiverUsername,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSentByMe ? Colors.cyanAccent : Colors.white70,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        message['content'],
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    if (isSentByMe) ...[
                                      const SizedBox(width: 5),
                                      Icon(
                                        Icons.done_all,
                                        size: 16,
                                        color: message['seen'] == true ? Colors.cyanAccent : Colors.grey,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatTimestampForMessage(message['timestamp']),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    if (isSentByMe && message['seen'] == true) ...[
                                      const SizedBox(width: 5),
                                      Text(
                                        'Seen',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.cyanAccent,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Message input field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            color: Colors.white.withOpacity(0.1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _messageController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Type a message',
                              hintStyle: const TextStyle(color: Colors.white70),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.transparent,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _sendMessage,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [
                                Colors.cyanAccent,
                                Colors.blueAccent,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.cyanAccent.withOpacity(0.5),
                                blurRadius: 5,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.send,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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