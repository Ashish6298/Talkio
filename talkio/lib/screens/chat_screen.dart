

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:logger/logger.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

// Logger setup
class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );

  static void debug(String message) => _logger.d(message);
  static void info(String message) => _logger.i(message);
  static void warning(String message) => _logger.w(message);
  static void error(String message, [dynamic error, StackTrace? stackTrace]) =>
      _logger.e(message, error: error, stackTrace: stackTrace);
}

class ChatScreen extends StatefulWidget {
  final String token;
  final String receiverId;
  final String receiverUsername;
  final String? receiverProfilePic;

  const ChatScreen({
    super.key,
    required this.token,
    required this.receiverId,
    required this.receiverUsername,
    this.receiverProfilePic,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin { // Changed to TickerProviderStateMixin
  late io.Socket socket;
  final _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  String? _currentUserId;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final ScrollController _scrollController = ScrollController();
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  bool _isRecording = false;
  bool _isRecorderInitialized = false;
  bool _isAudioInitializing = false;
  bool _hasMicPermission = false;
  String? _recordedAudioPath;
  int? _recordedDuration;
  DateTime? _recordingStartTime;

  // State for tracking playing voice messages
  String? _currentlyPlayingVoiceId; // Tracks the voiceId of the currently playing voice note
  AnimationController? _pulseAnimationController;
  Animation<double>? _pulseAnimation;

  static const String baseUrl = 'http://10.0.2.2:5000'; // For emulator; replace with your local IP for physical device

  @override
  void initState() {
    super.initState();
    _currentUserId = _getUserIdFromToken();

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

    // Initialize the pulse animation for playing voice notes
    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseAnimationController!, curve: Curves.easeInOut),
    );

    _animationController.forward();

    // Connect socket and fetch data after initialization
    _connectSocket();
    _fetchChatHistory();
    _markMessagesAsSeen();
    _checkAndRequestPermissions();
  }

  Future<String> getDownloadDirectory() async {
    Directory? directory;
    if (Platform.isAndroid) {
      directory = Directory('/storage/emulated/0/Download/Talkio');
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    if (!(await directory.exists())) {
      await directory.create(recursive: true);
    }
    return directory.path;
  }

  Future<void> _checkAndRequestPermissions() async {
    AppLogger.info('Checking and requesting permissions...');
    PermissionStatus micStatus = await Permission.microphone.request();
    setState(() {
      _hasMicPermission = micStatus.isGranted;
    });

    if (_hasMicPermission) {
      AppLogger.info('Microphone permission granted, initializing audio');
      await _initializeAudio();
    } else {
      AppLogger.warning('Microphone permission not granted');
      _showPermissionDialog();
    }

    // Request storage permissions for Android (needed for /storage/emulated/0)
    if (Platform.isAndroid) {
      PermissionStatus storageStatus = await Permission.storage.request();
      if (!storageStatus.isGranted) {
        AppLogger.warning('Storage permission not granted');
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text('This app needs microphone permission to record voice messages. Please enable it in settings.'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
              await _checkAndRequestPermissions();
            },
            child: const Text('Open Settings'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeAudio() async {
    if (!_hasMicPermission) return;

    setState(() => _isAudioInitializing = true);
    try {
      _recorder = FlutterSoundRecorder();
      _player = FlutterSoundPlayer();

      await _recorder!.openRecorder();
      await _player!.openPlayer();

      setState(() {
        _isRecorderInitialized = true;
      });
      AppLogger.info('Audio components initialized successfully');
    } catch (e) {
      AppLogger.error('Failed to initialize audio components', e);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to initialize audio system')),
      );
      setState(() {
        _isRecorderInitialized = false;
      });
    } finally {
      setState(() => _isAudioInitializing = false);
    }
  }

  void _connectSocket() {
    socket = io.io(baseUrl, {
      'transports': ['websocket', 'polling'],
      'autoConnect': false,
      'auth': {'token': widget.token},
      'reconnection': true,
      'reconnectionAttempts': 10,
      'reconnectionDelay': 1000,
      'connectTimeout': 30000,
    });

    socket.connect();

    socket.onConnect((_) {
      AppLogger.info('ChatScreen: Connected to Socket.IO at $baseUrl (User: $_currentUserId)');
    });

    socket.on('messageSent', (data) {
      AppLogger.debug('ChatScreen: Message sent confirmation: $data');
      setState(() {
        if (data['isVoice'] == true && data['localFilePath'] != null) {
          AppLogger.info('Voice message sent with localFilePath: ${data['localFilePath']}');
        }
        _messages.add(data);
        _scrollToBottom();
      });
    });

    socket.on('receiveMessage', (data) {
      AppLogger.debug('ChatScreen: Received message: $data');
      if (data['sender'] == widget.receiverId || data['receiver'] == widget.receiverId) {
        setState(() {
          _messages.add(data);
          _scrollToBottom();
        });
      }
    });

    socket.on('voiceNoteData', (data) async {
      AppLogger.info('Received voiceNoteData: $data');
      final voiceId = data['voiceId'] ?? data['messageId'];
      final voiceData = data['voiceData'];
      final voiceDuration = data['voiceDuration'];
      final messageId = data['messageId'];

      // Save the voice note locally in the Talkio directory with .aac extension
      final directory = await getDownloadDirectory();
      final filePath = '$directory/voice_$voiceId.aac';
      final file = File(filePath);
      final bytes = base64Decode(voiceData);
      await file.writeAsBytes(bytes);

      if (await file.exists()) {
        AppLogger.info('Voice note saved successfully at: $filePath');
      } else {
        AppLogger.error('Failed to save voice note at: $filePath');
        return;
      }

      // Update the message with the local file path and voiceId
      setState(() {
        final messageIndex = _messages.indexWhere((msg) => msg['_id'] == messageId);
        if (messageIndex != -1) {
          _messages[messageIndex]['localFilePath'] = filePath;
          _messages[messageIndex]['voiceId'] = voiceId;
          AppLogger.info('Updated message with localFilePath: $filePath and voiceId: $voiceId');
        } else {
          AppLogger.warning('Message with ID $messageId not found in _messages');
          _messages.add({
            '_id': messageId,
            'isVoice': true,
            'voiceDuration': voiceDuration,
            'localFilePath': filePath,
            'voiceId': voiceId,
            'sender': widget.receiverId,
            'receiver': _currentUserId,
            'timestamp': DateTime.now().toIso8601String(),
          });
          _scrollToBottom();
        }
      });
    });

    socket.on('error', (error) {
      AppLogger.error('ChatScreen: Socket error: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error['error'] ?? 'An error occurred')),
      );
    });
  }

  Future<void> _fetchChatHistory() async {
    final url = Uri.parse('$baseUrl/api/messages/${widget.receiverId}');
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
      AppLogger.error('Failed to fetch chat history: ${response.body}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch chat history')),
      );
    }
  }

  void _markMessagesAsSeen() {
    socket.emit('markMessagesAsSeen', {'senderId': widget.receiverId});
  }

  Future<void> _startRecording() async {
    if (!_hasMicPermission) {
      _showPermissionDialog();
      return;
    }

    if (!_isRecorderInitialized) {
      await _initializeAudio();
      if (!_isRecorderInitialized) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to initialize recorder')),
        );
        return;
      }
    }

    try {
      final directory = await getDownloadDirectory();
      final voiceId = const Uuid().v4();
      final path = '$directory/voice_$voiceId.aac';

      await _recorder!.startRecorder(
        toFile: path,
        codec: Codec.aacADTS,
      );
      setState(() {
        _isRecording = true;
        _recordedAudioPath = path;
        _recordingStartTime = DateTime.now();
      });
      AppLogger.info('Started recording to: $path with voiceId: $voiceId');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording started')),
      );
    } catch (e) {
      AppLogger.error('Error starting recording', e);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start recording')),
      );
      setState(() {
        _isRecording = false;
        _recordedAudioPath = null;
        _recordingStartTime = null;
      });
    }
  }

  Future<void> _stopRecordingAndSend() async {
    if (!_isRecording) return;

    try {
      final path = await _recorder!.stopRecorder();
      final duration = DateTime.now().difference(_recordingStartTime!).inSeconds;

      setState(() {
        _isRecording = false;
        _recordedAudioPath = path;
        _recordedDuration = duration;
      });

      if (await File(path!).exists()) {
        AppLogger.info('Recorded file exists at: $path');
      } else {
        AppLogger.error('Recorded file does not exist at: $path');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save voice message')),
        );
        return;
      }

      final file = File(_recordedAudioPath!);
      final bytes = await file.readAsBytes();
      final voiceData = base64Encode(bytes);

      final voiceId = _recordedAudioPath!.split('voice_').last.replaceAll('.aac', '');

      final message = {
        'receiverId': widget.receiverId,
        'content': 'Voice message',
        'isVoice': true,
        'voiceDuration': duration,
        'voiceData': voiceData,
        'voiceId': voiceId,
        'localFilePath': _recordedAudioPath,
        'sender': _currentUserId,
        'timestamp': DateTime.now().toIso8601String(),
      };

      AppLogger.debug('ChatScreen: Sending voice message: $message');
      socket.emit('sendMessage', message);

      setState(() {
        _recordedAudioPath = null;
        _recordedDuration = null;
        _recordingStartTime = null;
      });
    } catch (e) {
      AppLogger.error('Error stopping recording and sending', e);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send voice message')),
      );
      setState(() {
        _isRecording = false;
        _recordedAudioPath = null;
        _recordedDuration = null;
        _recordingStartTime = null;
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_isRecording) {
      await _stopRecordingAndSend();
      return;
    }

    if (_messageController.text.isEmpty) return;

    final message = {
      'receiverId': widget.receiverId,
      'content': _messageController.text,
      'isVoice': false,
      'sender': _currentUserId,
      'timestamp': DateTime.now().toIso8601String(),
    };

    socket.emit('sendMessage', message);
    setState(() {
      _messageController.clear();
    });
  }

  Future<void> _playVoiceMessage(String? voiceId, String? localFilePath) async {
    AppLogger.info('Attempting to play voice message: voiceId=$voiceId, localFilePath=$localFilePath');

    if (voiceId == null) {
      AppLogger.error('VoiceId is null, cannot play voice message');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot play voice message: Missing voice ID')),
      );
      return;
    }

    // If another voice note is playing, stop it
    if (_currentlyPlayingVoiceId != null && _currentlyPlayingVoiceId != voiceId) {
      await _player!.stopPlayer();
      setState(() {
        _currentlyPlayingVoiceId = null;
      });
      if (_pulseAnimationController != null && _pulseAnimationController!.isAnimating) {
        _pulseAnimationController!.stop();
      }
    }

    // If the same voice note is playing, pause it
    if (_currentlyPlayingVoiceId == voiceId) {
      await _player!.stopPlayer();
      setState(() {
        _currentlyPlayingVoiceId = null;
      });
      if (_pulseAnimationController != null && _pulseAnimationController!.isAnimating) {
        _pulseAnimationController!.stop();
      }
      return;
    }

    String? filePath;

    if (localFilePath != null && await File(localFilePath).exists()) {
      filePath = localFilePath;
      AppLogger.info('Using localFilePath for playback: $filePath');
    } else {
      final directory = await getDownloadDirectory();
      filePath = '$directory/voice_$voiceId.aac';
      AppLogger.info('Constructed file path for playback: $filePath');
    }

    try {
      if (await File(filePath).exists()) {
        AppLogger.info('Playing voice message from: $filePath');
        setState(() {
          _currentlyPlayingVoiceId = voiceId;
        });
        if (_pulseAnimationController != null) {
          _pulseAnimationController!.repeat(reverse: true); // Start the pulsing animation
        }
        await _player!.startPlayer(
          fromURI: filePath,
          whenFinished: () {
            AppLogger.info('Voice message playback finished');
            setState(() {
              _currentlyPlayingVoiceId = null;
            });
            if (_pulseAnimationController != null && _pulseAnimationController!.isAnimating) {
              _pulseAnimationController!.stop();
            }
          },
        );
      } else {
        AppLogger.error('Voice message file not found at: $filePath');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice message file not found')),
        );
      }
    } catch (e) {
      AppLogger.error('Error playing voice message', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to play voice message: $e')),
      );
      setState(() {
        _currentlyPlayingVoiceId = null;
      });
      if (_pulseAnimationController != null && _pulseAnimationController!.isAnimating) {
        _pulseAnimationController!.stop();
      }
    }
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
    _pulseAnimationController?.dispose();
    _scrollController.dispose();
    if (_isRecorderInitialized) {
      _recorder?.closeRecorder();
      _player?.closePlayer();
    }
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
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
                          CircleAvatar(
                            backgroundColor: Colors.cyanAccent.withOpacity(0.3),
                            radius: 20,
                            child: widget.receiverProfilePic != null && widget.receiverProfilePic!.isNotEmpty
                                ? ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: widget.receiverProfilePic!,
                                      fit: BoxFit.cover,
                                      width: 40,
                                      height: 40,
                                      placeholder: (context, url) => const CircularProgressIndicator(),
                                      errorWidget: (context, url, error) => Text(
                                        widget.receiverUsername[0].toUpperCase(),
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  )
                                : Text(
                                    widget.receiverUsername[0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            widget.receiverUsername,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.cyanAccent),
                      onPressed: _fetchChatHistory,
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
                    final username = isSentByMe ? 'You' : widget.receiverUsername;
                    final voiceId = message['voiceId'] as String? ?? message['_id'] as String?;
                    final isPlaying = _currentlyPlayingVoiceId == voiceId;

                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: Row(
                        mainAxisAlignment: isSentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          if (!isSentByMe) ...[
                            CircleAvatar(
                              backgroundColor: Colors.cyanAccent.withOpacity(0.3),
                              radius: 20,
                              child: widget.receiverProfilePic != null && widget.receiverProfilePic!.isNotEmpty
                                  ? ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: widget.receiverProfilePic!,
                                        fit: BoxFit.cover,
                                        width: 40,
                                        height: 40,
                                        placeholder: (context, url) => const CircularProgressIndicator(),
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
                            const SizedBox(width: 10),
                          ],
                          Flexible(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 5),
                              padding: const EdgeInsets.all(12),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                              decoration: BoxDecoration(
                                color: isSentByMe ? Colors.cyanAccent.withOpacity(0.2) : Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Column(
                                crossAxisAlignment: isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    username,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isSentByMe ? Colors.cyanAccent : Colors.white70,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  if (message['isVoice'] == true)
                                    GestureDetector(
                                      onTap: () {
                                        if (voiceId != null) {
                                          _playVoiceMessage(
                                            voiceId,
                                            message['localFilePath'] as String?,
                                          );
                                        } else {
                                          AppLogger.error('No voiceId or messageId found for voice message');
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Cannot play voice message: Missing ID')),
                                          );
                                        }
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _pulseAnimation != null
                                              ? ScaleTransition(
                                                  scale: isPlaying ? _pulseAnimation! : const AlwaysStoppedAnimation(1.0),
                                                  child: Icon(
                                                    isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                                    color: Colors.cyanAccent,
                                                  ),
                                                )
                                              : Icon(
                                                  isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                                  color: Colors.cyanAccent,
                                                ),
                                          const SizedBox(width: 5),
                                          Text(
                                            '${message['voiceDuration']}s',
                                            style: const TextStyle(fontSize: 16, color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    Text(
                                      message['content'],
                                      style: const TextStyle(fontSize: 16, color: Colors.white),
                                    ),
                                  const SizedBox(height: 5),
                                  Text(
                                    _formatTimestamp(message['timestamp']),
                                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Recording status
              if (_isRecording)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text('Recording...', style: TextStyle(color: Colors.redAccent)),
                ),
              // Message input
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
                          ),
                          child: Row(
                            children: [
                              Expanded(
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
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.mic,
                                  color: _isRecording ? Colors.grey : Colors.cyanAccent,
                                ),
                                onPressed: _isRecording ? null : _startRecording,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _sendMessage,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Colors.cyanAccent, Colors.blueAccent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Icon(Icons.send, color: Colors.white),
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