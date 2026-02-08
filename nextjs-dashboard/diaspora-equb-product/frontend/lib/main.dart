import 'package:flutter/material.dart';

void main() {
  runApp(const DiasporaEqubApp());
}

class DiasporaEqubApp extends StatelessWidget {
  const DiasporaEqubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Diaspora Equb MVP',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diaspora Equb MVP')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _SectionTitle('Get Verified'),
          _SectionCard(
            title: 'Verify with Fayda',
            description: 'Bind your wallet to a verified identity hash.',
          ),
          _SectionTitle('Join an Equb'),
          _SectionCard(
            title: 'Tier 0 Pool',
            description: 'Start with minimal collateral and streamed payout.',
          ),
          _SectionTitle('Stay on Track'),
          _SectionCard(
            title: 'Contribution Schedule',
            description: 'View upcoming rounds and payout releases.',
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(description),
          ],
        ),
      ),
    );
  }
}
