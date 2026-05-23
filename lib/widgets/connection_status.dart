import 'package:flutter/material.dart';

class ConnectionStatus extends StatelessWidget {
  final bool isConnected;
  final String connectionType;

  const ConnectionStatus({
    super.key,
    required this.isConnected,
    required this.connectionType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConnected ? Icons.wifi : Icons.wifi_off,
            color: isConnected ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            isConnected ? '$connectionType 已连接' : '未连接',
            style: TextStyle(
              color: isConnected ? Colors.green : Colors.red,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
