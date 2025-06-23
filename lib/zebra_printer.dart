import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zebrautil/zebra_device.dart';

/// Media types supported by Zebra printers
enum EnumMediaType {
  /// Standard label printing
  label,

  /// Black mark detection mode
  blackMark,

  /// Continuous journal paper
  journal
}

/// Available printer configuration commands
enum Command {
  /// Calibrate printer sensors
  calibrate,

  /// Set media type and detection mode
  mediaType,

  /// Adjust print darkness/contrast
  darkness
}

/// Constants for method channel communication
class _ZebraPrinterConstants {
  static const String checkPermission = 'checkPermission';
  static const String startScan = 'startScan';
  static const String stopScan = 'stopScan';
  static const String connectToPrinter = 'connectToPrinter';
  static const String connectToGenericPrinter = 'connectToGenericPrinter';
  static const String print = 'print';
  static const String disconnect = 'disconnect';
  static const String isPrinterConnected = 'isPrinterConnected';
  static const String setSettings = 'setSettings';
  static const String getLocateValue = 'getLocateValue';

  // Method call responses
  static const String printerFound = 'printerFound';
  static const String printerRemoved = 'printerRemoved';
  static const String changePrinterStatus = 'changePrinterStatus';
  static const String onDiscoveryError = 'onDiscoveryError';
  static const String onDiscoveryDone = 'onDiscoveryDone';
  static const String onPrintComplete = 'onPrintComplete';
  static const String onPrintError = 'onPrintError';

  // Parameter keys
  static const String address = 'Address';
  static const String data = 'Data';
  static const String settingCommand = 'SettingCommand';
  static const String resourceKey = 'ResourceKey';
  static const String errorCode = 'ErrorCode';
  static const String errorText = 'ErrorText';
  static const String status = 'Status';
  static const String color = 'Color';
  static const String name = 'Name';
  static const String isWifi = 'IsWifi';

  // ZPL Commands
  static const String calibrateCommand = '~jc^xa^jus^xz';
  static const String labelGapMode = '''
          ! U1 setvar "media.type" "label"
           ! U1 setvar "media.sense_mode" "gap"
          ''';
  static const String blackMarkMode = '''
          ! U1 setvar "media.type" "label"
          ! U1 setvar "media.sense_mode" "bar"
          ''';
  static const String journalMode = '''
          ! U1 setvar "media.type" "journal"
          ''';

  // Validation constants
  static const List<int> validDarknessValues = [
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
  static const int maxAddressLength = 255;
  static const int maxDataLength = 65536; // 64KB limit for ZPL data

  // Timeouts
  static const Duration operationTimeout = Duration(seconds: 30);
  static const Duration connectionDelay = Duration(milliseconds: 500);

  // Connected status key
  static const String connectedKey = 'connected';
}

/// Exception thrown when printer operations fail
class ZebraPrinterException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const ZebraPrinterException(this.message, {this.code, this.originalError});

  @override
  String toString() =>
      'ZebraPrinterException: $message${code != null ? ' (Code: $code)' : ''}';
}

/// Exception thrown when validation fails
class ZebraValidationException extends ZebraPrinterException {
  const ZebraValidationException(String message) : super(message);
}

/// Callback type for discovery error handling
typedef OnDiscoveryError = void Function(String errorCode, String? errorText);

/// Callback type for permission denied handling
typedef OnPermissionDenied = void Function();

/// Callback type for print completion handling
typedef OnPrintComplete = void Function();

/// Callback type for print error handling
typedef OnPrintError = void Function(String errorMessage);

/// Main class for interacting with Zebra printers
///
/// This class provides functionality to:
/// - Discover Bluetooth and WiFi printers
/// - Connect to printers
/// - Configure printer settings (media type, darkness)
/// - Print ZPL data
/// - Manage printer state
class ZebraPrinter {
  late final MethodChannel _channel;

  OnDiscoveryError? _onDiscoveryError;
  OnPermissionDenied? _onPermissionDenied;
  OnPrintComplete? _onPrintComplete;
  OnPrintError? _onPrintError;

  bool _isRotated = false;
  bool _isScanning = false;
  bool _shouldSync = false;
  bool _isDisposed = false;

  late final ZebraController _controller;
  final Completer<void> _initCompleter = Completer<void>();

