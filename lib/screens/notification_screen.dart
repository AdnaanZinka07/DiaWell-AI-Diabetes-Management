import 'package:flutter/material.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.blueAccent,
      ),
      body: const Center(
        child: Text(
          'You have no notifications at the moment!',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
