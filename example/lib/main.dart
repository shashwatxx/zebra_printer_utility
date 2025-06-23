import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zebrautil/zebra_device.dart';
import 'package:zebrautil/zebra_printer.dart';
import 'package:zebrautil/zebra_util.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zebra Printer Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: FutureBuilder<ZebraPrinter>(
        future: ZebraUtil.getPrinterInstance(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => main(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Initializing Zebra Printer...'),
                  ],
                ),
              ),
            );
          }

          return ZebraPrinterApp(printer: snapshot.data!);
        },
      ),
    );
  }
}

class ZebraPrinterApp extends StatefulWidget {
  const ZebraPrinterApp({super.key, required this.printer});

  final ZebraPrinter printer;

  @override
  State<ZebraPrinterApp> createState() => _ZebraPrinterAppState();
}

class _ZebraPrinterAppState extends State<ZebraPrinterApp> {
  late ZebraPrinter _printer;
  late ZebraController _controller;

  String? _errorMessage;
  String? _statusMessage;
  ZebraDevice? _selectedPrinter;
  bool _isConnecting = false;
  bool _isPrinting = false;
  Timer? _printTimeoutTimer;

  // Test label ZPL data
  static const String _testLabelZpl = '''
^XA
^CF0,60
^FO50,50^FDZebra Test Label^FS
^CF0,30
^FO50,120^FDDate: \${DateTime.now().toString().split(' ')[0]}^FS
^FO50,160^FDTime: \${DateTime.now().toString().split(' ')[1].split('.')[0]}^FS
^FO50,200^FDStatus: Print Test Successful^FS
^FO50,240^FDPrinter: Ready^FS
^FO50,300^GB400,2,2^FS
^FO50,320^FDThank you for using Zebra Printer Utility!^FS
^XZ
''';

  @override
  void initState() {
    super.initState();
    _printer = widget.printer;
    _controller = _printer.controller;
    _setupPrinterCallbacks();
  }

