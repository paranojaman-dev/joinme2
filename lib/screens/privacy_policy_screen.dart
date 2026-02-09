import 'package:flutter/material.dart';
import 'package:joinme2/utils/app_localizations.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.translate('privacy_policy'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.translate('pp_title'),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildSection(
              loc.translate('pp_1_title'),
              loc.translate('pp_1_content'),
            ),
            _buildSection(
              loc.translate('pp_2_title'),
              loc.translate('pp_2_content'),
            ),
            _buildSection(
              loc.translate('pp_3_title'),
              loc.translate('pp_3_content'),
            ),
            _buildSection(
              loc.translate('pp_4_title'),
              loc.translate('pp_4_content'),
            ),
            _buildSection(
              loc.translate('pp_5_title'),
              loc.translate('pp_5_content'),
            ),
            const SizedBox(height: 30),
            Text(
              loc.translate('pp_last_update'),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.white70)),
        ],
      ),
    );
  }
}
