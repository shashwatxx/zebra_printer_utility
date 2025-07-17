# Zebra Utility - New Singleton API Guide

## 🚀 Overview

The Zebra Utility plugin now features a modern, type-safe singleton API that follows the Firebase initialization pattern. This new API provides better error handling, structured responses, and reactive programming capabilities.

## ✨ Key Features

### 🔧 Firebase-Style Initialization
- **Singleton Pattern**: Initialize once, use anywhere
- **Type-Safe Configuration**: Strongly typed configuration options
- **Comprehensive Error Handling**: Structured error responses with detailed information

### 📊 Reactive Programming
- **Real-time Streams**: Listen to discovery, print jobs, and connection changes
- **Event-Driven**: Automatic updates when printer state changes
- **Structured Data**: Type-safe models for all operations

### 🛡️ Enhanced Safety
- **Result Wrapper**: All operations return `ZebraResult<T>` for safe error handling
- **Validation**: Input validation with specific error messages
- **State Management**: Automatic cleanup and resource management

## 🏃‍♂️ Quick Start

### 1. Initialize (Once in your app)

```dart
import 'package:zebrautil/zebrautil.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize ZebraUtility with configuration
  final initResult = await ZebraUtility.initialize(
    config: ZebraConfig(
      enableDebugLogging: true,
      operationTimeout: Duration(seconds: 30),
      autoConnectLastPrinter: false,
    ),
  );
  
  if (initResult.isSuccess) {
    print('ZebraUtility initialized successfully!');
  } else {
    print('Failed to initialize: ${initResult.error?.message}');
  }
  
  runApp(MyApp());
}
```

### 2. Use Anywhere in Your App

```dart
class PrinterPage extends StatefulWidget {
  @override
  _PrinterPageState createState() => _PrinterPageState();
}

class _PrinterPageState extends State<PrinterPage> {
  late ZebraUtility zebra;
  StreamSubscription<DiscoverySession>? _discoverySubscription;
  StreamSubscription<PrintJob>? _printSubscription;

  @override
  void initState() {
    super.initState();
    
    // Get the singleton instance
    zebra = ZebraUtility.instance;
    
    // Setup event listeners
    _setupListeners();
  }

  void _setupListeners() {
    // Listen to discovery events
    _discoverySubscription = zebra.discoveryStream.listen((session) {
      print('Discovery status: ${session.status}');
      print('Found ${session.discoveredDevices.length} devices');
    });

    // Listen to print job events
    _printSubscription = zebra.printStream.listen((printJob) {
      print('Print job ${printJob.id}: ${printJob.status}');
    });
  }

  @override
  void dispose() {
    _discoverySubscription?.cancel();
    _printSubscription?.cancel();
    super.dispose();
  }
}
```

## 📝 Complete API Documentation

### Configuration

```dart
class ZebraConfig {
  final ZebraController? controller;           // Custom state controller
  final bool enableDebugLogging;              // Enable debug logs
  final Duration operationTimeout;            // Timeout for operations
  final bool autoConnectLastPrinter;          // Auto-reconnect feature
  final ConnectionType? preferredConnectionType; // Bluetooth/WiFi preference
}

enum ConnectionType { bluetooth, wifi, any }
```

### Initialization

```dart
// Initialize with default config
final result = await ZebraUtility.initialize();

// Initialize with custom config
final result = await ZebraUtility.initialize(
  config: ZebraConfig(
    enableDebugLogging: true,
    operationTimeout: Duration(seconds: 45),
    autoConnectLastPrinter: true,
    preferredConnectionType: ConnectionType.bluetooth,
  ),
);

// Check if initialized
if (ZebraUtility.isInitialized) {
  final zebra = ZebraUtility.instance;
}
```

### Discovery Operations

```dart
final zebra = ZebraUtility.instance;

// Start discovery
final startResult = await zebra.startDiscovery();
if (startResult.isSuccess) {
  final session = startResult.data!;
  print('Discovery session started: ${session.id}');
}

// Stop discovery
final stopResult = await zebra.stopDiscovery();
if (stopResult.isSuccess) {
  final session = stopResult.data!;
  print('Found ${session.discoveredDevices.length} devices');
}

// Listen to discovery events
zebra.discoveryStream.listen((session) {
  switch (session.status) {
    case DiscoveryStatus.scanning:
      print('Scanning for devices...');
      break;
    case DiscoveryStatus.completed:
      print('Discovery completed');
      break;
    case DiscoveryStatus.error:
      print('Discovery error: ${session.errorMessage}');
      break;
  }
});

// Get discovered devices
final devices = zebra.discoveredDevices;
```

