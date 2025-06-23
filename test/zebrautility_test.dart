import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/zebra_device.dart';
import 'package:zebrautil/zebra_printer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ZebraPrinter Tests', () {
    late ZebraPrinter printer;
    late MethodChannel channel;
    const String testId = 'test_printer_id';

    setUp(() {
      // Mock method channel
      channel = const MethodChannel('ZebraPrinterObject$testId');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'checkPermission':
            return true;
          case 'startScan':
            return null;
          case 'stopScan':
            return null;
          case 'disconnect':
            return null;
          case 'setSettings':
            return null;
          case 'print':
            return null;
          case 'connectToPrinter':
            return null;
          case 'connectToGenericPrinter':
            return null;
          case 'isPrinterConnected':
            return null;
          case 'getLocateValue':
            return 'test_value';
          default:
            throw PlatformException(
                code: 'UNIMPLEMENTED', message: 'Not implemented');
        }
      });

      printer = ZebraPrinter(testId);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    group('Constructor Tests', () {
      test('should create printer with valid ID', () {
        expect(printer, isNotNull);
        expect(printer.isScanning, isFalse);
        expect(printer.isRotated, isFalse);
        expect(printer.isDisposed, isFalse);
      });

      test('should throw exception with empty ID', () {
        expect(
          () => ZebraPrinter(''),
          throwsA(isA<ZebraValidationException>()),
        );
      });

      test('should accept custom controller', () {
        final customController = ZebraController();
        final customPrinter =
            ZebraPrinter('custom_id', controller: customController);
        expect(customPrinter.controller, equals(customController));
      });
    });

    group('Scanning Tests', () {
      test('should start scanning successfully', () async {
        await printer.startScanning();
        expect(printer.isScanning, isTrue);
      });

      test('should stop scanning successfully', () async {
        await printer.startScanning();
        await printer.stopScanning();
        expect(printer.isScanning, isFalse);
      });

      test('should ignore duplicate start scanning calls', () async {
        await printer.startScanning();
        expect(printer.isScanning, isTrue);

        // Should not throw error or change state
        await printer.startScanning();
        expect(printer.isScanning, isTrue);
      });

      test('should handle permission denied', () async {
        // Mock permission denied
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'checkPermission') {
            return false;
          }
          return null;
        });

        bool permissionDeniedCalled = false;
        printer.setOnPermissionDenied(() {
          permissionDeniedCalled = true;
        });

        await expectLater(
          printer.startScanning(),
          throwsA(isA<ZebraPrinterException>()),
        );
        expect(permissionDeniedCalled, isTrue);
        expect(printer.isScanning, isFalse);
      });
    });

    group('Connection Tests', () {
      test('should validate address before connecting', () async {
        await expectLater(
          printer.connectToPrinter(''),
          throwsA(isA<ZebraValidationException>()),
        );
      });

      test('should validate address with whitespace', () async {
        await expectLater(
          printer.connectToPrinter(' 192.168.1.1 '),
          throwsA(isA<ZebraValidationException>()),
        );
      });

      test('should validate address length', () async {
        final longAddress = 'a' * 300; // Exceeds max length
        await expectLater(
          printer.connectToPrinter(longAddress),
          throwsA(isA<ZebraValidationException>()),
        );
      });

      test('should connect to valid address', () async {
        await printer.connectToPrinter('192.168.1.100');
        expect(printer.controller.selectedAddress, equals('192.168.1.100'));
      });

      test('should disconnect and reconnect to same address', () async {
        await printer.connectToPrinter('192.168.1.100');
        expect(printer.controller.selectedAddress, equals('192.168.1.100'));

        // Connecting to same address should disconnect
        await printer.connectToPrinter('192.168.1.100');
        expect(printer.controller.selectedAddress, isNull);
      });
    });

    group('Print Tests', () {
      test('should validate print data', () async {
        await expectLater(
          printer.print(data: ''),
          throwsA(isA<ZebraValidationException>()),
        );
      });

      test('should validate print data length', () async {
        final longData = 'a' * 70000; // Exceeds max length
        await expectLater(
          printer.print(data: longData),
          throwsA(isA<ZebraValidationException>()),
        );
      });

      test('should process print data correctly', () async {
        await printer.print(data: '^XATest^XZ');
        // Should not throw error
      });

      test('should handle rotation in print data', () async {
        printer.rotate();
        expect(printer.isRotated, isTrue);

        await printer.print(data: '^XA^PONTest^XZ');
        // Should process rotation correctly
      });
    });

    group('Settings Tests', () {
      test('should validate darkness values', () async {
        await expectLater(
          printer.setDarkness(999), // Invalid value
          throwsA(isA<ZebraValidationException>()),
        );
      });

      test('should accept valid darkness values', () async {
        for (final value in [
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
        ]) {
          await printer.setDarkness(value);
          // Should not throw error
        }
      });

      test('should set media type', () async {
        await printer.setMediaType(EnumMediaType.Label);
        await printer.setMediaType(EnumMediaType.BlackMark);
        await printer.setMediaType(EnumMediaType.Journal);
        // Should not throw errors
      });

      test('should calibrate printer', () async {
        await printer.calibratePrinter();
        // Should not throw error
      });
    });

    group('Error Handling Tests', () {
      test('should handle platform exceptions', () async {
        // Mock platform exception
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          throw PlatformException(
              code: 'TEST_ERROR', message: 'Test error message');
        });

        String? receivedErrorCode;
        String? receivedErrorMessage;
        printer.setOnDiscoveryError((errorCode, errorMessage) {
          receivedErrorCode = errorCode;
          receivedErrorMessage = errorMessage;
        });

        await expectLater(
          printer.startScanning(),
          throwsA(isA<ZebraPrinterException>()),
        );

        expect(receivedErrorCode, equals('TEST_ERROR'));
        expect(receivedErrorMessage, equals('Test error message'));
      });

      test('should handle timeout exceptions', () async {
        // Mock long-running operation that will timeout
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          await Future.delayed(
              const Duration(seconds: 35)); // Longer than timeout
          return null;
        });

        await expectLater(
          printer.startScanning(),
          throwsA(isA<ZebraPrinterException>()),
        );
      });
    });

    group('Disposal Tests', () {
      test('should dispose properly', () async {
        await printer.startScanning();
        await printer.connectToPrinter('192.168.1.100');

        await printer.dispose();

        expect(printer.isDisposed, isTrue);
        expect(printer.isScanning, isFalse);
      });

      test('should throw exception when using disposed printer', () async {
        await printer.dispose();

        await expectLater(
          printer.startScanning(),
          throwsA(isA<ZebraPrinterException>()),
        );
      });

      test('should handle multiple dispose calls', () async {
        await printer.dispose();
        await printer.dispose(); // Should not throw error
        expect(printer.isDisposed, isTrue);
      });
    });

    group('Method Call Handler Tests', () {
      test('should handle printer found event', () async {
        final testDevice = ZebraDevice(
          address: '192.168.1.100',
          name: 'Test Printer',
          status: 'Ready',
          isWifi: true,
        );

        // Simulate printer found event
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'flutter/tests',
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('printerFound', {
              'Address': '192.168.1.100',
              'Name': 'Test Printer',
              'Status': 'Ready',
              'IsWifi': 'true',
            }),
          ),
          (data) {},
        );

        // Verify printer was added to controller
        expect(printer.controller.printers.length, greaterThan(0));
      });
    });
  });

  group('ZebraController Tests', () {
    late ZebraController controller;

    setUp(() {
      controller = ZebraController();
    });

    test('should start with empty printer list', () {
      expect(controller.printers, isEmpty);
      expect(controller.selectedAddress, isNull);
    });

    test('should add printers', () {
      final device = ZebraDevice(
        address: '192.168.1.100',
        name: 'Test Printer',
        status: 'Ready',
        isWifi: true,
      );

      controller.addPrinter(device);
      expect(controller.printers.length, equals(1));
      expect(controller.printers.first, equals(device));
    });

    test('should not add duplicate printers', () {
      final device = ZebraDevice(
        address: '192.168.1.100',
        name: 'Test Printer',
        status: 'Ready',
        isWifi: true,
      );

      controller.addPrinter(device);
      controller.addPrinter(device); // Should not add duplicate
      expect(controller.printers.length, equals(1));
    });

    test('should remove printers by address', () {
      final device = ZebraDevice(
        address: '192.168.1.100',
        name: 'Test Printer',
        status: 'Ready',
        isWifi: true,
      );

      controller.addPrinter(device);
      controller.removePrinter('192.168.1.100');
      expect(controller.printers, isEmpty);
    });

    test('should clear selected address when removing selected printer', () {
      final device = ZebraDevice(
        address: '192.168.1.100',
        name: 'Test Printer',
        status: 'Ready',
        isWifi: true,
      );

      controller.addPrinter(device);
      controller.selectedAddress = '192.168.1.100';
      controller.removePrinter('192.168.1.100');

      expect(controller.printers, isEmpty);
      expect(controller.selectedAddress, isNull);
    });

    test('should clean disconnected printers', () {
      final connectedDevice = ZebraDevice(
        address: '192.168.1.100',
        name: 'Connected Printer',
        status: 'Ready',
        isWifi: true,
        isConnected: true,
      );

      final disconnectedDevice = ZebraDevice(
        address: '192.168.1.101',
        name: 'Disconnected Printer',
        status: 'Offline',
        isWifi: true,
        isConnected: false,
      );

      controller.addPrinter(connectedDevice);
      controller.addPrinter(disconnectedDevice);
      controller.cleanAll();

      expect(controller.printers.length, equals(1));
      expect(controller.printers.first.address, equals('192.168.1.100'));
    });

    test('should update printer status', () {
      final device = ZebraDevice(
        address: '192.168.1.100',
        name: 'Test Printer',
        status: 'Ready',
        isWifi: true,
      );

      controller.addPrinter(device);
      controller.selectedAddress = '192.168.1.100';
      controller.updatePrinterStatus('Printing', 'G');

      final updatedDevice = controller.printers.first;
      expect(updatedDevice.status, equals('Printing'));
      expect(updatedDevice.isConnected, isTrue);
    });

    test('should dispose properly', () {
      final device = ZebraDevice(
        address: '192.168.1.100',
        name: 'Test Printer',
        status: 'Ready',
        isWifi: true,
      );

      controller.addPrinter(device);
      controller.selectedAddress = '192.168.1.100';
      controller.dispose();

      expect(controller.printers, isEmpty);
      expect(controller.selectedAddress, isNull);
    });
  });

  group('Exception Tests', () {
    test('ZebraPrinterException should format correctly', () {
      const exception =
          ZebraPrinterException('Test message', code: 'TEST_CODE');
      expect(exception.toString(), contains('Test message'));
      expect(exception.toString(), contains('TEST_CODE'));
    });

    test('ZebraValidationException should extend ZebraPrinterException', () {
      const exception = ZebraValidationException('Validation failed');
      expect(exception, isA<ZebraPrinterException>());
      expect(exception.message, equals('Validation failed'));
    });
  });
}
