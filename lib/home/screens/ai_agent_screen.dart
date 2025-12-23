import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:skedule/main.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:skedule/features/settings/settings_provider.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

class AiAgentScreen extends StatefulWidget {
  const AiAgentScreen({super.key});

  @override
  State<AiAgentScreen> createState() => _AiAgentScreenState();
}

class _AiAgentScreenState extends State<AiAgentScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;

  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    // Initial message will be set in build or handled differently to support localization
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_messages.isEmpty) {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      _messages.insert(
          0,
          ChatMessage(
              text: settings.strings.translate('ai_greeting'), isUser: false));
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    try {
      await supabase.auth.signOut();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(settings.strings.translate('error_sign_out')),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _sendMessage({String? text, String? audioFilePath}) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if ((text == null || text.isEmpty) && audioFilePath == null) return;

    if (text != null) _textController.clear();

    setState(() {
      // Nếu là tin nhắn văn bản, thêm vào UI ngay
      if (text != null) {
        _messages.insert(0, ChatMessage(text: text, isUser: true));
      }
      _isLoading = true;
    });

    try {
      final session = supabase.auth.currentSession;
      if (session == null) {
        _signOut();
        return;
      }
      final accessToken = session.accessToken;
      final serverUrl = dotenv.env['AI_SERVER_URL'];

      if (serverUrl == null || serverUrl.isEmpty) {
        _addMessageToChat(settings.strings.translate('error_config_ai_url'),
            isUser: false);
        setState(() => _isLoading = false);
        return;
      }

      var request = http.MultipartRequest('POST', Uri.parse('$serverUrl/chat'));
      request.headers['Authorization'] = 'Bearer $accessToken';
      request.headers['ngrok-skip-browser-warning'] = 'true';

      if (text != null) {
        request.fields['prompt'] = text;
      } else if (audioFilePath != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'audio_file',
          audioFilePath,
          contentType: MediaType('audio', 'm4a'),
        ));
      }

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 45));
      final responseBody = await streamedResponse.stream.bytesToString();
      final decodedResponse = jsonDecode(responseBody);

      if (streamedResponse.statusCode == 200) {
        final String? userPrompt = decodedResponse['user_prompt'];
        final String responseText = decodedResponse['text_response'] ??
            settings.strings.translate('error_no_response');
        final String audioBase64 = decodedResponse['audio_base64'] ?? '';

        // Nếu input là audio, giờ chúng ta mới thêm tin nhắn của người dùng vào UI
        if (userPrompt != null) {
          _addMessageToChat(userPrompt, isUser: true);
        }

        _addMessageToChat(responseText, isUser: false);

        if (audioBase64.isNotEmpty) {
          _playAudio(audioBase64);
        }
      } else {
        final String errorMessage = decodedResponse['detail'] ??
            '${settings.strings.translate('error_unknown_server')} (${streamedResponse.statusCode}).';
        _addMessageToChat(
            '${settings.strings.translate('error')}: $errorMessage',
            isUser: false);
      }
    } on TimeoutException {
      _addMessageToChat(settings.strings.translate('error_connection_timeout'),
          isUser: false);
    } catch (e) {
      _addMessageToChat("${settings.strings.translate('error_connection')}: $e",
          isUser: false);
      print("--- DEBUG: Lỗi chi tiết: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleRecord() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      if (path != null) {
        setState(() => _isRecording = false);
        // Không thêm tin nhắn tạm thời nữa, chỉ gửi file đi
        _sendMessage(audioFilePath: path);
      }
    } else {
      if (await Permission.microphone.request().isGranted) {
        final dir = await getApplicationDocumentsDirectory();
        await _audioRecorder.start(const RecordConfig(),
            path: '${dir.path}/recording.m4a');
        setState(() => _isRecording = true);
      } else {
        _addMessageToChat(settings.strings.translate('error_mic_permission'),
            isUser: false);
      }
    }
  }

  Future<void> _playAudio(String base64Audio) async {
    try {
      final audioBytes = base64Decode(base64Audio);
      await _audioPlayer.play(BytesSource(audioBytes));
      _audioPlayer.onPlayerComplete.listen((event) {
        if (mounted) setState(() {});
      });
    } catch (e) {
      print("Lỗi phát audio: $e");
    }
  }

  void _addMessageToChat(String text, {required bool isUser}) {
    setState(() {
      _messages.insert(0, ChatMessage(text: text, isUser: isUser));
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    // Colors based on theme
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    final appBarColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF2D3142);
    final inputBgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final hintColor = isDark ? Colors.grey[400] : Colors.grey[500];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          settings.strings.translate('skedule_ai'),
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: settings.strings.translate('sign_out'),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (_, int index) {
                final message = _messages[index];
                return _buildMessageBubble(message, isDark);
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                color: Color(0xFF3B82F6),
                minHeight: 2,
              ),
            ),
          _buildTextComposer(isDark, inputBgColor, textColor, hintColor),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isDark) {
    final isUser = message.isUser;
    final bubbleColor = isUser
        ? const Color(0xFF3B82F6) // Blue for user
        : (isDark ? const Color(0xFF2C2C2C) : Colors.white); // Dark grey or White for AI

    final textColor = isUser
        ? Colors.white
        : (isDark ? Colors.white : const Color(0xFF2D3142));

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 16.0, left: isUser ? 50 : 0, right: isUser ? 0 : 50),
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(4),
              bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(20),
            ),
            boxShadow: [
              if (!isDark && !isUser)
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
            ]
        ),
        child: Text(
          message.text,
          style: TextStyle(color: textColor, fontSize: 15, height: 1.4),
        ),
      ),
    );
  }

  Widget _buildTextComposer(bool isDark, Color bgColor, Color textColor, Color? hintColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
          color: bgColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              offset: const Offset(0, -2),
              blurRadius: 10,
            )
          ]
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        style: TextStyle(color: textColor),
                        onSubmitted: _isLoading ? null : (text) => _sendMessage(text: text),
                        decoration: InputDecoration(
                          hintText: 'Message...',
                          hintStyle: TextStyle(color: hintColor),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        enabled: !_isLoading,
                      ),
                    ),
                    IconButton(
                      icon: Icon(_isRecording ? Icons.stop_circle : Icons.mic_none_rounded),
                      onPressed: _isLoading ? null : _handleRecord,
                      color: _isRecording ? Colors.redAccent : Colors.grey[600],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF3B82F6),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: _isLoading
                    ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white))
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                onPressed: _isLoading
                    ? null
                    : () => _sendMessage(text: _textController.text),
              ),
            )
          ],
        ),
      ),
    );
  }
}
