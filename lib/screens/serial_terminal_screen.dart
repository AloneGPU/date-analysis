import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/connection_config.dart';
import '../providers/data_provider.dart';
import '../services/serial_service.dart';

class SerialTerminalScreen extends StatefulWidget {
  const SerialTerminalScreen({super.key});

  @override
  State<SerialTerminalScreen> createState() => _SerialTerminalScreenState();
}

class _SerialTerminalScreenState extends State<SerialTerminalScreen> {
  final TextEditingController _sendController = TextEditingController();
  final ScrollController _receiveScrollController = ScrollController();
  final ScrollController _logScrollController = ScrollController();
  
  String? _selectedPort;
  SerialBaudRate _selectedBaudRate = SerialBaudRate.b9600;
  SerialDataBits _selectedDataBits = SerialDataBits.b8;
  SerialStopBits _selectedStopBits = SerialStopBits.one;
  SerialParity _selectedParity = SerialParity.none;
  
  List<String> _receivedData = [];
  List<String> _logMessages = [];
  bool _isConnecting = false;

  final List<String> _presetCommands = [
    'AT',
    'AT+VERSION',
    'AT+RESET',
    'AT+CONFIG',
    'AT+START',
    'AT+STOP',
  ];

  @override
  void initState() {
    super.initState();
    _startListeningLog();
    _discoverPorts();
  }