  /// Creates a new ZebraPrinter instance
  ///
  /// [id] - Unique identifier for this printer instance
  /// [onDiscoveryError] - Optional callback for discovery errors
  /// [onPermissionDenied] - Optional callback for permission denial
  /// [onPrintComplete] - Optional callback for print completion
  /// [onPrintError] - Optional callback for print errors
  /// [controller] - Optional custom controller, creates default if null
  ZebraPrinter(
    String id, {
    OnDiscoveryError? onDiscoveryError,
    OnPermissionDenied? onPermissionDenied,
    OnPrintComplete? onPrintComplete,
    OnPrintError? onPrintError,
    ZebraController? controller,
  }) {
    if (id.isEmpty) {
      throw const ZebraValidationException('Printer ID cannot be empty');
    }

    _onDiscoveryError = onDiscoveryError;
    _onPermissionDenied = onPermissionDenied;
    _onPrintComplete = onPrintComplete;
    _onPrintError = onPrintError;
    _controller = controller ?? ZebraController();

    _channel = MethodChannel('ZebraPrinterObject$id');
    _channel.setMethodCallHandler(_nativeMethodCallHandler);

    _initCompleter.complete();

    developer.log('ZebraPrinter initialized with ID: $id',
        name: 'ZebraPrinter');
  }

  /// Gets the controller managing printer state
  ZebraController get controller => _controller;

  /// Whether the printer is currently scanning for devices
  bool get isScanning => _isScanning;

  /// Whether ZPL output is rotated
  bool get isRotated => _isRotated;

  /// Whether this instance has been disposed
  bool get isDisposed => _isDisposed;

  /// Starts scanning for available printers
  ///
  /// Throws [ZebraPrinterException] if already disposed or scanning fails
  Future<void> startScanning() async {
    _ensureNotDisposed();

    if (_isScanning) {
      developer.log('Already scanning, ignoring startScanning call',
          name: 'ZebraPrinter');
      return;
    }

    try {
      await _initCompleter.future;

      _isScanning = true;
      _controller.cleanAll();

      developer.log('Starting printer scan with channel: ${_channel.name}',
          name: 'ZebraPrinter');

      final isGrantPermission = await _channel
          .invokeMethod<bool>(_ZebraPrinterConstants.checkPermission)
          .timeout(_ZebraPrinterConstants.operationTimeout);

      developer.log('Permission check result: $isGrantPermission',
          name: 'ZebraPrinter');

      if (isGrantPermission == true) {
        await _channel
            .invokeMethod(_ZebraPrinterConstants.startScan)
            .timeout(_ZebraPrinterConstants.operationTimeout);
        developer.log('StartScan method invoked successfully',
            name: 'ZebraPrinter');
      } else {
        _isScanning = false;
        _onPermissionDenied?.call();
        throw const ZebraPrinterException(
            'Permissions not granted for printer scanning');
      }
    } on TimeoutException {
      _isScanning = false;
      throw const ZebraPrinterException('Timeout while starting printer scan');
    } on PlatformException catch (e) {
      _isScanning = false;
      developer.log('Platform exception during scan: ${e.code} - ${e.message}',
          name: 'ZebraPrinter');
      _handlePlatformException(e);
    } catch (e) {
      _isScanning = false;
      developer.log('Error during scan: $e', name: 'ZebraPrinter');
      throw ZebraPrinterException('Failed to start scanning: $e',
          originalError: e);
    }
  }

  /// Stops scanning for printers
  ///
  /// Throws [ZebraPrinterException] if already disposed
  Future<void> stopScanning() async {
    _ensureNotDisposed();

    if (!_isScanning) {
      developer.log('Not currently scanning, ignoring stopScanning call',
          name: 'ZebraPrinter');
      return;
    }

    try {
      _isScanning = false;
      _shouldSync = true;

      await _channel
          .invokeMethod(_ZebraPrinterConstants.stopScan)
          .timeout(_ZebraPrinterConstants.operationTimeout);

      developer.log('Stopped printer scan', name: 'ZebraPrinter');
    } on TimeoutException {
      throw const ZebraPrinterException('Timeout while stopping printer scan');
    } on PlatformException catch (e) {
      _handlePlatformException(e);
    } catch (e) {
      throw ZebraPrinterException('Failed to stop scanning: $e',
          originalError: e);
    }
  }

