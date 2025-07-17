import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zebrautil/zebra_device.dart';
import 'package:zebrautil/zebra_printer.dart';
import 'package:zebrautil/zebra_util.dart';

// Constants
class AppConstants {
  static const String appTitle = 'Zebra Printer Demo';
  static const String appBarTitle = 'Zebra Printer Utility';
  static const String initializingMessage = 'Initializing Zebra Printer...';
  static const String retryText = 'Retry';
  static const String disconnectTooltip = 'Disconnect';

  // Status messages
  static const String searchingForPrinters = 'Searching for printers...';
  static const String scanningForPrinters = 'Scanning for printers...';
  static const String scanStopped = 'Scan stopped';
  static const String testPrinterAdded = 'Test printer added';
  static const String printingTestLabel = 'Printing test label...';
  static const String printCommandSent = 'Print command sent to printer...';
  static const String calibratingPrinter = 'Calibrating printer...';
  static const String calibrationCompleted = 'Printer calibration completed';
  static const String disconnectedFromPrinter = 'Disconnected from printer';
  static const String readyForNextPrint = 'Ready for next print job';

  // Error messages
  static const String discoveryErrorPrefix = 'Discovery Error: ';
  static const String permissionDeniedError =
      'Permission denied. Please grant Bluetooth and location permissions in your device settings.';
  static const String printErrorPrefix = 'Print Error: ';
  static const String printTimeoutError =
      'Print timeout - no response from printer within 30 seconds';
  static const String failedToStartScanning = 'Failed to start scanning: ';
  static const String failedToStopScanning = 'Failed to stop scanning: ';
  static const String failedToConnect = 'Failed to connect to ';
  static const String failedToDisconnect = 'Failed to disconnect: ';
  static const String failedToPrint = 'Failed to send print command: ';
  static const String failedToCalibrate = 'Failed to calibrate printer: ';
  static const String failedToSetDarkness = 'Failed to set darkness: ';
  static const String failedToSetMediaType = 'Failed to set media type: ';

  // UI Constants
  static const double defaultIconSize = 64.0;
  static const double defaultSpacing = 16.0;
  static const double smallSpacing = 8.0;
  static const double borderRadius = 12.0;
  static const double smallBorderRadius = 8.0;
  static const double tinyBorderRadius = 6.0;
  static const double strokeWidth = 2.0;
  static const int printTimeoutSeconds = 30;
  static const double progressIndicatorSize = 16.0;
  static const double progressIndicatorSizeSmall = 20.0;
  static const EdgeInsets defaultPadding = EdgeInsets.all(16.0);
  static const EdgeInsets smallPadding = EdgeInsets.all(8.0);
  static const EdgeInsets tinyPadding = EdgeInsets.all(4.0);
  static const EdgeInsets horizontalPadding =
      EdgeInsets.symmetric(horizontal: 16.0);
  static const EdgeInsets verticalPadding = EdgeInsets.symmetric(vertical: 4.0);

  // Button text
  static const String stopScan = 'Stop Scan';
  static const String startScan = 'Start Scan';
  static const String test = 'Test';
  static const String printing = 'Printing...';
  static const String printTest = 'Print Test';
  static const String calibrate = 'Calibrate';
  static const String settings = 'Settings';
  static const String close = 'Close';
  static const String cancel = 'Cancel';
  static const String ok = 'OK';
  static const String printAnother = 'Print Another';

  // Dialog titles
  static const String printerSettings = 'Printer Settings';
  static const String setPrintDarkness = 'Set Print Darkness';
  static const String setMediaType = 'Set Media Type';
  static const String printSuccessful = 'Print Successful!';

