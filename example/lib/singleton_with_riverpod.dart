import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zebrautil/zebrautil.dart';

/// Comprehensive example demonstrating ZebraUtility singleton API with Riverpod
///
/// This example shows:
/// - Reactive state management with Riverpod
/// - Clean separation of concerns with providers
/// - Type-safe error handling
/// - Real-time UI updates
/// - Proper lifecycle management
class SingletonWithRiverpodApp extends StatelessWidget {
  const SingletonWithRiverpodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zebra Utility - Singleton API with Riverpod',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ProviderScope(
        child: ZebraUtilityRiverpodDemo(),
      ),
    );
  }
}

// ============================================================================
// STATE CLASSES
// ============================================================================

/// State for ZebraUtility initialization
@immutable
class ZebraUtilityState {
  final ZebraUtility? instance;
  final bool isInitialized;
  final bool isInitializing;
  final String? errorMessage;

  const ZebraUtilityState({
    this.instance,
    this.isInitialized = false,
    this.isInitializing = false,
    this.errorMessage,
  });

  ZebraUtilityState copyWith({
    ZebraUtility? instance,
    bool? isInitialized,
    bool? isInitializing,
    String? errorMessage,
  }) {
    return ZebraUtilityState(
      instance: instance ?? this.instance,
      isInitialized: isInitialized ?? this.isInitialized,
      isInitializing: isInitializing ?? this.isInitializing,
      errorMessage: errorMessage,
    );
  }
}

/// State for printer discovery
@immutable
class DiscoveryState {
  final DiscoverySession? currentSession;
  final List<ZebraDevice> discoveredDevices;
  final bool isScanning;
  final String? errorMessage;

  const DiscoveryState({
    this.currentSession,
    this.discoveredDevices = const [],
    this.isScanning = false,
    this.errorMessage,
  });

  DiscoveryState copyWith({
    DiscoverySession? currentSession,
    List<ZebraDevice>? discoveredDevices,
    bool? isScanning,
    String? errorMessage,
  }) {
    return DiscoveryState(
      currentSession: currentSession ?? this.currentSession,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      isScanning: isScanning ?? this.isScanning,
      errorMessage: errorMessage,
    );
  }
}

/// State for printer connection
@immutable
class ConnectionState {
  final ZebraDevice? connectedDevice;
  final bool isConnecting;
  final String? errorMessage;

  const ConnectionState({
    this.connectedDevice,
    this.isConnecting = false,
    this.errorMessage,
  });

  ConnectionState copyWith({
    ZebraDevice? connectedDevice,
    bool? isConnecting,
    String? errorMessage,
  }) {
    return ConnectionState(
      connectedDevice: connectedDevice ?? this.connectedDevice,
      isConnecting: isConnecting ?? this.isConnecting,
      errorMessage: errorMessage,
    );
  }
}

/// State for print operations
@immutable
class PrintState {
  final Map<String, PrintJob> printJobs;
  final bool isPrinting;
  final String? errorMessage;
  final String? lastCompletedJobId;

  const PrintState({
    this.printJobs = const {},
    this.isPrinting = false,
    this.errorMessage,
    this.lastCompletedJobId,
  });

  PrintState copyWith({
    Map<String, PrintJob>? printJobs,
    bool? isPrinting,
    String? errorMessage,
    String? lastCompletedJobId,
  }) {
    return PrintState(
      printJobs: printJobs ?? this.printJobs,
      isPrinting: isPrinting ?? this.isPrinting,
      errorMessage: errorMessage,
      lastCompletedJobId: lastCompletedJobId ?? this.lastCompletedJobId,
    );
  }
}

// ============================================================================
// PROVIDERS
// ============================================================================

/// Provider for ZebraUtility initialization
final zebraUtilityProvider =
    StateNotifierProvider<ZebraUtilityNotifier, ZebraUtilityState>(
  (ref) => ZebraUtilityNotifier(),
);

/// Provider for discovery operations
final discoveryProvider =
    StateNotifierProvider<DiscoveryNotifier, DiscoveryState>(
  (ref) => DiscoveryNotifier(ref),
);

