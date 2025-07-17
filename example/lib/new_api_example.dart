import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:zebrautil/zebrautil.dart';

/// Example app demonstrating the new ZebraUtility singleton API
class NewApiExampleApp extends StatelessWidget {
  const NewApiExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zebra Utility - New API Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ZebraUtilityDemo(),
    );
  }
}

/// Main demo widget showcasing the new API
class ZebraUtilityDemo extends StatefulWidget {
  const ZebraUtilityDemo({super.key});

  @override
  State<ZebraUtilityDemo> createState() => _ZebraUtilityDemoState();
}

class _ZebraUtilityDemoState extends State<ZebraUtilityDemo> {
  ZebraUtility? _zebra;
  DiscoverySession? _currentSession;
  ZebraDevice? _connectedDevice;
  final List<PrintJob> _printJobs = [];
  String? _errorMessage;
  bool _isInitializing = false;

  // Stream subscriptions
  StreamSubscription<DiscoverySession>? _discoverySubscription;
  StreamSubscription<PrintJob>? _printSubscription;
  StreamSubscription<ZebraDevice?>? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _initializeZebraUtility();
  }

  @override
  void dispose() {
    _discoverySubscription?.cancel();
    _printSubscription?.cancel();
    _connectionSubscription?.cancel();
    _zebra?.dispose();
    super.dispose();
  }

  /// Initialize ZebraUtility with configuration
  Future<void> _initializeZebraUtility() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      // Initialize with configuration
      final initResult = await ZebraUtility.initialize(
        config: const ZebraConfig(
          enableDebugLogging: true,
          operationTimeout: Duration(seconds: 30),
          autoConnectLastPrinter: false,
        ),
      );

      if (initResult.isSuccess) {
        _zebra = initResult.data!;
        _setupEventListeners();
        developer.log('ZebraUtility initialized successfully');
      } else {
        setState(() {
          _errorMessage =
              initResult.error?.message ?? 'Unknown initialization error';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize: $e';
      });
    } finally {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  /// Setup event listeners for streams
  void _setupEventListeners() {
    if (_zebra == null) return;

    // Listen to discovery events
    _discoverySubscription = _zebra!.discoveryStream.listen(
      (session) {
        setState(() {
          _currentSession = session;
        });
        developer.log('Discovery update: ${session.status}');
      },
    );

    // Listen to print job events
    _printSubscription = _zebra!.printStream.listen(
      (printJob) {
        setState(() {
          final index = _printJobs.indexWhere((job) => job.id == printJob.id);
          if (index >= 0) {
            _printJobs[index] = printJob;
          } else {
            _printJobs.add(printJob);
          }
        });
        developer.log('Print job update: ${printJob.id} - ${printJob.status}');
      },
    );

    // Listen to connection events
    _connectionSubscription = _zebra!.connectionStream.listen(
      (device) {
        setState(() {
          _connectedDevice = device;
        });
        developer
            .log('Connection update: ${device?.address ?? 'disconnected'}');
      },
    );
  }

  /// Start device discovery
  Future<void> _startDiscovery() async {
    if (_zebra == null) return;

    final result = await _zebra!.startDiscovery();
    if (!result.isSuccess) {
      _showError('Failed to start discovery: ${result.error?.message}');
    }
  }

  /// Stop device discovery
  Future<void> _stopDiscovery() async {
    if (_zebra == null) return;

    final result = await _zebra!.stopDiscovery();
    if (!result.isSuccess) {
      _showError('Failed to stop discovery: ${result.error?.message}');
    }
  }

  /// Connect to a selected device
  Future<void> _connectToDevice(ZebraDevice device) async {
    if (_zebra == null) return;

    final result = await _zebra!.connect(device);
    if (!result.isSuccess) {
      _showError(
          'Failed to connect to ${device.name}: ${result.error?.message}');
    }
  }

  /// Disconnect from current device
  Future<void> _disconnect() async {
    if (_zebra == null) return;

    final result = await _zebra!.disconnect();
    if (!result.isSuccess) {
      _showError('Failed to disconnect: ${result.error?.message}');
    }
  }

  /// Print a test label
  Future<void> _printTestLabel() async {
    if (_zebra == null) return;

    const testZpl = '''
^XA
^CF0,60
^FO50,50^FDZebra Utility Test^FS
^CF0,30
^FO50,120^FDNew Singleton API^FS
^FO50,160^FDDate: $_placeholder_date^FS
^FO50,200^FDTime: $_placeholder_time^FS
^FO50,250^GB400,2,2^FS
^FO50,270^FDPrint Test Successful!^FS
^XZ
''';

    final now = DateTime.now();
    final zplWithDateTime = testZpl
        .replaceAll(_placeholder_date,
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}')
        .replaceAll(_placeholder_time,
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}');

    final result = await _zebra!.print(zplWithDateTime);
    if (!result.isSuccess) {
      _showError('Failed to print: ${result.error?.message}');
    }
  }

  static const String _placeholder_date = r'${_placeholder_date}';
  static const String _placeholder_time = r'${_placeholder_time}';

  /// Configure printer settings
  Future<void> _configureSettings() async {
    if (_zebra == null) return;

    final result = await _zebra!.configureSettings(
      mediaType: EnumMediaType.label,
      darkness: 0,
      calibrate: true,
    );

    if (result.isSuccess) {
      _showSuccess('Printer settings configured successfully');
    } else {
      _showError('Failed to configure settings: ${result.error?.message}');
    }
  }

  /// Show error message
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Show success message
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing ZebraUtility...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Initialization Error',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initializeZebraUtility,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zebra Utility - New API'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(_zebra?.isRotated == true
                ? Icons.screen_rotation
                : Icons.screen_lock_rotation),
            onPressed: () {
              _zebra?.toggleRotation();
              setState(() {});
            },
            tooltip: 'Toggle Rotation',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Card
          _buildStatusCard(),

          // Control Buttons
          _buildControlButtons(),

          // Discovered Devices
          Expanded(
            child: _buildDevicesList(),
          ),

          // Print Jobs
          if (_printJobs.isNotEmpty) _buildPrintJobsList(),
        ],
      ),
    );
  }

  /// Build status information card
  Widget _buildStatusCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            _buildStatusRow(
                'Initialized', ZebraUtility.isInitialized ? 'Yes' : 'No'),
            _buildStatusRow(
                'Scanning', _zebra?.isScanning == true ? 'Yes' : 'No'),
            _buildStatusRow(
                'Connected', _connectedDevice != null ? 'Yes' : 'No'),
            if (_connectedDevice != null)
              _buildStatusRow('Device', _connectedDevice!.name),
            _buildStatusRow(
                'Discovery Session', _currentSession?.status.name ?? 'None'),
            _buildStatusRow('Print Jobs', _printJobs.length.toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  /// Build control buttons
  Widget _buildControlButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _zebra?.isScanning == true
                      ? _stopDiscovery
                      : _startDiscovery,
                  icon: Icon(
                      _zebra?.isScanning == true ? Icons.stop : Icons.search),
                  label: Text(_zebra?.isScanning == true
                      ? 'Stop Discovery'
                      : 'Start Discovery'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _connectedDevice != null ? _disconnect : null,
                  icon: const Icon(Icons.bluetooth_disabled),
                  label: const Text('Disconnect'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _connectedDevice != null ? _printTestLabel : null,
                  icon: const Icon(Icons.print),
                  label: const Text('Print Test'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      _connectedDevice != null ? _configureSettings : null,
                  icon: const Icon(Icons.settings),
                  label: const Text('Configure'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build discovered devices list
  Widget _buildDevicesList() {
    final devices = _zebra?.discoveredDevices ?? [];

    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Discovered Devices (${devices.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          Expanded(
            child: devices.isEmpty
                ? const Center(
                    child: Text(
                        'No devices found. Start discovery to search for printers.'),
                  )
                : ListView.separated(
                    itemCount: devices.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      final isConnected =
                          _connectedDevice?.address == device.address;

                      return ListTile(
                        leading: Icon(
                          device.isWifi ? Icons.wifi : Icons.bluetooth,
                          color: isConnected ? Colors.green : null,
                        ),
                        title: Text(
                          device.name.isEmpty ? 'Unknown Device' : device.name,
                          style: TextStyle(
                            fontWeight: isConnected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Address: ${device.address}'),
                            Text(
                                'Type: ${device.isWifi ? 'WiFi' : 'Bluetooth'}'),
                            Text('Status: ${device.status}'),
                          ],
                        ),
                        trailing: isConnected
                            ? const Icon(Icons.check_circle,
                                color: Colors.green)
                            : IconButton(
                                icon: const Icon(Icons.connect_without_contact),
                                onPressed: () => _connectToDevice(device),
                              ),
                        onTap:
                            isConnected ? null : () => _connectToDevice(device),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Build print jobs list
  Widget _buildPrintJobsList() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Print Jobs (${_printJobs.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          SizedBox(
            height: 150,
            child: ListView.separated(
              itemCount: _printJobs.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final job = _printJobs[
                    _printJobs.length - 1 - index]; // Show newest first

                return ListTile(
                  leading: Icon(
                    _getJobStatusIcon(job.status),
                    color: _getJobStatusColor(job.status),
                  ),
                  title: Text('Job ${job.id.split('_').last}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Status: ${job.status.name}'),
                      Text('Created: ${_formatDateTime(job.createdAt)}'),
                      if (job.completedAt != null)
                        Text('Completed: ${_formatDateTime(job.completedAt!)}'),
                      if (job.errorMessage != null)
                        Text('Error: ${job.errorMessage}',
                            style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                  isThreeLine: true,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _getJobStatusIcon(PrintJobStatus status) {
    switch (status) {
      case PrintJobStatus.queued:
        return Icons.schedule;
      case PrintJobStatus.printing:
        return Icons.print;
      case PrintJobStatus.completed:
        return Icons.check_circle;
      case PrintJobStatus.failed:
        return Icons.error;
      case PrintJobStatus.cancelled:
        return Icons.cancel;
    }
  }

  Color _getJobStatusColor(PrintJobStatus status) {
    switch (status) {
      case PrintJobStatus.queued:
        return Colors.orange;
      case PrintJobStatus.printing:
        return Colors.blue;
      case PrintJobStatus.completed:
        return Colors.green;
      case PrintJobStatus.failed:
        return Colors.red;
      case PrintJobStatus.cancelled:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }
}
