import 'package:flutter/material.dart';
import 'package:joinme2/screens/main_screen.dart';
import 'package:joinme2/utils/app_localizations.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(loc.translate('premium')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            // Jeśli użytkownik zamknie ekran premium po onboardingu, idzie do Main
            Navigator.pushReplacement(
              context, 
              MaterialPageRoute(builder: (context) => const MainScreen())
            );
          },
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: Center(child: Icon(Icons.chair, size: 350, color: Colors.green.shade700)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const Icon(Icons.stars_rounded, size: 80, color: Colors.amber),
                const SizedBox(height: 16),
                Text(
                  loc.translate('premium').toUpperCase(),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.amber, letterSpacing: 2),
                ),
                const SizedBox(height: 12),
                Text(
                  loc.translate('premium_desc'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 40),
                
                // KORZYŚCI - Zlokalizowane
                _buildBenefit(Icons.block, loc.translate('benefit_ads'), Colors.green),
                _buildBenefit(Icons.map_outlined, loc.translate('benefit_maps'), Colors.blue),
                _buildBenefit(Icons.verified_user, loc.translate('benefit_badge'), Colors.amber),
                _buildBenefit(Icons.history_toggle_off, loc.translate('benefit_views'), Colors.purple),
                
                const Spacer(),
                
                // PANEL ZAKUPU
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
                  ),
                  child: Column(
                    children: [
                      Text(
                        loc.translate('price_monthly'), 
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: () {
                            // Tu będzie in_app_purchase
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          child: Text(
                            loc.translate('activate_premium'), 
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  loc.translate('cancel_anytime'), 
                  style: const TextStyle(fontSize: 12, color: Colors.grey)
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefit(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text, 
              style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w500)
            )
          ),
        ],
      ),
    );
  }
}
