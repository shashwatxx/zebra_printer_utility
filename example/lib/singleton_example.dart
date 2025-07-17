import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:zebrautil/zebrautil.dart';

/// Comprehensive example demonstrating the ZebraUtility singleton API
///
/// This example shows the complete workflow:
/// 1. Initialize ZebraUtility
/// 2. Start scanning for printers
/// 3. Connect to selected printer
/// 4. Print test labels
/// 5. Configure printer settings
/// 6. Disconnect from printer
class SingletonExampleApp extends StatelessWidget {
  const SingletonExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zebra Utility - Singleton API Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ZebraUtilityDemo(),
    );
  }
}

/// Main demo widget showcasing the new singleton API
class ZebraUtilityDemo extends StatefulWidget {
  const ZebraUtilityDemo({super.key});

  @override
  State<ZebraUtilityDemo> createState() => _ZebraUtilityDemoState();
}

class _ZebraUtilityDemoState extends State<ZebraUtilityDemo> {
  ZebraUtility? _zebra;
  bool _isInitialized = false;
  bool _isInitializing = false;
  String? _errorMessage;

  // Current state
  List<ZebraDevice> _discoveredDevices = [];
  final List<ZebraDevice> _testDevices = []; // Keep test devices separate
  ZebraDevice? _connectedDevice;
  DiscoverySession? _currentSession;
  final List<PrintJob> _printJobs = [];

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
    super.dispose();
  }

  /// Initialize ZebraUtility singleton
  Future<void> _initializeZebraUtility() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      developer.log('Initializing ZebraUtility...', name: 'SingletonExample');

      final initResult = await ZebraUtility.initialize(
        config: const ZebraConfig(
          enableDebugLogging: true,
          operationTimeout: Duration(seconds: 30),
        ),
      );

      if (initResult.isSuccess) {
        _zebra = initResult.data!;
        _isInitialized = true;
        _setupEventListeners();
        developer.log('ZebraUtility initialized successfully',
            name: 'SingletonExample');
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
      developer.log('Failed to initialize ZebraUtility: $e',
          name: 'SingletonExample');
    } finally {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  /// Setup event listeners for reactive updates
  void _setupEventListeners() {
    if (_zebra == null) return;

    // Listen to discovery events
    _discoverySubscription = _zebra!.discoveryStream.listen(
      (session) {
        setState(() {
          _currentSession = session;
          _updateDiscoveredDevices();
        });

        switch (session.status) {
          case DiscoveryStatus.scanning:
            _showSnackBar('Scanning for printers...', Colors.blue);
            break;
          case DiscoveryStatus.completed:
            final totalCount =
                session.discoveredDevices.length + _testDevices.length;
            _showSnackBar(
                'Discovery completed. Found $totalCount devices (${session.discoveredDevices.length} discovered, ${_testDevices.length} test).',
                Colors.green);
            break;
          case DiscoveryStatus.error:
            _showSnackBar(
                'Discovery error: ${session.errorMessage}', Colors.red);
            break;
          default:
            break;
        }
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

        switch (printJob.status) {
          case PrintJobStatus.printing:
            _showSnackBar('Printing job ${printJob.id}...', Colors.blue);
            break;
          case PrintJobStatus.completed:
            _showSnackBar('Print completed successfully!', Colors.green);
            _showPrintSuccessDialog(printJob);
            break;
          case PrintJobStatus.failed:
            _showSnackBar('Print failed: ${printJob.errorMessage}', Colors.red);
            break;
          default:
            break;
        }
      },
    );

    // Listen to connection events
    _connectionSubscription = _zebra!.connectionStream.listen(
      (device) {
        setState(() {
          _connectedDevice = device;
        });

        if (device != null) {
          _showSnackBar('Connected to ${device.name}', Colors.green);
          // Auto-stop discovery when connected
          if (_zebra!.isScanning) {
            _stopDiscovery();
          }
        } else {
          _showSnackBar('Disconnected from printer', Colors.orange);
        }
      },
    );
  }

  /// Start discovering printers
  Future<void> _startDiscovery() async {
    if (_zebra == null) return;

    final result = await _zebra!.startDiscovery();
    if (!result.isSuccess) {
      _showSnackBar(
          'Failed to start discovery: ${result.error?.message}', Colors.red);
    }
  }

  /// Stop discovering printers
  Future<void> _stopDiscovery() async {
    if (_zebra == null) return;

    final result = await _zebra!.stopDiscovery();
    if (!result.isSuccess) {
      _showSnackBar(
          'Failed to stop discovery: ${result.error?.message}', Colors.red);
    }
  }

  /// Connect to a printer
  Future<void> _connectToPrinter(ZebraDevice device) async {
    if (_zebra == null) return;

    _showSnackBar('Connecting to ${device.name}...', Colors.blue);

    final result = await _zebra!.connect(device);
    if (!result.isSuccess) {
      _showSnackBar('Failed to connect: ${result.error?.message}', Colors.red);
    }
  }

  /// Disconnect from current printer
  Future<void> _disconnect() async {
    if (_zebra == null) return;

    final result = await _zebra!.disconnect();
    if (!result.isSuccess) {
      _showSnackBar(
          'Failed to disconnect: ${result.error?.message}', Colors.red);
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
^FO50,120^FDSingleton API Demo^FS
^FO50,160^FDDate: {{DATE}}^FS
^FO50,200^FDTime: {{TIME}}^FS
^FO50,250^GB400,2,2^FS
^FO50,270^FDPrint Test Successful!^FS
^FO50,310^FDJob ID: {{JOB_ID}}^FS
^XZ
''';

    final now = DateTime.now();
    final jobId = 'test_${now.millisecondsSinceEpoch}';
    final zplWithData = testZpl
        .replaceAll('{{DATE}}',
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}')
        .replaceAll('{{TIME}}',
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}')
        .replaceAll('{{JOB_ID}}', jobId);

    final result = await _zebra!.print(zplWithData, jobId: jobId);
    if (!result.isSuccess) {
      _showSnackBar('Failed to print: ${result.error?.message}', Colors.red);
    }
  }

  /// Calibrate the printer
  Future<void> _calibratePrinter() async {
    if (_zebra == null) return;

    _showSnackBar('Calibrating printer...', Colors.blue);

    final result = await _zebra!.configureSettings(calibrate: true);
    if (result.isSuccess) {
      _showSnackBar('Printer calibrated successfully!', Colors.green);
    } else {
      _showSnackBar(
          'Failed to calibrate: ${result.error?.message}', Colors.red);
    }
  }

  /// Show printer settings dialog
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => _PrinterSettingsDialog(zebra: _zebra!),
    );
  }

  /// Show print success dialog
  void _showPrintSuccessDialog(PrintJob printJob) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 64),
        title: const Text('Print Successful!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Job ID: ${printJob.id}'),
            Text('Started: ${_formatDateTime(printJob.createdAt)}'),
            if (printJob.completedAt != null)
              Text('Completed: ${_formatDateTime(printJob.completedAt!)}'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    _connectedDevice!.isWifi ? Icons.wifi : Icons.bluetooth,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _connectedDevice!.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                        Text(
                          _connectedDevice!.address,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _printTestLabel();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Print Another'),
          ),
        ],
      ),
    );
  }

  /// Show snackbar message
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Format DateTime for display
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  /// Merge discovered devices with test devices, avoiding duplicates
  void _updateDiscoveredDevices() {
    final sessionDevices =
        _currentSession?.discoveredDevices ?? <ZebraDevice>[];
    final allDevices = <ZebraDevice>[...sessionDevices];

    for (final testDevice in _testDevices) {
      if (!allDevices.any((device) => device.address == testDevice.address)) {
        allDevices.add(testDevice);
      }
    }

    developer.log(
        'Updated discovered devices: ${allDevices.length} total (${sessionDevices.length} discovered, ${_testDevices.length} test)',
        name: 'SingletonExample');

    _discoveredDevices = allDevices;
  }

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (_isInitializing) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Zebra Utility - Singleton API'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: const Center(
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

    // Error state
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Zebra Utility - Singleton API'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
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

    // Main UI
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zebra Utility - Singleton API'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(_zebra?.isRotated == true
                ? Icons.screen_rotation
                : Icons.screen_lock_rotation),
            onPressed: () {
              _zebra?.toggleRotation();
              setState(() {});
              _showSnackBar(
                  'Print rotation ${_zebra?.isRotated == true ? "enabled" : "disabled"}',
                  Colors.blue);
            },
            tooltip: 'Toggle Rotation',
          ),
          if (_connectedDevice != null)
            IconButton(
              icon: const Icon(Icons.bluetooth_disabled),
              onPressed: _disconnect,
              tooltip: 'Disconnect',
            ),
        ],
      ),
      body: Column(
        children: [
          // Status Card
          _buildStatusCard(),

          // Control Buttons
          _buildControlButtons(),

          // Main content area with flexible space distribution
          Expanded(
            child: Column(
              children: [
                // Discovered Devices
                Expanded(
                  flex: _printJobs.isNotEmpty ? 2 : 1,
                  child: _buildDevicesList(),
                ),

                // Print Jobs (if any) - takes up to 1/3 of available space
                if (_printJobs.isNotEmpty)
                  Expanded(
                    flex: 1,
                    child: _buildPrintJobsList(),
                  ),
              ],
            ),
          ),
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
            _buildStatusRow('Initialized', _isInitialized ? 'Yes' : 'No'),
            _buildStatusRow(
                'Scanning', _zebra?.isScanning == true ? 'Yes' : 'No'),
            _buildStatusRow(
                'Connected', _connectedDevice != null ? 'Yes' : 'No'),
            if (_connectedDevice != null) ...[
              _buildStatusRow('Device', _connectedDevice!.name),
              _buildStatusRow('Address', _connectedDevice!.address),
              _buildStatusRow(
                  'Type', _connectedDevice!.isWifi ? 'WiFi' : 'Bluetooth'),
            ],
            _buildStatusRow(
                'Discovery Session', _currentSession?.status.name ?? 'None'),
            _buildStatusRow('Print Jobs', _printJobs.length.toString()),
            _buildStatusRow(
                'Rotation', _zebra?.isRotated == true ? 'Enabled' : 'Disabled'),
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
          // Discovery Controls
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _zebra?.isScanning == true ? Colors.red : Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  // Add test printer with timestamp to make it unique
                  final timestamp = DateTime.now().millisecondsSinceEpoch;
                  final testDevice = ZebraDevice(
                    address:
                        '00:07:4D:C9:${(52 + _testDevices.length).toString().padLeft(2, '0')}:88',
                    name: 'Test Zebra Printer ${_testDevices.length + 1}',
                    status: 'Ready (Test)',
                    isWifi: false,
                  );
                  setState(() {
                    // Add to test devices list if not already present
                    if (!_testDevices.any(
                        (device) => device.address == testDevice.address)) {
                      _testDevices.add(testDevice);
                      developer.log(
                          'Added test device: ${testDevice.name} (${testDevice.address})',
                          name: 'SingletonExample');
                      _updateDiscoveredDevices();
                    } else {
                      developer.log(
                          'Test device already exists: ${testDevice.address}',
                          name: 'SingletonExample');
                    }
                  });
                  _showSnackBar('Test printer added', Colors.orange);
                },
                icon: const Icon(Icons.bug_report),
                label: const Text('Add Test'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),

          // Printer Controls (when connected)
          if (_connectedDevice != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _printTestLabel,
                    icon: const Icon(Icons.print),
                    label: const Text('Print Test'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _calibratePrinter,
                    icon: const Icon(Icons.tune),
                    label: const Text('Calibrate'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showSettingsDialog,
                icon: const Icon(Icons.settings),
                label: const Text('Printer Settings'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build discovered devices list
  Widget _buildDevicesList() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Discovered Devices (${_discoveredDevices.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          Expanded(
            child: _discoveredDevices.isEmpty
                ? const Center(
                    child: Text(
                        'No devices found. Start discovery to search for printers.'),
                  )
                : ListView.separated(
                    itemCount: _discoveredDevices.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final device = _discoveredDevices[index];
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
                                onPressed: () => _connectToPrinter(device),
                              ),
                        onTap: isConnected
                            ? null
                            : () => _connectToPrinter(device),
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
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
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _printJobs.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final job = _printJobs[
                    _printJobs.length - 1 - index]; // Show newest first

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _getJobStatusIcon(job.status),
                          color: _getJobStatusColor(job.status),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Job ${job.id.split('_').last}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Status: ${job.status.name}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                'Created: ${_formatDateTime(job.createdAt)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              if (job.completedAt != null)
                                Text(
                                  'Completed: ${_formatDateTime(job.completedAt!)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              if (job.errorMessage != null)
                                Text(
                                  'Error: ${job.errorMessage}',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
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
}

/// Printer settings dialog
class _PrinterSettingsDialog extends StatelessWidget {
  const _PrinterSettingsDialog({required this.zebra});

  final ZebraUtility zebra;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Printer Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text('Set Darkness'),
            subtitle: const Text('Adjust print darkness'),
            onTap: () {
              Navigator.pop(context);
              _showDarknessDialog(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.article),
            title: const Text('Media Type'),
            subtitle: const Text('Configure media settings'),
            onTap: () {
              Navigator.pop(context);
              _showMediaTypeDialog(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.rotate_right),
            title: const Text('Toggle Rotation'),
            subtitle: Text(
                zebra.isRotated ? 'Currently: Rotated' : 'Currently: Normal'),
            onTap: () {
              zebra.toggleRotation();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Print rotation ${zebra.isRotated ? "enabled" : "disabled"}'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  void _showDarknessDialog(BuildContext context) {
    const darknessLevels = [
      -99,
      -75,
      -50,
      -25,
      0,
      25,
      50,
      75,
      100,
      125,
      150,
      175,
      200
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Print Darkness'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select darkness level:'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: darknessLevels
                  .map((value) => ActionChip(
                        label: Text('$value'),
                        onPressed: () async {
                          final result =
                              await zebra.configureSettings(darkness: value);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(result.isSuccess
                                    ? 'Darkness set to $value'
                                    : 'Failed to set darkness: ${result.error?.message}'),
                                backgroundColor: result.isSuccess
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            );
                          }
                        },
                      ))
                  .toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showMediaTypeDialog(BuildContext context) {
    final mediaTypes = [
      (EnumMediaType.label, 'Standard label with gap detection'),
      (EnumMediaType.blackMark, 'Labels with black mark detection'),
      (EnumMediaType.journal, 'Continuous journal paper'),
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Media Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: mediaTypes
              .map((typeInfo) => ListTile(
                    title: Text(typeInfo.$1.name),
                    subtitle: Text(typeInfo.$2),
                    onTap: () async {
                      final result =
                          await zebra.configureSettings(mediaType: typeInfo.$1);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result.isSuccess
                                ? 'Media type set to ${typeInfo.$1.name}'
                                : 'Failed to set media type: ${result.error?.message}'),
                            backgroundColor:
                                result.isSuccess ? Colors.green : Colors.red,
                          ),
                        );
                      }
                    },
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

/// Entry point for the singleton example
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const SingletonExampleApp());
}