  void _startListeningLog() {
    final provider = Provider.of<DataProvider>(context, listen: false);
    provider.serialLogStream.listen((message) {
      setState(() {
        _logMessages.add('[${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}] $message');
        if (_logMessages.length > 100) {
          _logMessages.removeAt(0);
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _logScrollController.jumpTo(_logScrollController.position.maxScrollExtent);
      });
    });
  }

  Future<void> _discoverPorts() async {
    final provider = Provider.of<DataProvider>(context, listen: false);
    await provider.discoverSerialPorts();
  }

  void _handlePortSelected(String? portName) {
    setState(() {
      _selectedPort = portName;
    });
  }

  Future<void> _connect() async {
    if (_selectedPort == null || _selectedPort!.isEmpty) {
      _showError('请选择串口');
      return;
    }

    setState(() {
      _isConnecting = true;
    });

    try {
      final provider = Provider.of<DataProvider>(context, listen: false);
      final config = ConnectionConfig.serial(
        portName: _selectedPort!,
        baudRate: _selectedBaudRate,
        dataBits: _selectedDataBits,
        stopBits: _selectedStopBits,
        parity: _selectedParity,
      );
      await provider.connect(config);
      
      _addLog('串口连接成功');
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  void _disconnect() {
    final provider = Provider.of<DataProvider>(context, listen: false);
    provider.disconnect();
    _addLog('串口已断开');
  }

  Future<void> _sendData() async {
    if (_sendController.text.isEmpty) return;

    try {
      final provider = Provider.of<DataProvider>(context, listen: false);
      await provider.serialService.sendData(_sendController.text);
      _sendController.clear();
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _sendPresetCommand(String command) {
    _sendController.text = command;
    _sendData();
  }

  void _clearReceivedData() {
    setState(() {
      _receivedData.clear();
    });
  }

  void _saveReceivedData() async {
    if (_receivedData.isEmpty) {
      _showError('没有可保存的数据');
      return;
    }

    try {
      final content = _receivedData.join('\n');
      final file = await _createFile('serial_data_${DateTime.now().millisecondsSinceEpoch}.txt');
      await file.writeAsString(content);
      _showSuccess('数据已保存到: ${file.path}');
    } catch (e) {
      _showError('保存失败: $e');
    }
  }

  Future<String> _getDocumentsDirectory() async {
    return '/sdcard/Documents';
  }

  Future<String> _createFile(String filename) async {
    final dir = await _getDocumentsDirectory();
    return '$dir/$filename';
  }

  void _addLog(String message) {
    setState(() {
      _logMessages.add('[${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}] $message');
      if (_logMessages.length > 100) {
        _logMessages.removeAt(0);
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
    _addLog('错误: $message');
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DataProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('串口终端'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _discoverPorts,
                tooltip: '刷新串口列表',
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildPortSelection(provider),
                const SizedBox(height: 16),
                _buildSerialConfig(),
                const SizedBox(height: 16),
                _buildConnectionButton(provider),
                const SizedBox(height: 16),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildReceivePanel(),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: _buildLogPanel(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildSendPanel(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPortSelection(DataProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('串口选择', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedPort,
                    hint: const Text('选择串口'),
                    items: provider.discoveredSerialPorts
                        .map((port) => DropdownMenuItem(
                              value: port.name,
                              child: Text('${port.name} - ${port.description ?? 'Unknown'}'),
                            ))
                        .toList(),
                    onChanged: _handlePortSelected,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _discoverPorts,
                  child: const Icon(Icons.search),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSerialConfig() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('串口参数配置', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('波特率', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      DropdownButtonFormField<SerialBaudRate>(
                        value: _selectedBaudRate,
                        items: SerialBaudRate.values
                            .map((rate) => DropdownMenuItem(
                                  value: rate,
                                  child: Text(rate.toString()),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedBaudRate = value!;
                          });
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('数据位', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      DropdownButtonFormField<SerialDataBits>(
                        value: _selectedDataBits,
                        items: SerialDataBits.values
                            .map((bits) => DropdownMenuItem(
                                  value: bits,
                                  child: Text(bits.toString()),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedDataBits = value!;
                          });
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('停止位', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      DropdownButtonFormField<SerialStopBits>(
                        value: _selectedStopBits,
                        items: SerialStopBits.values
                            .map((bits) => DropdownMenuItem(
                                  value: bits,
                                  child: Text(bits.toString()),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedStopBits = value!;
                          });
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('校验位', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      DropdownButtonFormField<SerialParity>(
                        value: _selectedParity,
                        items: SerialParity.values
                            .map((parity) => DropdownMenuItem(
                                  value: parity,
                                  child: Text(parity == SerialParity.none ? 'None' : parity.toString()),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedParity = value!;
                          });
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionButton(DataProvider provider) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: provider.isConnected ? Colors.red : Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _isConnecting ? null : (provider.isConnected ? _disconnect : _connect),
            child: _isConnecting
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(provider.isConnected ? '断开连接' : '连接串口', style: const TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: provider.isConnected ? Colors.green : Colors.grey,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                provider.isConnected ? '已连接' : '未连接',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReceivePanel() {
    return Card(
      child: Column(
        children: [
          Row(
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('接收数据', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: _clearReceivedData,
                tooltip: '清空',
              ),
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: _saveReceivedData,
                tooltip: '保存',
              ),
            ],
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                controller: _receiveScrollController,
                itemCount: _receivedData.length,
                itemBuilder: (context, index) {
                  return Text(
                    _receivedData[index],
                    style: const TextStyle(color: Colors.green, fontFamily: 'Monospace'),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogPanel() {
    return Card(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('日志', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1a1a1a),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                controller: _logScrollController,
                itemCount: _logMessages.length,
                itemBuilder: (context, index) {
                  return Text(
                    _logMessages[index],
                    style: const TextStyle(color: Colors.grey, fontSize: 11, fontFamily: 'Monospace'),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                const Text('预设指令:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 8),
                Wrap(
                  spacing: 8,
                  children: _presetCommands.map((cmd) {
                    return ElevatedButton(
                      onPressed: () => _sendPresetCommand(cmd),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.grey[800],
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        minimumSize: const Size(40, 28),
                      ),
                      child: Text(cmd),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _sendController,
                    decoration: const InputDecoration(
                      labelText: '输入发送数据',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendData(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _sendData,
                  child: const Text('发送'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
