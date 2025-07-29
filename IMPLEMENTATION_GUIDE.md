# ZebraUtility Implementation Guide

## Enhanced Singleton with Persistence

The ZebraUtility singleton now supports persistent printer storage and auto-connection. This allows you to:

1. **Initialize once** at app startup
2. **Auto-connect** to the last used printer
3. **Connect and print** in one operation
4. **Persist printer information** across app sessions

## Quick Start

### 1. Initialize at App Startup

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize ZebraUtility once
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
```

### 2. Use Anywhere in Your App

```dart
class PrintService {
  static final ZebraUtility _zebra = ZebraUtility.instance;
  
  // Simple print with auto-connect
  static Future<bool> quickPrint(String zplData) async {
    final result = await _zebra.connectAndPrint(zplData);
    return result.isSuccess;
  }
  
  // Check if printer is available
  static bool get hasPrinter => _zebra.hasStoredPrinter || _zebra.isConnected;
}
```

### 3. Connect and Print in One Call

```dart
// This will automatically connect to stored printer if needed
final result = await ZebraUtility.instance.connectAndPrint('''
^XA
^CF0,60
^FO50,50^FDHello World^FS
^XZ
''');

if (result.isSuccess) {
  print('Print job started: ${result.data!.id}');
} else {
  print('Print failed: ${result.error!.message}');
}
```

## Implementing Persistence

The current implementation includes placeholder methods for persistence. To add actual storage, implement these methods:

### Using SharedPreferences

Add to your `pubspec.yaml`:
```yaml
dependencies:
  shared_preferences: ^2.2.2
```

Then implement the persistence methods in `ZebraUtility`:

```dart
// Replace the placeholder _loadStoredPrinterInfo method
Future<void> _loadStoredPrinterInfo() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_config!.storageKey);
    if (jsonString != null) {
      final json = jsonDecode(jsonString);
      _storedPrinterInfo = StoredPrinterInfo.fromJson(json);
      
      if (_config?.enableDebugLogging == true) {
        developer.log('Loaded stored printer: ${_storedPrinterInfo!.address}', 
            name: 'ZebraUtility');
      }
    }
  } catch (e) {
    if (_config?.enableDebugLogging == true) {
      developer.log('Failed to load stored printer info: $e', name: 'ZebraUtility');
    }
  }
}

// Replace the placeholder _persistPrinterInfo method
Future<void> _persistPrinterInfo() async {
  try {
    if (_storedPrinterInfo == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(_storedPrinterInfo!.toJson());
    await prefs.setString(_config!.storageKey, jsonString);
    
    if (_config?.enableDebugLogging == true) {
      developer.log('Persisted printer info: ${_storedPrinterInfo!.address}', 
          name: 'ZebraUtility');
    }
  } catch (e) {
    if (_config?.enableDebugLogging == true) {
      developer.log('Failed to persist printer info: $e', name: 'ZebraUtility');
    }
  }
}

// Replace the placeholder _clearPersistedPrinterInfo method
Future<void> _clearPersistedPrinterInfo() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_config!.storageKey);
    
    if (_config?.enableDebugLogging == true) {
      developer.log('Cleared persisted printer info', name: 'ZebraUtility');
    }
  } catch (e) {
    if (_config?.enableDebugLogging == true) {
      developer.log('Failed to clear persisted printer info: $e', name: 'ZebraUtility');
    }
  }
}
```

### Using Hive (Alternative)

For more advanced storage, you can use Hive:

```yaml
dependencies:
  hive: ^2.2.3
  hive_flutter: ^1.1.0
```

## Key Features

### 1. Auto-Connection
- Automatically connects to the last used printer on app startup
- Configurable via `ZebraConfig.autoConnectLastPrinter`

### 2. One-Shot Printing
- `connectAndPrint()` method handles connection and printing in one call
- Automatically connects to stored printer if not already connected

### 3. Persistent Storage
- Saves printer information across app sessions
- Configurable storage key for custom implementations

### 4. Enhanced Error Handling
- Type-safe `ZebraResult<T>` wrapper for all operations
- Detailed error information with error types

### 5. Stream-Based Updates
- Real-time updates for connections, discoveries, and print jobs
- Easy integration with Flutter's reactive widgets

### 6. Saved Printer Management
- `getSavedPrinter()` - Get saved printer as ZebraDevice
- `getSavedPrinterInfo()` - Get detailed saved printer information  
- `deleteSavedPrinter()` / `clearStoredPrinter()` - Remove saved printer

## Saved Printer Methods

### Get Saved Printer

```dart
// Get saved printer as ZebraDevice for connection
final result = ZebraUtility.instance.getSavedPrinter();
if (result.isSuccess) {
  final device = result.data!;
  print('Saved printer: ${device.name} (${device.address})');
  
  // You can use this device to connect
  await zebra.connect(device);
} else {
  print('No saved printer: ${result.error!.message}');
}

// Get detailed saved printer information with metadata
final infoResult = ZebraUtility.instance.getSavedPrinterInfo();
if (infoResult.isSuccess) {
  final info = infoResult.data!;
  print('Printer: ${info.name}');
  print('Last connected: ${info.lastConnected}');
  print('Uses generic connection: ${info.useGenericConnection}');
  print('Connection type: ${info.isWifi ? 'WiFi' : 'Bluetooth'}');
}
```

### Delete Saved Printer

```dart
// Delete the saved printer
final result = await ZebraUtility.instance.deleteSavedPrinter();
if (result.isSuccess) {
  print('Saved printer deleted successfully');
} else {
  print('Failed to delete saved printer: ${result.error!.message}');
}

// Alternative method (same functionality)
await ZebraUtility.instance.clearStoredPrinter();
```

### Check if Printer is Saved

```dart
// Quick check
if (ZebraUtility.instance.hasStoredPrinter) {
  print('A printer is saved');
}

// Or get the stored printer info directly (getter, no error handling)
final storedInfo = ZebraUtility.instance.storedPrinterInfo;
if (storedInfo != null) {
  print('Saved printer: ${storedInfo.name}');
}
```

## App Lifecycle Management

### Initialization
```dart
// Initialize once in main()
await ZebraUtility.initialize(config: myConfig);
```

### Usage Throughout App
```dart
// Use anywhere without re-initialization
final zebra = ZebraUtility.instance;
```

### Cleanup (Optional)
```dart
// Only needed for testing or complete reset
await ZebraUtility.reset();
```

## Best Practices

1. **Initialize Early**: Call `ZebraUtility.initialize()` in `main()` before `runApp()`
2. **Use Streams**: Listen to streams for reactive UI updates
3. **Handle Errors**: Always check `ZebraResult.isSuccess` before using data
4. **Store Important Printers**: Let the system store frequently used printers
5. **Test Connectivity**: Use `connectAndPrint()` for reliable printing

## Configuration Options

```dart
ZebraConfig(
  enableDebugLogging: true,           // Enable detailed logging
  autoConnectLastPrinter: true,       // Auto-connect on startup
  persistPrinterInfo: true,           // Save printer across sessions
  operationTimeout: Duration(seconds: 30), // Custom timeout
  storageKey: 'my_printer_storage',   // Custom storage key
)
```

## Error Handling

```dart
final result = await zebra.connectAndPrint(zplData);
if (result.isSuccess) {
  // Success - use result.data
  print('Print job: ${result.data!.id}');
} else {
  // Handle error - use result.error
  switch (result.error!.type) {
    case ErrorType.connection:
      // Handle connection errors
      break;
    case ErrorType.printing:
      // Handle printing errors
      break;
    default:
      // Handle other errors
      break;
  }
}
``` 