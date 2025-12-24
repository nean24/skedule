import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:skedule/main.dart'; // Chứa biến supabase global
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:skedule/features/settings/settings_provider.dart';
import 'package:skedule/features/payment/subscription_service.dart';
import 'package:skedule/home/screens/payment_screen.dart';

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

  final SubscriptionService _subService = SubscriptionService();
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    // 1. Kiểm tra quyền Premium
    _checkAccess();
    // 2. Gọi hàm Ping Server (đánh thức Render)
    _pingServer();
  }

  /// Hàm gửi request giả để đánh thức server Render
  Future<void> _pingServer() async {
    final serverUrl = dotenv.env['AI_SERVER_URL'];
    if (serverUrl != null && serverUrl.isNotEmpty) {
      try {
        // Gửi GET request nhẹ nhàng đến root hoặc endpoint health check
        // Timeout ngắn để không treo app, mục đích chỉ là gửi tín hiệu
        await http
            .get(Uri.parse(serverUrl))
            .timeout(const Duration(seconds: 3));
        debugPrint("Đã gửi tín hiệu đánh thức AI Server.");
      } catch (e) {
        // Lỗi timeout là bình thường với Render khi đang sleep, kệ nó
        debugPrint("Ping server error (có thể do đang sleep): $e");
      }
    }
  }

  Future<void> _checkAccess() async {
    final isPrem = await _subService.isPremium();
    if (mounted) {
      setState(() => _isPremium = isPrem);
      _addGreetingMessage(); // Thêm tin nhắn chào sau khi biết trạng thái
    }
  }

  void _addGreetingMessage() {
    // Xóa tin nhắn cũ để tránh duplicate nếu gọi nhiều lần
    _messages.clear();

    final settings = Provider.of<SettingsProvider>(context, listen: false);

    // Tin nhắn hệ thống (luôn hiện)
    _messages.insert(
        0,
        ChatMessage(
            text: settings.strings
                .translate('ai_greeting'), // "Tôi là trợ lý AI..."
            isUser: false));

    // Tin nhắn riêng cho Free User
    if (!_isPremium) {
      _messages.insert(
          0,
          ChatMessage(
              text:
                  "🔒 Chức năng AI đang bị khóa. Nâng cấp Premium để mở khóa ngay!",
              isUser: false));
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
    try {
      await supabase.auth.signOut();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      debugPrint("Lỗi đăng xuất: $error");
    }
  }

  Future<void> _sendMessage({String? text, String? audioFilePath}) async {
    // 1. CHẶN NẾU KHÔNG PHẢI PREMIUM
    if (!_isPremium) {
      _showPremiumDialog();
      return;
    }

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
        _addMessageToChat("Chưa cấu hình Server URL trong .env", isUser: false);
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

      // Tăng timeout lên 60s vì server Render khởi động lâu
      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 60));
      final responseBody = await streamedResponse.stream.bytesToString();

      try {
        final decodedResponse = jsonDecode(responseBody);

        if (streamedResponse.statusCode == 200) {
          final settings =
              Provider.of<SettingsProvider>(context, listen: false);
          final String responseText = decodedResponse['text_response'] ??
              settings.strings.translate('error_no_response');
          final String audioBase64 = decodedResponse['audio_base64'] ?? '';

          if (decodedResponse['user_prompt'] != null && audioFilePath != null) {
            _addMessageToChat(decodedResponse['user_prompt'], isUser: true);
          }

          _addMessageToChat(responseText, isUser: false);

          if (audioBase64.isNotEmpty) {
            _playAudio(audioBase64);
          }
        } else {
          _addMessageToChat(
              "Lỗi server (${streamedResponse.statusCode}): ${decodedResponse['detail'] ?? 'Unknown error'}",
              isUser: false);
        }
      } catch (jsonError) {
        _addMessageToChat("Lỗi phản hồi từ server: $responseBody",
            isUser: false);
      }
    } catch (e) {
      if (e is TimeoutException) {
        _addMessageToChat(
            "Server đang khởi động, vui lòng thử lại sau 30 giây...",
            isUser: false);
        // Gửi lại tín hiệu ping
        _pingServer();
      } else {
        _addMessageToChat("Lỗi kết nối: $e", isUser: false);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRecord() async {
    if (!_isPremium) {
      _showPremiumDialog();
      return;
    }

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
    } catch (e) {
      debugPrint("Lỗi phát audio: $e");
    }
  }

  void _addMessageToChat(String text, {required bool isUser}) {
    setState(() {
      _messages.insert(0, ChatMessage(text: text, isUser: isUser));
    });
  }

  void _showPremiumDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.lock, color: Colors.orange),
          SizedBox(width: 8),
          Text('Tính năng VIP')
        ]),
        content: const Text(
          'Tính năng Trợ lý AI chỉ dành cho tài khoản Premium.\n\nVui lòng nâng cấp để sử dụng tính năng thông minh này!',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF455A75)),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const PaymentScreen()))
                  .then((_) => _checkAccess());
            },
            child: const Text('Nâng cấp ngay',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = colorScheme.background;
    final textColor = colorScheme.onSurface;
    final cardColor = colorScheme.surface;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            Text(settings.strings.translate('skedule_ai'),
                style:
                    TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            if (_isPremium)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(4)),
                child: const Text("PRO",
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              )
          ],
        ),
        backgroundColor: backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          )
        ],
      ),
      body: Column(
        children: [
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
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
                      color: message.isUser
                          ? colorScheme.primary
                          : cardColor,
                      borderRadius: BorderRadius.circular(20.0),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5)
                      ],
                    ),
                    child: Text(
                      message.text,
                      style: TextStyle(
                          color: message.isUser
                              ? Colors.white
                              : textColor),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: LinearProgressIndicator(
                    backgroundColor: Colors.transparent)),
          Container(
            padding: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(25)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2))
              ],
            ),
            child: Container(
              margin:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Flexible(
                    child: GestureDetector(
                      onTap: !_isPremium ? _showPremiumDialog : null,
                      child: TextField(
                        controller: _textController,
                        style: TextStyle(color: textColor),
                        enabled: _isPremium && !_isLoading,
                        onSubmitted: _isLoading
                            ? null
                            : (text) => _sendMessage(text: text),
                        decoration: InputDecoration(
                          hintText: _isPremium
                              ? 'Nhập tin nhắn...'
                              : 'Chức năng chỉ dành cho VIP 🔒',
                          hintStyle:
                              TextStyle(color: textColor.withOpacity(0.5)),
                          border: InputBorder.none,
                          prefixIcon: !_isPremium
                              ? const Icon(Icons.lock, color: Colors.grey)
                              : null,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                        color: _isRecording
                            ? Colors.red.withOpacity(0.1)
                            : Colors.transparent,
                        shape: BoxShape.circle),
                    child: IconButton(
                      icon: Icon(_isRecording
                          ? Icons.stop_circle_outlined
                          : Icons.mic),
                      onPressed: _isLoading ? null : _handleRecord,
                      color: !_isPremium
                          ? Colors.grey
                          : (_isRecording
                              ? Colors.redAccent
                              : colorScheme.primary),
                      iconSize: 24,
                    ),
                  ),
                  IconButton(
                    icon: _isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                                color: colorScheme.primary))
                        : const Icon(Icons.send),
                    color: !_isPremium
                        ? Colors.grey
                        : colorScheme.primary,
                    onPressed: _isLoading
                        ? null
                        : () => _sendMessage(text: _textController.text),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