  // List constants
  static const List<int> darknessLevels = [
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
}

// Test label ZPL template
class ZPLTemplates {
  static const String testLabel = '''
^XA
^CF0,60
^FO50,50^FDZebra Test Label^FS
^CF0,30
^FO50,120^FDDate: {{DATE}}^FS
^FO50,160^FDTime: {{TIME}}^FS
^FO50,200^FDStatus: Print Test Successful^FS
^FO50,240^FDPrinter: Ready^FS
^FO50,300^GB400,2,2^FS
^FO50,320^FDThank you for using Zebra Printer Utility!^FS
^XZ
''';
}

// Utility class for date/time formatting
class DateTimeUtils {
  static String getCurrentDate() => DateTime.now().toString().split(' ')[0];
  static String getCurrentTime() =>
      DateTime.now().toString().split(' ')[1].split('.')[0];

  static String processZPLTemplate(String template) {
    return template
        .replaceAll('{{DATE}}', getCurrentDate())
        .replaceAll('{{TIME}}', getCurrentTime());
  }
}

// Media type descriptions
class MediaTypeDescriptions {
  static String getDescription(EnumMediaType type) {
    switch (type) {
      case EnumMediaType.label:
        return 'Standard label with gap detection';
      case EnumMediaType.blackMark:
        return 'Labels with black mark detection';
      case EnumMediaType.journal:
        return 'Continuous journal paper';
    }
  }
}

// Riverpod Providers
final printerProvider = FutureProvider<ZebraPrinter>((ref) async {
  return await ZebraUtil.getPrinterInstance();
});

final errorMessageProvider = StateProvider<String?>((ref) => null);
final statusMessageProvider = StateProvider<String?>((ref) => null);
final selectedPrinterProvider = StateProvider<ZebraDevice?>((ref) => null);
final isConnectingProvider = StateProvider<bool>((ref) => false);
final isPrintingProvider = StateProvider<bool>((ref) => false);

// Services
class PrinterService {
  PrinterService(this.ref);

  final Ref ref;
  Timer? _printTimeoutTimer;

  void _logError(String message) {
    developer.log(message, name: 'PrinterService', level: 1000);
  }

  void _logInfo(String message) {
    developer.log(message, name: 'PrinterService', level: 800);
  }

  Future<void> startScanning(ZebraPrinter printer) async {
    try {
      _logInfo('Starting printer scan');
      ref.read(errorMessageProvider.notifier).state = null;
      ref.read(statusMessageProvider.notifier).state =
          AppConstants.searchingForPrinters;
      ref.read(selectedPrinterProvider.notifier).state = null;

      await printer.startScanning();
      ref.read(statusMessageProvider.notifier).state =
          printer.isScanning ? AppConstants.scanningForPrinters : null;
    } catch (e) {
      _logError('Failed to start scanning: $e');
      ref.read(errorMessageProvider.notifier).state =
          '${AppConstants.failedToStartScanning}$e';
      ref.read(statusMessageProvider.notifier).state = null;
    }
  }

  Future<void> stopScanning(ZebraPrinter printer) async {
    try {
      _logInfo('Stopping printer scan');
      await printer.stopScanning();
      ref.read(statusMessageProvider.notifier).state = AppConstants.scanStopped;
    } catch (e) {
      _logError('Failed to stop scanning: $e');
      ref.read(errorMessageProvider.notifier).state =
          '${AppConstants.failedToStopScanning}$e';
    }
  }

  Future<void> connectToPrinter(
      ZebraPrinter printer, ZebraDevice device) async {
    if (ref.read(isConnectingProvider)) return;

    _logInfo('Connecting to printer: ${device.name} (${device.address})');
    ref.read(isConnectingProvider.notifier).state = true;
    ref.read(errorMessageProvider.notifier).state = null;
    ref.read(statusMessageProvider.notifier).state =
        'Connecting to ${device.name}...';

    try {
      await printer.connectToPrinter(device.address);
      ref.read(selectedPrinterProvider.notifier).state = device;
      ref.read(statusMessageProvider.notifier).state =
          'Connected to ${device.name}';
      ref.read(isConnectingProvider.notifier).state = false;

      if (printer.isScanning) {
        await stopScanning(printer);
      }
    } catch (e) {
      _logError('Failed to connect to ${device.name}: $e');
      ref.read(errorMessageProvider.notifier).state =
          '${AppConstants.failedToConnect}${device.name}: $e';
      ref.read(statusMessageProvider.notifier).state = null;
      ref.read(isConnectingProvider.notifier).state = false;
    }
  }

