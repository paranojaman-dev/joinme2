import 'package:flutter/material.dart';
import '../utils/constants.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Center(
        child: Text(
          'Czat - w budowie',
          style: TextStyle(color: AppColors.textColor),
        ),
      ),
    );
  }
}