import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hilla_ride/core/services/auth_setup.dart';

class FirebaseSetupCard extends StatelessWidget {
  const FirebaseSetupCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.orange.shade50,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Firebase setup (do once)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
            ),
            const SizedBox(height: 8),
            const Text('1. Authentication → Sign-in method → enable Phone'),
            const Text('2. Same page → Phone numbers for testing → add +9647701234567 / 123456'),
            const Text('3. Project settings → Android app → add SHA-1 fingerprint:'),
            const SizedBox(height: 8),
            SelectableText(
              AuthTestConfig.androidDebugSha1,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(text: AuthTestConfig.androidDebugSha1),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('SHA-1 copied')),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy SHA-1'),
            ),
            const SizedBox(height: 4),
            Text(
              '4. Download new google-services.json → replace android/app/google-services.json',
              style: TextStyle(color: Colors.orange.shade900, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