  void _setupPrinterCallbacks() {
    _printer.setOnDiscoveryError((errorCode, errorText) {
      if (mounted) {
        setState(() {
          _errorMessage = "Discovery Error: $errorText";
          _statusMessage = null;
        });
      }
    });

    _printer.setOnPermissionDenied(() {
      if (mounted) {
        setState(() {
          _errorMessage =
              "Permission denied. Please grant Bluetooth and location permissions in your device settings.";
          _statusMessage = null;
        });
      }
    });

    _printer.setOnPrintComplete(() {
      if (mounted) {
        _printTimeoutTimer?.cancel();
        _printTimeoutTimer = null;
        setState(() {
          _statusMessage = null;
          _isPrinting = false;
        });
        _showPrintSuccessDialog();
      }
    });

    _printer.setOnPrintError((errorMessage) {
      if (mounted) {
        setState(() {
          _errorMessage = "Print Error: $errorMessage";
          _statusMessage = null;
          _isPrinting = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _printTimeoutTimer?.cancel();
    _printer.dispose();
    super.dispose();
  }

  Future<void> _startScanning() async {
    try {
      setState(() {
        _errorMessage = null;
        _statusMessage = "Searching for printers...";
        _selectedPrinter = null;
      });

      await _printer.startScanning();

      if (mounted) {
        setState(() {
          _statusMessage =
              _printer.isScanning ? "Scanning for printers..." : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to start scanning: $e";
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _stopScanning() async {
    try {
      await _printer.stopScanning();
      if (mounted) {
        setState(() {
          _statusMessage = "Scan stopped";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to stop scanning: $e";
        });
      }
    }
  }

  Future<void> _connectToPrinter(ZebraDevice printer) async {
    if (_isConnecting) return;

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
      _statusMessage = "Connecting to ${printer.name}...";
    });

    try {
      await _printer.connectToPrinter(printer.address);

      if (mounted) {
        setState(() {
          _selectedPrinter = printer;
          _statusMessage = "Connected to ${printer.name}";
          _isConnecting = false;
        });
      }

      // Stop scanning after successful connection
      if (_printer.isScanning) {
        await _stopScanning();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to connect to ${printer.name}: $e";
          _statusMessage = null;
          _isConnecting = false;
        });
      }
    }
  }

  Future<void> _disconnect() async {
    try {
      await _printer.disconnect();
      if (mounted) {
        setState(() {
          _selectedPrinter = null;
          _statusMessage = "Disconnected from printer";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to disconnect: $e";
        });
      }
    }
  }

  Future<void> _printTestLabel() async {
    if (_isPrinting || _selectedPrinter == null) return;

    setState(() {
      _isPrinting = true;
      _errorMessage = null;
      _statusMessage = "Printing test label...";
    });

    try {
      // Process the ZPL data with current date/time
      final processedZpl = _testLabelZpl
          .replaceAll('\${DateTime.now().toString().split(\' \')[0]}',
              DateTime.now().toString().split(' ')[0])
          .replaceAll(
              '\${DateTime.now().toString().split(\' \')[1].split(\'.\')[0]}',
              DateTime.now().toString().split(' ')[1].split('.')[0]);

      await _printer.print(data: processedZpl);

      if (mounted) {
        setState(() {
          _statusMessage = "Print command sent to printer...";
        });

        // Set a timeout to show success dialog if no native callback is received
        _startPrintTimeoutTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to send print command: $e";
          _statusMessage = null;
          _isPrinting = false;
        });
      }
    }
  }

  Future<void> _calibratePrinter() async {
    if (_selectedPrinter == null) return;

    setState(() {
      _statusMessage = "Calibrating printer...";
      _errorMessage = null;
    });

    try {
      await _printer.calibratePrinter();
      if (mounted) {
        setState(() {
          _statusMessage = "Printer calibration completed";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to calibrate printer: $e";
          _statusMessage = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zebra Printer Utility'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_selectedPrinter != null)
            IconButton(
              onPressed: _disconnect,
              icon: const Icon(Icons.bluetooth_disabled),
              tooltip: 'Disconnect',
            ),
        ],
      ),
      body: Column(
        children: [
          // Status Section
          _buildStatusSection(),

          // Control Buttons Section
          _buildControlSection(),

          // Printers List Section
          Expanded(
            child: _buildPrintersSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _selectedPrinter != null
                    ? Icons.bluetooth_connected
                    : Icons.bluetooth_searching,
                color: _selectedPrinter != null ? Colors.green : Colors.blue,
              ),
              const SizedBox(width: 8),
              Text(
                'Status',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_selectedPrinter != null) ...[
            Text('Connected: ${_selectedPrinter!.name}'),
            Text('Address: ${_selectedPrinter!.address}'),
            Text('Type: ${_selectedPrinter!.isWifi ? "WiFi" : "Bluetooth"}'),
          ] else ...[
            const Text('No printer connected'),
          ],
          if (_statusMessage != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusMessage!,
                    style: const TextStyle(color: Colors.blue),
                  ),
                ),
              ],
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Scanning Controls
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      _printer.isScanning ? _stopScanning : _startScanning,
                  icon: Icon(_printer.isScanning ? Icons.stop : Icons.search),
                  label: Text(_printer.isScanning ? 'Stop Scan' : 'Start Scan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _printer.isScanning ? Colors.red : Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  _printer.addTestPrinter();
                  setState(() {
                    _statusMessage = "Test printer added";
                  });
                },
                icon: const Icon(Icons.bug_report),
                label: const Text('Test'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
              if (_selectedPrinter != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isPrinting ? null : _printTestLabel,
                    icon: _isPrinting
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
                    label: Text(_isPrinting ? 'Printing...' : 'Print Test'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),

          // Printer Settings (if connected)
          if (_selectedPrinter != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _calibratePrinter,
                    icon: const Icon(Icons.tune),
                    label: const Text('Calibrate'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showSettingsDialog(context),
                    icon: const Icon(Icons.settings),
                    label: const Text('Settings'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrintersSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Text(
              'Discovered Printers',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, child) {
                final printers = _controller.printers;

                if (printers.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.print_disabled,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No printers found',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
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

                return ListView.builder(
                  itemCount: printers.length,
                  itemBuilder: (context, index) {
                    final printer = printers[index];
                    final isSelected =
                        _selectedPrinter?.address == printer.address;
                    final isConnecting = _isConnecting &&
                        _selectedPrinter?.address == printer.address;

                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              )
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
                          printer.name.isEmpty
                              ? 'Unknown Printer'
                              : printer.name,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
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
                        trailing: isConnecting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : isSelected
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : const Icon(Icons.radio_button_unchecked),
                        onTap: isSelected
                            ? null
                            : () => _connectToPrinter(printer),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
              leading: const Icon(Icons.rotate_right),
              title: const Text('Toggle Rotation'),
              subtitle: Text(_printer.isRotated
                  ? 'Currently: Rotated'
                  : 'Currently: Normal'),
              onTap: () {
                _printer.rotate();
                Navigator.pop(context);
                setState(() {
                  _statusMessage =
                      'Print rotation ${_printer.isRotated ? "enabled" : "disabled"}';
                });
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
      ),
    );
  }

  void _showDarknessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Print Darkness'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select darkness level:'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
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
              ]
                  .map((value) => ActionChip(
                        label: Text('$value'),
                        onPressed: () async {
                          try {
                            await _printer.setDarkness(value);
                            if (mounted) {
                              Navigator.pop(context);
                              setState(() {
                                _statusMessage = 'Darkness set to $value';
                              });
                            }
                          } catch (e) {
                            if (mounted) {
                              setState(() {
                                _errorMessage = 'Failed to set darkness: $e';
                              });
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
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showMediaTypeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Media Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: EnumMediaType.values
              .map((type) => ListTile(
                    title: Text(type.name),
                    subtitle: Text(_getMediaTypeDescription(type)),
                    onTap: () async {
                      try {
                        await _printer.setMediaType(type);
                        if (mounted) {
                          Navigator.pop(context);
                          setState(() {
                            _statusMessage = 'Media type set to ${type.name}';
                          });
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() {
                            _errorMessage = 'Failed to set media type: $e';
                          });
                        }
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

  String _getMediaTypeDescription(EnumMediaType type) {
    switch (type) {
      case EnumMediaType.label:
        return 'Standard label with gap detection';
      case EnumMediaType.blackMark:
        return 'Labels with black mark detection';
      case EnumMediaType.journal:
        return 'Continuous journal paper';
    }
  }

  void _startPrintTimeoutTimer() {
    // Cancel any existing timer
    _printTimeoutTimer?.cancel();

    // Start a 10-second timeout timer
    _printTimeoutTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _isPrinting) {
        setState(() {
          _statusMessage = null;
          _isPrinting = false;
        });
        _showPrintSuccessDialog();
      }
    });
  }

  void _showPrintSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 64,
          ),
          title: const Text('Print Successful!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Your test label has been printed successfully.'),
              if (_selectedPrinter != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _selectedPrinter!.isWifi ? Icons.wifi : Icons.bluetooth,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedPrinter!.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                            Text(
                              _selectedPrinter!.address,
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
                setState(() {
                  _statusMessage = 'Ready for next print job';
                });
              },
              child: const Text('OK'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _printTestLabel(); // Print another label
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Print Another'),
            ),
          ],
        );
      },
    );
  }
}
