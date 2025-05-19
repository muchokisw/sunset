import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import '../chat/gemini_service.dart';
import '../theme_notifier.dart'; // Import ThemeNotifier
import 'dart:html' as html;

class SendMessageIntent extends Intent {
  const SendMessageIntent();
}

class AddNewLineIntent extends Intent {
  const AddNewLineIntent();
}

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final GeminiService _geminiService = GeminiService();
  final Logger _logger = Logger();
  String? _chatId;
  final List<Map<String, String>> _messages = [];
  List<Map<String, dynamic>> _chats = [];
  StreamSubscription? _messagesSubscription;
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingResponse = false; // Track if the bot is generating a response

  bool get _isSignedIn => FirebaseAuth.instance.currentUser != null;

  @override
  void initState() {
    super.initState();
    if (_isSignedIn) {
      _loadChats();
    }
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _messageController.dispose();
    _focusNode.dispose(); // Dispose the FocusNode
    _scrollController.dispose(); // Dispose the ScrollController
    super.dispose();
  }

  Future<void> _loadChats() async {
    if (!_isSignedIn) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final chatsRef = FirebaseFirestore.instance.collection('users').doc(userId).collection('chats');
      final chatSnapshot = await chatsRef.orderBy('updatedAt', descending: true).get();

      if (!mounted) return;
      setState(() {
        _chats = chatSnapshot.docs.map((doc) {
          return {
            'chatId': doc.id,
            'title': doc['title'],
          };
        }).toList();
      });

      if (_chats.isNotEmpty) {
        _chatId = _chats.first['chatId'];
        _loadMessages();
      }
    } catch (e) {
      _logger.e('Error loading chats: $e');
    }
  }

  Future<void> _startNewChat() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    try {
      final chatsRef = FirebaseFirestore.instance.collection('users').doc(userId).collection('chats');
      final newChat = await chatsRef.add({
        'title': 'New Chat',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await chatsRef.doc(newChat.id).update({'chatId': newChat.id});

      if (!mounted) return;
      setState(() {
        _chats.insert(0, {'chatId': newChat.id, 'title': 'New Chat'});
        _chatId = newChat.id;
        _messages.clear();
        _messages.add({
          'role': 'bot',
          'text': 'Welcome to Shop Assist!\n\nHere are some tips to get a good response:\n\n'
              '• Be specific with your questions.\n'
              '• Provide context if needed.\n'
              '• Ask one question at a time.\n'
              '• Use clear and concise language.',
        });
      });

      _logger.i('New chat started with ID: ${newChat.id}');
    } catch (e) {
      _logger.e('Error starting new chat: $e');
    }
  }

  Future<void> _loadMessages() async {
    if (!_isSignedIn || _chatId == null) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final messagesRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .orderBy('timestamp', descending: false);

      await _messagesSubscription?.cancel();

      _messagesSubscription = messagesRef.snapshots().listen((snapshot) {
        if (!mounted) return;
        setState(() {
          _messages.clear();
          for (var doc in snapshot.docs) {
            _messages.add({
              'role': doc['role'] ?? 'unknown',
              'text': doc['text'] ?? '',
            });
          }
        });
        _scrollToBottom();
        _logger.i('Messages loaded successfully.');
      });
    } catch (e) {
      _logger.e('Error loading messages: $e');
    }
  }

  Future<void> _sendMessage(String message) async {
    if (message.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': message});
      _isLoadingResponse = true; // Show loading indicator
    });

    _messageController.clear();
    _scrollToBottom(); // Ensure the new message and loading indicator are visible

    if (_isSignedIn) {
      await _sendMessageForSignedInUser(message);
    } else {
      await _sendMessageForAnonymousUser(message);
    }

    setState(() {
      _isLoadingResponse = false; // Hide loading indicator
    });

    _scrollToBottom(); // Ensure the bot's response is visible
  }

  Future<void> _sendMessageForSignedInUser(String message) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    if (_chatId == null) {
      await _startNewChat();
    }

    if (_chatId == null) return;

    final messagesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('chats')
        .doc(_chatId)
        .collection('messages');

    try {
      final newMessage = await messagesRef.add({
        'role': 'user',
        'text': message,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await messagesRef.doc(newMessage.id).update({'messageId': newMessage.id});

      if (!mounted) return;

      if (_chats.isNotEmpty && _chats.first['chatId'] == _chatId && _chats.first['title'] == 'New Chat') {
        final chatsRef = FirebaseFirestore.instance.collection('users').doc(userId).collection('chats');
        await chatsRef.doc(_chatId).update({'title': message});

        setState(() {
          _chats.first['title'] = message;
        });
      }

      var response = await _geminiService.sendMessage(message);

      if (response.isEmpty) {
        response = 'No response received.';
      }

      final botMessage = await messagesRef.add({
        'role': 'bot',
        'text': response,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await messagesRef.doc(botMessage.id).update({'messageId': botMessage.id});

      setState(() {
        _messages.add({'role': 'bot', 'text': response});
      });

      _scrollToBottom();
    } catch (e) {
      _logger.e('Error sending message: $e');
      setState(() {
        _messages.add({'role': 'bot', 'text': 'Error: Unable to get a response.'});
      });
    }
  }

  Future<void> _sendMessageForAnonymousUser(String message) async {
    try {
      var response = await _geminiService.sendMessage(message);

      if (response.isEmpty) {
        response = 'No response received.';
      }

      setState(() {
        _messages.add({'role': 'bot', 'text': response});
      });

      _scrollToBottom();
    } catch (e) {
      _logger.e('Error sending message: $e');
      setState(() {
        _messages.add({'role': 'bot', 'text': 'Error: Unable to get a response.'});
      });
    }
  }

  Widget _buildBotResponse(String response, bool isDarkMode) {
    final spans = _parseResponseToSpans(response, isDarkMode);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: RichText(
        text: TextSpan(
          children: spans,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  List<TextSpan> _parseResponseToSpans(String response, bool isDarkMode) {
    final spans = <TextSpan>[];
    final lines = response.split('\n');

    for (var line in lines) {
      final trimmedLine = line.trimLeft();
      final leadingSpaces = line.length - trimmedLine.length;

      if (trimmedLine.startsWith('* ')) {
        if (trimmedLine.contains('**')) {
          final parts = trimmedLine.substring(2).split('**');
          spans.add(
            TextSpan(
              text: '${' ' * leadingSpaces}• ',
              style: TextStyle(
                fontWeight: FontWeight.normal,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          );
          for (var i = 0; i < parts.length; i++) {
            if (i % 2 == 1) {
              spans.add(
                TextSpan(
                  text: parts[i],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              );
            } else {
              spans.add(
                TextSpan(
                  text: parts[i],
                  style: TextStyle(
                    fontWeight: FontWeight.normal,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              );
            }
          }
          spans.add(const TextSpan(text: '\n'));
        } else {
          spans.add(
            TextSpan(
              text: '${' ' * leadingSpaces}• ${trimmedLine.substring(2)}\n',
              style: TextStyle(
                fontWeight: FontWeight.normal,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          );
        }
      } else if (trimmedLine.contains('**')) {
        final parts = trimmedLine.split('**');
        for (var i = 0; i < parts.length; i++) {
          if (i % 2 == 1) {
            spans.add(
              TextSpan(
                text: parts[i],
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            );
          } else {
            spans.add(
              TextSpan(
                text: parts[i],
                style: TextStyle(
                  fontWeight: FontWeight.normal,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            );
          }
        }
        spans.add(const TextSpan(text: '\n'));
      } else {
        spans.add(
          TextSpan(
            text: '${' ' * leadingSpaces}$line\n',
            style: TextStyle(
              fontWeight: FontWeight.normal,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
        );
      }
    }

    return spans;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Always set the title on every build
    html.document.title = 'Sunset Marketplace';
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Shop Assist'),
        actions: _isSignedIn
            ? [
                IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                ),
              ]
            : [
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: ThemeNotifier.themeMode,
                  builder: (context, themeMode, child) {
                    return IconButton(
                     icon: Icon(
              ThemeNotifier.themeMode.value == ThemeMode.light
                  ? Icons.dark_mode
                  : Icons.light_mode,
                      ),
                      onPressed: () {
                        ThemeNotifier.toggleTheme(); // Toggle the theme
                      },
                    );
                  },
                ),
              ],
      ),
      endDrawer: _isSignedIn
          ? Drawer(
              child: Column(
                children: [
                  Container(
                    color: isDarkMode ? Colors.grey[900] : Colors.white,
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        'Chats',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _chats.isEmpty
                        ? const Center(
                            child: CircularProgressIndicator(), // Show loading indicator while chats are loading
                          )
                        : ListView.builder(
                            itemCount: _chats.length,
                            itemBuilder: (context, index) {
                              final chat = _chats[index];
                              final isSelected = chat['chatId'] == _chatId;

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _chatId = chat['chatId'];
                                    _loadMessages();
                                  });
                                  Navigator.pop(context);
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? (isDarkMode ? Colors.grey[800] : Colors.grey[300])
                                        : (isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          chat['title'],
                                          style: TextStyle(
                                            color: isSelected
                                                ? (isDarkMode ? Colors.white : Colors.black)
                                                : (isDarkMode ? Colors.white : Colors.black),
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('New Chat'),
                    onTap: () {
                      _startNewChat();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            )
          : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24.0, 48.0, 24.0, 24.0),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[900] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.all(8.0),
                    child: _messages.isEmpty
                        ? Center(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'Welcome to Shop Assist!',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isDarkMode ? Colors.white : Colors.black,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Here are some tips to get a good response:',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: isDarkMode ? Colors.white : Colors.black,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  const Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('• Be specific with your questions.'),
                                      Text('• Provide context if needed.'),
                                      Text('• Ask one question at a time.'),
                                      Text('• Use clear and concise language.'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            itemCount: _messages.length + (_isLoadingResponse ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (_isLoadingResponse && index == _messages.length) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: CircularProgressIndicator(
                                      color: isDarkMode ? Colors.white : Colors.black,
                                    ),
                                  ),
                                );
                              }

                              final message = _messages[index];
                              final isUser = message['role'] == 'user';

                              if (isUser) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isDarkMode ? Colors.black : Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        message['text'] ?? '',
                                        style: TextStyle(
                                          color: isDarkMode ? Colors.white : Colors.black,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                );
                              } else {
                                return _buildBotResponse(message['text'] ?? '', isDarkMode);
                              }
                            },
                          ),
                  ),
                ),
                Column(
                  children: [
                    Shortcuts(
                      shortcuts: <LogicalKeySet, Intent>{
                        LogicalKeySet(LogicalKeyboardKey.enter): const SendMessageIntent(),
                        LogicalKeySet(LogicalKeyboardKey.enter, LogicalKeyboardKey.shift): const AddNewLineIntent(),
                      },
                      child: Actions(
                        actions: <Type, Action<Intent>>{
                          SendMessageIntent: CallbackAction<SendMessageIntent>(
                            onInvoke: (SendMessageIntent intent) {
                              _sendMessage(_messageController.text); // Send the message
                              return null;
                            },
                          ),
                          AddNewLineIntent: CallbackAction<AddNewLineIntent>(
                            onInvoke: (AddNewLineIntent intent) {
                              final newValue = '${_messageController.text}\n'; // Add a new line
                              _messageController.value = TextEditingValue(
                                text: newValue,
                                selection: TextSelection.collapsed(offset: newValue.length),
                              );
                              return null;
                            },
                          ),
                        },
                        child: Focus(
                          autofocus: true,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _messageController,
                                    decoration: InputDecoration(
                                      hintText: 'Ask',
                                      filled: true,
                                      fillColor: isDarkMode ? Colors.grey[900] : Colors.grey[200],
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(24),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(24),
                                        borderSide: BorderSide.none,
                                      ),
                                      hintStyle: TextStyle(
                                        color: isDarkMode ? Colors.grey[600] : Colors.grey[500],
                                      ),
                                    ),
                                    style: TextStyle(
                                      color: isDarkMode ? Colors.white : Colors.black,
                                    ),
                                    maxLines: null,
                                    focusNode: _focusNode,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: () => _sendMessage(_messageController.text),
                                  icon: const Icon(Icons.send),
                                  color: isDarkMode ? Colors.white : Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Gemini API',
                      style: TextStyle(fontSize: 6, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}