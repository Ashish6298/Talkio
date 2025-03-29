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

    _rotateAnimation = Tween<double>(begin: -0.1, end: 0.0).animate(
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
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
        child: Column(
          children: [
            Expanded(
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
                      : SingleChildScrollView(
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
                                    margin: const EdgeInsets.symmetric(horizontal: 20),
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
                                                    imageUrl: _profile!['profilePic'],
                                                    fit: BoxFit.cover,
                                                    width: 120,
                                                    height: 120,
                                                    placeholder: (context, url) => const CircularProgressIndicator(
                                                      color: Colors.cyanAccent,
                                                    ),
                                                    errorWidget: (context, url, error) => Text(
                                                      _profile!['username'][0].toUpperCase(),
                                                      style: const TextStyle(color: Colors.white, fontSize: 50, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                )
                                              : Text(
                                                  _profile!['username'][0].toUpperCase(),
                                                  style: const TextStyle(color: Colors.white, fontSize: 50, fontWeight: FontWeight.bold),
                                                ),
                                        ),
                                        const SizedBox(height: 15),
                                        Text(
                                          _profile!['username'],
                                          style: const TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _profile!['email'],
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
                                  ScaleTransition(
                                    scale: _scaleAnimation,
                                    child: _buildInfoTile(
                                      title: 'Friends',
                                      value: _profile!['numberOfFriends'].toString(),
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
                              // Friends Grid with Slide Animation
                              if (_profile!['friends'].isNotEmpty) ...[
                                Text(
                                  'Your Friends',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 15),
                                SlideTransition(
                                  position: _slideAnimation,
                                  child: FadeTransition(
                                    opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                                      CurvedAnimation(parent: _animationController, curve: const Interval(0.4, 1.0, curve: Curves.easeIn)),
                                    ),
                                    child: Wrap(
                                      spacing: 15,
                                      runSpacing: 15,
                                      alignment: WrapAlignment.center,
                                      children: List.generate(
                                        _profile!['friends'].length,
                                        (index) {
                                          final friend = _profile!['friends'][index];
                                          return _buildFriendCard(
                                            username: friend['username'],
                                            profilePic: friend['profilePic'],
                                          );
                                        },
                                      ),
                                    ),
                                  ),
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

  Widget _buildFriendCard({required String username, String? profilePic}) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
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
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.cyanAccent.withOpacity(0.3),
            child: profilePic != null && profilePic.isNotEmpty
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: profilePic,
                      fit: BoxFit.cover,
                      width: 60,
                      height: 60,
                      placeholder: (context, url) => const CircularProgressIndicator(
                        color: Colors.cyanAccent,
                      ),
                      errorWidget: (context, url, error) => Text(
                        username[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                : Text(
                    username[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            username,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}