  Future<void> disconnect(ZebraPrinter printer) async {
    try {
      _logInfo('Disconnecting from printer');
      await printer.disconnect();
      ref.read(selectedPrinterProvider.notifier).state = null;
      ref.read(statusMessageProvider.notifier).state =
          AppConstants.disconnectedFromPrinter;
    } catch (e) {
      _logError('Failed to disconnect: $e');
      ref.read(errorMessageProvider.notifier).state =
          '${AppConstants.failedToDisconnect}$e';
    }
  }

  Future<void> printTestLabel(ZebraPrinter printer) async {
    if (ref.read(isPrintingProvider) ||
        ref.read(selectedPrinterProvider) == null) return;

    _logInfo('Printing test label');
    ref.read(isPrintingProvider.notifier).state = true;
    ref.read(errorMessageProvider.notifier).state = null;
    ref.read(statusMessageProvider.notifier).state =
        AppConstants.printingTestLabel;

    try {
      final processedZpl =
          DateTimeUtils.processZPLTemplate(ZPLTemplates.testLabel);
      await printer.print(data: processedZpl);
      ref.read(statusMessageProvider.notifier).state =
          AppConstants.printCommandSent;
      _startPrintTimeoutTimer();
    } catch (e) {
      _logError('Failed to print test label: $e');
      ref.read(errorMessageProvider.notifier).state =
          '${AppConstants.failedToPrint}$e';
      ref.read(statusMessageProvider.notifier).state = null;
      ref.read(isPrintingProvider.notifier).state = false;
    }
  }

  Future<void> calibratePrinter(ZebraPrinter printer) async {
    if (ref.read(selectedPrinterProvider) == null) return;

    _logInfo('Calibrating printer');
    ref.read(statusMessageProvider.notifier).state =
        AppConstants.calibratingPrinter;
    ref.read(errorMessageProvider.notifier).state = null;

    try {
      await printer.calibratePrinter();
      ref.read(statusMessageProvider.notifier).state =
          AppConstants.calibrationCompleted;
    } catch (e) {
      _logError('Failed to calibrate printer: $e');
      ref.read(errorMessageProvider.notifier).state =
          '${AppConstants.failedToCalibrate}$e';
      ref.read(statusMessageProvider.notifier).state = null;
    }
  }

  void addTestPrinter(ZebraPrinter printer) {
    _logInfo('Adding test printer');
    printer.addTestPrinter();
    ref.read(statusMessageProvider.notifier).state =
        AppConstants.testPrinterAdded;
  }

  void onPrintComplete() {
    _logInfo('Print completed successfully');
    _printTimeoutTimer?.cancel();
    _printTimeoutTimer = null;
    ref.read(statusMessageProvider.notifier).state = null;
    ref.read(isPrintingProvider.notifier).state = false;
  }

  void onPrintError(String errorMessage) {
    _logError('Print error: $errorMessage');
    ref.read(errorMessageProvider.notifier).state =
        '${AppConstants.printErrorPrefix}$errorMessage';
    ref.read(statusMessageProvider.notifier).state = null;
    ref.read(isPrintingProvider.notifier).state = false;
  }

  void onDiscoveryError(String errorCode, String errorText) {
    _logError('Discovery error: $errorCode - $errorText');
    ref.read(errorMessageProvider.notifier).state =
        '${AppConstants.discoveryErrorPrefix}$errorText';
    ref.read(statusMessageProvider.notifier).state = null;
  }

  void onPermissionDenied() {
    _logError('Permission denied');
    ref.read(errorMessageProvider.notifier).state =
        AppConstants.permissionDeniedError;
    ref.read(statusMessageProvider.notifier).state = null;
  }

