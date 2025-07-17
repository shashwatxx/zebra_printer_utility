/// Zebra Printer Utility Plugin
///
/// A comprehensive Flutter plugin for working with Zebra printers.
/// Supports both Bluetooth and WiFi connections with a type-safe API.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:zebrautil/zebrautil.dart';
///
/// // Initialize once in main()
/// await ZebraUtility.initialize(
///   config: ZebraConfig(enableDebugLogging: true)
/// );
///
/// // Use anywhere in the app
/// final zebra = ZebraUtility.instance;
///
/// // Start discovery
/// final discoveryResult = await zebra.startDiscovery();
/// if (discoveryResult.isSuccess) {
///   // Listen for discovered devices
///   zebra.discoveryStream.listen((session) {
///     print('Discovered ${session.discoveredDevices.length} devices');
///   });
/// }
///
/// // Connect to a printer
/// final device = zebra.discoveredDevices.first;
/// final connectResult = await zebra.connect(device);
///
/// // Print ZPL data
/// if (connectResult.isSuccess) {
///   final printResult = await zebra.print('^XA^FO50,50^FDHello World^FS^XZ');
///   if (printResult.isSuccess) {
///     print('Print job started: ${printResult.data!.id}');
///   }
/// }
/// ```
library zebrautil;

// Data models
export 'zebra_device.dart';
// Legacy API (for backward compatibility)
export 'zebra_printer.dart';
export 'zebra_util.dart';
// Core singleton API
export 'zebra_utility.dart';
