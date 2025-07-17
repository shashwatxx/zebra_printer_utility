# Flutter ZebraUtil

## 🚀 NEW: Modern Singleton API Available!

> **⚡ Major Update**: We've introduced a **brand new singleton API** that follows the Firebase initialization pattern! This provides better type safety, error handling, and reactive programming capabilities.

### 🌟 Choose Your API Style

#### 🔥 **New Singleton API** (Recommended)
```dart
// Initialize once in main()
await ZebraUtility.initialize(
  config: ZebraConfig(enableDebugLogging: true)
);

// Use anywhere in your app
final zebra = ZebraUtility.instance;
await zebra.startDiscovery();
```
**[📖 View Complete New API Guide →](NEW_API_GUIDE.md)**

#### 📱 **Legacy API** (Still Supported)
```dart
final printer = await ZebraUtil.getPrinterInstance();
await printer.startScanning();
```

---

Zebra utility is a production-ready plugin for working with Zebra printers in your Flutter project.

### ✨ Key Features
  - **🔥 NEW: Singleton API** - Firebase-style initialization with type-safe operations
  - **📊 Reactive Programming** - Real-time streams for discovery, print jobs, and connections
  - **🛡️ Enhanced Error Handling** - Structured error responses with detailed information
  - **🔧 Type Safety** - Full TypeScript-style type safety for all operations
  - **⚡ Stable & Crash-Free** - Fixed critical threading issues for reliable printing
  - **🔍 Discovery** - Bluetooth and WiFi printers on Android, Bluetooth printers on iOS
  - **🔗 Easy Connection** - Connect and disconnect to printers seamlessly
  - **⚙️ ZPL Commands** - Set mediatype, darkness, calibrate without writing ZPL code
  - **🔄 Print Rotation** - Rotate ZPL without changing your existing code
  - **📡 Real-time Callbacks** - Get immediate feedback on print success/failure

### 🛠️ Recent Major Improvements
- ✅ **🚀 NEW Singleton API**: Firebase-style initialization with comprehensive type safety
- ✅ **📊 Reactive Streams**: Real-time event streams for all printer operations
- ✅ **🛡️ Enhanced Error Handling**: Structured `ZebraResult<T>` responses with detailed error information
- ✅ **🔧 Type Safety**: Full type-safe API with validation and proper error messages
- ✅ **🧵 Fixed Threading Crashes**: Resolved `Methods marked with @UiThread must be executed on the main thread` errors
- ✅ **📡 Enhanced Print Callbacks**: Real-time print completion and error detection
- ✅ **🔒 Improved Stability**: Thread-safe method channel communications
- ✅ **📋 State Management**: Automatic state synchronization and cleanup


# Installation

## Android

Add this code to android block in `build.gradle` (Module level).

```sh
android {
    packagingOptions {
        exclude 'META-INF/LICENSE.txt'
        exclude 'META-INF/NOTICE.txt'
        exclude 'META-INF/NOTICE'
        exclude 'META-INF/LICENSE'
        exclude 'META-INF/DEPENDENCIES'
    }
}
```

Include the necessary permission in the Android Manifest.
```sh
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

## iOS
Add `Supported external accessory protocols` in your `info.plist` and then add `com.zebra.rawport`to its.
Add `Privacy - Local Network Usage Description` in your `info.plist`.

# Quick Start Examples

## 🔥 New Singleton API (Recommended)

### Initialize Once in Main
```dart
import 'package:zebrautil/zebrautil.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize ZebraUtility (similar to Firebase.initializeApp())
  final initResult = await ZebraUtility.initialize(
    config: ZebraConfig(
      enableDebugLogging: true,
      operationTimeout: Duration(seconds: 30),
    ),
  );
  
  if (initResult.isSuccess) {
    print('ZebraUtility initialized successfully!');
  }
  
  runApp(MyApp());
}
```

### Use Anywhere in Your App
```dart
class PrinterWidget extends StatefulWidget {
  @override
  _PrinterWidgetState createState() => _PrinterWidgetState();
}

class _PrinterWidgetState extends State<PrinterWidget> {
  late ZebraUtility zebra;

  @override
  void initState() {
    super.initState();
    
    // Get singleton instance
    zebra = ZebraUtility.instance;
    
    // Setup reactive listeners
    zebra.discoveryStream.listen((session) {
      print('Found ${session.discoveredDevices.length} devices');
    });
    
    zebra.printStream.listen((printJob) {
      print('Print job ${printJob.id}: ${printJob.status}');
    });
  }

