import 'dart:async';
import 'dart:developer' as developer;

import 'package:zebrautil/zebra_device.dart';
import 'package:zebrautil/zebra_printer.dart';
import 'package:zebrautil/zebra_util.dart';

/// Configuration class for initializing ZebraUtility
class ZebraConfig {
  /// Optional custom controller for managing printer state
  final ZebraController? controller;

  /// Whether to enable debug logging
  final bool enableDebugLogging;

  /// Custom timeout for operations (defaults to 30 seconds)
  final Duration operationTimeout;

  /// Auto-connect to the last known printer on startup
  final bool autoConnectLastPrinter;

  /// Preferred connection type (Bluetooth or WiFi)
  final ConnectionType? preferredConnectionType;

  const ZebraConfig({
    this.controller,
    this.enableDebugLogging = false,
    this.operationTimeout = const Duration(seconds: 30),
    this.autoConnectLastPrinter = false,
    this.preferredConnectionType,
  });

  ZebraConfig copyWith({
    ZebraController? controller,
    bool? enableDebugLogging,
    Duration? operationTimeout,
    bool? autoConnectLastPrinter,
    ConnectionType? preferredConnectionType,
  }) {
    return ZebraConfig(
      controller: controller ?? this.controller,
      enableDebugLogging: enableDebugLogging ?? this.enableDebugLogging,
      operationTimeout: operationTimeout ?? this.operationTimeout,
      autoConnectLastPrinter:
          autoConnectLastPrinter ?? this.autoConnectLastPrinter,
      preferredConnectionType:
          preferredConnectionType ?? this.preferredConnectionType,
    );
  }
}

/// Connection type preferences
enum ConnectionType { bluetooth, wifi }

/// Print job status
enum PrintJobStatus { queued, printing, completed, failed, cancelled }

/// Discovery status
enum DiscoveryStatus { idle, scanning, completed, error }

/// Type-safe result wrapper for operations
class ZebraResult<T> {
  final T? data;
  final ZebraError? error;
  final bool isSuccess;

  const ZebraResult.success(this.data)
      : error = null,
        isSuccess = true;

  const ZebraResult.failure(this.error)
      : data = null,
        isSuccess = false;

  /// Returns data if successful, throws error if failed
  T get dataOrThrow {
    if (isSuccess && data != null) {
      return data!;
    }
    throw error ?? const ZebraError('Unknown error occurred');
  }

  /// Returns data if successful, returns defaultValue if failed
  T getDataOr(T defaultValue) {
    return isSuccess && data != null ? data! : defaultValue;
  }
}

/// Structured error class for better error handling
class ZebraError implements Exception {
  final String message;
  final String? code;
  final ErrorType type;
  final dynamic originalError;

  const ZebraError(
    this.message, {
    this.code,
    this.type = ErrorType.unknown,
    this.originalError,
  });

  @override
  String toString() =>
      'ZebraError($type): $message${code != null ? ' (Code: $code)' : ''}';
}

/// Error types for better categorization
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

/// Print job information
class PrintJob {
  final String id;
  final String data;
  final PrintJobStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? errorMessage;

  PrintJob({
    required this.id,
    required this.data,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.errorMessage,
  });

