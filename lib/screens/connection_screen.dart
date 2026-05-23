import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/connection_config.dart';
import '../providers/data_provider.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  ConnectionType _selectedType = ConnectionType.mqtt;
  bool _autoSave = false;
  bool _isConnecting = false;
  bool _isDiscovering = false;

  final TextEditingController _brokerController = TextEditingController(text: 'broker.emqx.io');
  final TextEditingController _portController = TextEditingController(text: '1883');
  final TextEditingController _topicController = TextEditingController(text: 'sensor/data');
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final TextEditingController _bluetoothDeviceIdController = TextEditingController();

  final TextEditingController _wifiHostController = TextEditingController(text: '192.168.1.100');
  final TextEditingController _wifiPortController = TextEditingController(text: '8080');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedConfig();
    });
  }

  void _loadSavedConfig() {
    final provider = context.read<DataProvider>();
    final config = provider.savedConfig ?? provider.currentConfig;
    if (config == null) {
      setState(() {
        _autoSave = provider.autoSave;
      });
      return;
    }

    setState(() {
      _selectedType = config.type;
      _autoSave = config.autoSave || provider.autoSave;
      final settings = config.settings;
      switch (config.type) {
        case ConnectionType.mqtt:
          _brokerController.text = (settings['broker'] ?? _brokerController.text).toString();
          _portController.text = (settings['port'] ?? _portController.text).toString();
          _topicController.text = (settings['topic'] ?? _topicController.text).toString();
          _usernameController.text = (settings['username'] ?? '').toString();
          _passwordController.text = (settings['password'] ?? '').toString();
          break;
        case ConnectionType.bluetooth:
          _bluetoothDeviceIdController.text = (settings['device_id'] ?? '').toString();
          break;
        case ConnectionType.wifi:
          _wifiHostController.text = (settings['host'] ?? _wifiHostController.text).toString();
          _wifiPortController.text = (settings['port'] ?? _wifiPortController.text).toString();
          break;
      }
    });
  }

  @override
  void dispose() {
    _brokerController.dispose();
    _portController.dispose();
    _topicController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _bluetoothDeviceIdController.dispose();
    _wifiHostController.dispose();
    _wifiPortController.dispose();
    super.dispose();
  }

  ConnectionConfig _buildConfig() {
    switch (_selectedType) {
      case ConnectionType.mqtt:
        return ConnectionConfig.mqtt(
          broker: _brokerController.text,
          port: int.tryParse(_portController.text) ?? 1883,
          topic: _topicController.text,
          username: _usernameController.text.isNotEmpty ? _usernameController.text : null,
          password: _passwordController.text.isNotEmpty ? _passwordController.text : null,
          autoSave: _autoSave,
        );
      case ConnectionType.bluetooth:
        return ConnectionConfig.bluetooth(
          deviceId: _bluetoothDeviceIdController.text,
          autoSave: _autoSave,
        );
      case ConnectionType.wifi:
        return ConnectionConfig.wifi(
          host: _wifiHostController.text,
          port: int.tryParse(_wifiPortController.text) ?? 8080,
          autoSave: _autoSave,
        );
    }
  }

  void _connect() async {
    if (_isConnecting) return;

    setState(() {
      _isConnecting = true;
    });

    try {
      final config = _buildConfig();
      final provider = context.read<DataProvider>();
      await provider.connect(config);
      
      if (mounted) {
        if (provider.isConnected && provider.errorMessage == null) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('连接成功'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(provider.errorMessage!),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('连接失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  void _discoverBluetoothDevices() async {
    if (_isDiscovering) return;

    setState(() {
      _isDiscovering = true;
    });

    try {
      final provider = context.read<DataProvider>();
      await provider.discoverBluetoothDevices();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设备扫描完成')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('扫描失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDiscovering = false;
        });
      }
    }
  }

  void _discoverWifiDevices() async {
    if (_isDiscovering) return;

    setState(() {
      _isDiscovering = true;
    });

    try {
      final provider = context.read<DataProvider>();
      await provider.discoverWifiDevices(
        dataPort: int.tryParse(_wifiPortController.text),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.discoveredWifiDevices.isEmpty
                ? '未发现设备，可手动输入 IP 和端口'
                : '发现 ${provider.discoveredWifiDevices.length} 个设备'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('扫描失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDiscovering = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('连接设置'),
        actions: [
          Consumer<DataProvider>(
            builder: (context, provider, child) {
              if (provider.isConnected) {
                return TextButton.icon(
                  onPressed: () {
                    provider.disconnect();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已断开连接')),
                    );
                  },
                  icon: const Icon(Icons.link_off, color: Colors.red),
                  label: const Text('断开', style: TextStyle(color: Colors.red)),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConnectionStatusCard(),
            const SizedBox(height: 16),
            const Text(
              '通讯方式',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildConnectionTypeSelector(),
            const SizedBox(height: 24),
            _buildSettingsPanel(),
            const SizedBox(height: 16),
            _buildAutoSaveSwitch(),
            const SizedBox(height: 24),
            _buildConnectionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatusCard() {
    return Consumer<DataProvider>(
      builder: (context, provider, child) {
        final isConnected = provider.isConnected;
        final connectionType = provider.currentConfig?.type;
        
        return Card(
          color: isConnected ? Colors.green[50] : Colors.grey[100],
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  isConnected ? Icons.check_circle : Icons.info,
                  color: isConnected ? Colors.green : Colors.grey,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isConnected ? '已连接' : '未连接',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isConnected ? Colors.green : Colors.grey[600],
                        ),
                      ),
                      if (isConnected && connectionType != null)
                        Text(
                          '使用 ${_getConnectionTypeName(connectionType)} 连接',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getConnectionTypeName(ConnectionType type) {
    switch (type) {
      case ConnectionType.mqtt:
        return 'MQTT';
      case ConnectionType.bluetooth:
        return '蓝牙';
      case ConnectionType.wifi:
        return 'WiFi';
    }
  }

  Widget _buildConnectionTypeSelector() {
    return SegmentedButton<ConnectionType>(
      segments: [
        ButtonSegment(
          value: ConnectionType.mqtt,
          label: const Text('MQTT'),
          icon: Icon(
            Icons.cloud,
            color: _selectedType == ConnectionType.mqtt ? Colors.blue : null,
          ),
        ),
        ButtonSegment(
          value: ConnectionType.bluetooth,
          label: const Text('蓝牙'),
          icon: Icon(
            Icons.bluetooth,
            color: _selectedType == ConnectionType.bluetooth ? Colors.blue : null,
          ),
        ),
        ButtonSegment(
          value: ConnectionType.wifi,
          label: const Text('WiFi'),
          icon: Icon(
            Icons.wifi,
            color: _selectedType == ConnectionType.wifi ? Colors.blue : null,
          ),
        ),
      ],
      selected: {_selectedType},
      onSelectionChanged: (Set<ConnectionType> selection) {
        setState(() {
          _selectedType = selection.first;
        });
      },
    );
  }

  Widget _buildAutoSaveSwitch() {
    return Card(
      child: SwitchListTile(
        title: const Text('自动保存数据'),
        subtitle: const Text('接收到的数据将自动保存到本地数据库'),
        value: _autoSave,
        onChanged: (value) {
          setState(() {
            _autoSave = value;
          });
        },
      ),
    );
  }

  Widget _buildConnectionButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isConnecting ? null : _connect,
        child: _isConnecting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('连接', style: TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _buildSettingsPanel() {
    switch (_selectedType) {
      case ConnectionType.mqtt:
        return _buildMqttSettings();
      case ConnectionType.bluetooth:
        return _buildBluetoothSettings();
      case ConnectionType.wifi:
        return _buildWifiSettings();
    }
  }

  Widget _buildMqttSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud, color: Colors.blue),
                const SizedBox(width: 8),
                const Text('MQTT 设置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _brokerController,
              decoration: const InputDecoration(
                labelText: 'Broker 地址',
                hintText: '例如: broker.emqx.io',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.dns),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _portController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '端口',
                hintText: '1883',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.numbers),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _topicController,
              decoration: const InputDecoration(
                labelText: 'Topic',
                hintText: '例如: sensor/data',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.topic),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: '用户名（可选）',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '密码（可选）',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBluetoothSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bluetooth, color: Colors.blue),
                const SizedBox(width: 8),
                const Text('蓝牙设置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bluetoothDeviceIdController,
              decoration: const InputDecoration(
                labelText: '设备地址',
                hintText: '例如: 00:11:22:33:44:55',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.devices),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isDiscovering ? null : _discoverBluetoothDevices,
                icon: _isDiscovering
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bluetooth_searching),
                label: Text(_isDiscovering ? '扫描中...' : '扫描设备'),
              ),
            ),
            const SizedBox(height: 8),
            _buildBluetoothDeviceList(),
            const SizedBox(height: 8),
            Text(
              '提示: Windows 端建议先在系统蓝牙设置中完成配对；Android 端首次扫描需要允许蓝牙和定位权限。',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBluetoothDeviceList() {
    return Consumer<DataProvider>(
      builder: (context, provider, child) {
        final devices = provider.discoveredBluetoothDevices;
        if (devices.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _isDiscovering ? '正在搜索附近蓝牙设备...' : '暂无设备。请先扫描，或手动输入设备地址。',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          );
        }

        return Container(
          constraints: const BoxConstraints(maxHeight: 220),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: devices.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final device = devices[index];
              final name = (device.name == null || device.name!.trim().isEmpty)
                  ? '未知设备'
                  : device.name!.trim();
              return ListTile(
                dense: true,
                leading: const Icon(Icons.bluetooth),
                title: Text(name),
                subtitle: Text(device.address),
                trailing: device.isBonded ? const Text('已配对') : const Text('未配对'),
                onTap: () {
                  setState(() {
                    _bluetoothDeviceIdController.text = device.address;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已选择: $name')),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  static const List<int> commonPorts = [8080, 4210, 80, 9001, 1883, 5000];

  Widget _buildWifiSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.wifi, color: Colors.blue),
                const SizedBox(width: 8),
                const Text('WiFi 设置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _wifiHostController,
              decoration: const InputDecoration(
                labelText: '主机地址',
                hintText: '例如: 192.168.1.100',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.computer),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _wifiPortController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '端口',
                hintText: '8080',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.dialpad),
              ),
            ),
            const SizedBox(height: 8),
            _buildPortQuickSelect(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isDiscovering ? null : _discoverWifiDevices,
                icon: _isDiscovering
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.travel_explore),
                label: Text(_isDiscovering ? '扫描中...' : '扫描局域网设备'),
              ),
            ),
            const SizedBox(height: 8),
            _buildWifiDeviceList(),
            const SizedBox(height: 8),
            Text(
              '提示: 只发现支持本应用 UDP 发现协议的数据采集设备；请确保设备与手机/电脑在同一网络中。',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortQuickSelect() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '常用端口:',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: commonPorts.map((port) {
            final isSelected = _wifiPortController.text == port.toString();
            return ElevatedButton(
              onPressed: () {
                setState(() {
                  _wifiPortController.text = port.toString();
                });
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: const Size(50, 32),
                backgroundColor: isSelected ? Colors.blue : Colors.grey[100],
                foregroundColor: isSelected ? Colors.white : Colors.grey[700],
                elevation: isSelected ? 2 : 0,
              ),
              child: Text('$port'),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildWifiDeviceList() {
    return Consumer<DataProvider>(
      builder: (context, provider, child) {
        final devices = provider.discoveredWifiDevices;
        if (devices.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _isDiscovering ? '正在搜索局域网数据设备...' : '暂无设备。请先扫描，或手动输入主机地址和端口。',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          );
        }

        return Container(
          constraints: const BoxConstraints(maxHeight: 220),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: devices.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final device = devices[index];
              final title = device.deviceId == null || device.deviceId!.trim().isEmpty
                  ? device.name
                  : '${device.name} (${device.deviceId})';
              return ListTile(
                dense: true,
                leading: const Icon(Icons.wifi_tethering),
                title: Text(title),
                subtitle: Text('${device.host}:${device.port}'),
                onTap: () {
                  setState(() {
                    _wifiHostController.text = device.host;
                    _wifiPortController.text = device.port.toString();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已选择: ${device.name}')),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
