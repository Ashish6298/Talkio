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
import 'package:image_picker/image_picker.dart';
import 'package:device_info_plus/device_info_plus.dart';

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

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
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
  String? _currentlyPlayingVoiceId;
  AnimationController? _pulseAnimationController;
  Animation<double>? _pulseAnimation;
  final ImagePicker _picker = ImagePicker();

  static const String baseUrl = 'http://10.0.2.2:5000'; // Update for physical device if needed

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

    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseAnimationController!, curve: Curves.easeInOut),
    );

    _animationController.forward();

    _connectSocket();
    _fetchChatHistory();
    _markMessagesAsSeen();
    _checkAndRequestPermissions();
  }

  Future<String> getDownloadDirectory() async {
    Directory? directory;
    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory();
      directory = Directory('${directory?.path}/Talkio');
    } else {
      directory = await getApplicationDocumentsDirectory();
      directory = Directory('${directory.path}/Talkio');
    }
    if (!(await directory.exists())) {
      await directory.create(recursive: true);
    }
    return directory.path;
  }

  Future<void> _checkAndRequestPermissions() async {
    AppLogger.info('Checking and requesting permissions...');

    PermissionStatus micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      micStatus = await Permission.microphone.request();
    }

    PermissionStatus storageStatus;
    bool storagePermissionGranted = false;

    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      AppLogger.info('Android SDK version: $sdkInt');

      if (sdkInt >= 33) {
        PermissionStatus photoStatus = await Permission.photos.status;
        if (!photoStatus.isGranted) {
          photoStatus = await Permission.photos.request();
        }
        AppLogger.info('Photo permission: $photoStatus');
        storagePermissionGranted = photoStatus.isGranted;

        PermissionStatus audioStatus = await Permission.audio.status;
        if (!audioStatus.isGranted) {
          audioStatus = await Permission.audio.request();
        }
        AppLogger.info('Audio permission: $audioStatus');
      } else {
        PermissionStatus readStorageStatus = await Permission.storage.status;
        if (!readStorageStatus.isGranted) {
          readStorageStatus = await Permission.storage.request();
        }
        AppLogger.info('Legacy storage permission: $readStorageStatus');
        storagePermissionGranted = readStorageStatus.isGranted;
      }
    } else {
      PermissionStatus storageStatus = await Permission.storage.status;
      if (!storageStatus.isGranted) {
        storageStatus = await Permission.storage.request();
      }
      AppLogger.info('Storage permission (non-Android): $storageStatus');
      storagePermissionGranted = storageStatus.isGranted;
    }

    setState(() {
      _hasMicPermission = micStatus.isGranted;
    });

    List<String> missingPermissions = [];
    if (!micStatus.isGranted) {
      missingPermissions.add('microphone');
    }
    if (!storagePermissionGranted) {
      missingPermissions.add('storage');
    }

    if (missingPermissions.isNotEmpty) {
      AppLogger.warning('Missing permissions: $missingPermissions');
      _showPermissionDialog(missingPermissions);
    } else {
      AppLogger.info('All required permissions are granted');
      if (_hasMicPermission) {
        AppLogger.info('Microphone permission granted, initializing audio');
        await _initializeAudio();
      }

      final directory = await getDownloadDirectory();
      final testFile = File('$directory/test.txt');
      try {
        await testFile.writeAsString('Test');
        AppLogger.info('Successfully wrote to $directory/test.txt');
        await testFile.delete();
      } catch (e) {
        AppLogger.error('Failed to write to $directory/test.txt', e);
        missingPermissions.add('storage');
        _showPermissionDialog(['storage']);
      }
    }
  }

  void _showPermissionDialog(List<String> missingPermissions) {
    String message;
    if (missingPermissions.contains('microphone') && missingPermissions.contains('storage')) {
      message = 'This app needs microphone and storage permissions for voice and image features. Please enable them in settings.';
    } else if (missingPermissions.contains('microphone')) {
      message = 'This app needs microphone permission for voice features. Please enable it in settings.';
    } else {
      message = 'This app needs storage permission for image features. Please enable it in settings.';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: Text(message),
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

    socket.onConnectError((error) {
      AppLogger.error('Socket connection error: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Socket connection error: $error')),
      );
    });

    socket.onDisconnect((_) {
      AppLogger.warning('ChatScreen: Disconnected from Socket.IO');
    });

    socket.on('messageSent', (data) {
      AppLogger.debug('ChatScreen: Message sent confirmation: $data');
      setState(() {
        final messageIndex = _messages.indexWhere((msg) => msg['tempId'] == data['tempId']);
        if (messageIndex != -1) {
          _messages[messageIndex] = {
            ..._messages[messageIndex],
            '_id': data['_id']?.toString(),
            'deliveredAt': data['deliveredAt']?.toString(),
            'seen': data['seen'] ?? false,
            'seenAt': data['seenAt']?.toString(),
          };
        } else {
          _messages.add(data);
        }
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
      final voiceId = data['voiceId']?.toString() ?? data['messageId']?.toString();
      final voiceData = data['voiceData']?.toString();
      final voiceDuration = data['voiceDuration'];
      final messageId = data['messageId']?.toString();

      if (voiceId == null || voiceData == null || messageId == null) {
        AppLogger.error('Missing required fields in voiceNoteData: $data');
        return;
      }

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

      setState(() {
        final messageIndex = _messages.indexWhere((msg) => msg['_id']?.toString() == messageId);
        if (messageIndex != -1) {
          _messages[messageIndex]['localFilePath'] = filePath;
          _messages[messageIndex]['voiceId'] = voiceId;
        } else {
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

    socket.on('imageData', (data) async {
      AppLogger.info('Received imageData: $data');
      final imageId = data['imageId']?.toString() ?? data['messageId']?.toString();
      final imageData = data['imageData']?.toString();
      final messageId = data['messageId']?.toString();

      if (imageId == null || imageData == null || messageId == null) {
        AppLogger.error('Missing required fields in imageData: $data');
        return;
      }

      final directory = await getDownloadDirectory();
      final filePath = '$directory/image_$imageId.jpg';
      final file = File(filePath);
      final bytes = base64Decode(imageData);
      await file.writeAsBytes(bytes);

      if (await file.exists()) {
        AppLogger.info('Image saved successfully at: $filePath');
      } else {
        AppLogger.error('Failed to save image at: $filePath');
        return;
      }

      setState(() {
        final messageIndex = _messages.indexWhere((msg) => msg['_id']?.toString() == messageId);
        if (messageIndex != -1) {
          _messages[messageIndex]['localFilePath'] = filePath;
          _messages[messageIndex]['imageId'] = imageId;
        } else {
          _messages.add({
            '_id': messageId,
            'isImage': true,
            'localFilePath': filePath,
            'imageId': imageId,
            'sender': widget.receiverId,
            'receiver': _currentUserId,
            'timestamp': DateTime.now().toIso8601String(),
          });
          _scrollToBottom();
        }
      });
    });

    socket.on('messageDelivered', (data) {
      AppLogger.info('Message delivered: $data');
      setState(() {
        final messageIndex = _messages.indexWhere((msg) => msg['_id']?.toString() == data['messageId']?.toString());
        if (messageIndex != -1) {
          _messages[messageIndex]['deliveredAt'] = data['deliveredAt']?.toString();
        }
      });
    });

    socket.on('messageSeen', (data) {
      AppLogger.info('Message seen: $data');
      setState(() {
        final messageIndex = _messages.indexWhere((msg) => msg['_id']?.toString() == data['messageId']?.toString());
        if (messageIndex != -1) {
          _messages[messageIndex]['seen'] = true;
          _messages[messageIndex]['seenAt'] = data['seenAt']?.toString();
        }
      });
    });

    socket.on('error', (error) {
      AppLogger.error('ChatScreen: Socket error: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error['error']?.toString() ?? 'An error occurred')),
      );
    });
  }

  Future<void> _fetchChatHistory() async {
    final url = Uri.parse('$baseUrl/api/messages/${widget.receiverId}');
    AppLogger.info('Fetching chat history for receiverId: ${widget.receiverId}');
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      AppLogger.info('Chat history response status: ${response.statusCode}');
      AppLogger.info('Chat history response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.info('Chat history data: $data');
        if (data['success']) {
          final List<Map<String, dynamic>> fetchedMessages = List<Map<String, dynamic>>.from(data['messages']);
          
          // Process each message to ensure localFilePath is set for images and voice notes
          for (var message in fetchedMessages) {
            if (message['isImage'] == true) {
              final imageId = message['imageId']?.toString() ?? message['_id']?.toString();
              if (imageId != null) {
                final directory = await getDownloadDirectory();
                final filePath = '$directory/image_$imageId.jpg';
                final file = File(filePath);

                // Check if the image file already exists
                if (await file.exists()) {
                  message['localFilePath'] = filePath;
                } else if (message['imageData'] != null) {
                  // If the server provides imageData, save it to the local file system
                  final bytes = base64Decode(message['imageData']);
                  await file.writeAsBytes(bytes);
                  if (await file.exists()) {
                    message['localFilePath'] = filePath;
                    AppLogger.info('Image re-saved successfully at: $filePath');
                  } else {
                    AppLogger.error('Failed to re-save image at: $filePath');
                  }
                } else {
                  AppLogger.warning('Image file not found and no imageData provided for imageId: $imageId');
                }
              }
            } else if (message['isVoice'] == true) {
              final voiceId = message['voiceId']?.toString() ?? message['_id']?.toString();
              if (voiceId != null) {
                final directory = await getDownloadDirectory();
                final filePath = '$directory/voice_$voiceId.aac';
                final file = File(filePath);

                if (await file.exists()) {
                  message['localFilePath'] = filePath;
                } else if (message['voiceData'] != null) {
                  final bytes = base64Decode(message['voiceData']);
                  await file.writeAsBytes(bytes);
                  if (await file.exists()) {
                    message['localFilePath'] = filePath;
                    AppLogger.info('Voice note re-saved successfully at: $filePath');
                  } else {
                    AppLogger.error('Failed to re-save voice note at: $filePath');
                  }
                } else {
                  AppLogger.warning('Voice file not found and no voiceData provided for voiceId: $voiceId');
                }
              }
            }
          }

          setState(() {
            _messages.clear();
            _messages.addAll(fetchedMessages);
            AppLogger.info('Messages fetched: ${_messages.length}');
            _scrollToBottom();
          });
        } else {
          AppLogger.warning('Chat history fetch failed: ${data['message']}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to fetch chat history: ${data['message']}')),
          );
        }
      } else {
        AppLogger.error('Failed to fetch chat history: ${response.statusCode} - ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch chat history: ${response.statusCode}')),
        );
      }
    } catch (e) {
      AppLogger.error('Error fetching chat history', e);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error fetching chat history')),
      );
    }
  }

  void _markMessagesAsSeen() {
    socket.emit('markMessagesAsSeen', {'senderId': widget.receiverId});
  }

  Future<void> _startRecording() async {
    if (!_hasMicPermission) {
      await _checkAndRequestPermissions();
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

      final file = File(_recordedAudioPath!);
      final bytes = await file.readAsBytes();
      final voiceData = base64Encode(bytes);

      final voiceId = _recordedAudioPath!.split('voice_').last.replaceAll('.aac', '');

      final tempId = const Uuid().v4();
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
        'tempId': tempId,
      };

      setState(() {
        _messages.add({
          'tempId': tempId,
          'content': 'Voice message',
          'isVoice': true,
          'voiceDuration': duration,
          'localFilePath': _recordedAudioPath,
          'voiceId': voiceId,
          'sender': _currentUserId,
          'timestamp': DateTime.now().toIso8601String(),
        });
        _scrollToBottom();
      });

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
    }
  }

