# Zebra Printer Utility Examples

This directory contains comprehensive examples demonstrating different approaches to using the Zebra Printer Utility plugin.

## 📱 Available Examples

### 1. **Legacy Pattern Example** (`main.dart`)
The original API pattern using direct ZebraPrinter instances with callbacks.

**Features:**
- Direct ZebraPrinter instantiation
- Callback-based event handling
- Manual state management
- Basic UI with Flutter widgets

**How to run:**
```bash
# Uncomment the legacy line in main.dart, then run:
flutter run
```

### 2. **Singleton API Example** (`singleton_example.dart`)
The new Firebase-style singleton API with reactive streams.

**Features:**
- Firebase-style initialization pattern
- Type-safe `ZebraResult<T>` responses
- Reactive streams for real-time updates
- Structured state management
- Comprehensive error handling

**How to run:**
```bash
# Option 1: Default in main.dart
flutter run

# Option 2: Direct standalone
flutter run -t lib/main_singleton.dart
```

### 3. **Singleton API with Riverpod** (`singleton_with_riverpod.dart`)
The singleton API integrated with Riverpod for advanced state management.

**Features:**
- All singleton API benefits
- Riverpod providers for reactive state
- Computed providers for derived state
- Clean separation of concerns
- Automatic UI updates
- Professional state architecture

**How to run:**
```bash
# Option 1: Uncomment in main.dart
# Edit main.dart: runApp(const SingletonWithRiverpodApp());
flutter run

# Option 2: Direct standalone  
flutter run -t lib/main_singleton_riverpod.dart
```

## 🔄 **API Comparison**

| Feature | Legacy API | Singleton API | Singleton + Riverpod |
|---------|------------|---------------|---------------------|
| **Initialization** | `ZebraUtil.getPrinterInstance()` | `ZebraUtility.initialize()` | `ZebraUtility.initialize()` |
| **State Management** | Manual callbacks | Reactive streams | Riverpod providers |
| **Error Handling** | String messages | `ZebraResult<T>` | `ZebraResult<T>` + state |
| **Type Safety** | ❌ Basic | ✅ Full | ✅ Full |
| **Reactive UI** | ❌ Manual | ✅ Stream-based | ✅ Provider-based |
| **Code Complexity** | Simple | Moderate | Advanced |
| **Scalability** | Limited | Good | Excellent |

## 🚀 **Quick Start Guide**

### Legacy Pattern
```dart
final printer = await ZebraUtil.getPrinterInstance();
printer.setOnPrintComplete(() => print('Done!'));
await printer.startScanning();
```

### Singleton API
```dart
await ZebraUtility.initialize();
final zebra = ZebraUtility.instance;
zebra.printStream.listen((job) => print('Job: ${job.status}'));
await zebra.startDiscovery();
```

### Singleton + Riverpod
```dart
// Providers handle initialization automatically
class MyWidget extends ConsumerWidget {
  Widget build(context, ref) {
    final printState = ref.watch(printProvider);
    // UI automatically updates when state changes
  }
}
```

## 🎯 **When to Use Each**

### Use **Legacy Pattern** when:
- Simple, one-off printer operations
- Minimal state management needs
- Quick prototyping
- Existing callback-based architecture

### Use **Singleton API** when:
- Complex printer workflows
- Need reactive UI updates
- Want type-safe error handling
- Building professional applications

### Use **Singleton + Riverpod** when:
- Large applications with complex state
- Need computed/derived state
- Want professional architecture patterns
- Building production apps with teams

## 📊 **Example Features Comparison**

| Feature | Legacy | Singleton | Singleton + Riverpod |
|---------|--------|-----------|---------------------|
| Device Discovery | ✅ Basic | ✅ Real-time | ✅ Reactive |
| Connection Management | ✅ Manual | ✅ Streams | ✅ Providers |
| Print Job Tracking | ❌ Limited | ✅ Full history | ✅ Full + computed |
| Error Display | ✅ Basic | ✅ Structured | ✅ State-driven |
| Settings UI | ✅ Dialogs | ✅ Type-safe | ✅ Reactive forms |
| Code Organization | ❌ Mixed | ✅ Separated | ✅ Provider-based |

## 🔧 **Development Tips**

1. **Start with Singleton API** for new projects
2. **Add Riverpod** when state complexity grows
3. **Use Legacy** only for simple integrations
4. **Test with real Zebra printers** for best results
5. **Enable debug logging** during development

## 📚 **Further Reading**

- [ZebraUtility API Documentation](../NEW_API_GUIDE.md)
- [Riverpod Documentation](https://riverpod.dev)
- [Flutter State Management](https://flutter.dev/docs/development/data-and-backend/state-mgmt)
- [Zebra Developer Documentation](https://www.zebra.com/us/en/support-downloads/software/developer-tools.html)