### Connection Operations

```dart
// Connect to a device
final device = zebra.discoveredDevices.first;
final connectResult = await zebra.connect(device);

if (connectResult.isSuccess) {
  print('Connected to ${device.name}');
} else {
  print('Connection failed: ${connectResult.error?.message}');
}

// Connect with generic connection
final genericResult = await zebra.connect(device, useGenericConnection: true);

// Disconnect
final disconnectResult = await zebra.disconnect();

// Check connection status
final statusResult = await zebra.checkConnection();
final isConnected = statusResult.getDataOr(false);

// Listen to connection changes
zebra.connectionStream.listen((device) {
  if (device != null) {
    print('Connected to: ${device.name}');
  } else {
    print('Disconnected');
  }
});
```

### Printing Operations

```dart
// Print ZPL data
const zplData = '''
^XA
^CF0,60
^FO50,50^FDHello World^FS
^XZ
''';

final printResult = await zebra.print(zplData);
if (printResult.isSuccess) {
  final job = printResult.data!;
  print('Print job started: ${job.id}');
} else {
  print('Print failed: ${printResult.error?.message}');
}

// Print with custom job ID
final customResult = await zebra.print(zplData, jobId: 'my-custom-job-123');

// Listen to print job updates
zebra.printStream.listen((printJob) {
  switch (printJob.status) {
    case PrintJobStatus.printing:
      print('Printing job ${printJob.id}...');
      break;
    case PrintJobStatus.completed:
      print('Print completed successfully');
      break;
    case PrintJobStatus.failed:
      print('Print failed: ${printJob.errorMessage}');
      break;
  }
});

// Get all print jobs
final jobs = zebra.printJobs;
```

### Configuration Operations

```dart
// Configure printer settings
final configResult = await zebra.configureSettings(
  mediaType: EnumMediaType.label,
  darkness: 25,
  calibrate: true,
);

if (configResult.isSuccess) {
  print('Settings applied successfully');
}

// Individual settings
await zebra.configureSettings(mediaType: EnumMediaType.blackMark);
await zebra.configureSettings(darkness: 50);
await zebra.configureSettings(calibrate: true);
```

### Rotation Operations

```dart
// Toggle rotation
zebra.toggleRotation();

// Check rotation status
final isRotated = zebra.isRotated;
print('Rotation enabled: $isRotated');
```

### State Information

```dart
final zebra = ZebraUtility.instance;

// Check various states
print('Scanning: ${zebra.isScanning}');
print('Connected: ${zebra.isConnected}');
print('Connected device: ${zebra.connectedDevice?.name}');
print('Discovered devices: ${zebra.discoveredDevices.length}');
print('Current session: ${zebra.currentDiscoverySession?.id}');
print('Print jobs: ${zebra.printJobs.length}');
```

## 📊 Data Models

### ZebraResult<T>

```dart
class ZebraResult<T> {
  final T? data;
  final ZebraError? error;
  final bool isSuccess;

  // Get data or throw error
  T get dataOrThrow;
  
  // Get data or default value
  T getDataOr(T defaultValue);
}

// Usage examples
final result = await zebra.startDiscovery();
if (result.isSuccess) {
  final session = result.data!;
  // Use session
} else {
  print('Error: ${result.error?.message}');
}

// Or use convenience methods
final session = result.dataOrThrow;  // Throws if failed
final session = result.getDataOr(fallbackSession);  // Returns fallback if failed
```

### ZebraError

```dart
class ZebraError {
  final String message;
  final String? code;
  final ErrorType type;
  final dynamic originalError;
}

enum ErrorType {
  initialization,
  connection,
  permission,
  validation,
  printing,
  discovery,
  timeout,
  unknown
}
```

### PrintJob

```dart
class PrintJob {
  final String id;
  final String data;
  final PrintJobStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? errorMessage;
}

enum PrintJobStatus {
  queued,
  printing,
  completed,
  failed,
  cancelled
}
```

### DiscoverySession

```dart
class DiscoverySession {
  final String id;
  final DiscoveryStatus status;
  final List<ZebraDevice> discoveredDevices;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? errorMessage;
}

enum DiscoveryStatus {
  idle,
  scanning,
  completed,
  error
}
```

## 🔄 Migration Guide

### From Old API to New API

#### Old Way (Legacy)
```dart
// Old initialization
final printer = await ZebraUtil.getPrinterInstance(
  onDiscoveryError: (code, text) => print('Error: $code'),
  onPrintComplete: () => print('Print completed'),
  onPrintError: (error) => print('Print error: $error'),
);

// Old usage
await printer.startScanning();
await printer.connectToPrinter('192.168.1.100');
await printer.print(data: zplData);
await printer.disconnect();
```