  void _startPrintTimeoutTimer() {
    _printTimeoutTimer?.cancel();
    _printTimeoutTimer =
        Timer(const Duration(seconds: AppConstants.printTimeoutSeconds), () {
      if (ref.read(isPrintingProvider)) {
        _logError('Print timeout occurred');
        ref.read(statusMessageProvider.notifier).state = null;
        ref.read(isPrintingProvider.notifier).state = false;
        ref.read(errorMessageProvider.notifier).state =
            AppConstants.printTimeoutError;
      }
    });
  }

  void dispose() {
    _printTimeoutTimer?.cancel();
  }
}

final printerServiceProvider =
    Provider<PrinterService>((ref) => PrinterService(ref));



class OldPatternApp extends StatelessWidget {
  const OldPatternApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ZebraPrinterInitializer(),
    );
  }
}

class ZebraPrinterInitializer extends ConsumerWidget {
  const ZebraPrinterInitializer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final printerAsync = ref.watch(printerProvider);

    return printerAsync.when(
      data: (printer) => ZebraPrinterApp(printer: printer),
      loading: () => const LoadingScaffold(),
      error: (error, stack) => ErrorScaffold(error: error.toString()),
    );
  }
}

class LoadingScaffold extends StatelessWidget {
  const LoadingScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppConstants.defaultSpacing),
            Text(AppConstants.initializingMessage),
          ],
        ),
      ),
    );
  }
}

class ErrorScaffold extends ConsumerWidget {
  const ErrorScaffold({super.key, required this.error});

  final String error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error,
                size: AppConstants.defaultIconSize, color: Colors.red),
            const SizedBox(height: AppConstants.defaultSpacing),
            Text('Error: $error'),
            const SizedBox(height: AppConstants.defaultSpacing),
            ElevatedButton(
              onPressed: () => ref.invalidate(printerProvider),
              child: const Text(AppConstants.retryText),
            ),
          ],
        ),
      ),
    );
  }
}

class ZebraPrinterApp extends ConsumerStatefulWidget {
  const ZebraPrinterApp({super.key, required this.printer});

  final ZebraPrinter printer;

  @override
  ConsumerState<ZebraPrinterApp> createState() => _ZebraPrinterAppState();
}

class _ZebraPrinterAppState extends ConsumerState<ZebraPrinterApp>
    with WidgetsBindingObserver {
  late final ZebraPrinter _printer;
  late final ZebraController _controller;
  late final PrinterService _printerService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _printer = widget.printer;
    _controller = _printer.controller;
    _printerService = ref.read(printerServiceProvider);
    _setupPrinterCallbacks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _printerService.dispose();
    _printer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _printerService.dispose();
    }
  }

  void _setupPrinterCallbacks() {
    _printer.setOnDiscoveryError((errorCode, errorText) {
      _printerService.onDiscoveryError(errorCode, errorText ?? '');
    });

    _printer.setOnPermissionDenied(() {
      _printerService.onPermissionDenied();
    });

    _printer.setOnPrintComplete(() {
      _printerService.onPrintComplete();
      _showPrintSuccessDialog();
    });

    _printer.setOnPrintError((errorMessage) {
      _printerService.onPrintError(errorMessage);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appBarTitle),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Consumer(
            builder: (context, ref, child) {
              final selectedPrinter = ref.watch(selectedPrinterProvider);
              if (selectedPrinter == null) return const SizedBox.shrink();
              return IconButton(
                onPressed: () => _printerService.disconnect(_printer),
                icon: const Icon(Icons.bluetooth_disabled),
                tooltip: AppConstants.disconnectTooltip,
              );
            },
          ),
        ],
      ),
      body: const Column(
        children: [
          StatusSection(),
          ControlSection(),
          Expanded(child: PrintersSection()),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _SettingsDialog(printer: _printer),
    );
  }

  void _showPrintSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _PrintSuccessDialog(),
    );
  }
}