  /// Sets printer configuration settings
  Future<void> _setSettings(Command setting, dynamic values) async {
    _ensureNotDisposed();

    String command = _buildSettingCommand(setting, values);

    if (command.isEmpty) {
      throw ZebraValidationException('Invalid setting command for $setting');
    }

    try {
      await _channel.invokeMethod(
        _ZebraPrinterConstants.setSettings,
        {_ZebraPrinterConstants.settingCommand: command},
      ).timeout(_ZebraPrinterConstants.operationTimeout);

      developer.log('Applied setting: $setting', name: 'ZebraPrinter');
    } on TimeoutException {
      throw const ZebraPrinterException(
          'Timeout while applying printer settings');
    } on PlatformException catch (e) {
      _handlePlatformException(e);
    } catch (e) {
      throw ZebraPrinterException('Failed to apply settings: $e',
          originalError: e);
    }
  }

  /// Builds the appropriate command string for printer settings
  String _buildSettingCommand(Command setting, dynamic values) {
    switch (setting) {
      case Command.mediaType:
        return _getMediaTypeCommand(values as EnumMediaType);
      case Command.calibrate:
        return _ZebraPrinterConstants.calibrateCommand;
      case Command.darkness:
        return '! U1 setvar "print.tone" "$values"';
    }
  }

  /// Gets the ZPL command for the specified media type
  String _getMediaTypeCommand(EnumMediaType mediaType) {
    switch (mediaType) {
      case EnumMediaType.blackMark:
        return _ZebraPrinterConstants.blackMarkMode;
      case EnumMediaType.journal:
        return _ZebraPrinterConstants.journalMode;
      case EnumMediaType.label:
        return _ZebraPrinterConstants.labelGapMode;
    }
  }

  /// Sets the discovery error callback
  void setOnDiscoveryError(OnDiscoveryError? onDiscoveryError) {
    _onDiscoveryError = onDiscoveryError;
  }

  /// Sets the permission denied callback
  void setOnPermissionDenied(OnPermissionDenied? onPermissionDenied) {
    _onPermissionDenied = onPermissionDenied;
  }

  /// Sets the print complete callback
  void setOnPrintComplete(OnPrintComplete? onPrintComplete) {
    _onPrintComplete = onPrintComplete;
  }

  /// Sets the print error callback
  void setOnPrintError(OnPrintError? onPrintError) {
    _onPrintError = onPrintError;
  }

  /// Sets the printer darkness level
  ///
  /// [darkness] must be one of the valid darkness values
  /// Throws [ZebraValidationException] if the value is invalid
  Future<void> setDarkness(int darkness) async {
    if (!_ZebraPrinterConstants.validDarknessValues.contains(darkness)) {
      throw ZebraValidationException(
        'Invalid darkness value: $darkness. Valid values are: ${_ZebraPrinterConstants.validDarknessValues}',
      );
    }

    await _setSettings(Command.darkness, darkness.toString());
  }

  /// Sets the media type for the printer
  Future<void> setMediaType(EnumMediaType mediaType) async {
    await _setSettings(Command.mediaType, mediaType);
  }

  /// Connects to a printer at the specified address
  ///
  /// [address] - IP address for WiFi printers or MAC address for Bluetooth
  /// Throws [ZebraValidationException] if address is invalid
  /// Throws [ZebraPrinterException] if connection fails
  Future<void> connectToPrinter(String address) async {
    _validateAddress(address);
    await _connectToPrinterInternal(
        address, _ZebraPrinterConstants.connectToPrinter);
  }

  /// Connects to a generic printer at the specified address
  ///
  /// [address] - IP address for WiFi printers or MAC address for Bluetooth
  /// Throws [ZebraValidationException] if address is invalid
  /// Throws [ZebraPrinterException] if connection fails
  Future<void> connectToGenericPrinter(String address) async {
    _validateAddress(address);
    await _connectToPrinterInternal(
        address, _ZebraPrinterConstants.connectToGenericPrinter);
  }

  /// Internal method to handle printer connections
  Future<void> _connectToPrinterInternal(String address, String method) async {
    _ensureNotDisposed();

    try {
      // Disconnect from current printer if connected
      if (_controller.selectedAddress != null) {
        await disconnect();
        await Future.delayed(_ZebraPrinterConstants.connectionDelay);
      }

      // If trying to connect to the same printer, disconnect and return
      if (_controller.selectedAddress == address) {
        await disconnect();
        _controller.selectedAddress = null;
        return;
      }

      _controller.selectedAddress = address;

      await _channel.invokeMethod(
        method,
        {_ZebraPrinterConstants.address: address},
      ).timeout(_ZebraPrinterConstants.operationTimeout);

      developer.log('Connected to printer at: $address', name: 'ZebraPrinter');
    } on TimeoutException {
      _controller.selectedAddress = null;
      throw const ZebraPrinterException('Timeout while connecting to printer');
    } on PlatformException catch (e) {
      _controller.selectedAddress = null;
      _handlePlatformException(e);
    } catch (e) {
      _controller.selectedAddress = null;
      throw ZebraPrinterException('Failed to connect to printer: $e',
          originalError: e);
    }
  }

