import 'package:flutter/material.dart';
import 'package:zebrautil/zebrautil.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize ZebraUtility once at app startup
  await ZebraUtility.initialize(
    config: const ZebraConfig(
      enableDebugLogging: true,
      autoConnectLastPrinter: true,
      persistPrinterInfo: true,
      operationTimeout: Duration(seconds: 30),
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Enhanced Zebra Utility Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ZebraPrinterDemo(),
    );
  }
}

class ZebraPrinterDemo extends StatefulWidget {
  const ZebraPrinterDemo({super.key});

  @override
  State<ZebraPrinterDemo> createState() => _ZebraPrinterDemoState();
}

class _ZebraPrinterDemoState extends State<ZebraPrinterDemo> {
  late final ZebraUtility _zebra;
  List<ZebraDevice> _discoveredDevices = [];
  ZebraDevice? _connectedDevice;
  StoredPrinterInfo? _storedPrinterInfo;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _zebra = ZebraUtility.instance;
    _setupListeners();
    _updateStoredPrinterInfo();
  }

  void _setupListeners() {
    // Listen to connection changes
    _zebra.connectionStream.listen((device) {
      setState(() {
        _connectedDevice = device;
        _statusMessage =
            device != null ? 'Connected to ${device.name}' : 'Disconnected';
      });
    });

    // Listen to discovery changes
    _zebra.discoveryStream.listen((session) {
      setState(() {
        _discoveredDevices = session.discoveredDevices;
        if (session.status == DiscoveryStatus.completed) {
          _statusMessage = 'Found ${session.discoveredDevices.length} devices';
        }
      });
    });

    // Listen to print jobs
    _zebra.printStream.listen((printJob) {
      setState(() {
        _statusMessage = 'Print ${printJob.status.name}: ${printJob.id}';
      });
    });
  }

  void _updateStoredPrinterInfo() {
    setState(() {
      _storedPrinterInfo = _zebra.storedPrinterInfo;
    });
  }

  // Quick print method using connectAndPrint
  Future<void> _quickPrint() async {
    const zplData = '''
^XA
^CF0,60
^FO50,50^FDQuick Print Test^FS
^CF0,30
^FO50,120^FDConnectAndPrint Demo^FS
^FO50,160^FDTime: {{TIME}}^FS
^XZ
''';

    final now = DateTime.now();
    final timeString =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final finalZpl = zplData.replaceAll('{{TIME}}', timeString);

    final result = await _zebra.connectAndPrint(finalZpl);

    setState(() {
      if (result.isSuccess) {
        _statusMessage = 'Print job started: ${result.data!.id}';
      } else {
        _statusMessage = 'Print failed: ${result.error!.message}';
      }
    });
  }

  // Connect to a specific device
  Future<void> _connectToDevice(ZebraDevice device) async {
    final result = await _zebra.connect(device);

    setState(() {
      if (result.isSuccess) {
        _statusMessage = 'Connected to ${device.name}';
        _updateStoredPrinterInfo();
      } else {
        _statusMessage = 'Connection failed: ${result.error!.message}';
      }
    });
  }

  // Connect to stored printer
  Future<void> _connectToStoredPrinter() async {
    final result = await _zebra.connectToStoredPrinter();

    setState(() {
      if (result.isSuccess) {
        _statusMessage = 'Connected to stored printer';
      } else {
        _statusMessage =
            'Failed to connect to stored printer: ${result.error!.message}';
      }
    });
  }

  // Start device discovery
  Future<void> _startDiscovery() async {
    final result = await _zebra.startDiscovery();

    setState(() {
      if (result.isSuccess) {
        _statusMessage = 'Scanning for devices...';
      } else {
        _statusMessage = 'Discovery failed: ${result.error!.message}';
      }
    });
  }

  // Clear stored printer
  Future<void> _clearStoredPrinter() async {
    final result = await _zebra.clearStoredPrinter();

    setState(() {
      if (result.isSuccess) {
        _statusMessage = 'Cleared stored printer';
        _updateStoredPrinterInfo();
      } else {
        _statusMessage = 'Failed to clear: ${result.error!.message}';
      }
    });
  }

  // Get saved printer information
  Future<void> _getSavedPrinter() async {
    final result = _zebra.getSavedPrinter();

    setState(() {
      if (result.isSuccess) {
        final device = result.data!;
        _statusMessage = 'Saved printer: ${device.name} (${device.address})';
      } else {
        _statusMessage = 'No saved printer: ${result.error!.message}';
      }
    });
  }

  // Get saved printer detailed info
  Future<void> _getSavedPrinterInfo() async {
    final result = _zebra.getSavedPrinterInfo();

    setState(() {
      if (result.isSuccess) {
        final info = result.data!;
        _statusMessage =
            'Saved: ${info.name}, Last used: ${info.lastConnected.hour}:${info.lastConnected.minute.toString().padLeft(2, '0')}';
      } else {
        _statusMessage = 'No saved printer info: ${result.error!.message}';
      }
    });
  }

  // Delete saved printer
  Future<void> _deleteSavedPrinter() async {
    final result = await _zebra.deleteSavedPrinter();

    setState(() {
      if (result.isSuccess) {
        _statusMessage = 'Deleted saved printer';
        _updateStoredPrinterInfo();
      } else {
        _statusMessage = 'Failed to delete: ${result.error!.message}';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Enhanced Zebra Utility Demo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
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
                    Text('Message: $_statusMessage'),
                    Text('Connected: ${_connectedDevice?.name ?? 'None'}'),
                    Text(
                        'Stored Printer: ${_storedPrinterInfo?.name ?? 'None'}'),
                    Text(
                        'Has Stored: ${_zebra.hasStoredPrinter ? 'Yes' : 'No'}'),
                    Text('Scanning: ${_zebra.isScanning ? 'Yes' : 'No'}'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Quick Actions
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),

            // Quick Print Button (main feature)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _quickPrint,
                icon: const Icon(Icons.print),
                label: const Text('Quick Print (Connect & Print)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Other action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _zebra.isScanning ? null : _startDiscovery,
                    icon: const Icon(Icons.search),
                    label: const Text('Discover'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _zebra.hasStoredPrinter
                        ? _connectToStoredPrinter
                        : null,
                    icon: const Icon(Icons.link),
                    label: const Text('Connect Stored'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _zebra.hasStoredPrinter ? _clearStoredPrinter : null,
                icon: const Icon(Icons.clear),
                label: const Text('Clear Stored Printer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Saved Printer Actions
            if (_zebra.hasStoredPrinter) ...[
              Text(
                'Saved Printer Actions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _getSavedPrinter,
                      icon: const Icon(Icons.info_outline),
                      label: const Text('Get Saved'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _getSavedPrinterInfo,
                      icon: const Icon(Icons.details),
                      label: const Text('Get Details'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _deleteSavedPrinter,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete Saved Printer'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Discovered Devices
            Text(
              'Discovered Devices (${_discoveredDevices.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),

            Expanded(
              child: _discoveredDevices.isEmpty
                  ? const Center(
                      child: Text(
                          'No devices found. Start discovery to find printers.'),
                    )
                  : ListView.builder(
                      itemCount: _discoveredDevices.length,
                      itemBuilder: (context, index) {
                        final device = _discoveredDevices[index];
                        final isConnected =
                            _connectedDevice?.address == device.address;

                        return Card(
                          child: ListTile(
                            leading: Icon(
                              device.isWifi ? Icons.wifi : Icons.bluetooth,
                              color: isConnected ? Colors.green : null,
                            ),
                            title: Text(
                              device.name.isEmpty
                                  ? 'Unknown Device'
                                  : device.name,
                              style: TextStyle(
                                fontWeight: isConnected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                                '${device.address} (${device.isWifi ? 'WiFi' : 'Bluetooth'})'),
                            trailing: isConnected
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : IconButton(
                                    icon: const Icon(
                                        Icons.connect_without_contact),
                                    onPressed: () => _connectToDevice(device),
                                  ),
                            onTap: isConnected
                                ? null
                                : () => _connectToDevice(device),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
