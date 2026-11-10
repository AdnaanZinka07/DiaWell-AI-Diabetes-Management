// lib/widgets/floating_chatbot_button.dart
import 'package:flutter/material.dart';
import '../screens/chatbot_screen.dart';

class FloatingChatbotButton extends StatelessWidget {
  const FloatingChatbotButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 70,
      right: 20,
      child: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChatbotScreen()),
          );
        },
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.chat, color: Colors.white),
      ),
    );
  }
}
