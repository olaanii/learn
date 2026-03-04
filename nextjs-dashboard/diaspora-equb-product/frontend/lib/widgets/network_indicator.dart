import 'package:flutter/material.dart';
import '../config/app_config.dart';

class NetworkIndicator extends StatelessWidget {
  const NetworkIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    if (AppConfig.isMainnet) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => _showNetworkInfo(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: Colors.orange.withValues(alpha: 0.5), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Colors.orange),
            ),
            const SizedBox(width: 4),
            Text(
              AppConfig.isMainnet ? 'MAINNET' : 'TESTNET',
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNetworkInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Network Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Network', AppConfig.networkName),
            const SizedBox(height: 8),
            _infoRow('Chain ID', AppConfig.chainId.toString()),
            const SizedBox(height: 8),
            _infoRow('RPC URL', AppConfig.rpcUrl),
            const SizedBox(height: 16),
            if (!AppConfig.isMainnet)
              const Text('This is a test network. Tokens have no real value.',
                  style: TextStyle(fontSize: 12, color: Colors.orange)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
        ),
      ],
    );
  }
}