/// Provider for connection operations
final connectionProvider =
    StateNotifierProvider<ConnectionNotifier, ConnectionState>(
  (ref) => ConnectionNotifier(ref),
);

/// Provider for print operations
final printProvider = StateNotifierProvider<PrintNotifier, PrintState>(
  (ref) => PrintNotifier(ref),
);

/// Computed provider for UI state
final uiStateProvider = Provider<Map<String, dynamic>>((ref) {
  final zebra = ref.watch(zebraUtilityProvider);
  final discovery = ref.watch(discoveryProvider);
  final connection = ref.watch(connectionProvider);
  final print = ref.watch(printProvider);

  return {
    'isReady': zebra.isInitialized && zebra.instance != null,
    'hasError': zebra.errorMessage != null ||
        discovery.errorMessage != null ||
        connection.errorMessage != null ||
        print.errorMessage != null,
    'isLoading': zebra.isInitializing ||
        discovery.isScanning ||
        connection.isConnecting ||
        print.isPrinting,
    'deviceCount': discovery.discoveredDevices.length,
    'jobCount': print.printJobs.length,
  };
});

// ============================================================================
// STATE NOTIFIERS
// ============================================================================

/// Notifier for ZebraUtility initialization
class ZebraUtilityNotifier extends StateNotifier<ZebraUtilityState> {
  ZebraUtilityNotifier() : super(const ZebraUtilityState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    if (state.isInitialized) return;

    state = state.copyWith(isInitializing: true, errorMessage: null);

    try {
      developer.log('Initializing ZebraUtility with Riverpod',
          name: 'ZebraRiverpod');

      final result = await ZebraUtility.initialize(
        config: const ZebraConfig(
          enableDebugLogging: true,
          operationTimeout: Duration(seconds: 30),
        ),
      );

      if (result.isSuccess) {
        state = state.copyWith(
          instance: result.data!,
          isInitialized: true,
          isInitializing: false,
        );
        developer.log('ZebraUtility initialized successfully',
            name: 'ZebraRiverpod');
      } else {
        state = state.copyWith(
          isInitializing: false,
          errorMessage: result.error?.message ?? 'Unknown initialization error',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isInitializing: false,
        errorMessage: 'Failed to initialize: $e',
      );
      developer.log('ZebraUtility initialization failed: $e',
          name: 'ZebraRiverpod');
    }
  }

  void retry() {
    state = const ZebraUtilityState();
    _initialize();
  }
}

/// Notifier for discovery operations
class DiscoveryNotifier extends StateNotifier<DiscoveryState> {
  final Ref _ref;
  StreamSubscription<DiscoverySession>? _discoverySubscription;
  StreamSubscription<ZebraDevice?>? _connectionSubscription;
  Timer? _discoveryTimeoutTimer;
  static const Duration _discoveryTimeout = Duration(seconds: 30);

  DiscoveryNotifier(this._ref) : super(const DiscoveryState()) {
    _setupSubscription();
    _setupConnectionListener();
  }

  void _setupSubscription() {
    // Listen to zebra instance changes
    _ref.listen(zebraUtilityProvider, (previous, next) {
      if (next.instance != null && previous?.instance != next.instance) {
        _discoverySubscription?.cancel();
        _discoverySubscription =
            next.instance!.discoveryStream.listen(_handleDiscoveryUpdate);
      }
    });
  }

  void _setupConnectionListener() {
    // Listen to connection changes to auto-stop discovery
    _ref.listen(zebraUtilityProvider, (previous, next) {
      if (next.instance != null && previous?.instance != next.instance) {
        _connectionSubscription?.cancel();
        _connectionSubscription =
            next.instance!.connectionStream.listen((device) {
          // If a device is connected, stop discovery
          if (device != null && state.isScanning) {
            developer.log('Auto-stopping discovery: printer connected',
                name: 'ZebraRiverpod');
            stopDiscovery();
          }
        });
      }
    });
  }

  void _handleDiscoveryUpdate(DiscoverySession session) {
    state = state.copyWith(
      currentSession: session,
      discoveredDevices: session.discoveredDevices,
      isScanning: session.status == DiscoveryStatus.scanning,
      errorMessage:
          session.status == DiscoveryStatus.error ? session.errorMessage : null,
    );
  }