  /// Prints ZPL data to the connected printer
  ///
  /// [data] - ZPL command string to print
  /// Throws [ZebraValidationException] if data is invalid
  /// Throws [ZebraPrinterException] if printing fails
  Future<void> print({required String data}) async {
    _validatePrintData(data);
    _ensureNotDisposed();

    try {
      String processedData = _processPrintData(data);

      await _channel.invokeMethod(
        _ZebraPrinterConstants.print,
        {_ZebraPrinterConstants.data: processedData},
      ).timeout(_ZebraPrinterConstants.operationTimeout);
    } on TimeoutException {
      throw const ZebraPrinterException('Timeout while sending print job');
    } on PlatformException catch (e) {
      _handlePlatformException(e);
    } catch (e) {
      throw ZebraPrinterException('Failed to print: $e', originalError: e);
    }
  }

  /// Processes print data by adding required commands and handling rotation
  String _processPrintData(String data) {
    String processedData = data;

    // Add ^PON command if not present
    if (!processedData.contains('^PON')) {
      processedData = processedData.replaceAll('^XA', '^XA^PON');
    }

    // Handle rotation
    if (_isRotated) {
      processedData = processedData.replaceAll('^PON', '^POI');
    }

    return processedData;
  }

  /// Disconnects from the currently connected printer
  ///
  /// Throws [ZebraPrinterException] if disconnection fails
  Future<void> disconnect() async {
    _ensureNotDisposed();

    try {
      await _channel
          .invokeMethod(_ZebraPrinterConstants.disconnect, null)
          .timeout(_ZebraPrinterConstants.operationTimeout);

      _controller.selectedAddress = null;
    } on TimeoutException {
      throw const ZebraPrinterException(
          'Timeout while disconnecting from printer');
    } on PlatformException catch (e) {
      _handlePlatformException(e);
    } catch (e) {
      throw ZebraPrinterException('Failed to disconnect: $e', originalError: e);
    }
  }

  /// Calibrates the printer sensors
  ///
  /// Throws [ZebraPrinterException] if calibration fails
  Future<void> calibratePrinter() async {
    await _setSettings(Command.calibrate, null);
  }

  /// Checks if the printer is currently connected
  ///
  /// Throws [ZebraPrinterException] if the check fails
  Future<void> isPrinterConnected() async {
    _ensureNotDisposed();

    try {
      await _channel
          .invokeMethod(_ZebraPrinterConstants.isPrinterConnected)
          .timeout(_ZebraPrinterConstants.operationTimeout);
    } on TimeoutException {
      throw const ZebraPrinterException(
          'Timeout while checking printer connection');
    } on PlatformException catch (e) {
      _handlePlatformException(e);
    } catch (e) {
      throw ZebraPrinterException('Failed to check printer connection: $e',
          originalError: e);
    }
  }

  /// Toggles the rotation state for ZPL output
  void rotate() {
    _isRotated = !_isRotated;
    developer.log('Rotation toggled: $_isRotated', name: 'ZebraPrinter');
  }

  /// Gets a localized value from the printer
  Future<String> _getLocateValue({required String key}) async {
    _ensureNotDisposed();

    if (key.isEmpty) {
      throw const ZebraValidationException('Resource key cannot be empty');
    }

    try {
      final String? value = await _channel.invokeMethod<String?>(
        _ZebraPrinterConstants.getLocateValue,
        {_ZebraPrinterConstants.resourceKey: key},
      ).timeout(_ZebraPrinterConstants.operationTimeout);

      return value ?? '';
    } on TimeoutException {
      throw const ZebraPrinterException('Timeout while getting locate value');
    } on PlatformException catch (e) {
      _handlePlatformException(e);
      return '';
    } catch (e) {
      throw ZebraPrinterException('Failed to get locate value: $e',
          originalError: e);
    }
  }