#### New Way (Recommended)
```dart
// New initialization (once in main)
await ZebraUtility.initialize(
  config: ZebraConfig(enableDebugLogging: true),
);

// New usage (anywhere in app)
final zebra = ZebraUtility.instance;

// Setup listeners
zebra.discoveryStream.listen((session) {
  if (session.status == DiscoveryStatus.error) {
    print('Discovery error: ${session.errorMessage}');
  }
});

zebra.printStream.listen((job) {
  switch (job.status) {
    case PrintJobStatus.completed:
      print('Print completed');
      break;
    case PrintJobStatus.failed:
      print('Print error: ${job.errorMessage}');
      break;
  }
});

// Operations with proper error handling
final startResult = await zebra.startDiscovery();
if (!startResult.isSuccess) return;

final device = zebra.discoveredDevices.first;
final connectResult = await zebra.connect(device);
if (!connectResult.isSuccess) return;

final printResult = await zebra.print(zplData);
if (!printResult.isSuccess) return;

await zebra.disconnect();
```

### Migration Checklist

- [ ] **Replace initialization**: Use `ZebraUtility.initialize()` in `main()`
- [ ] **Update instance access**: Use `ZebraUtility.instance` instead of storing printer instance
- [ ] **Replace callbacks**: Use streams (`discoveryStream`, `printStream`, `connectionStream`)
- [ ] **Update error handling**: Use `ZebraResult<T>` instead of try-catch
- [ ] **Replace method calls**: Use new method names (e.g., `startDiscovery()` instead of `startScanning()`)
- [ ] **Update imports**: Use `import 'package:zebrautil/zebrautil.dart';`

## 💡 Best Practices

### 1. Initialize Early
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize as early as possible
  await ZebraUtility.initialize(
    config: ZebraConfig(enableDebugLogging: true),
  );
  
  runApp(MyApp());
}
```

### 2. Use Streams for Real-time Updates
```dart
class PrinterWidget extends StatefulWidget {
  @override
  _PrinterWidgetState createState() => _PrinterWidgetState();
}

class _PrinterWidgetState extends State<PrinterWidget> {
  final zebra = ZebraUtility.instance;
  List<ZebraDevice> devices = [];
  ZebraDevice? connectedDevice;

  @override
  void initState() {
    super.initState();
    
    // Real-time updates
    zebra.discoveryStream.listen((session) {
      setState(() {
        devices = session.discoveredDevices;
      });
    });
    
    zebra.connectionStream.listen((device) {
      setState(() {
        connectedDevice = device;
      });
    });
  }
}
```

### 3. Handle Errors Gracefully
```dart
Future<void> performPrinterOperation() async {
  final zebra = ZebraUtility.instance;
  
  // Start discovery
  final discoveryResult = await zebra.startDiscovery();
  if (!discoveryResult.isSuccess) {
    _showError('Failed to start discovery: ${discoveryResult.error?.message}');
    return;
  }
  
  // Wait for devices (in real app, use stream listener)
  await Future.delayed(Duration(seconds: 3));
  
  if (zebra.discoveredDevices.isEmpty) {
    _showError('No devices found');
    return;
  }
  
  // Connect to first device
  final connectResult = await zebra.connect(zebra.discoveredDevices.first);
  if (!connectResult.isSuccess) {
    _showError('Connection failed: ${connectResult.error?.message}');
    return;
  }
  
  // Print
  final printResult = await zebra.print('^XA^FO50,50^FDTest^FS^XZ');
  if (!printResult.isSuccess) {
    _showError('Print failed: ${printResult.error?.message}');
    return;
  }
  
  _showSuccess('Print job started: ${printResult.data!.id}');
}
```

### 4. Clean Up Resources
```dart
class PrinterPage extends StatefulWidget {
  @override
  _PrinterPageState createState() => _PrinterPageState();
}

class _PrinterPageState extends State<PrinterPage> {
  StreamSubscription<DiscoverySession>? _discoverySubscription;
  StreamSubscription<PrintJob>? _printSubscription;
  StreamSubscription<ZebraDevice?>? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  @override
  void dispose() {
    // Clean up subscriptions
    _discoverySubscription?.cancel();
    _printSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }
  
