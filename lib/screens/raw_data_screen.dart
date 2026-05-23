import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/data_provider.dart';

class RawDataScreen extends StatelessWidget {
  const RawDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('原始数据'),
        actions: [
          IconButton(
            tooltip: '保存当前数据',
            icon: const Icon(Icons.save_alt),
            onPressed: () async {
              await context.read<DataProvider>().saveRecentData();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.read<DataProvider>().errorMessage ?? '已保存')),
              );
            },
          ),
        ],
      ),
      body: Consumer<DataProvider>(
        builder: (context, provider, child) {
          final data = provider.recentData;
          if (data.isEmpty) {
            return const Center(child: Text('暂无数据'));
          }

          return ListView.separated(
            itemCount: data.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = data[index];
              return ExpansionTile(
                leading: Icon(item.isStructured ? Icons.data_object : Icons.subject),
                title: Text('${item.deviceId}  ${item.timestamp.toIso8601String()}'),
                subtitle: Text(item.isStructured ? '结构化数据' : '原始文本'),
                childrenPadding: const EdgeInsets.all(16),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SelectableText(
                      item.rawPayload,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (item.data.isNotEmpty) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('解析结果', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 8),
                    ...item.data.entries.map((entry) {
                      return ListTile(
                        dense: true,
                        title: Text(entry.key),
                        trailing: Text('${entry.value}'),
                      );
                    }),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}
