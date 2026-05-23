import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('帮助与说明'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              context,
              '应用简介',
              Icons.info_outline,
              '''
数据监控助手是一款跨平台的上位机应用，支持通过MQTT、蓝牙和WiFi三种方式接收单片机或嵌入式设备的数据，并提供实时可视化、历史数据回放等功能。
              ''',
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              'MQTT连接',
              Icons.cloud,
              '''
1. 在连接设置中选择MQTT通讯方式
2. 输入MQTT Broker地址（如 broker.emqx.io）
3. 设置端口号（默认1883）
4. 输入Topic名称
5. 如有需要，输入用户名和密码
6. 点击连接按钮

提示：确保设备与MQTT Broker的网络连接正常。
              ''',
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              '蓝牙连接',
              Icons.bluetooth,
              '''
1. 在连接设置中选择蓝牙通讯方式
2. 确保手机/电脑的蓝牙已开启
3. 点击扫描设备按钮
4. 从设备列表中选择目标设备
5. 输入设备地址或选择已配对设备
6. 点击连接按钮

提示：部分设备可能需要先在系统设置中配对。
              ''',
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              'WiFi连接',
              Icons.wifi,
              '''
1. 在连接设置中选择WiFi通讯方式
2. 输入设备IP地址
3. 设置端口号
4. 确保设备与手机/电脑在同一网络中
5. 点击连接按钮

提示：某些网络环境可能需要配置防火墙规则。
              ''',
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              '数据格式',
              Icons.data_object,
              '''
应用支持JSON格式的数据，示例格式：

{
  "device_id": "sensor_001",
  "timestamp": 1640000000000,
  "data": {
    "temperature": 25.5,
    "humidity": 60.0,
    "voltage": 3.3
  }
}

timestamp为毫秒级时间戳，data字段包含传感器数据。
              ''',
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              '数据存储',
              Icons.storage,
              '''
- 自动保存：开启后将自动保存所有接收到的数据
- 手动导出：支持CSV和JSON格式导出
- 历史查看：可按时间范围查询历史数据
- 数据清理：支持清空全部或指定时间段的数据
              ''',
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              'AI 分析',
              Icons.psychology_alt,
              '''
1. 在 AI 分析页面填写接口地址、Key 和模型名
2. 选择实时数据或历史数据作为上下文
3. 输入你的问题，或直接点击自动分析
4. AI 会基于采集数据总结趋势、异常和建议

说明：本项目采用 OpenAI 兼容接口格式，接入其他大模型网关时通常只需要修改接口地址和模型名。
              ''',
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              '常见问题',
              Icons.help_outline,
              '''
Q: 连接失败怎么办？
A: 检查网络连接、设备状态、地址端口是否正确。

Q: 数据不显示怎么办？
A: 确认数据格式是否为有效的JSON格式。

Q: 如何导出数据？
A: 在存储设置页面选择导出格式。

Q: 如何清除历史数据？
A: 在存储设置页面选择清空数据。
              ''',
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              '关于应用',
              Icons.info,
              '''
版本: 1.0.0
开发者: 数据监控助手团队

如有问题或建议，请联系开发者。
              ''',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, IconData icon, String content) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              content.trim(),
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
