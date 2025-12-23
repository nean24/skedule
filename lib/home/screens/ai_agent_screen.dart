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

    // --- ĐỒNG BỘ MÀU SẮC VỚI CALENDAR/DASHBOARD ---
    // Light: 0xFFDDE3ED (Xám xanh), Dark: 0xFF121212 (Đen)
    final backgroundColor =
        isDark ? const Color(0xFF121212) : const Color(0xFFDDE3ED);

    // Màu chữ
    final textColor =
        isDark ? const Color(0xFFE0E0E0) : const Color(0xFF2D3142);

    // Màu khung chat (Card)
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    // ----------------------------------------------

    return Scaffold(
      backgroundColor: backgroundColor, // Áp dụng màu nền đồng bộ
      appBar: AppBar(
        title: Text(settings.strings.translate('skedule_ai'),
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: backgroundColor, // AppBar cùng màu nền
        elevation: 0, // Bỏ bóng để trông phẳng và liền mạch
        iconTheme: IconThemeData(color: textColor), // Icon màu tương phản
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
          Flexible(
            child: ListView.builder(
              padding:
                  const EdgeInsets.all(16.0), // Tăng padding chút cho thoáng
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (_, int index) {
                final message = _messages[index];
                return Align(
                  alignment: message.isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        vertical: 6.0, horizontal: 4.0),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12.0, horizontal: 16.0),
                    decoration: BoxDecoration(
                      // Bong bóng chat User: Màu xanh (giữ nguyên hoặc chỉnh nhẹ)
                      // Bong bóng chat AI: Màu trắng (Light) hoặc xám đậm (Dark) để nổi trên nền
                      color: message.isUser
                          ? Colors.blue[600]
                          : (isDark ? const Color(0xFF2C2C2C) : Colors.white),
                      borderRadius: BorderRadius.circular(20.0),
                      boxShadow: [
                        // Thêm bóng nhẹ cho bong bóng chat để tách biệt khỏi nền
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Text(
                      message.text,
                      style: TextStyle(
                        color: message.isUser
                            ? Colors.white
                            : (isDark ? Colors.white : Colors.black87),
                        fontSize: 15,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child:
                  LinearProgressIndicator(backgroundColor: Colors.transparent),
            ),

          // --- KHU VỰC NHẬP LIỆU ---
          Container(
            padding: const EdgeInsets.only(
                bottom: 10), // Padding cho safe area nếu cần
            decoration: BoxDecoration(
              color: cardColor, // Màu nền trắng/đen cho khung nhập
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(25)), // Bo tròn góc trên
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                )
              ],
            ),
            child: _buildTextComposer(textColor, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildTextComposer(Color textColor, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Flexible(
            child: TextField(
              controller: _textController,
              style: TextStyle(color: textColor),
              onSubmitted:
                  _isLoading ? null : (text) => _sendMessage(text: text),
              decoration: InputDecoration(
                hintText: 'Nhập hoặc giữ nút micro để nói...',
                hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
                border: InputBorder.none, // Bỏ viền mặc định của TextField
              ),
              enabled: !_isLoading,
            ),
          ),
          // Nút Micro
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: _isRecording
                  ? Colors.red.withOpacity(0.1)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(_isRecording ? Icons.stop_circle_outlined : Icons.mic),
              onPressed: _isLoading ? null : _handleRecord,
              color: _isRecording
                  ? Colors.redAccent
                  : Theme.of(context).primaryColor,
              iconSize: 24,
            ),
          ),
          // Nút Gửi
          IconButton(
            icon: _isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        color: Theme.of(context).primaryColor))
                : const Icon(Icons.send),
            color: Theme.of(context).primaryColor,
            onPressed: _isLoading
                ? null
                : () => _sendMessage(text: _textController.text),
          )
        ],
      ),
    );
  }
}
