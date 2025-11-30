import 'package:flutter/material.dart';
import '../utils/constants.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Center(
        child: Text(
          'Eventy - w budowie',
          style: TextStyle(color: AppColors.textColor),
        ),
      ),
    );
  }
}