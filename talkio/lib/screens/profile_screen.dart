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

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
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
        if (data['success']) {
          setState(() {
            _profile = data['profile'];
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to load profile: ${response.body}');
      }
    } catch (error) {
      print('Error fetching profile: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load profile',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent.withOpacity(0.8),
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
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
        child: Column( // Removed SafeArea, wrapped content in Column
          children: [
            Expanded( // Added Expanded to ensure content takes full height
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
                            style: TextStyle(color: Colors.white),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Profile Picture
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.cyanAccent.withOpacity(0.3),
                                child: _profile!['profilePic'] != null && _profile!['profilePic'].isNotEmpty
                                    ? ClipOval(
                                        child: CachedNetworkImage(
                                          imageUrl: _profile!['profilePic'],
                                          fit: BoxFit.cover,
                                          width: 100,
                                          height: 100,
                                          placeholder: (context, url) => const CircularProgressIndicator(
                                            color: Colors.cyanAccent,
                                          ),
                                          errorWidget: (context, url, error) => Text(
                                            _profile!['username'][0].toUpperCase(),
                                            style: const TextStyle(color: Colors.white, fontSize: 40),
                                          ),
                                        ),
                                      )
                                    : Text(
                                        _profile!['username'][0].toUpperCase(),
                                        style: const TextStyle(color: Colors.white, fontSize: 40),
                                      ),
                              ),
                              const SizedBox(height: 16),
                              // Username
                              Text(
                                _profile!['username'],
                                style: const TextStyle(
                                  fontSize: 28,
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
                              const SizedBox(height: 8),
                              // Email
                              Text(
                                _profile!['email'],
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Number of Friends
                              _buildInfoCard(
                                title: 'Friends',
                                value: _profile!['numberOfFriends'].toString(),
                              ),
                              const SizedBox(height: 8),
                              // Sent Requests Count
                              _buildInfoCard(
                                title: 'Sent Requests',
                                value: _profile!['sentRequestsCount'].toString(),
                              ),
                              const SizedBox(height: 8),
                              // Received Requests Count
                              _buildInfoCard(
                                title: 'Received Requests',
                                value: _profile!['receivedRequestsCount'].toString(),
                              ),
                              const SizedBox(height: 16),
                              // Friends List
                              if (_profile!['friends'].isNotEmpty) ...[
                                const Text(
                                  'Your Friends',
                                  style: TextStyle(
                                    fontSize: 20,
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
                                const SizedBox(height: 8),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _profile!['friends'].length,
                                  itemBuilder: (context, index) {
                                    final friend = _profile!['friends'][index];
                                    return _buildFriendTile(
                                      username: friend['username'],
                                      profilePic: friend['profilePic'],
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white.withOpacity(0.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.cyanAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendTile({required String username, String? profilePic}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: Colors.white.withOpacity(0.1),
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
                    errorWidget: (context, url, error) => Text(
                      username[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                )
              : Text(
                  username[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
        ),
        title: Text(
          username,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}