  /// Handles incoming method calls from the native platform
  Future<void> _nativeMethodCallHandler(MethodCall methodCall) async {
    if (_isDisposed) return;

    try {
      developer.log(
          'Received method call: ${methodCall.method} with args: ${methodCall.arguments}',
          name: 'ZebraPrinter');

      // Handle arguments more safely - they could be Map<String, dynamic> or Map<Object?, Object?>
      Map<String, dynamic>? args;
      if (methodCall.arguments != null) {
        if (methodCall.arguments is Map<String, dynamic>) {
          args = methodCall.arguments as Map<String, dynamic>;
        } else if (methodCall.arguments is Map) {
          // Convert Map<Object?, Object?> to Map<String, dynamic>
          final rawMap = methodCall.arguments as Map;
          args = <String, dynamic>{};
          rawMap.forEach((key, value) {
            if (key is String) {
              args![key] = value;
            }
          });
        }
      }

      switch (methodCall.method) {
        case _ZebraPrinterConstants.printerFound:
          await _handlePrinterFound(args);
          break;
        case _ZebraPrinterConstants.printerRemoved:
          await _handlePrinterRemoved(args);
          break;
        case _ZebraPrinterConstants.changePrinterStatus:
          await _handlePrinterStatusChange(args);
          break;
        case _ZebraPrinterConstants.onDiscoveryError:
          await _handleDiscoveryError(args);
          break;
        case _ZebraPrinterConstants.onDiscoveryDone:
          await _handleDiscoveryDone();
          break;
        case _ZebraPrinterConstants.onPrintComplete:
          await _handlePrintComplete();
          break;
        case _ZebraPrinterConstants.onPrintError:
          await _handlePrintError(args);
          break;
        default:
          developer.log('Unknown method call: ${methodCall.method}',
              name: 'ZebraPrinter');
      }
    } catch (e) {
      developer.log('Error handling method call ${methodCall.method}: $e',
          name: 'ZebraPrinter');
    }
  }

  /// Handles printer found events
  Future<void> _handlePrinterFound(Map<String, dynamic>? args) async {
    developer.log('_handlePrinterFound called with args: $args',
        name: 'ZebraPrinter');

    if (args == null) {
      developer.log('Args is null in _handlePrinterFound',
          name: 'ZebraPrinter');
      return;
    }

    try {
      final address = args[_ZebraPrinterConstants.address] as String? ?? '';
      final status = args[_ZebraPrinterConstants.status] as String? ?? '';
      final name = args[_ZebraPrinterConstants.name] as String? ?? '';

      // Handle IsWifi as either boolean or string
      final isWifiRaw = args[_ZebraPrinterConstants.isWifi];
      bool isWifi = false;
      if (isWifiRaw is bool) {
        isWifi = isWifiRaw;
      } else if (isWifiRaw is String) {
        isWifi = isWifiRaw.toLowerCase() == 'true';
      }

      developer.log(
          'Parsed printer data - Address: $address, Name: $name, Status: $status, IsWifi: $isWifi (raw: $isWifiRaw)',
          name: 'ZebraPrinter');

      final newPrinter = ZebraDevice(
        address: address,
        status: status,
        name: name,
        isWifi: isWifi,
      );

      _controller.addPrinter(newPrinter);
      developer.log('Printer added to controller: ${newPrinter.address}',
          name: 'ZebraPrinter');
    } catch (e) {
      developer.log('Error handling printer found: $e', name: 'ZebraPrinter');
    }
  }

  /// Handles printer removed events
  Future<void> _handlePrinterRemoved(Map<String, dynamic>? args) async {
    if (args == null) return;

    try {
      final String address =
          args[_ZebraPrinterConstants.address] as String? ?? '';
      if (address.isNotEmpty) {
        _controller.removePrinter(address);
        developer.log('Printer removed: $address', name: 'ZebraPrinter');
      }
    } catch (e) {
      developer.log('Error handling printer removed: $e', name: 'ZebraPrinter');
    }
  }

  /// Handles printer status change events
  Future<void> _handlePrinterStatusChange(Map<String, dynamic>? args) async {
    if (args == null) return;

    try {
      final String status =
          args[_ZebraPrinterConstants.status] as String? ?? '';
      final String colorCode =
          args[_ZebraPrinterConstants.color] as String? ?? '';

      if (status.isNotEmpty && colorCode.isNotEmpty) {
        _controller.updatePrinterStatus(status, colorCode);
        developer.log('Printer status changed: $status', name: 'ZebraPrinter');
      }
    } catch (e) {
      developer.log('Error handling printer status change: $e',
          name: 'ZebraPrinter');
    }
  }