  Future<void> startDiscovery() async {
    final zebra = _ref.read(zebraUtilityProvider);
    if (zebra.instance == null) return;

    // Cancel any existing timeout timer
    _discoveryTimeoutTimer?.cancel();

    final result = await zebra.instance!.startDiscovery();
    if (result.isSuccess) {
      // Start timeout timer
      _discoveryTimeoutTimer = Timer(_discoveryTimeout, () {
        if (state.isScanning && state.discoveredDevices.isEmpty) {
          developer.log(
              'Auto-stopping discovery: 30-second timeout with no devices found',
              name: 'ZebraRiverpod');
          stopDiscovery();
          state = state.copyWith(
            errorMessage:
                'No printers found within 30 seconds. Please ensure printers are powered on and in range.',
          );
        } else if (state.isScanning) {
          developer.log('Auto-stopping discovery: 30-second timeout reached',
              name: 'ZebraRiverpod');
          stopDiscovery();
        }
      });

      developer.log('Discovery started with 30-second timeout',
          name: 'ZebraRiverpod');
    } else {
      state = state.copyWith(errorMessage: result.error?.message);
    }
  }

  Future<void> stopDiscovery() async {
    final zebra = _ref.read(zebraUtilityProvider);
    if (zebra.instance == null) return;

    // Cancel timeout timer
    _discoveryTimeoutTimer?.cancel();
    _discoveryTimeoutTimer = null;

    final result = await zebra.instance!.stopDiscovery();
    if (!result.isSuccess) {
      state = state.copyWith(errorMessage: result.error?.message);
    } else {
      developer.log('Discovery stopped', name: 'ZebraRiverpod');
    }
  }

  void addTestDevice() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final testDevice = ZebraDevice(
      address:
          '00:07:4D:C9:${(52 + state.discoveredDevices.length).toString().padLeft(2, '0')}:88',
      name: 'Test Printer ${state.discoveredDevices.length + 1}',
      status: 'Ready (Test)',
      isWifi: false,
    );

    state = state.copyWith(
      discoveredDevices: [...state.discoveredDevices, testDevice],
    );
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  @override
  void dispose() {
    _discoverySubscription?.cancel();
    _connectionSubscription?.cancel();
    _discoveryTimeoutTimer?.cancel();
    super.dispose();
  }
}

/// Notifier for connection operations
class ConnectionNotifier extends StateNotifier<ConnectionState> {
  final Ref _ref;
  StreamSubscription<ZebraDevice?>? _connectionSubscription;

  ConnectionNotifier(this._ref) : super(const ConnectionState()) {
    _setupSubscription();
  }

  void _setupSubscription() {
    _ref.listen(zebraUtilityProvider, (previous, next) {
      if (next.instance != null && previous?.instance != next.instance) {
        _connectionSubscription?.cancel();
        _connectionSubscription =
            next.instance!.connectionStream.listen(_handleConnectionUpdate);
      }
    });
  }

  void _handleConnectionUpdate(ZebraDevice? device) {
    state = state.copyWith(
      connectedDevice: device,
      isConnecting: false,
      errorMessage: null,
    );
  }

  Future<void> connect(ZebraDevice device) async {
    final zebra = _ref.read(zebraUtilityProvider);
    if (zebra.instance == null) return;

    state = state.copyWith(isConnecting: true, errorMessage: null);

    final result = await zebra.instance!.connect(device);
    if (!result.isSuccess) {
      state = state.copyWith(
        isConnecting: false,
        errorMessage: result.error?.message,
      );
    }
    // Success is handled by the stream listener
  }

  Future<void> disconnect() async {
    final zebra = _ref.read(zebraUtilityProvider);
    if (zebra.instance == null) return;

    final result = await zebra.instance!.disconnect();
    if (!result.isSuccess) {
      state = state.copyWith(errorMessage: result.error?.message);
    }
    // Success is handled by the stream listener
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    super.dispose();
  }
}

/// Notifier for print operations
class PrintNotifier extends StateNotifier<PrintState> {
  final Ref _ref;
  StreamSubscription<PrintJob>? _printSubscription;

