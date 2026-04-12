import 'package:flutter/material.dart';
import 'presentation/screens/login_screen.dart';

void main()
{
   runApp(const NoorAIApp());
}

class NoorAIApp extends StatelessWidget
{
  const NoorAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Noor-AI',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFC5A059),
              brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const LoginScreen(),
    );
  }
}