  void _setupListeners() {
    final zebra = ZebraUtility.instance;
    
    _discoverySubscription = zebra.discoveryStream.listen((session) {
      // Handle discovery updates
    });
    
    _printSubscription = zebra.printStream.listen((job) {
      // Handle print job updates
    });
    
    _connectionSubscription = zebra.connectionStream.listen((device) {
      // Handle connection changes
    });
  }
}
```

### 5. Use Configuration for Different Environments
```dart
// Development
await ZebraUtility.initialize(
  config: ZebraConfig(
    enableDebugLogging: true,
    operationTimeout: Duration(seconds: 10),
  ),
);

// Production
await ZebraUtility.initialize(
  config: ZebraConfig(
    enableDebugLogging: false,
    operationTimeout: Duration(seconds: 30),
    autoConnectLastPrinter: true,
  ),
);
```

## 🔍 Troubleshooting

### Common Issues

#### 1. "ZebraUtility has not been initialized"
```dart
// Problem: Trying to access instance before initialization
final zebra = ZebraUtility.instance; // Throws error

// Solution: Initialize first
await ZebraUtility.initialize();
final zebra = ZebraUtility.instance; // Works
```

#### 2. Memory Leaks from Stream Subscriptions
```dart
// Problem: Not canceling subscriptions
zebra.discoveryStream.listen((session) {
  // Handle discovery
}); // Memory leak

// Solution: Cancel in dispose
StreamSubscription? subscription;

@override
void initState() {
  subscription = zebra.discoveryStream.listen((session) {
    // Handle discovery
  });
}

@override
void dispose() {
  subscription?.cancel();
  super.dispose();
}
```

#### 3. Handling Null Results
```dart
// Problem: Not checking for null
final devices = zebra.discoveredDevices;
final firstDevice = devices[0]; // May crash if empty

// Solution: Check before accessing
final devices = zebra.discoveredDevices;
if (devices.isNotEmpty) {
  final firstDevice = devices.first;
  // Use firstDevice safely
}
```

### Debug Tips

1. **Enable Debug Logging**
   ```dart
   await ZebraUtility.initialize(
     config: ZebraConfig(enableDebugLogging: true),
   );
   ```

2. **Check Result Objects**
   ```dart
   final result = await zebra.startDiscovery();
   if (!result.isSuccess) {
     print('Error Type: ${result.error?.type}');
     print('Error Code: ${result.error?.code}');
     print('Error Message: ${result.error?.message}');
     print('Original Error: ${result.error?.originalError}');
   }
   ```

3. **Monitor State**
   ```dart
   print('Is Initialized: ${ZebraUtility.isInitialized}');
   print('Is Scanning: ${zebra.isScanning}');
   print('Is Connected: ${zebra.isConnected}');
   print('Device Count: ${zebra.discoveredDevices.length}');
   ```

## 📚 Examples

### Complete Example App

See `example/lib/new_api_example.dart` for a comprehensive example that demonstrates:
- Proper initialization
- Real-time stream listening
- Error handling with ZebraResult
- State management
- UI updates based on printer events
- Print job tracking
- Device discovery and connection

### Simple Print Example

```dart
import 'package:flutter/material.dart';
import 'package:zebrautil/zebrautil.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await ZebraUtility.initialize(
    config: ZebraConfig(enableDebugLogging: true),
  );
  
  runApp(SimplePrintApp());
}

class SimplePrintApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: PrintPage(),
    );
  }
}

class PrintPage extends StatefulWidget {
  @override
  _PrintPageState createState() => _PrintPageState();
}

class _PrintPageState extends State<PrintPage> {
  final zebra = ZebraUtility.instance;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Simple Print')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _startDiscovery,
              child: Text('Start Discovery'),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: zebra.discoveredDevices.isNotEmpty ? _connectAndPrint : null,
              child: Text('Connect & Print'),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _startDiscovery() async {
    final result = await zebra.startDiscovery();
    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Discovery started')),
      );
    }
  }
  
  Future<void> _connectAndPrint() async {
    final device = zebra.discoveredDevices.first;
    
    final connectResult = await zebra.connect(device);
    if (!connectResult.isSuccess) return;
    
    final printResult = await zebra.print('^XA^FO50,50^FDHello World^FS^XZ');
    if (printResult.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print started: ${printResult.data!.id}')),
      );
    }
  }
}
```

## 🎯 Conclusion

The new ZebraUtility singleton API provides:

✅ **Better Developer Experience**: Firebase-style initialization, type safety, and structured responses  
✅ **Enhanced Error Handling**: Comprehensive error information with specific error types  
✅ **Reactive Programming**: Real-time streams for all printer events  
✅ **Improved State Management**: Automatic state synchronization and cleanup  
✅ **Production Ready**: Robust error handling and resource management  

Start using the new API today for a more reliable and maintainable Zebra printer integration! 