  PrintNotifier(this._ref) : super(const PrintState()) {
    _setupSubscription();
  }

  void _setupSubscription() {
    _ref.listen(zebraUtilityProvider, (previous, next) {
      if (next.instance != null && previous?.instance != next.instance) {
        _printSubscription?.cancel();
        _printSubscription =
            next.instance!.printStream.listen(_handlePrintUpdate);
      }
    });
  }

  void _handlePrintUpdate(PrintJob job) {
    final updatedJobs = Map<String, PrintJob>.from(state.printJobs);
    updatedJobs[job.id] = job;

    state = state.copyWith(
      printJobs: updatedJobs,
      isPrinting: job.status == PrintJobStatus.printing ||
          updatedJobs.values.any((j) => j.status == PrintJobStatus.printing),
      lastCompletedJobId: job.status == PrintJobStatus.completed
          ? job.id
          : state.lastCompletedJobId,
      errorMessage:
          job.status == PrintJobStatus.failed ? job.errorMessage : null,
    );
  }

  Future<void> printTestLabel() async {
    final zebra = _ref.read(zebraUtilityProvider);
    if (zebra.instance == null) return;

    const testZpl = '''
^XA
^CF0,60
^FO50,50^FDZebra Utility Riverpod^FS
^CF0,30
^FO50,120^FDSingleton API + Riverpod^FS
^FO50,160^FDDate: {{DATE}}^FS
^FO50,200^FDTime: {{TIME}}^FS
^FO50,250^GB400,2,2^FS
^FO50,270^FDReactive State Management^FS
^FO50,310^FDJob ID: {{JOB_ID}}^FS
^XZ
''';

    final now = DateTime.now();
    final jobId = 'riverpod_${now.millisecondsSinceEpoch}';
    final zplWithData = testZpl
        .replaceAll('{{DATE}}',
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}')
        .replaceAll('{{TIME}}',
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}')
        .replaceAll('{{JOB_ID}}', jobId);

    final result = await zebra.instance!.print(zplWithData, jobId: jobId);
    if (!result.isSuccess) {
      state = state.copyWith(errorMessage: result.error?.message);
    }
    // Success is handled by the stream listener
  }

  Future<void> configureSettings({
    EnumMediaType? mediaType,
    int? darkness,
    bool? calibrate,
  }) async {
    final zebra = _ref.read(zebraUtilityProvider);
    if (zebra.instance == null) return;

    final result = await zebra.instance!.configureSettings(
      mediaType: mediaType,
      darkness: darkness,
      calibrate: calibrate,
    );

    if (!result.isSuccess) {
      state = state.copyWith(errorMessage: result.error?.message);
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  @override
  void dispose() {
    _printSubscription?.cancel();
    super.dispose();
  }
}

// ============================================================================
// UI COMPONENTS
// ============================================================================

/// Main demo widget
class ZebraUtilityRiverpodDemo extends ConsumerWidget {
  const ZebraUtilityRiverpodDemo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zebraState = ref.watch(zebraUtilityProvider);
    final uiState = ref.watch(uiStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zebra Utility - Singleton API + Riverpod'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Toggle rotation
          Consumer(
            builder: (context, ref, child) {
              final zebra = ref.watch(zebraUtilityProvider);
              if (zebra.instance == null) return const SizedBox.shrink();

              return IconButton(
                icon: Icon(zebra.instance!.isRotated
                    ? Icons.screen_rotation
                    : Icons.screen_lock_rotation),
                onPressed: () {
                  zebra.instance!.toggleRotation();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Print rotation ${zebra.instance!.isRotated ? "enabled" : "disabled"}'),
                      backgroundColor: Colors.blue,
                    ),
                  );
                },
                tooltip: 'Toggle Rotation',
              );
            },
          ),
          // Disconnect button
          Consumer(
            builder: (context, ref, child) {
              final connection = ref.watch(connectionProvider);
              if (connection.connectedDevice == null)
                return const SizedBox.shrink();

              return IconButton(
                icon: const Icon(Icons.bluetooth_disabled),
                onPressed: () =>
                    ref.read(connectionProvider.notifier).disconnect(),
                tooltip: 'Disconnect',
              );
            },
          ),
        ],
      ),
      body: zebraState.isInitializing
          ? const InitializingView()
          : zebraState.errorMessage != null
              ? ErrorView(
                  error: zebraState.errorMessage!,
                  onRetry: () =>
                      ref.read(zebraUtilityProvider.notifier).retry(),
                )
              : const MainView(),
    );
  }
}

