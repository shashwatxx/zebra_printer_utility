# Changelog

## [2.0.0] - 2024-12-19

### 🚀 MAJOR UPDATE: New Singleton API

This is a **major release** introducing a modern, type-safe singleton API that follows the Firebase initialization pattern.

#### ✨ New Features

- **🔥 Singleton API**: Firebase-style initialization with `ZebraUtility.initialize()`
- **📊 Reactive Programming**: Real-time streams for discovery, print jobs, and connections
- **🛡️ Enhanced Error Handling**: Structured `ZebraResult<T>` responses with detailed error information
- **🔧 Type Safety**: Full type-safe API with validation and proper error messages
- **📋 State Management**: Automatic state synchronization and cleanup
- **🎯 Configuration System**: Comprehensive configuration options with `ZebraConfig`
- **📡 Event Streams**: Real-time updates via `discoveryStream`, `printStream`, and `connectionStream`
- **🏷️ Print Job Tracking**: Track print jobs with IDs, status, and completion times
- **📋 Discovery Sessions**: Structured discovery sessions with status tracking

#### 📚 New API Components

- `ZebraUtility` - Main singleton class
- `ZebraConfig` - Configuration options
- `ZebraResult<T>` - Type-safe result wrapper
- `ZebraError` - Structured error information
- `PrintJob` - Print job tracking
- `DiscoverySession` - Discovery session management
- Multiple enums for type safety (`ConnectionType`, `PrintJobStatus`, `DiscoveryStatus`, `ErrorType`)

#### 🔄 Backward Compatibility

- **Legacy API Preserved**: All existing `ZebraUtil` and `ZebraPrinter` APIs remain functional
- **Gradual Migration**: Users can migrate at their own pace
- **Documentation**: Comprehensive migration guide provided

#### 📖 Documentation

- Added `NEW_API_GUIDE.md` with complete documentation
- Migration guide from legacy to new API
- Best practices and troubleshooting
- Complete example implementation

#### 🎯 Usage

```dart
// Initialize once in main()
await ZebraUtility.initialize(
  config: ZebraConfig(enableDebugLogging: true)
);

// Use anywhere in your app
final zebra = ZebraUtility.instance;
final result = await zebra.startDiscovery();
```

### 🛠️ Improvements

- **Enhanced Documentation**: Updated README with new API examples
- **Better Type Safety**: Comprehensive type checking and validation
- **Improved Error Messages**: More specific and actionable error information
- **Performance Optimizations**: Better resource management and cleanup

### 📋 Files Added

- `lib/zebra_utility.dart` - Main singleton API
- `lib/zebrautil.dart` - Library exports
- `NEW_API_GUIDE.md` - Comprehensive API documentation
- `example/lib/new_api_example.dart` - Complete example implementation

---

## [1.5.4] - Previous Release

### 🛠️ Recent Improvements
- ✅ **Fixed Threading Crashes**: Resolved `Methods marked with @UiThread must be executed on the main thread` errors
- ✅ **Enhanced Print Callbacks**: Real-time print completion and error detection
- ✅ **Improved Stability**: Thread-safe method channel communications
- ✅ **Better Error Handling**: Specific error messages for different printer states

### ✨ Key Features
- **Stable & Crash-Free**: Fixed critical threading issues for reliable printing
- **Discovery**: Bluetooth and WiFi printers on Android, Bluetooth printers on iOS
- **Easy Connection**: Connect and disconnect to printers seamlessly
- **ZPL Commands**: Set mediatype, darkness, calibrate without writing ZPL code
- **Print Rotation**: Rotate ZPL without changing your existing code
- **Real-time Callbacks**: Get immediate feedback on print success/failure