  PrintJob copyWith({
    PrintJobStatus? status,
    DateTime? completedAt,
    String? errorMessage,
  }) {
    return PrintJob(
      id: id,
      data: data,
      status: status ?? this.status,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Discovery session information
class DiscoverySession {
  final String id;
  final DiscoveryStatus status;
  final List<ZebraDevice> discoveredDevices;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? errorMessage;

  DiscoverySession({
    required this.id,
    required this.status,
    required this.discoveredDevices,
    required this.startedAt,
    this.completedAt,
    this.errorMessage,
  });

  DiscoverySession copyWith({
    DiscoveryStatus? status,
    List<ZebraDevice>? discoveredDevices,
    DateTime? completedAt,
    String? errorMessage,
  }) {
    return DiscoverySession(
      id: id,
      status: status ?? this.status,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Main singleton class for Zebra printer operations
///
/// Usage:
/// ```dart
/// // Initialize once in main()
/// await ZebraUtility.initialize(
///   config: ZebraConfig(enableDebugLogging: true)
/// );
///
/// // Use anywhere in the app
/// final zebra = ZebraUtility.instance;
/// await zebra.startDiscovery();
/// ```
class ZebraUtility {
  static ZebraUtility? _instance;
  static ZebraConfig? _config;
  static bool _isInitialized = false;

  late final ZebraPrinter _printer;
  late final ZebraController _controller;
  late final String _instanceId;

  final StreamController<DiscoverySession> _discoveryController =
      StreamController.broadcast();
  final StreamController<PrintJob> _printController =
      StreamController.broadcast();
  final StreamController<ZebraDevice?> _connectionController =
      StreamController.broadcast();

  DiscoverySession? _currentDiscoverySession;
  final Map<String, PrintJob> _printJobs = {};
  ZebraDevice? _connectedDevice;
  bool _isDisposed = false;

  /// Private constructor
  ZebraUtility._(this._instanceId, this._controller, this._printer) {
    _setupEventHandlers();
  }

  /// Initialize ZebraUtility singleton
  ///
  /// This must be called once before using [instance]
  /// Throws [ZebraError] if initialization fails
  static Future<ZebraResult<ZebraUtility>> initialize({
    ZebraConfig config = const ZebraConfig(),
  }) async {
    if (_isInitialized) {
      return ZebraResult.success(_instance!);
    }

    try {
      developer.log('Initializing ZebraUtility', name: 'ZebraUtility');

      // Create printer instance using existing API
      final printer = await ZebraUtil.getPrinterInstance(
        controller: config.controller,
      );

      final controller = config.controller ?? printer.controller;
      final instanceId = DateTime.now().millisecondsSinceEpoch.toString();

      _instance = ZebraUtility._(instanceId, controller, printer);
      _config = config;
      _isInitialized = true;

      if (config.enableDebugLogging) {
        developer.log(
            'ZebraUtility initialized successfully with ID: $instanceId',
            name: 'ZebraUtility');
      }

      return ZebraResult.success(_instance!);
    } catch (e) {
      developer.log('Failed to initialize ZebraUtility: $e',
          name: 'ZebraUtility');
      return ZebraResult.failure(
        ZebraError(
          'Failed to initialize ZebraUtility: ${e.toString()}',
          type: ErrorType.initialization,
          originalError: e,
        ),
      );
    }
  }

  /// Get the singleton instance
  ///
  /// Throws [ZebraError] if not initialized
  static ZebraUtility get instance {
    if (!_isInitialized || _instance == null) {
      throw const ZebraError(
        'ZebraUtility has not been initialized. Call ZebraUtility.initialize() first.',
        type: ErrorType.initialization,
      );
    }
    return _instance!;
  }

  /// Check if ZebraUtility is initialized
  static bool get isInitialized => _isInitialized;

  /// Get current configuration
  static ZebraConfig? get config => _config;

  /// Stream of discovery sessions
  Stream<DiscoverySession> get discoveryStream => _discoveryController.stream;

  /// Stream of print jobs
  Stream<PrintJob> get printStream => _printController.stream;

  /// Stream of connection changes
  Stream<ZebraDevice?> get connectionStream => _connectionController.stream;

  /// Get current discovery session
  DiscoverySession? get currentDiscoverySession => _currentDiscoverySession;

  /// Get all print jobs
  Map<String, PrintJob> get printJobs => Map.unmodifiable(_printJobs);

  /// Get currently connected device
  ZebraDevice? get connectedDevice => _connectedDevice;

  /// Get discovered devices
  List<ZebraDevice> get discoveredDevices => _controller.printers;

  /// Whether currently scanning for devices
  bool get isScanning => _printer.isScanning;

  /// Whether a device is connected
  bool get isConnected => _connectedDevice != null;

  /// Setup event handlers for the underlying printer
  void _setupEventHandlers() {
    _printer.setOnDiscoveryError((errorCode, errorText) {
      final session = _currentDiscoverySession;
      if (session != null) {
        final updatedSession = session.copyWith(
          status: DiscoveryStatus.error,
          completedAt: DateTime.now(),
          errorMessage: '$errorCode: ${errorText ?? 'Unknown error'}',
        );
        _currentDiscoverySession = updatedSession;
        _discoveryController.add(updatedSession);
      }
    });

    _printer.setOnPrintComplete(() {
      _handlePrintComplete();
    });

    _printer.setOnPrintError((errorMessage) {
      _handlePrintError(errorMessage);
    });

    // Listen to real-time controller changes for discovered devices
    _controller.addListener(_onControllerChanged);
  }

  /// Start discovering printers
  ///
  /// Returns a [ZebraResult] with the discovery session
  Future<ZebraResult<DiscoverySession>> startDiscovery() async {
    try {
      _ensureNotDisposed();

      if (_printer.isScanning) {
        return ZebraResult.failure(
          const ZebraError(
            'Discovery is already in progress',
            type: ErrorType.discovery,
          ),
        );
      }

      final sessionId = 'discovery_${DateTime.now().millisecondsSinceEpoch}';
      final session = DiscoverySession(
        id: sessionId,
        status: DiscoveryStatus.scanning,
        discoveredDevices: [],
        startedAt: DateTime.now(),
      );

      _currentDiscoverySession = session;
      _discoveryController.add(session);

      await _printer.startScanning();

      if (_config?.enableDebugLogging == true) {
        developer.log('Started discovery session: $sessionId',
            name: 'ZebraUtility');
      }

      return ZebraResult.success(session);
    } catch (e) {
      return ZebraResult.failure(
        ZebraError(
          'Failed to start discovery: ${e.toString()}',
          type: ErrorType.discovery,
          originalError: e,
        ),
      );
    }
  }

  /// Stop discovering printers
  Future<ZebraResult<DiscoverySession>> stopDiscovery() async {
    try {
      _ensureNotDisposed();

      if (!_printer.isScanning) {
        return ZebraResult.failure(
          const ZebraError(
            'No discovery session is currently active',
            type: ErrorType.discovery,
          ),
        );
      }

      await _printer.stopScanning();

      final session = _currentDiscoverySession;
      if (session != null) {
        final updatedSession = session.copyWith(
          status: DiscoveryStatus.completed,
          completedAt: DateTime.now(),
          discoveredDevices: _controller.printers,
        );
        _currentDiscoverySession = updatedSession;
        _discoveryController.add(updatedSession);

        if (_config?.enableDebugLogging == true) {
          developer.log('Stopped discovery session: ${session.id}',
              name: 'ZebraUtility');
        }

        return ZebraResult.success(updatedSession);
      }

      return ZebraResult.failure(
        const ZebraError(
          'No active discovery session found',
          type: ErrorType.discovery,
        ),
      );
    } catch (e) {
      return ZebraResult.failure(
        ZebraError(
          'Failed to stop discovery: ${e.toString()}',
          type: ErrorType.discovery,
          originalError: e,
        ),
      );
    }
  }

  /// Connect to a printer
  ///
  /// [device] - The device to connect to
  /// [useGenericConnection] - Whether to use generic printer connection
  Future<ZebraResult<ZebraDevice>> connect(
    ZebraDevice device, {
    bool useGenericConnection = false,
  }) async {
    try {
      _ensureNotDisposed();
      _validateDevice(device);

      if (_connectedDevice?.address == device.address) {
        return ZebraResult.success(device);
      }

      // Disconnect from current device if connected
      if (_connectedDevice != null) {
        await disconnect();
      }

      if (useGenericConnection) {
        await _printer.connectToGenericPrinter(device.address);
      } else {
        await _printer.connectToPrinter(device.address);
      }

      _connectedDevice = device;
      _connectionController.add(device);

      if (_config?.enableDebugLogging == true) {
        developer.log('Connected to printer: ${device.address}',
            name: 'ZebraUtility');
      }

      return ZebraResult.success(device);
    } catch (e) {
      return ZebraResult.failure(
        ZebraError(
          'Failed to connect to printer: ${e.toString()}',
          type: ErrorType.connection,
          originalError: e,
        ),
      );
    }
  }

  /// Disconnect from current printer
  Future<ZebraResult<void>> disconnect() async {
    try {
      _ensureNotDisposed();

      if (_connectedDevice == null) {
        return const ZebraResult.success(null);
      }

      await _printer.disconnect();

      final disconnectedDevice = _connectedDevice;
      _connectedDevice = null;
      _connectionController.add(null);

      if (_config?.enableDebugLogging == true) {
        developer.log(
            'Disconnected from printer: ${disconnectedDevice?.address}',
            name: 'ZebraUtility');
      }

      return const ZebraResult.success(null);
    } catch (e) {
      return ZebraResult.failure(
        ZebraError(
          'Failed to disconnect from printer: ${e.toString()}',
          type: ErrorType.connection,
          originalError: e,
        ),
      );
    }
  }

  /// Print ZPL data
  ///
  /// [data] - ZPL command string to print
  /// [jobId] - Optional custom job ID, auto-generated if not provided
  Future<ZebraResult<PrintJob>> print(
    String data, {
    String? jobId,
  }) async {
    try {
      _ensureNotDisposed();
      _validatePrintData(data);

      if (_connectedDevice == null) {
        return ZebraResult.failure(
          const ZebraError(
            'No printer connected. Connect to a printer first.',
            type: ErrorType.connection,
          ),
        );
      }

      final id = jobId ?? 'print_${DateTime.now().millisecondsSinceEpoch}';
      final job = PrintJob(
        id: id,
        data: data,
        status: PrintJobStatus.printing,
        createdAt: DateTime.now(),
      );

      _printJobs[id] = job;
      _printController.add(job);

      await _printer.print(data: data);

      if (_config?.enableDebugLogging == true) {
        developer.log('Started print job: $id', name: 'ZebraUtility');
      }

      return ZebraResult.success(job);
    } catch (e) {
      return ZebraResult.failure(
        ZebraError(
          'Failed to print: ${e.toString()}',
          type: ErrorType.printing,
          originalError: e,
        ),
      );
    }
  }

  /// Configure printer settings
  Future<ZebraResult<void>> configureSettings({
    EnumMediaType? mediaType,
    int? darkness,
    bool? calibrate,
  }) async {
    try {
      _ensureNotDisposed();

      if (_connectedDevice == null) {
        return ZebraResult.failure(
          const ZebraError(
            'No printer connected. Connect to a printer first.',
            type: ErrorType.connection,
          ),
        );
      }

      if (mediaType != null) {
        await _printer.setMediaType(mediaType);
      }

      if (darkness != null) {
        await _printer.setDarkness(darkness);
      }

      if (calibrate == true) {
        await _printer.calibratePrinter();
      }

      if (_config?.enableDebugLogging == true) {
        developer.log('Applied printer settings', name: 'ZebraUtility');
      }

      return const ZebraResult.success(null);
    } catch (e) {
      return ZebraResult.failure(
        ZebraError(
          'Failed to configure settings: ${e.toString()}',
          type: ErrorType.validation,
          originalError: e,
        ),
      );
    }
  }

  /// Check if printer is connected
  Future<ZebraResult<bool>> checkConnection() async {
    try {
      _ensureNotDisposed();

      final isConnected = await _printer.isPrinterConnected();

      // Update internal state if connection status changed
      if (!isConnected && _connectedDevice != null) {
        _connectedDevice = null;
        _connectionController.add(null);
      }

      return ZebraResult.success(isConnected);
    } catch (e) {
      return ZebraResult.failure(
        ZebraError(
          'Failed to check connection: ${e.toString()}',
          type: ErrorType.connection,
          originalError: e,
        ),
      );
    }
  }

  /// Toggle print rotation
  void toggleRotation() {
    _ensureNotDisposed();
    _printer.rotate();

    if (_config?.enableDebugLogging == true) {
      developer.log('Toggled print rotation: ${_printer.isRotated}',
          name: 'ZebraUtility');
    }
  }

  /// Get current rotation state
  bool get isRotated => _printer.isRotated;

  /// Handle print completion
  void _handlePrintComplete() {
    // Find the most recent printing job and mark as completed
    final printingJobs = _printJobs.values
        .where((job) => job.status == PrintJobStatus.printing)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (printingJobs.isNotEmpty) {
      final job = printingJobs.first;
      final completedJob = job.copyWith(
        status: PrintJobStatus.completed,
        completedAt: DateTime.now(),
      );
      _printJobs[job.id] = completedJob;
      _printController.add(completedJob);

      if (_config?.enableDebugLogging == true) {
        developer.log('Print job completed: ${job.id}', name: 'ZebraUtility');
      }
    }
  }

  /// Handle print error
  void _handlePrintError(String errorMessage) {
    // Find the most recent printing job and mark as failed
    final printingJobs = _printJobs.values
        .where((job) => job.status == PrintJobStatus.printing)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (printingJobs.isNotEmpty) {
      final job = printingJobs.first;
      final failedJob = job.copyWith(
        status: PrintJobStatus.failed,
        completedAt: DateTime.now(),
        errorMessage: errorMessage,
      );
      _printJobs[job.id] = failedJob;
      _printController.add(failedJob);

      if (_config?.enableDebugLogging == true) {
        developer.log('Print job failed: ${job.id} - $errorMessage',
            name: 'ZebraUtility');
      }
    }
  }

  /// Handle real-time controller changes (when devices are discovered)
  void _onControllerChanged() {
    // Update the current discovery session with new devices
    final session = _currentDiscoverySession;

    if (_config?.enableDebugLogging == true) {
      developer.log(
          'Controller changed: ${_controller.printers.length} devices, session status: ${session?.status}',
          name: 'ZebraUtility');
    }

    if (session != null && session.status == DiscoveryStatus.scanning) {
      final updatedSession = session.copyWith(
        discoveredDevices: _controller.printers,
      );
      _currentDiscoverySession = updatedSession;
      _discoveryController.add(updatedSession);

      if (_config?.enableDebugLogging == true) {
        developer.log(
            'Discovery session updated: ${_controller.printers.length} devices found',
            name: 'ZebraUtility');
      }
    }
  }

  /// Validate device data
  void _validateDevice(ZebraDevice device) {
    if (device.address.isEmpty) {
      throw const ZebraError(
        'Device address cannot be empty',
        type: ErrorType.validation,
      );
    }
  }

  /// Validate print data
  void _validatePrintData(String data) {
    if (data.isEmpty) {
      throw const ZebraError(
        'Print data cannot be empty',
        type: ErrorType.validation,
      );
    }
  }

  /// Ensure instance is not disposed
  void _ensureNotDisposed() {
    if (_isDisposed) {
      throw const ZebraError(
        'ZebraUtility instance has been disposed',
        type: ErrorType.initialization,
      );
    }
  }

  /// Dispose of resources
  Future<void> dispose() async {
    if (_isDisposed) return;

    try {
      // Stop scanning if active
      if (_printer.isScanning) {
        await stopDiscovery();
      }

      // Disconnect if connected
      if (_connectedDevice != null) {
        await disconnect();
      }

      // Remove controller listener
      _controller.removeListener(_onControllerChanged);

      // Close streams
      await _discoveryController.close();
      await _printController.close();
      await _connectionController.close();

      // Dispose printer
      await _printer.dispose();

      _isDisposed = true;
      _isInitialized = false;
      _instance = null;
      _config = null;

      developer.log('ZebraUtility disposed', name: 'ZebraUtility');
    } catch (e) {
      developer.log('Error during disposal: $e', name: 'ZebraUtility');
      _isDisposed = true; // Mark as disposed even if cleanup failed
    }
  }
}
