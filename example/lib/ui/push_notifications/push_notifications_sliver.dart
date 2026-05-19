import 'package:ably_example/ui/utilities.dart';
import 'package:flutter/material.dart';

class PushNotificationsSliver extends StatelessWidget {
  const PushNotificationsSliver({super.key});

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          title: const Text(
            'Push Notifications',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          subtitle: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Not available in the pure Dart SDK.\n'
              'Push notification support requires Flutter platform integration '
              '(ably_flutter package).',
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.notifications_off_outlined),
            onPressed: () => showNotImplementedToast('Push Notifications'),
          ),
        ),
      );
}
