import 'package:flutter/material.dart';

class CreateEventScreen extends StatelessWidget {
  const CreateEventScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stwórz event'),
      ),
      body: const Center(
        child: Text('Ekran tworzenia eventu - w budowie'),
      ),
    );
  }
}