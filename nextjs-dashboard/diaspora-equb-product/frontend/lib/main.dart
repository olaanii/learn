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
          _SectionTitle('Identity'),
          _SectionCard(
            title: 'Fayda Verification',
            description: 'Complete e-ID verification to receive your identity hash.',
            status: 'Ready',
          ),
          _SectionCard(
            title: 'Wallet Binding',
            description: 'Bind your wallet to your verified identity.',
            status: 'Ready',
          ),
          _SectionTitle('Equb Pools'),
          _SectionCard(
            title: 'Join Tier 0 Pool',
            description: 'Start with minimal collateral and streamed payouts.',
            status: 'Open',
          ),
          _SectionCard(
            title: 'Pool Status',
            description: 'Track your current round and contribution status.',
            status: 'Active',
          ),
          _SectionTitle('Payouts & Credit'),
          _SectionCard(
            title: 'Payout Stream Tracker',
            description: 'Monitor upfront release and round-by-round payouts.',
            status: 'Scheduled',
          ),
          _SectionCard(
            title: 'Credit Score Progress',
            description: 'See your credit score and tier eligibility updates.',
            status: 'Healthy',
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
  const _SectionCard({
    required this.title,
    required this.description,
    required this.status,
  });

  final String title;
  final String description;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(title, style: Theme.of(context).textTheme.titleMedium),
                ),
                _StatusChip(label: status),
              ],
            ),
            const SizedBox(height: 8),
            Text(description),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}