  /// Handles discovery error events
  Future<void> _handleDiscoveryError(Map<String, dynamic>? args) async {
    if (args == null || _onDiscoveryError == null) return;

    try {
      final String errorCode =
          args[_ZebraPrinterConstants.errorCode] as String? ?? '';
      final String? errorText =
          args[_ZebraPrinterConstants.errorText] as String?;

      _onDiscoveryError!(errorCode, errorText);
      developer.log('Discovery error: $errorCode - $errorText',
          name: 'ZebraPrinter');
    } catch (e) {
      developer.log('Error handling discovery error: $e', name: 'ZebraPrinter');
    }
  }

  /// Handles discovery completion events
  Future<void> _handleDiscoveryDone() async {
    if (!_shouldSync) return;

    try {
      final connectedString =
          await _getLocateValue(key: _ZebraPrinterConstants.connectedKey);
      _controller.synchronizePrinter(connectedString);
      _shouldSync = false;
      developer.log('Discovery completed and synchronized',
          name: 'ZebraPrinter');
    } catch (e) {
      developer.log('Error handling discovery done: $e', name: 'ZebraPrinter');
    }
  }

  /// Handles print completion events
  Future<void> _handlePrintComplete() async {
    try {
      developer.log('Print completed successfully', name: 'ZebraPrinter');
      _onPrintComplete?.call();
    } catch (e) {
      developer.log('Error handling print complete: $e', name: 'ZebraPrinter');
    }
  }

  /// Handles print error events
  Future<void> _handlePrintError(Map<String, dynamic>? args) async {
    if (_onPrintError == null) return;

    try {
      final String errorMessage =
          args?[_ZebraPrinterConstants.errorText] as String? ??
              'Unknown print error';

      developer.log('Print error: $errorMessage', name: 'ZebraPrinter');
      _onPrintError!(errorMessage);
    } catch (e) {
      developer.log('Error handling print error: $e', name: 'ZebraPrinter');
    }
  }

  /// Validates a printer address
  void _validateAddress(String address) {
    if (address.isEmpty) {
      throw const ZebraValidationException('Printer address cannot be empty');
    }

    if (address.length > _ZebraPrinterConstants.maxAddressLength) {
      throw const ZebraValidationException('Printer address is too long');
    }

    // Basic format validation (you can extend this for more specific validation)
    if (address.trim() != address) {
      throw const ZebraValidationException(
          'Printer address cannot have leading or trailing whitespace');
    }
  }

  /// Validates print data
  void _validatePrintData(String data) {
    if (data.isEmpty) {
      throw const ZebraValidationException('Print data cannot be empty');
    }

    if (data.length > _ZebraPrinterConstants.maxDataLength) {
      throw const ZebraValidationException('Print data exceeds maximum length');
    }
  }

  /// Ensures the instance hasn't been disposed
  void _ensureNotDisposed() {
    if (_isDisposed) {
      throw const ZebraPrinterException(
          'ZebraPrinter instance has been disposed');
    }
  }

  /// Handles platform exceptions and converts them to ZebraPrinterException
  void _handlePlatformException(PlatformException e) {
    _onDiscoveryError?.call(e.code, e.message);
    throw ZebraPrinterException(
      e.message ?? 'Platform exception occurred',
      code: e.code,
      originalError: e,
    );
  }

  /// Test method to manually add a printer for debugging
  /// This should only be used for testing purposes
  void addTestPrinter() {
    developer.log('Adding test printer manually', name: 'ZebraPrinter');

    final testArgs = <String, dynamic>{
      _ZebraPrinterConstants.address: '00:07:4D:C9:52:88',
      _ZebraPrinterConstants.name: 'Test Zebra Printer',
      _ZebraPrinterConstants.status: 'Ready',
      _ZebraPrinterConstants.isWifi: 'false',
    };

    _handlePrinterFound(testArgs);
  }

  /// Disposes of resources used by this instance
  ///
  /// Should be called when the printer is no longer needed
  Future<void> dispose() async {
    if (_isDisposed) return;

    try {
      // Stop scanning if active
      if (_isScanning) {
        await stopScanning();
      }

      // Disconnect if connected
      if (_controller.selectedAddress != null) {
        await disconnect();
      }

      // Clean up method channel
      _channel.setMethodCallHandler(null);

      _isDisposed = true;
      developer.log('ZebraPrinter disposed', name: 'ZebraPrinter');
    } catch (e) {
      developer.log('Error during disposal: $e', name: 'ZebraPrinter');
      _isDisposed = true; // Mark as disposed even if cleanup failed
    }
  }
}