class StatusSection extends ConsumerWidget {
  const StatusSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedPrinter = ref.watch(selectedPrinterProvider);
    final statusMessage = ref.watch(statusMessageProvider);
    final errorMessage = ref.watch(errorMessageProvider);

    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        margin: AppConstants.defaultPadding,
        padding: AppConstants.defaultPadding,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  selectedPrinter != null
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_searching,
                  color: selectedPrinter != null ? Colors.green : Colors.blue,
                ),
                const SizedBox(width: AppConstants.smallSpacing),
                Text(
                  'Status',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.smallSpacing),
            if (selectedPrinter != null) ...[
              Text('Connected: ${selectedPrinter.name}'),
              Text('Address: ${selectedPrinter.address}'),
              Text('Type: ${selectedPrinter.isWifi ? "WiFi" : "Bluetooth"}'),
            ] else
              const Text('No printer connected'),
            if (statusMessage != null) ...[
              const SizedBox(height: AppConstants.smallSpacing),
              Row(
                children: [
                  const SizedBox(
                    width: AppConstants.progressIndicatorSize,
                    height: AppConstants.progressIndicatorSize,
                    child: CircularProgressIndicator(
                        strokeWidth: AppConstants.strokeWidth),
                  ),
                  const SizedBox(width: AppConstants.smallSpacing),
                  Expanded(
                    child: Text(
                      statusMessage,
                      style: const TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ],
            if (errorMessage != null) ...[
              const SizedBox(height: AppConstants.smallSpacing),
              Container(
                padding: AppConstants.smallPadding,
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius:
                      BorderRadius.circular(AppConstants.tinyBorderRadius),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error,
                        color: Colors.red,
                        size: AppConstants.progressIndicatorSizeSmall),
                    const SizedBox(width: AppConstants.smallSpacing),
                    Expanded(
                      child: Text(
                        errorMessage,
                        style: TextStyle(color: Colors.red.shade800),
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
}

class ControlSection extends ConsumerWidget {
  const ControlSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPrinter = ref.watch(selectedPrinterProvider);
    final isPrinting = ref.watch(isPrintingProvider);
    final printerAsync = ref.watch(printerProvider);

    return printerAsync.when(
      data: (printer) => _ControlSectionContent(
        printer: printer,
        selectedPrinter: selectedPrinter,
        isPrinting: isPrinting,
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _ControlSectionContent extends ConsumerWidget {
  const _ControlSectionContent({
    required this.printer,
    required this.selectedPrinter,
    required this.isPrinting,
  });

  final ZebraPrinter printer;
  final ZebraDevice? selectedPrinter;
  final bool isPrinting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final printerService = ref.read(printerServiceProvider);

    return Padding(
      padding: AppConstants.horizontalPadding,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: printer.isScanning
                      ? () => printerService.stopScanning(printer)
                      : () => printerService.startScanning(printer),
                  icon: Icon(printer.isScanning ? Icons.stop : Icons.search),
                  label: Text(printer.isScanning
                      ? AppConstants.stopScan
                      : AppConstants.startScan),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        printer.isScanning ? Colors.red : Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.smallSpacing),
              ElevatedButton.icon(
                onPressed: () => printerService.addTestPrinter(printer),
                icon: const Icon(Icons.bug_report),
                label: const Text(AppConstants.test),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          if (selectedPrinter != null) ...[
            const SizedBox(height: AppConstants.smallSpacing),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isPrinting
                        ? null
                        : () => printerService.printTestLabel(printer),
                    icon: isPrinting
                        ? const SizedBox(
                            width: AppConstants.progressIndicatorSize,
                            height: AppConstants.progressIndicatorSize,
                            child: CircularProgressIndicator(
                              strokeWidth: AppConstants.strokeWidth,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.print),
                    label: Text(isPrinting
                        ? AppConstants.printing
                        : AppConstants.printTest),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: AppConstants.smallSpacing),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => printerService.calibratePrinter(printer),
                    icon: const Icon(Icons.tune),
                    label: const Text(AppConstants.calibrate),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.smallSpacing),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showSettingsDialog(context, printer),
                icon: const Icon(Icons.settings),
                label: const Text(AppConstants.settings),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context, ZebraPrinter printer) {
    showDialog(
      context: context,
      builder: (context) => _SettingsDialog(printer: printer),
    );
  }
}

class PrintersSection extends ConsumerWidget {
  const PrintersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final printerAsync = ref.watch(printerProvider);

    return printerAsync.when(
      data: (printer) => _PrintersSectionContent(
        controller: printer.controller,
        printer: printer,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading printer')),
    );
  }
}

class _PrintersSectionContent extends ConsumerWidget {
  const _PrintersSectionContent({
    required this.controller,
    required this.printer,
  });

  final ZebraController controller;
  final ZebraPrinter printer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedPrinter = ref.watch(selectedPrinterProvider);
    final isConnecting = ref.watch(isConnectingProvider);
    final printerService = ref.read(printerServiceProvider);

    return RepaintBoundary(
      child: Container(
        margin: AppConstants.defaultPadding,
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: AppConstants.defaultPadding,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppConstants.borderRadius),
                  topRight: Radius.circular(AppConstants.borderRadius),
                ),
              ),
              child: Text(
                'Discovered Printers',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, child) {
                  final printers = controller.printers;

                  if (printers.isEmpty) {
                    return const _EmptyPrintersView();
                  }

                  return ListView.builder(
                    itemCount: printers.length,
                    itemBuilder: (context, index) {
                      final printerDevice = printers[index];
                      return _PrinterListItem(
                        key: ValueKey(printerDevice.address),
                        printer: printerDevice,
                        selectedPrinter: selectedPrinter,
                        isConnecting: isConnecting,
                        onConnectToPrinter: (device) =>
                            printerService.connectToPrinter(printer, device),
                      );
                    },
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

class _EmptyPrintersView extends StatelessWidget {
  const _EmptyPrintersView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.print_disabled,
                size: AppConstants.defaultIconSize, color: Colors.grey),
            SizedBox(height: AppConstants.defaultSpacing),
            Text(
              'No printers found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: AppConstants.smallSpacing),
            Text(
              'Make sure:\n• Bluetooth is enabled\n• Location permission is granted\n• Zebra printers are powered on\n• Printers are in discoverable mode',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrinterListItem extends StatelessWidget {
  const _PrinterListItem({
    required this.printer,
    required this.selectedPrinter,
    required this.isConnecting,
    required this.onConnectToPrinter,
    super.key,
  });

  final ZebraDevice printer;
  final ZebraDevice? selectedPrinter;
  final bool isConnecting;
  final void Function(ZebraDevice) onConnectToPrinter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = selectedPrinter?.address == printer.address;
    final isCurrentlyConnecting = isConnecting && isSelected;

    return Container(
      margin: AppConstants.verticalPadding.add(AppConstants.horizontalPadding),
      decoration: BoxDecoration(
        color: isSelected ? theme.colorScheme.primaryContainer : null,
        borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
        border: isSelected
            ? Border.all(
                color: theme.colorScheme.primary,
                width: AppConstants.strokeWidth)
            : null,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: printer.color,
          child: Icon(
            printer.isWifi ? Icons.wifi : Icons.bluetooth,
            color: Colors.white,
          ),
        ),
        title: Text(
          printer.name.isEmpty ? 'Unknown Printer' : printer.name,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${printer.address} • ${printer.isWifi ? "WiFi" : "Bluetooth"}'),
            Text(
              printer.status,
              style: TextStyle(color: printer.color),
            ),
          ],
        ),
        trailing: isCurrentlyConnecting
            ? const SizedBox(
                width: AppConstants.progressIndicatorSizeSmall,
                height: AppConstants.progressIndicatorSizeSmall,
                child: CircularProgressIndicator(
                    strokeWidth: AppConstants.strokeWidth),
              )
            : isSelected
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.radio_button_unchecked),
        onTap: isSelected ? null : () => onConnectToPrinter(printer),
      ),
    );
  }
}

class _SettingsDialog extends ConsumerWidget {
  const _SettingsDialog({required this.printer});

  final ZebraPrinter printer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: const Text(AppConstants.printerSettings),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text('Set Darkness'),
            subtitle: const Text('Adjust print darkness'),
            onTap: () {
              Navigator.pop(context);
              _showDarknessDialog(context, ref);
            },
          ),
          ListTile(
            leading: const Icon(Icons.article),
            title: const Text('Media Type'),
            subtitle: const Text('Configure media settings'),
            onTap: () {
              Navigator.pop(context);
              _showMediaTypeDialog(context, ref);
            },
          ),
          ListTile(
            leading: const Icon(Icons.rotate_right),
            title: const Text('Toggle Rotation'),
            subtitle: Text(
                printer.isRotated ? 'Currently: Rotated' : 'Currently: Normal'),
            onTap: () {
              printer.rotate();
              Navigator.pop(context);
              ref.read(statusMessageProvider.notifier).state =
                  'Print rotation ${printer.isRotated ? "enabled" : "disabled"}';
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(AppConstants.close),
        ),
      ],
    );
  }

  void _showDarknessDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppConstants.setPrintDarkness),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select darkness level:'),
            const SizedBox(height: AppConstants.defaultSpacing),
            Wrap(
              spacing: AppConstants.smallSpacing,
              children: AppConstants.darknessLevels
                  .map((value) => ActionChip(
                        label: Text('$value'),
                        onPressed: () async {
                          try {
                            await printer.setDarkness(value);
                            if (context.mounted) {
                              Navigator.pop(context);
                              ref.read(statusMessageProvider.notifier).state =
                                  'Darkness set to $value';
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ref.read(errorMessageProvider.notifier).state =
                                  '${AppConstants.failedToSetDarkness}$e';
                            }
                          }
                        },
                      ))
                  .toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppConstants.cancel),
          ),
        ],
      ),
    );
  }

  void _showMediaTypeDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppConstants.setMediaType),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: EnumMediaType.values
              .map((type) => ListTile(
                    title: Text(type.name),
                    subtitle: Text(MediaTypeDescriptions.getDescription(type)),
                    onTap: () async {
                      try {
                        await printer.setMediaType(type);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ref.read(statusMessageProvider.notifier).state =
                              'Media type set to ${type.name}';
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ref.read(errorMessageProvider.notifier).state =
                              '${AppConstants.failedToSetMediaType}$e';
                        }
                      }
                    },
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppConstants.cancel),
          ),
        ],
      ),
    );
  }
}

class _PrintSuccessDialog extends ConsumerWidget {
  const _PrintSuccessDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPrinter = ref.watch(selectedPrinterProvider);
    final printerAsync = ref.watch(printerProvider);

    return AlertDialog(
      icon: const Icon(
        Icons.check_circle,
        color: Colors.green,
        size: AppConstants.defaultIconSize,
      ),
      title: const Text(AppConstants.printSuccessful),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Your test label has been printed successfully.'),
          if (selectedPrinter != null) ...[
            const SizedBox(height: AppConstants.defaultSpacing),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius:
                    BorderRadius.circular(AppConstants.smallBorderRadius),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    selectedPrinter.isWifi ? Icons.wifi : Icons.bluetooth,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(width: AppConstants.smallSpacing),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedPrinter.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                        Text(
                          selectedPrinter.address,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            ref.read(statusMessageProvider.notifier).state =
                AppConstants.readyForNextPrint;
          },
          child: const Text(AppConstants.ok),
        ),
        printerAsync.when(
          data: (printer) => ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(printerServiceProvider).printTestLabel(printer);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text(AppConstants.printAnother),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
