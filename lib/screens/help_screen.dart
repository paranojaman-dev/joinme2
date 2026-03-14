import 'package:flutter/material.dart';
import 'package:joinme2/utils/app_localizations.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.translate('help'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            loc.translate('help_title'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
          ),
          const SizedBox(height: 20),
          _buildHelpItem(Icons.visibility, Colors.green, loc.translate('icon_eye_desc')),
          _buildHelpItem(Icons.public, Colors.blue, loc.translate('icon_visibility_desc')),
          _buildHelpItem(Icons.casino, Colors.orange, loc.translate('icon_dice_desc')),
          _buildHelpItem(Icons.refresh, Colors.white, loc.translate('icon_refresh_desc')),
          _buildHelpItem(Icons.my_location, Colors.white, loc.translate('icon_location_desc')),
          _buildHelpItem(Icons.add, Colors.blue, loc.translate('icon_add_desc')),
          _buildHelpItem(Icons.person_search, Colors.teal, loc.translate('icon_search_desc')),
          _buildHelpItem(Icons.push_pin, Colors.cyanAccent, loc.translate('icon_pin_desc')),
        ],
      ),
    );
  }

  Widget _buildHelpItem(IconData icon, Color color, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
