import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_config.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiUrl = ref.watch(apiBaseUrlProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Backend'),
          ListTile(title: const Text('API URL'), subtitle: Text(apiUrl)),
          ListTile(title: const Text('News refresh'), subtitle: const Text('Every 15 minutes')),
          const _SectionHeader('Display'),
          ListTile(title: const Text('Theme'), subtitle: const Text('System default')),
          ListTile(title: const Text('Text size'), subtitle: const Text('Medium')),
          const _SectionHeader('Notifications'),
          ListTile(title: const Text('Critical alerts'), subtitle: const Text('On')),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}