/// Controller for managing printer state and discovered devices
///
/// This class extends [ChangeNotifier] to provide reactive updates
/// when printer state changes occur.
class ZebraController extends ChangeNotifier {
  final List<ZebraDevice> _printers = <ZebraDevice>[];
  String? _selectedAddress;

  /// Gets an unmodifiable list of discovered printers
  List<ZebraDevice> get printers => List.unmodifiable(_printers);

  /// Gets the currently selected printer address
  String? get selectedAddress => _selectedAddress;

  /// Sets the selected printer address
  set selectedAddress(String? address) {
    if (_selectedAddress != address) {
      _selectedAddress = address;
      notifyListeners();
    }
  }

  /// Adds a new printer to the list if it doesn't already exist
  ///
  /// [printer] - The printer device to add
  void addPrinter(ZebraDevice printer) {
    if (!_printers.contains(printer)) {
      _printers.add(printer);
      notifyListeners();
      developer.log('Added printer: ${printer.address}',
          name: 'ZebraController');
    }
  }

  /// Removes a printer from the list by address
  ///
  /// [address] - The address of the printer to remove
  void removePrinter(String address) {
    if (address.isEmpty) return;

    final int initialLength = _printers.length;
    _printers.removeWhere((element) => element.address == address);

    if (_printers.length != initialLength) {
      // If the removed printer was selected, clear selection
      if (_selectedAddress == address) {
        _selectedAddress = null;
      }
      notifyListeners();
      developer.log('Removed printer: $address', name: 'ZebraController');
    }
  }

  /// Removes all disconnected printers from the list
  void cleanAll() {
    if (_printers.isEmpty) return;

    final int initialLength = _printers.length;
    _printers.removeWhere((element) => !element.isConnected);

    if (_printers.length != initialLength) {
      notifyListeners();
      developer.log(
          'Cleaned ${initialLength - _printers.length} disconnected printers',
          name: 'ZebraController');
    }
  }

  /// Updates the status of the currently selected printer
  ///
  /// [status] - New status text
  /// [colorCode] - Color code ('R' for red, 'G' for green, other for grey)
  void updatePrinterStatus(String status, String colorCode) {
    if (_selectedAddress == null || status.isEmpty) return;

    final Color newColor = _getStatusColor(colorCode);
    final int index =
        _printers.indexWhere((element) => element.address == _selectedAddress);

    if (index != -1) {
      final ZebraDevice currentPrinter = _printers[index];
      _printers[index] = currentPrinter.copyWith(
        status: status,
        color: newColor,
        isConnected: currentPrinter.address == _selectedAddress,
      );
      notifyListeners();
      developer.log('Updated printer status: $status', name: 'ZebraController');
    }
  }

  /// Synchronizes the connection status of the selected printer
  ///
  /// [connectedString] - Status string indicating connection state
  void synchronizePrinter(String connectedString) {
    if (_selectedAddress == null || connectedString.isEmpty) return;

    final int index =
        _printers.indexWhere((element) => element.address == _selectedAddress);

    if (index == -1) {
      _selectedAddress = null;
      notifyListeners();
      return;
    }

    final ZebraDevice currentPrinter = _printers[index];
    if (currentPrinter.isConnected) return;

    _printers[index] = currentPrinter.copyWith(
      status: connectedString,
      color: Colors.green,
      isConnected: true,
    );
    notifyListeners();
    developer.log('Synchronized printer: $_selectedAddress',
        name: 'ZebraController');
  }

  /// Converts color code to Color object
  Color _getStatusColor(String colorCode) {
    switch (colorCode.toUpperCase()) {
      case 'R':
        return Colors.red;
      case 'G':
        return Colors.green;
      default:
        return Colors.grey.withOpacity(0.6);
    }
  }

  /// Clears all printers and resets state
  void clear() {
    if (_printers.isNotEmpty || _selectedAddress != null) {
      _printers.clear();
      _selectedAddress = null;
      notifyListeners();
      developer.log('Cleared all printers', name: 'ZebraController');
    }
  }

  @override
  void dispose() {
    clear();
    super.dispose();
  }
}