  Future<void> _discoverAndPrint() async {
    // Start discovery with proper error handling
    final discoveryResult = await zebra.startDiscovery();
    if (!discoveryResult.isSuccess) {
      print('Discovery failed: ${discoveryResult.error?.message}');
      return;
    }

    // Wait for devices (or use stream listener)
    await Future.delayed(Duration(seconds: 3));
    
    if (zebra.discoveredDevices.isEmpty) {
      print('No devices found');
      return;
    }

    // Connect to first device
    final device = zebra.discoveredDevices.first;
    final connectResult = await zebra.connect(device);
    if (!connectResult.isSuccess) {
      print('Connection failed: ${connectResult.error?.message}');
      return;
    }

    // Print with job tracking
    final printResult = await zebra.print('^XA^FO50,50^FDHello World^FS^XZ');
    if (printResult.isSuccess) {
      print('Print job started: ${printResult.data!.id}');
    }
  }
}
```

**[📖 Complete New API Documentation →](NEW_API_GUIDE.md)**

---

## 📱 Legacy API Example
## Getting Started
There is a static class that allows you to create different instances of ZebraPrinter.
```sh
     FutureBuilder(
        future: ZebraUtil.getPrinterInstance(), //required async 
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          final zebraPrinter = snapshot.data as ZebraPrinter;
          return PrinterTemplate(zebraPrinter);
        },
      ),
```

You can then set up callbacks for various events:

```sh
    // Discovery callbacks
    zebraPrinter.setOnDiscoveryError((errorCode, errorText) {
      print("Discovery Error: $errorCode, $errorText");
    });
    
    zebraPrinter.setOnPermissionDenied(() {
      print("Permission denied");
    });
    
    // Print completion callbacks (Enhanced!)
    zebraPrinter.setOnPrintComplete(() {
      print("Print completed successfully!");
      // Show success dialog or update UI
    });
    
    zebraPrinter.setOnPrintError((errorMessage) {
      print("Print failed: $errorMessage");
      // Handle specific error (paper out, head open, etc.)
    });
```

## Methods
After configuring the instance, use the following method to start searching for available devices:

```sh
  zebraPrinter.startScanning();
```
It won't stop automatically, if you wish to stop the scan you must call:

 ```sh
  zebraPrinter.stopScanning();
```

To listen for and display any devices (`ZebraDevice`), you can use the Zebra printer `ZebraController`
```sh
ListenableBuilder(
    listenable: zebraPrinter.controller,
    builder: (context, child) {
      final printers = zebraPrinter.controller.printers;
      if (printers.isEmpty) {
        return _getNotAvailablePage();
      }
      return _getListDevices(printers);
    },
  )
```

For connecting to printer, pass ipAddreess for wifi printer or macAddress for bluetooth printer to `connectToPrinter` method.
```sh
 zebraPrinter.connectToPrinter("192.168.47.50");
```

You can set media type between `Lable`, `Journal` and `BlackMark`. You can choose media type by `EnumMediaType`.
```sh
  zebraPrinter.setMediaType(EnumMediaType.BlackMark);
```
You may callibrate printer after set media type. You can use this method.
```sh
zebraPrinter.calibratePrinter();
```
You can set darkness. the valid darkness value are -99,-75,-50,-25,0,25,50,75,100,125,150,175,200.
```sh
  zebraPrinter.setDarkness(25);
```
For print ZPL, you pass ZPL to `print` method.
```sh
  zebraPrinter.print("Your ZPL");
```
For rotate your ZPL without changing your ZPL, you can use this method. You can call this again for normal printing.
```sh
  zebraPrinter.rotate();
```
For disconnect from printer, use `disconnect` method. For battery saver, disconnect from printer when you not need printer.
```sh
  zebraPrinter.disconnect();
```

## 🔧 Troubleshooting

### Common Issues and Solutions

**Threading Crashes (Fixed in Latest Version)**
- **Issue**: App crashes with `Methods marked with @UiThread must be executed on the main thread`
- **Solution**: Update to the latest version - this threading issue has been resolved

**Print Completion Detection**
- **Feature**: The plugin now provides real-time print completion callbacks
- **Usage**: Use `setOnPrintComplete()` and `setOnPrintError()` for immediate feedback

**Scanner Behavior**
- **Note**: Once connected to a printer, it may not be detected by subsequent scans
- **Recommendation**: Stop scanning after successful connection for better performance

### Getting Help
If you encounter issues:
1. Check the [Implementation Guide](IMPLEMENTATION_GUIDE.md) for detailed technical information
2. Ensure all required permissions are granted
3. Verify printer is powered on and in discoverable mode

# Acknowledgements
I would like to express my gratitude to Deltec for fostering a friendly and supportive environment.

Special thanks to [`MythiCode`](https://github.com/MythiCode/zebra_utlity) for providing the foundational code for this library. Specifically, I appreciate the following contributions:

* Base implementation for core functionalities
* Initial setup and structure
* Key algorithms and methods

Thank you to everyone who made this project possible!