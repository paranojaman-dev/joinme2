import 'package:flutter/material.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Ustawienia'),
        backgroundColor: AppColors.surfaceColor,
      ),
      body: const Center(
        child: Text(
          'Ustawienia - w budowie',
          style: TextStyle(color: AppColors.textColor),
        ),
      ),
    );
  }
}