Future<void> _sendImage() async {
  PermissionStatus photoStatus = await Permission.photos.status;
  if (!photoStatus.isGranted) {
    await _checkAndRequestPermissions();
    photoStatus = await Permission.photos.status;
    if (!photoStatus.isGranted) {
      return;
    }
  }

  try {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    // Show preview dialog
    bool? shouldSend = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.file(
              File(image.path),
              width: 300,
              height: 300,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Text(
                'Failed to load image preview',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // Close button
            child: const Text(
              'Close',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true), // Send button
            child: const Text(
              'Send',
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ],
      ),
    );

    if (shouldSend != true) {
      // If user clicks Close or dismisses dialog, return to gallery selection
      return;
    }

    // Proceed with sending if user clicked Send
    final directory = await getDownloadDirectory();
    final imageId = const Uuid().v4();
    final filePath = '$directory/image_$imageId.jpg';
    final file = File(filePath);
    await file.writeAsBytes(await image.readAsBytes());

    if (await file.exists()) {
      AppLogger.info('Image saved successfully at: $filePath');
    } else {
      AppLogger.error('Failed to save image at: $filePath');
      return;
    }

    final bytes = await file.readAsBytes();
    final imageData = base64Encode(bytes);

    final tempId = const Uuid().v4();
    final message = {
      'receiverId': widget.receiverId,
      'content': 'Image',
      'isImage': true,
      'imageData': imageData,
      'imageId': imageId,
      'localFilePath': filePath,
      'sender': _currentUserId,
      'timestamp': DateTime.now().toIso8601String(),
      'tempId': tempId,
    };

    setState(() {
      _messages.add({
        'tempId': tempId,
        'content': 'Image',
        'isImage': true,
        'localFilePath': filePath,
        'imageId': imageId,
        'sender': _currentUserId,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _scrollToBottom();
    });

    socket.emit('sendMessage', message);
  } catch (e) {
    AppLogger.error('Error sending image', e);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to send image')),
    );
  }
}

  Future<void> _sendMessage() async {
    if (_isRecording) {
      await _stopRecordingAndSend();
      return;
    }

    if (_messageController.text.isEmpty) return;

    final tempId = const Uuid().v4();
    final message = {
      'receiverId': widget.receiverId,
      'content': _messageController.text,
      'isVoice': false,
      'sender': _currentUserId,
      'timestamp': DateTime.now().toIso8601String(),
      'tempId': tempId,
    };

    setState(() {
      _messages.add({
        'tempId': tempId,
        'content': _messageController.text,
        'isVoice': false,
        'sender': _currentUserId,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _scrollToBottom();
      _messageController.clear();
    });

    socket.emit('sendMessage', message);
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

    if (_currentlyPlayingVoiceId != null && _currentlyPlayingVoiceId != voiceId) {
      await _player!.stopPlayer();
      setState(() {
        _currentlyPlayingVoiceId = null;
      });
      if (_pulseAnimationController != null && _pulseAnimationController!.isAnimating) {
        _pulseAnimationController!.stop();
      }
    }

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

    String? filePath = localFilePath ?? '${await getDownloadDirectory()}/voice_$voiceId.aac';

    try {
      if (await File(filePath).exists()) {
        setState(() {
          _currentlyPlayingVoiceId = voiceId;
        });
        if (_pulseAnimationController != null) {
          _pulseAnimationController!.repeat(reverse: true);
        }
        await _player!.startPlayer(
          fromURI: filePath,
          whenFinished: () {
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

  String _formatTimestamp(String? utcTimestamp) {
    if (utcTimestamp == null) return '';
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
    final isSentByMe = message['sender']?.toString() == _currentUserId;
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
              'Delivered: ${_formatTimestampForDialog(message['deliveredAt']?.toString())}',
              style: const TextStyle(color: Colors.black54),
            ),
            Text(
              'Seen: ${_formatTimestampForDialog(message['seenAt']?.toString())}',
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
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
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
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
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final isSentByMe = message['sender']?.toString() == _currentUserId;
                    final username = isSentByMe ? 'You' : widget.receiverUsername;
                    final voiceId = message['voiceId']?.toString() ?? message['_id']?.toString();
                    final isPlaying = _currentlyPlayingVoiceId == voiceId;
                    final localFilePath = message['localFilePath']?.toString();

                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: GestureDetector(
                        onLongPress: () => _showMessageInfo(message),
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
                                    if (message['isVoice'] == true && voiceId != null)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          GestureDetector(
                                            onTap: () => _playVoiceMessage(voiceId, localFilePath),
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
                                                  '${message['voiceDuration']?.toString() ?? '0'}s',
                                                  style: const TextStyle(fontSize: 16, color: Colors.white),
                                                ),
                                              ],
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
                                      )
                                    else if (message['isImage'] == true && localFilePath != null)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Image.file(
                                            File(localFilePath),
                                            width: 200,
                                            height: 200,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => const Text(
                                              'Failed to load image',
                                              style: TextStyle(color: Colors.red),
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
                                      )
                                    else
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              message['content']?.toString() ?? '',
                                              style: const TextStyle(fontSize: 16, color: Colors.white),
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
                                          _formatTimestamp(message['timestamp']?.toString()),
                                          style: const TextStyle(fontSize: 10, color: Colors.white70),
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
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_isRecording)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text('Recording...', style: TextStyle(color: Colors.redAccent)),
                ),
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
                                icon: const Icon(Icons.mic, color: Colors.cyanAccent),
                                onPressed: _isRecording ? null : _startRecording,
                              ),
                              IconButton(
                                icon: const Icon(Icons.image, color: Colors.cyanAccent),
                                onPressed: _sendImage,
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
    return decoded['id']?.toString();
  }
}