/// Initialization loading view
class InitializingView extends StatelessWidget {
  const InitializingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Initializing ZebraUtility with Riverpod...'),
        ],
      ),
    );
  }
}

/// Error view with retry functionality
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
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
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/// Main application view
class MainView extends StatelessWidget {
  const MainView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        StatusCard(),
        ControlButtons(),
        Expanded(
          child: Row(
            children: [
              Expanded(flex: 2, child: DevicesList()),
              Expanded(flex: 1, child: PrintJobsList()),
            ],
          ),
        ),
      ],
    );
  }
}

/// Status card showing current state
class StatusCard extends ConsumerWidget {
  const StatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zebraState = ref.watch(zebraUtilityProvider);
    final discoveryState = ref.watch(discoveryProvider);
    final connectionState = ref.watch(connectionProvider);
    final printState = ref.watch(printProvider);
    final uiState = ref.watch(uiStateProvider);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reactive State Dashboard',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildStatusChip(
                  'Initialized',
                  zebraState.isInitialized,
                  zebraState.isInitialized ? Colors.green : Colors.grey,
                ),
                _buildStatusChip(
                  'Scanning',
                  discoveryState.isScanning,
                  discoveryState.isScanning ? Colors.blue : Colors.grey,
                ),
                _buildStatusChip(
                  'Connected',
                  connectionState.connectedDevice != null,
                  connectionState.connectedDevice != null
                      ? Colors.green
                      : Colors.grey,
                ),
                _buildStatusChip(
                  'Printing',
                  printState.isPrinting,
                  printState.isPrinting ? Colors.orange : Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCounter('Devices', uiState['deviceCount']),
                _buildCounter('Jobs', uiState['jobCount']),
                _buildCounter('Errors', uiState['hasError'] ? 1 : 0),
              ],
            ),
            if (connectionState.connectedDevice != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      connectionState.connectedDevice!.isWifi
                          ? Icons.wifi
                          : Icons.bluetooth,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${connectionState.connectedDevice!.name} (${connectionState.connectedDevice!.address})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Discovery status and errors
            if (discoveryState.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_rounded,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        discoveryState.errorMessage!,
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () =>
                          ref.read(discoveryProvider.notifier).clearError(),
                      color: Colors.orange.shade700,
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ],
            // Auto-discovery info when scanning
            if (discoveryState.isScanning) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Scanning for printers... Auto-stop after 30s or when connected',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, bool isActive, Color color) {
    return Chip(
      label: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.white : Colors.black87,
          fontSize: 12,
        ),
      ),
      backgroundColor: isActive ? color : Colors.grey.shade200,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _buildCounter(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

/// Control buttons for actions
class ControlButtons extends ConsumerWidget {
  const ControlButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discoveryState = ref.watch(discoveryProvider);
    final connectionState = ref.watch(connectionProvider);
    final printState = ref.watch(printProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Discovery Controls
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: discoveryState.isScanning
                      ? () =>
                          ref.read(discoveryProvider.notifier).stopDiscovery()
                      : () =>
                          ref.read(discoveryProvider.notifier).startDiscovery(),
                  icon: Icon(
                      discoveryState.isScanning ? Icons.stop : Icons.search),
                  label: Text(discoveryState.isScanning
                      ? 'Stop Discovery'
                      : 'Start Discovery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        discoveryState.isScanning ? Colors.red : Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () =>
                    ref.read(discoveryProvider.notifier).addTestDevice(),
                icon: const Icon(Icons.bug_report),
                label: const Text('Add Test'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),

          // Print Controls (when connected)
          if (connectionState.connectedDevice != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: printState.isPrinting
                        ? null
                        : () =>
                            ref.read(printProvider.notifier).printTestLabel(),
                    icon: printState.isPrinting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.print),
                    label: Text(
                        printState.isPrinting ? 'Printing...' : 'Print Test'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _showSettingsDialog(context, ref),
                  icon: const Icon(Icons.settings),
                  label: const Text('Settings'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => SettingsDialog(ref: ref),
    );
  }
}

/// Discovered devices list
class DevicesList extends ConsumerWidget {
  const DevicesList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discoveryState = ref.watch(discoveryProvider);
    final connectionState = ref.watch(connectionProvider);

    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Discovered Devices (${discoveryState.discoveredDevices.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          Expanded(
            child: discoveryState.discoveredDevices.isEmpty
                ? const Center(
                    child: Text(
                        'No devices found. Start discovery to search for printers.'),
                  )
                : ListView.builder(
                    itemCount: discoveryState.discoveredDevices.length,
                    itemBuilder: (context, index) {
                      final device = discoveryState.discoveredDevices[index];
                      final isConnected =
                          connectionState.connectedDevice?.address ==
                              device.address;
                      final isConnecting =
                          connectionState.isConnecting && !isConnected;

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
                            Text(
                                '${device.address} • ${device.isWifi ? 'WiFi' : 'Bluetooth'}'),
                            Text(device.status,
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        trailing: isConnecting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : isConnected
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : IconButton(
                                    icon: const Icon(
                                        Icons.connect_without_contact),
                                    onPressed: () => ref
                                        .read(connectionProvider.notifier)
                                        .connect(device),
                                  ),
                        onTap: isConnected || isConnecting
                            ? null
                            : () => ref
                                .read(connectionProvider.notifier)
                                .connect(device),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Print jobs list
class PrintJobsList extends ConsumerWidget {
  const PrintJobsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final printState = ref.watch(printProvider);

    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Print Jobs (${printState.printJobs.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          Expanded(
            child: printState.printJobs.isEmpty
                ? const Center(
                    child: Text('No print jobs yet.'),
                  )
                : ListView.builder(
                    itemCount: printState.printJobs.length,
                    itemBuilder: (context, index) {
                      final jobs = printState.printJobs.values.toList();
                      jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                      final job = jobs[index];

                      return ListTile(
                        leading: Icon(
                          _getJobStatusIcon(job.status),
                          color: _getJobStatusColor(job.status),
                        ),
                        title: Text('Job ${job.id.split('_').last}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Status: ${job.status.name}',
                                style: const TextStyle(fontSize: 12)),
                            Text('Created: ${_formatTime(job.createdAt)}',
                                style: const TextStyle(fontSize: 12)),
                            if (job.completedAt != null)
                              Text(
                                  'Completed: ${_formatTime(job.completedAt!)}',
                                  style: const TextStyle(fontSize: 12)),
                            if (job.errorMessage != null)
                              Text('Error: ${job.errorMessage}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.red)),
                          ],
                        ),
                        isThreeLine: true,
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

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }
}

/// Settings dialog
class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key, required this.ref});

  final WidgetRef ref;

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
            leading: const Icon(Icons.tune),
            title: const Text('Calibrate'),
            subtitle: const Text('Calibrate printer sensors'),
            onTap: () async {
              Navigator.pop(context);
              await ref
                  .read(printProvider.notifier)
                  .configureSettings(calibrate: true);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Printer calibration completed'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
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
        content: Wrap(
          spacing: 8,
          children: darknessLevels
              .map((value) => ActionChip(
                    label: Text('$value'),
                    onPressed: () async {
                      await ref
                          .read(printProvider.notifier)
                          .configureSettings(darkness: value);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Darkness set to $value'),
                            backgroundColor: Colors.green,
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
                      await ref
                          .read(printProvider.notifier)
                          .configureSettings(mediaType: typeInfo.$1);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('Media type set to ${typeInfo.$1.name}'),
                            backgroundColor: Colors.green,
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

/// Entry point for the Riverpod singleton example
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SingletonWithRiverpodApp());
}
