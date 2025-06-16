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
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: FutureBuilder(
        future: ZebraUtil.getPrinterInstance(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          final printer = snapshot.data as ZebraPrinter;
          return PrinterTemplate(printer);
        },
      ),
    );
  }
}

class PrinterTemplate extends StatefulWidget {
  const PrinterTemplate(this.printer, {super.key});
  final ZebraPrinter printer;
  @override
  State<PrinterTemplate> createState() => _PrinterTemplateState();
}

class _PrinterTemplateState extends State<PrinterTemplate> {
  late ZebraPrinter zebraPrinter;
  late ZebraController controller;
  String? errorMessage;
  final String dataToPrint = """^XA
        ^FX Top section with logo, name and address.
        ^CF0,60
        ^FO50,50^GB100,100,100^FS
        ^FO75,75^FR^GB100,100,100^FS
        ^FO93,93^GB40,40,40^FS
        ^FO220,50^FDIntershipping, Inc.^FS
        ^CF0,30
        ^FO220,115^FD1000 Shipping Lane^FS
        ^FO220,155^FDShelbyville TN 38102^FS
        ^FO220,195^FDUnited States (USA)^FS
        ^FO50,250^GB700,3,3^FS
        ^XZ""";

  @override
  void initState() {
    zebraPrinter = widget.printer;
    controller = zebraPrinter.controller;

    // Add error handling
    zebraPrinter.onDiscoveryError = (errorCode, errorText) {
      print("Discovery Error: $errorCode - $errorText");
      setState(() {
        errorMessage = "Error: $errorText";
      });
    };

    zebraPrinter.onPermissionDenied = () {
      print("Permission denied");
      setState(() {
        errorMessage =
            "Permission denied. Please grant location and Bluetooth permissions.";
      });
    };

    zebraPrinter.startScanning();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Column(
            children: [
              const Text("My Printers"),
              if (zebraPrinter.isScanning)
                const Text(
                  "Searching for printers...",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            if (zebraPrinter.isScanning) {
              zebraPrinter.stopScanning();
            } else {
              setState(() {
                errorMessage = null;
              });
              zebraPrinter.startScanning();
            }
            setState(() {});
          },
          child: Icon(
              zebraPrinter.isScanning ? Icons.stop_circle : Icons.play_circle),
        ),
        body: Column(
          children: [
            if (errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.red.shade100,
                child: Text(
                  errorMessage!,
                  style: TextStyle(color: Colors.red.shade800),
                ),
              ),
            Expanded(
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, child) {
                  final printers = controller.printers;
                  if (printers.isEmpty) {
                    return _getNotAvailablePage();
                  }
                  return _getListDevices(printers);
                },
              ),
            ),
          ],
        ));
  }

  Widget _getListDevices(List<ZebraDevice> printers) {
    return ListView.builder(
        itemBuilder: (BuildContext context, int index) {
          return ListTile(
            title: Text(printers[index].name),
            subtitle: Text(printers[index].status,
                style: TextStyle(color: printers[index].color)),
            leading: IconButton(
              icon: Icon(Icons.print, color: printers[index].color),
              onPressed: () {
                zebraPrinter.print(data: dataToPrint);
              },
            ),
            trailing: IconButton(
              icon: Icon(Icons.connect_without_contact_rounded,
                  color: printers[index].color),
              onPressed: () async {
                await zebraPrinter.connectToPrinter(printers[index].address);
                setState(() {
                  if (zebraPrinter.isScanning) zebraPrinter.stopScanning();
                });
              },
            ),
          );
        },
        itemCount: printers.length);
  }

  SizedBox _getNotAvailablePage() {
    return const SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("Printers not found"),
          SizedBox(height: 16),
          Text(
            "Make sure:\n• Bluetooth is enabled\n• Location services are enabled\n• Zebra printers are in range and discoverable\n• For WiFi printers: connected to the same network",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
