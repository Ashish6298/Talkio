import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';

class ProfileScreen extends StatefulWidget {
  final String token;

  const ProfileScreen({super.key, required this.token});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
    );

    _rotateAnimation = Tween<double>(begin: -0.05, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.2, 0.8, curve: Curves.easeOutBack)),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(1.0, 0), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.4, 1.0, curve: Curves.easeOut)),
    );

    _fetchProfile();
    _animationController.forward();
  }

  Future<void> _fetchProfile() async {
    final url = Uri.parse('http://10.0.2.2:5000/api/profile');
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _profile = data['profile'] as Map<String, dynamic>?;
            _isLoading = false;
          });
        } else {
          throw Exception('API returned success: false - ${data['message'] ?? 'Unknown error'}');
        }
      } else {
        throw Exception('Failed to load profile: ${response.statusCode} - ${response.body}');
      }
    } catch (error) {
      print('Error fetching profile: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load profile: $error',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.redAccent.withOpacity(0.8),
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Method to show the friends list in a popup
  void _showFriendsPopup(BuildContext context) {
    if (_profile == null || _profile!['friends'] == null || (_profile!['friends'] as List).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No friends to display',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    print('Friends list before showing popup: ${_profile!['friends']}'); // Debug
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return FriendsPopup(friends: _profile!['friends'] as List);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0D1B2A),
              Color(0xFF1B263B),
              Color(0xFF415A77),
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                  ),
                )
              : _profile == null
                  ? const Center(
                      child: Text(
                        'Unable to load profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : CustomScrollView(
                      slivers: [
                        SliverFillRemaining(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Profile Card with Rotate and Fade Animation
                                FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: Transform.rotate(
                                    angle: _rotateAnimation.value,
                                    child: Container(
                                      padding: const EdgeInsets.all(20),
                                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.cyanAccent.withOpacity(0.7), width: 2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.3),
                                            blurRadius: 15,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        children: [
                                          CircleAvatar(
                                            radius: 60,
                                            backgroundColor: Colors.cyanAccent.withOpacity(0.3),
                                            child: _profile!['profilePic'] != null && _profile!['profilePic'].isNotEmpty
                                                ? ClipOval(
                                                    child: CachedNetworkImage(
                                                      imageUrl: _profile!['profilePic'] as String,
                                                      fit: BoxFit.cover,
                                                      width: 120,
                                                      height: 120,
                                                      placeholder: (context, url) => const CircularProgressIndicator(
                                                        color: Colors.cyanAccent,
                                                      ),
                                                      errorWidget: (context, url, error) => Text(
                                                        (_profile!['username'] as String)[0].toUpperCase(),
                                                        style: const TextStyle(color: Colors.white, fontSize: 50, fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  )
                                                : Text(
                                                    (_profile!['username'] as String)[0].toUpperCase(),
                                                    style: const TextStyle(color: Colors.white, fontSize: 50, fontWeight: FontWeight.bold),
                                                  ),
                                          ),
                                          const SizedBox(height: 15),
                                          Text(
                                            _profile!['username'] as String,
                                            style: const TextStyle(
                                              fontSize: 32,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 1.5,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            _profile!['email'] as String,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              color: Colors.cyanAccent,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 30),
                                // Info Tiles with Scale Animation
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    GestureDetector(
                                      onTap: () => _showFriendsPopup(context),
                                      child: ScaleTransition(
                                        scale: _scaleAnimation,
                                        child: _buildInfoTile(
                                          title: 'Friends',
                                          value: _profile!['numberOfFriends'].toString(),
                                        ),
                                      ),
                                    ),
                                    ScaleTransition(
                                      scale: Tween<double>(begin: 0.5, end: 1.0).animate(
                                        CurvedAnimation(parent: _animationController, curve: const Interval(0.3, 0.9, curve: Curves.easeOutBack)),
                                      ),
                                      child: _buildInfoTile(
                                        title: 'Sent',
                                        value: _profile!['sentRequestsCount'].toString(),
                                      ),
                                    ),
                                    ScaleTransition(
                                      scale: Tween<double>(begin: 0.5, end: 1.0).animate(
                                        CurvedAnimation(parent: _animationController, curve: const Interval(0.4, 1.0, curve: Curves.easeOutBack)),
                                      ),
                                      child: _buildInfoTile(
                                        title: 'Received',
                                        value: _profile!['receivedRequestsCount'].toString(),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 30),
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

  Widget _buildInfoTile({required String title, required String value}) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.15),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.7), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.cyanAccent,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              letterSpacing: 1.1,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Updated Widget for Friends Popup with Search Bar
class FriendsPopup extends StatefulWidget {
  final List friends;

  const FriendsPopup({super.key, required this.friends});

  @override
  _FriendsPopupState createState() => _FriendsPopupState();
}

class _FriendsPopupState extends State<FriendsPopup> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _filteredFriends = [];

  @override
  void initState() {
    super.initState();
    _filteredFriends = widget.friends;
    _searchController.addListener(_filterFriends);
    print('Initial friends list: ${widget.friends}'); // Debug
  }

  void _filterFriends() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredFriends = widget.friends.where((friend) {
        final username = friend['username']?.toString().toLowerCase() ?? '';
        return username.contains(query);
      }).toList();
      print('Filtered friends for query "$query": $_filteredFriends'); // Debug
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Make the height dynamic based on screen size
    final screenHeight = MediaQuery.of(context).size.height;
    final maxListHeight = screenHeight * 0.4; // 40% of screen height

    return Dialog(
      backgroundColor: Colors.black.withOpacity(0.8), // Semi-opaque background for the dialog to dim the background
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1B263B), // Fully opaque dark background (matches the app's gradient theme)
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.cyanAccent.withOpacity(0.7), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your Friends',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 15),
            // Search Bar
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search friends...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent),
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 15),
            // Friends List with dynamic height
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: maxListHeight, // Dynamic height
                minHeight: 100, // Minimum height to avoid collapse
              ),
              child: _filteredFriends.isEmpty
                  ? const Center(
                      child: Text(
                        'No friends found',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredFriends.length,
                      itemBuilder: (context, index) {
                        final friend = _filteredFriends[index];
                        return _buildFriendCard(
                          username: friend['username']?.toString() ?? 'Unknown',
                          profilePic: friend['profilePic']?.toString(),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 15),
            // Close Button
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent.withOpacity(0.8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendCard({required String username, String? profilePic}) {
    final displayUsername = username.isEmpty ? 'Unknown' : username;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1), // Keep the card slightly transparent for contrast
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.7), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.cyanAccent.withOpacity(0.3),
            child: profilePic != null && profilePic.isNotEmpty
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: profilePic,
                      fit: BoxFit.cover,
                      width: 50,
                      height: 50,
                      placeholder: (context, url) => const CircularProgressIndicator(
                        color: Colors.cyanAccent,
                      ),
                      errorWidget: (context, url, error) => Text(
                        displayUsername[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                : Text(
                    displayUsername[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              displayUsername,
              style: const TextStyle(
                color: Colors.cyanAccent, // Brighter color for better readability
                fontSize: 18, // Larger font size
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}