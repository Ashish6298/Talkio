import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:cached_network_image/cached_network_image.dart'; // Import cached_network_image
import 'chat_screen.dart';
import 'login_screen.dart';

class UserListScreen extends StatefulWidget {
  final String token;

  const UserListScreen({super.key, required this.token});

  @override
  _UserListScreenState createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _strangers = [];
  List<Map<String, dynamic>> _filteredFriends = [];
  List<Map<String, dynamic>> _filteredStrangers = [];
  String? _currentUserId;
  final _searchController = TextEditingController();
  late io.Socket socket;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Map<String, int> _unreadMessageCounts = {};

  @override
  void initState() {
    super.initState();
    _currentUserId = _getUserIdFromToken();
    _connectSocket();
    _fetchUsers();
    _searchController.addListener(_filterUsers);

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

    socket.on('friendRequestReceived', (data) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Friend request received from ${data['senderUsername']}',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.cyanAccent.withOpacity(0.8),
        ),
      );
      _fetchUsers();
    });

    socket.on('friendRequestSent', (data) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Friend request sent to ${data['receiverUsername']}',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.cyanAccent.withOpacity(0.8),
        ),
      );
      _fetchUsers();
    });

    socket.on('friendRequestAccepted', (data) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${data['username']} is now your friend!',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.cyanAccent.withOpacity(0.8),
        ),
      );
      _fetchUsers();
    });

    socket.on('receiveMessage', (data) {
      final senderId = data['sender'];
      if (_friends.any((friend) => friend['_id'] == senderId)) {
        setState(() {
          _unreadMessageCounts[senderId] = (_unreadMessageCounts[senderId] ?? 0) + 1;
        });
      }
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
          _friends = List<Map<String, dynamic>>.from(data['friends']);
          _strangers = List<Map<String, dynamic>>.from(data['strangers']);
          _filteredFriends = _friends;
          _filteredStrangers = _strangers;
        });
        // Debug: Print the fetched data to verify profilePic is included
        print('Friends: $_friends');
        print('Strangers: $_strangers');
      }
    } else {
      print('Failed to fetch users: ${response.body}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to fetch users',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent.withOpacity(0.8),
        ),
      );
    }
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredFriends = _friends;
        _filteredStrangers = _strangers;
      } else {
        _filteredFriends = _friends
            .where((user) => user['username'].toLowerCase().contains(query))
            .toList();
        _filteredStrangers = _strangers
            .where((user) => user['username'].toLowerCase().contains(query))
            .toList();
      }
    });
  }

  Future<void> _sendFriendRequest(String receiverId) async {
    final url = Uri.parse('http://10.0.2.2:5000/api/send-friend-request');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'receiverId': receiverId}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success']) {
      // Socket.IO will handle the update
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            data['message'] ?? 'Failed to send request',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent.withOpacity(0.8),
        ),
      );
    }
  }

  Future<void> _acceptFriendRequest(String senderId) async {
    final url = Uri.parse('http://10.0.2.2:5000/api/accept-friend-request');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'senderId': senderId}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success']) {
      // Socket.IO will handle the update
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            data['message'] ?? 'Failed to accept request',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent.withOpacity(0.8),
        ),
      );
    }
  }

  void _logout() {
    socket.disconnect();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  void dispose() {
    socket.disconnect();
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
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
              // Header with title and actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: const Text(
                        'Talk-Io',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2.0,
                          shadows: [
                            Shadow(
                              color: Colors.cyanAccent,
                              blurRadius: 10,
                              offset: Offset(0, 0),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.cyanAccent),
                          onPressed: () {
                            _searchController.clear();
                            _fetchUsers();
                          },
                          tooltip: 'Refresh',
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout, color: Colors.cyanAccent),
                          onPressed: _logout,
                          tooltip: 'Logout',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Search bar with glassmorphic effect
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: SlideTransition(
                  position: _slideAnimation,
                  child: _buildSearchBar(),
                ),
              ),
              // User list with slide animation
              Expanded(
                child: SlideTransition(
                  position: _slideAnimation,
                  child: (_friends.isEmpty && _strangers.isEmpty)
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          children: [
                            if (_filteredFriends.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  'Friends',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        color: Colors.cyanAccent,
                                        blurRadius: 5,
                                        offset: Offset(0, 0),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _filteredFriends.length,
                                itemBuilder: (context, index) {
                                  final user = _filteredFriends[index];
                                  final unreadCount = _unreadMessageCounts[user['_id']] ?? 0;
                                  return _buildUserTile(
                                    username: user['username'],
                                    profilePic: user['profilePic'],
                                    unreadCount: unreadCount,
                                    onTap: () {
                                      setState(() {
                                        _unreadMessageCounts[user['_id']] = 0;
                                      });
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
                            ],
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                'People You May Know',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      color: Colors.cyanAccent,
                                      blurRadius: 5,
                                      offset: Offset(0, 0),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            _filteredStrangers.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                      'No users found',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _filteredStrangers.length,
                                    itemBuilder: (context, index) {
                                      final user = _filteredStrangers[index];
                                      return _buildUserTile(
                                        username: user['username'],
                                        profilePic: user['profilePic'],
                                        trailing: user['isReceivedRequest']
                                            ? _buildActionButton(
                                                text: 'Accept',
                                                onPressed: () => _acceptFriendRequest(user['_id']),
                                              )
                                            : user['isSentRequest']
                                                ? const Text(
                                                    'Request Sent',
                                                    style: TextStyle(color: Colors.white70),
                                                  )
                                                : _buildActionButton(
                                                    text: 'Add Friend',
                                                    onPressed: () => _sendFriendRequest(user['_id']),
                                                  ),
                                      );
                                    },
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

  Widget _buildSearchBar() {
    return Container(
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
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search by username',
          hintStyle: const TextStyle(color: Colors.white70),
          prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.cyanAccent),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildUserTile({
    required String username,
    String? profilePic,
    VoidCallback? onTap,
    Widget? trailing,
    int unreadCount = 0,
  }) {
    print('Attempting to load profile picture for $username: $profilePic'); // Debug log
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5.0),
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
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.cyanAccent.withOpacity(0.3),
          child: profilePic != null && profilePic.isNotEmpty
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: profilePic,
                    fit: BoxFit.cover,
                    width: 40,
                    height: 40,
                    placeholder: (context, url) => const CircularProgressIndicator(
                      color: Colors.cyanAccent,
                    ),
                    errorWidget: (context, url, error) {
                      print('Error loading profile picture for $username: $error');
                      return Text(
                        username[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      );
                    },
                  ),
                )
              : Text(
                  username[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
        ),
        title: Row(
          children: [
            Text(
              username,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.cyanAccent,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withOpacity(0.5),
                      blurRadius: 5,
                      offset: const Offset(0, 0),
                    ),
                  ],
                ),
                child: Text(
                  unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        onTap: onTap,
        trailing: trailing,
      ),
    );
  }

  Widget _buildActionButton({required String text, required VoidCallback onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Colors.cyanAccent,
              Colors.blueAccent,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.cyanAccent.withOpacity(0.5),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
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