import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/theme.dart';

/// First frame while the stored device session is being restored.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ApsColors.bg,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/aps_lockup.png',
                  width: 240,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 14),
              const Text(ApsConfig.tagline, style: ApsText.label),
              const SizedBox(height: 26),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
