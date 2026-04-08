import 'package:flutter/material.dart';

class chatScreen extends StatelessWidget{
  const chatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Noor-AI: Islamic Companion",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          'Chat Interface Will be Here...',
          style: TextStyle(
            fontSize: 16,
          ),
        ),
      ),
    );
  }


}