import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

  late final GenerativeModel _model;
  late final ChatSession _chat;

  @override
  void initState() {
    super.initState();
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
    );
    _chat = _model.startChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({"text": text, "isUser": true});
      _isLoading = true;
    });

    _messageController.clear();

    try {
      final response = await _chat.sendMessage(Content.text(text));
      final aiText = response.text ?? 'Sorry, I could not understand that.';

      setState(() {
        _messages.add({"text": aiText, "isUser": false});
      });
    } catch (e) {
      String errorMessage = "Network Error. Please try again.";
      String realError = e.toString().toLowerCase();

      if (realError.contains('429') || realError.contains('quota') || realError.contains('exhausted')) {
        errorMessage = "⏳ সার্ভারে অনেক চাপ! দয়া করে একটু অপেক্ষা করে আবার প্রশ্ন করুন। (Rate Limit)";
      } else {
        errorMessage = "Error: $e";
      }

      setState(() {
        _messages.add({"text": errorMessage, "isUser": false});
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Noor-AI: Islamic Companion", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: Text('Send a message to start conversation...', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildChatBubble(msg['text'], msg['isUser']);
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: isUser ? Colors.transparent : Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
          border: Border.all(color: isUser ? Colors.grey.withValues(alpha: 0.5) : Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 16),
          ),
        ),
        child: Text(text, style: const TextStyle(fontSize: 15)),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                onSubmitted: (value) => !_isLoading ? _sendMessage() : null,
                decoration: InputDecoration(
                  hintText: 'Inquire about Islam, History...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(25.0)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              radius: 25,
              child: _isLoading
                  ? const Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0))
                  : IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: _sendMessage),
            ),
          ],
        ),
      ),
    );
  }
}