import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'daily_reminder_slider.dart';
import 'package:noor_ai_app/main.dart';
import 'login_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

  late GenerativeModel _model;
  late ChatSession _chat;

  List<String> _apiKeys = [];
  int _currentKeyIndex = 0;
  String? _groqKey;

  @override
  void initState() {
    super.initState();
    _apiKeys = [
      dotenv.env['GEMINI_API_KEY_1'] ?? '',
      dotenv.env['GEMINI_API_KEY_2'] ?? '',
      dotenv.env['GEMINI_API_KEY_3'] ?? '',
      dotenv.env['GEMINI_API_KEY_4'] ?? '',
    ].where((key) => key.isNotEmpty).toList();
    _groqKey = dotenv.env['GROQ_API_KEY'];

    _loadAndStart();
  }

  Future<void> _loadAndStart() async {
    await _loadChatHistory();
    _initModel();
  }

  Future<void> _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedData = prefs.getString('chat_history');

    if (savedData != null) {
      final List<dynamic> decodedData = jsonDecode(savedData);
      setState(() {
        _messages.clear();
        _messages.addAll(decodedData.map((e) => Map<String, dynamic>.from(e)).toList());
      });
    }
  }

  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(_messages);
    await prefs.setString('chat_history', encodedData);
  }

  void _initModel() {
    if (_apiKeys.isEmpty) return;

    List<Content> history = [];
    String lastRole = '';
    String combinedText = '';

    for (int i = 0; i < _messages.length; i++) {
      var msg = _messages[i];
      if (!msg['isUser'] && (msg['text'].contains('⏳') || msg['text'].contains('busy'))) continue;
      if (i == _messages.length - 1 && msg['isUser']) continue;

      String currentRole = msg['isUser'] ? 'user' : 'model';

      if (currentRole == lastRole) {
        combinedText += "\n" + msg['text'];
      } else {
        if (lastRole.isNotEmpty) {
          history.add(lastRole == 'user' ? Content.text(combinedText) : Content.model([TextPart(combinedText)]));
        }
        combinedText = msg['text'];
        lastRole = currentRole;
      }
    }

    if (lastRole == 'model') {
      history.add(Content.model([TextPart(combinedText)]));
    }

    final systemInstruction = '''
 You are Noor-AI, a sophisticated, highly empathetic, and caring Islamic companion dedicated to providing accurate knowledge.
*** STRICT OPERATIONAL PROTOCOLS ***
1. **THEOLOGICAL INTEGRITY (AQEEDAH):**
- **Creator:** Attribute creation SOLELY to Allah (SWT). Never imply human creation for your essence.
- **Development:** If asked about your origin/developer, state: "I was developed and programmed by **Kazi Abdul Halim Sunny**."
- **Smart Trigger:** If asked "What do you do?" or "Ki koro?", describe your function (teaching Islam). Do NOT mention the developer name unless explicitly asked "Who created you?".
2. **SALAM & GREETING PROTOCOL (CRITICAL):**
- **Language Rule:** If the user gives Salam in English, reply: "Wa 'alaykumu s-salam wa rahmatullahi wa barakatuh". If the user gives Salam in Bangla OR Banglish (e.g., "salam", "assalamu alaikum"), you MUST reply in native Bangla script: "ওয়া আলাইকুমুস সালাম ওয়া রাহমাতুল্লাহি ওয়া বারাকাতুহ" and then answer the query.
- If this is the VERY FIRST interaction of the conversation and the user DOES NOT give a salam, you MUST initiate the conversation by saying "Assalamu Alaikum" (or "আসসালামু আলাইকুম" for Bangla/Banglish queries) before answering their question.
- DO NOT say "Walaikumus salam" if the user has NOT given a salam. Do not repeat salams unnecessarily in every message.   
3. **CITATION & LINKS (MANDATORY FORMAT):**
- **Quran:** Write the Ayah meaning normally first in plain text. Then, cite strictly as: **[Surah Name: Ayah](https://quran.com/SURAH_NUMBER/AYAH_NUMBER)**
- **Hadith:** Write the Hadith text normally first in plain text. Then, provide direct, clickable links to **Sunnah.com** where applicable.
  - **Format:** `[Book Name: Number](https://sunnah.com/BOOK_SLUG/NUMBER)`
  - **Example:** **[Sahih al-Bukhari: 1](https://sunnah.com/bukhari:1)**
- **CRITICAL RULE:** NEVER put the Ayah or Hadith text inside the `[ ]` hyperlink brackets. Only the reference name MUST be the link.
4. **IDENTITY & BIO (PRESERVE EXACT TEXT - USE ONLY WHEN ASKED):**
- **Developer Name:** Kazi Abdul Halim Sunny.
- **Bangla Bio (Level 1):** "আমাকে তৈরি করেছেন **কাজী আব্দুল হালিম সানী**। তিনি নিজেকে আল্লাহর একজন নগণ্য গুনাহগার বান্দা এবং 'তালেবুল ইলম' হিসেবে পরিচয় দিতেই ভালোবাসেন। তাঁর একমাত্র ইচ্ছে, মানুষ যেন দ্বীনের সঠিক জ্ঞান পেয়ে আলোকিত হয়। তাঁর জন্য দোয়া করবেন।"
- **Bangla Bio (Level 2):** "দুনিয়াদারি পরিচয়ে তিনি **মেট্রোপলিটন ইউনিভার্সিটির** সফটওয়্যার ইঞ্জিনিয়ারিংয়ের (৪র্থ ব্যাচ) ছাত্র। তিনি একজন তরুণ বাংলাদেশি লেখক এবং ৪টি বই লিখেছেন: 'আজ কেন নয়?', 'একটুকরো স্বপ্ন', 'অমানিশা', এবং 'প্রিটেন্ড' (তরুণদের সমস্যা নিয়ে লেখা উপন্যাস - যার অনলাইন কপি সবার জন্য ফ্রী)।"
5. **THEOLOGICAL INTEGRITY & LANGUAGE:**
- Answer in English for English queries, and strictly in native Bangla script for Bangla/Banglish queries.
- Base your answers strictly on the Quran and authentic Sunnah.
- **Visual Emphasis:** Use **Bold** formatting ONLY for significant Islamic terminology (e.g., **Tawhid**, **Taqwa**) so they render in **GOLD**. Keep normal sentences in plain text to render WHITE.
6. **TAFSIR & QURANIC EXPLANATION PROTOCOL:**
- When asked to explain or elaborate on a Quranic Ayah, you MUST strictly base your answer on recognized classical Tafsir (e.g., **Tafsir Ibn Kathir**, **Tafsir As-Sa'di**, **Tafsir Al-Tabari**, or **Tafsir Al-Qurtubi**).
- NEVER invent your own interpretation, metaphorical meaning, or personal reasoning for any Ayah.
- Always mention the source of the explanation. 
  - English Example: "According to **Tafsir Ibn Kathir**..."
  - Bangla Example: "**তাফসীরে ইবনে কাসীর** অনুযায়ী..."
7. **CONTEXT & KNOWLEDGE USAGE (HIDDEN RAG PROTOCOL):**
- You will sometimes receive background text labeled as "CONTEXT:". This is for your internal knowledge only.
- NEVER use words like "উৎস প্রবন্ধ", "Source article", "প্রদত্ত সোর্স", "Context", or "আপনার দেওয়া ডেটাবেস" in your responses. Treat this injected knowledge seamlessly as your own memory.
- If the user asks a question, first check if the answer is in the CONTEXT. If it is, use it naturally.
- If the answer is NOT in the CONTEXT, DO NOT apologize or say "I cannot find it in the source". Instead, instantly use your vast general Islamic knowledge to answer the question accurately.
- Never expose the mechanical data retrieval process to the user.    
8. **CORE PERSONA & EMOTIONAL INTELLIGENCE (HUMAN-LIKE):**
- Speak like a wise, caring, and respectful human companion. NEVER sound like a robot or a search engine.
- Show empathy. If a user is sad, depressed, or confused, offer comforting words using Islamic perspective (e.g., reliance on Allah, patience) before giving facts.
- Use natural, conversational phrasing. AVOID robotic transitions like "Here is the answer," "Here are the points," or "Based on my knowledge."
- Validate their curiosity (e.g., "মাশাআল্লাহ, আপনার প্রশ্নটি খুবই সুন্দর..." or "আমি বুঝতে পারছি বিষয়টি নিয়ে আপনার মনে কেন দ্বিধা তৈরি হয়েছে...").
9. **STRICT AUTHENTICITY & ZERO HALLUCINATION (CRITICAL):**
- NEVER invent, guess, or hallucinate Islamic rulings, historical events, or Fatwas.
- **THE "ALLAHU ALAM" RULE:** If you do not know the exact answer, or if the user asks a highly debated Fiqh issue, you MUST NOT guess. Gracefully reply: "আল্লাহু আলাম (আল্লাহই সবচেয়ে ভালো জানেন)। এই বিষয়ে সুনির্দিষ্ট ফতোয়া বা রায় দেওয়ার মতো যথেষ্ট জ্ঞান আমার নেই। আমি বিনীতভাবে অনুরোধ করছি, এই বিষয়ে একজন বিজ্ঞ এবং নির্ভরযোগ্য আলেমের শরণাপন্ন হোন।"
 10. COUNSELING: If a user expresses sadness, depression, or suicidal thoughts, DO NOT refuse to answer. Instead, offer deep empathy, hope, and relevant Quranic verses.
 ''';

    final safetySettings = [
      SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
      SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
      SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
      SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
    ];

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKeys[_currentKeyIndex],
      systemInstruction: Content.system(systemInstruction),
      safetySettings: safetySettings,
    );

    _chat = _model.startChat(history: history);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _exportChatToPDF() async {
    if (_messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No chat history available to download!')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating PDF, please wait...')),
    );

    try {
      final pdf = pw.Document();
      final banglaFont = await PdfGoogleFonts.notoSansBengaliRegular();
      final boldFont = await PdfGoogleFonts.notoSansBengaliBold();
      final arabicFont = await PdfGoogleFonts.amiriRegular();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            List<pw.Widget> pdfContent = [
              pw.Header(
                level: 0,
                child: pw.Text('Noor-AI Chat History', style: pw.TextStyle(font: boldFont, fontSize: 24, color: PdfColors.teal)),
              ),
              pw.SizedBox(height: 20),
            ];

            for (var msg in _messages) {
              final isUser = msg['isUser'];
              pdfContent.add(
                pw.Text(
                  isUser ? 'You:' : 'Noor-AI:',
                  style: pw.TextStyle(font: boldFont, fontSize: 14, color: isUser ? PdfColors.blue800 : PdfColors.teal800),
                ),
              );
              pdfContent.add(pw.SizedBox(height: 4));

              final lines = msg['text'].toString().split('\n');
              for (var line in lines) {
                if (line.trim().isNotEmpty) {
                  pdfContent.add(
                    pw.Paragraph(
                      text: line,
                      style: pw.TextStyle(
                          font: banglaFont,
                          fontFallback: [arabicFont],
                          fontSize: 12
                      ),
                    ),
                  );
                }
              }
              pdfContent.add(pw.SizedBox(height: 10));
              pdfContent.add(pw.Divider(color: PdfColors.grey300));
              pdfContent.add(pw.SizedBox(height: 10));
            }

            return pdfContent;
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Noor_AI_Conversation.pdf',
      );
    } catch (e) {
      print("PDF Generation Error: $e");
    }
  }

  Future<void> _callGroqBackup() async {
    if (_groqKey == null || _groqKey!.isEmpty) throw Exception("No Backup Key");

    List<Map<String, String>> groqHistory = [
      {"role": "system", "content": "You are Noor-AI, an Islamic companion. Follow previous instructions strictly."}
    ];

    String lastRole = '';
    String combinedText = '';

    for (int i = 0; i < _messages.length; i++) {
      var msg = _messages[i];
      if (!msg['isUser'] && (msg['text'].contains('⏳') || msg['text'].contains('busy'))) continue;

      String currentRole = msg['isUser'] ? 'user' : 'assistant';

      if (currentRole == lastRole) {
        combinedText += "\n" + msg['text'];
      } else {
        if (lastRole.isNotEmpty) {
          groqHistory.add({"role": lastRole, "content": combinedText});
        }
        combinedText = msg['text'];
        lastRole = currentRole;
      }
    }

    if (lastRole.isNotEmpty) {
      groqHistory.add({"role": lastRole, "content": combinedText});
    }

    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $_groqKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "model": "llama-3.3-70b-versatile",
        "messages": groqHistory
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final aiText = data['choices'][0]['message']['content'];
      setState(() {
        _messages.add({"text": aiText, "isUser": false});
        _isLoading = false;
      });
      _saveChatHistory();
    } else {
      throw Exception("Backup Failed");
    }
  }

  Future<void> _sendMessage({String? retryText}) async {
    final text = retryText ?? _messageController.text.trim();
    if (text.isEmpty) return;

    if (retryText == null) {
      setState(() {
        _messages.add({"text": text, "isUser": true});
        _isLoading = true;
      });
      _saveChatHistory();
      _messageController.clear();
    }

    try {
      final response = await _chat.sendMessage(Content.text(text));
      final aiText = response.text ?? 'Sorry, I could not understand.';

      setState(() {
        _messages.add({"text": aiText, "isUser": false});
        _isLoading = false;
      });
      _saveChatHistory();
    } catch (e) {
      String realError = e.toString().toLowerCase();

      if (realError.contains('503') || realError.contains('429') || realError.contains('quota') || realError.contains('unavailable')) {
        if (_currentKeyIndex < _apiKeys.length - 1) {
          _currentKeyIndex++;
          _initModel();
          await _sendMessage(retryText: text);
          return;
        } else {
          try {
            await _callGroqBackup();
          } catch (backupErr) {
            setState(() {
              _messages.add({"text": "⏳ All servers are currently busy. Please try again later.", "isUser": false});
              _isLoading = false;
            });
          }
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Noor-AI: Islamic Companion", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(themeNotifier.value == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              themeNotifier.value = themeNotifier.value == ThemeMode.dark
                  ? ThemeMode.light
                  : ThemeMode.dark;
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Download Chat as PDF',
            onPressed: _isLoading ? null : _exportChatToPDF,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const DailyReminderSlider(),
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: Text('Send a message to start conversation...', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return _buildTypingIndicator();
                }
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

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2.0, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 10),
            const Text("Noor-AI thinking...", style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
          ],
        ),
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
        child: isUser
            ? Text(text, style: const TextStyle(fontSize: 15))
            : MarkdownBody(
          data: text,
          selectable: true,
          styleSheet: MarkdownStyleSheet(
            p: const TextStyle(fontSize: 15),
            strong: const TextStyle(fontWeight: FontWeight.bold),
            a: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
          ),
          onTapLink: (text, href, title) async {
            if (href != null) {
              final url = Uri.parse(href);
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              }
            }
          },
        ),
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
                onSubmitted: (value) {
                  if (!_isLoading) _sendMessage();
                },
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
                  : IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: () => _sendMessage()),
            ),
          ],
        ),
      ),
    );
  }
}