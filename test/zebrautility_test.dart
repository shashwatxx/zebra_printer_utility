import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zebrautil/zebra_device.dart';
import 'package:zebrautil/zebra_printer.dart';

// Test helper class for managing mock controller state
class TestZebraController extends ZebraController {
  String? _selectedAddress;
  final List<ZebraDevice> _testPrinters = [];

  @override
  List<ZebraDevice> get printers => List.unmodifiable(_testPrinters);

  @override
  String? get selectedAddress => _selectedAddress;

  @override
  set selectedAddress(String? address) {
    _selectedAddress = address;
    notifyListeners();
  }

  @override
  void addPrinter(ZebraDevice printer) {
    _testPrinters.add(printer);
    notifyListeners();
  }

  @override
  void removePrinter(String address) {
    _testPrinters.removeWhere((p) => p.address == address);
    notifyListeners();
  }

  @override
  void updatePrinterStatus(String status, String colorCode) {
    // Mock implementation
    notifyListeners();
  }

  @override
  void synchronizePrinter(String connectedString) {
    // Mock implementation
  }

  void clearPrinters() {
    _testPrinters.clear();
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ZebraPrinter', () {
    late ZebraPrinter printer;
    late TestZebraController testController;

    const String testPrinterId = 'test_printer_id';
    const String testPrinterAddress = '192.168.1.100';
    const String testBluetoothAddress = '00:07:4D:C9:52:88';

    setUp(() {
      testController = TestZebraController();

      // Mock platform channel responses
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        MethodChannel('ZebraPrinterObject$testPrinterId'),
        (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'checkPermission':
              return true;
            case 'startScan':
            case 'stopScan':
            case 'disconnect':
            case 'setSettings':
            case 'print':
            case 'connectToPrinter':
            case 'connectToGenericPrinter':
            case 'isPrinterConnected':
              return null;
            case 'getLocateValue':
              return 'test_value';
            default:
              throw PlatformException(
                code: 'UNIMPLEMENTED',
                message: 'Method ${methodCall.method} not implemented',
              );
          }
        },
      );

      printer = ZebraPrinter(testPrinterId, controller: testController);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        MethodChannel('ZebraPrinterObject$testPrinterId'),
        null,
      );
      testController.clearPrinters();
    });

    group('Construction', () {
      test('should create instance with valid parameters', () {
        // Arrange & Act
        final testPrinter = ZebraPrinter(
          'valid_id',
          controller: testController,
          onDiscoveryError: (code, message) {},
          onPermissionDenied: () {},
          onPrintComplete: () {},
          onPrintError: (error) {},
        );

        // Assert
        expect(testPrinter, isNotNull);
        expect(testPrinter.isScanning, isFalse);
        expect(testPrinter.isRotated, isFalse);
        expect(testPrinter.isDisposed, isFalse);
        expect(testPrinter.controller, equals(testController));
      });

      test('should throw ZebraValidationException for empty ID', () {
        // Arrange, Act & Assert
        expect(
          () => ZebraPrinter(''),
          throwsA(isA<ZebraValidationException>()),
        );
      });

      test('should accept null callback parameters', () {
        // Arrange & Act
        final testPrinter = ZebraPrinter(
          'test_id',
          controller: testController,
          onDiscoveryError: null,
          onPermissionDenied: null,
          onPrintComplete: null,
          onPrintError: null,
        );

        // Assert
        expect(testPrinter, isNotNull);
        expect(testPrinter.isDisposed, isFalse);
      });
    });

    group('Scanning Operations', () {
      test('should start scanning successfully when permission granted',
          () async {
        // Act
        await printer.startScanning();

        // Assert
        expect(printer.isScanning, isTrue);
      });

      test('should stop scanning successfully', () async {
        // Arrange
        await printer.startScanning();
        expect(printer.isScanning, isTrue);

        // Act
        await printer.stopScanning();

        // Assert
        expect(printer.isScanning, isFalse);
      });

      test('should throw exception when permission denied', () async {
        // Arrange
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          MethodChannel('ZebraPrinterObject$testPrinterId'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'checkPermission') {
              return false;
            }
            return null;
          },
        );

        // Act & Assert
        await expectLater(
          printer.startScanning(),
          throwsA(
            isA<ZebraPrinterException>().having(
              (e) => e.message,
              'message',
              contains('Permissions'),
            ),
          ),
        );
      });

      test('should handle multiple start scanning calls gracefully', () async {
        // Arrange & Act
        await printer.startScanning();
        expect(printer.isScanning, isTrue);

        // Should not throw when called again
        await printer.startScanning();

        // Assert
        expect(printer.isScanning, isTrue);
      });
    });

    group('Connection Management', () {
      test('should validate address before connecting', () async {
        // Act & Assert - Empty address
        await expectLater(
          printer.connectToPrinter(''),
          throwsA(
            isA<ZebraValidationException>().having(
              (e) => e.message,
              'message',
              contains('cannot be empty'),
            ),
          ),
        );

        // Act & Assert - Address with whitespace
        await expectLater(
          printer.connectToPrinter(' 192.168.1.1 '),
          throwsA(
            isA<ZebraValidationException>().having(
              (e) => e.message,
              'message',
              contains('whitespace'),
            ),
          ),
        );

        // Act & Assert - Address too long
        final longAddress = 'a' * 300;
        await expectLater(
          printer.connectToPrinter(longAddress),
          throwsA(
            isA<ZebraValidationException>().having(
              (e) => e.message,
              'message',
              contains('too long'),
            ),
          ),
        );
      });

      test('should connect to WiFi printer successfully', () async {
        // Act
        await printer.connectToPrinter(testPrinterAddress);

        // Assert
        expect(testController.selectedAddress, equals(testPrinterAddress));
      });

      test('should connect to Bluetooth printer successfully', () async {
        // Act
        await printer.connectToPrinter(testBluetoothAddress);

        // Assert
        expect(testController.selectedAddress, equals(testBluetoothAddress));
      });

      test('should disconnect from printer', () async {
        // Arrange
        testController.selectedAddress = testPrinterAddress;

        // Act
        await printer.disconnect();

        // Assert
        expect(testController.selectedAddress, isNull);
      });

      test('should handle connection timeout using fakeAsync', () {
        fakeAsync((async) {
          // Arrange
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(
            MethodChannel('ZebraPrinterObject$testPrinterId'),
            (MethodCall methodCall) async {
              if (methodCall.method == 'connectToPrinter') {
                // Simulate a long delay that will cause timeout
                await Future.delayed(const Duration(seconds: 35));
                return null;
              }
              return null;
            },
          );

          // Act & Assert
          expectLater(
            printer.connectToPrinter(testPrinterAddress),
            throwsA(
              isA<ZebraPrinterException>().having(
                (e) => e.message,
                'message',
                contains('Timeout'),
              ),
            ),
          );

          // Advance time to trigger timeout
          async.elapse(const Duration(seconds: 35));
        });
      });
    });

    group('Print Operations', () {
      test('should validate print data before sending', () async {
        // Act & Assert - Empty data
        await expectLater(
          printer.print(data: ''),
          throwsA(
            isA<ZebraValidationException>().having(
              (e) => e.message,
              'message',
              contains('cannot be empty'),
            ),
          ),
        );

        // Act & Assert - Data too long
        final longData = 'a' * 70000;
        await expectLater(
          printer.print(data: longData),
          throwsA(
            isA<ZebraValidationException>().having(
              (e) => e.message,
              'message',
              contains('exceeds maximum length'),
            ),
          ),
        );
      });

      test('should process ZPL data correctly', () async {
        // Arrange
        const testZpl = '^XATest Label^XZ';

        // Act
        await printer.print(data: testZpl);

        // Assert - Should not throw
      });

      test('should handle rotation in print data', () async {
        // Arrange
        printer.rotate();
        expect(printer.isRotated, isTrue);

        const testZpl = '^XA^PONTest^XZ';

        // Act
        await printer.print(data: testZpl);

        // Assert - Should not throw
      });

      test('should trigger print complete callback', () async {
        // Arrange
        bool callbackTriggered = false;
        printer.setOnPrintComplete(() {
          callbackTriggered = true;
        });

        // Simulate print completion
        await _simulatePrintComplete(testPrinterId);

        // Allow callback to process
        await Future.delayed(const Duration(milliseconds: 10));

        // Assert
        expect(callbackTriggered, isTrue);
      });

      test('should trigger print error callback with specific error', () async {
        // Arrange
        String? receivedError;
        printer.setOnPrintError((error) {
          receivedError = error;
        });

        const expectedError = 'Paper out';

        // Simulate print error
        await _simulatePrintError(testPrinterId, expectedError);

        // Allow callback to process
        await Future.delayed(const Duration(milliseconds: 10));

        // Assert
        expect(receivedError, equals(expectedError));
      });
    });

    group('Printer Settings', () {
      test('should validate darkness values', () async {
        // Act & Assert - Invalid darkness value
        await expectLater(
          printer.setDarkness(999),
          throwsA(
            isA<ZebraValidationException>().having(
              (e) => e.message,
              'message',
              contains('Invalid darkness'),
            ),
          ),
        );
      });

      test('should set valid darkness values', () async {
        // Arrange
        const validDarknessValues = [
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

        // Act & Assert
        for (final darkness in validDarknessValues) {
          await printer.setDarkness(darkness);
          // Should not throw
        }
      });

      test('should set media type correctly', () async {
        // Act
        await printer.setMediaType(EnumMediaType.label);
        await printer.setMediaType(EnumMediaType.blackMark);
        await printer.setMediaType(EnumMediaType.journal);

        // Assert - Should not throw
      });

      test('should calibrate printer', () async {
        // Act
        await printer.calibratePrinter();

        // Assert - Should not throw
      });

      test('should toggle rotation state', () {
        // Arrange
        expect(printer.isRotated, isFalse);

        // Act
        printer.rotate();

        // Assert
        expect(printer.isRotated, isTrue);

        // Act again
        printer.rotate();

        // Assert
        expect(printer.isRotated, isFalse);
      });
    });

    group('Device Discovery', () {
      test('should handle printer found event', () async {
        // Arrange
        const testDevice = {
          'Address': testPrinterAddress,
          'Name': 'Test Printer',
          'Status': 'Ready',
          'IsWifi': 'true',
        };

        // Act
        await _simulatePrinterFound(testPrinterId, testDevice);

        // Allow processing
        await Future.delayed(const Duration(milliseconds: 10));

        // Assert
        expect(testController.printers.length, equals(1));
        expect(
            testController.printers.first.address, equals(testPrinterAddress));
      });

      test('should handle printer removed event', () async {
        // Arrange - Add a printer first
        const testDevice = {
          'Address': testPrinterAddress,
          'Name': 'Test Printer',
          'Status': 'Ready',
          'IsWifi': 'true',
        };
        await _simulatePrinterFound(testPrinterId, testDevice);
        await Future.delayed(const Duration(milliseconds: 10));
        expect(testController.printers.length, equals(1));

        // Act
        const testEvent = {'Address': testPrinterAddress};
        await _simulatePrinterRemoved(testPrinterId, testEvent);

        // Allow processing
        await Future.delayed(const Duration(milliseconds: 10));

        // Assert
        expect(testController.printers.length, equals(0));
      });

      test('should handle discovery error callback', () async {
        // Arrange
        String? receivedErrorCode;
        String? receivedErrorMessage;

        printer.setOnDiscoveryError((errorCode, errorMessage) {
          receivedErrorCode = errorCode;
          receivedErrorMessage = errorMessage;
        });

        const testError = {
          'ErrorCode': 'BLUETOOTH_DISABLED',
          'ErrorText': 'Bluetooth is disabled',
        };

        // Act
        await _simulateDiscoveryError(testPrinterId, testError);

        // Allow processing
        await Future.delayed(const Duration(milliseconds: 10));

        // Assert
        expect(receivedErrorCode, equals('BLUETOOTH_DISABLED'));
        expect(receivedErrorMessage, equals('Bluetooth is disabled'));
      });
    });

    group('Callback Management', () {
      test('should allow callback replacement', () async {
        // Arrange
        int callCount = 0;

        // Set initial callback
        printer.setOnPrintComplete(() {
          callCount++;
        });

        // Trigger callback
        await _simulatePrintComplete(testPrinterId);
        await Future.delayed(const Duration(milliseconds: 10));
        expect(callCount, equals(1));

        // Replace callback
        printer.setOnPrintComplete(() {
          callCount += 10;
        });

        // Trigger callback again
        await _simulatePrintComplete(testPrinterId);
        await Future.delayed(const Duration(milliseconds: 10));

        // Assert - should be 11 (1 + 10), not 12 (1 + 1 + 10)
        expect(callCount, equals(11));
      });

      test('should handle rapid callback triggers using fakeAsync', () {
        fakeAsync((async) {
          // Arrange
          final receivedCallbacks = <String>[];

          printer.setOnPrintComplete(() {
            receivedCallbacks.add('complete');
          });

          printer.setOnPrintError((error) {
            receivedCallbacks.add('error:$error');
          });

          // Act - Trigger multiple callbacks rapidly
          for (int i = 0; i < 5; i++) {
            _simulatePrintComplete(testPrinterId);
            _simulatePrintError(testPrinterId, 'Error$i');
            async.flushMicrotasks();
          }

          // Advance time to process all callbacks
          async.elapse(const Duration(milliseconds: 100));

          // Assert
          expect(receivedCallbacks.length, equals(10));
          expect(receivedCallbacks.where((cb) => cb == 'complete').length,
              equals(5));
          expect(receivedCallbacks.where((cb) => cb.startsWith('error')).length,
              equals(5));
        });
      });
    });

    group('Resource Management', () {
      test('should dispose resources properly', () async {
        // Arrange
        testController.selectedAddress = testPrinterAddress;
        await printer.startScanning();

        // Act
        await printer.dispose();

        // Assert
        expect(printer.isDisposed, isTrue);
        expect(printer.isScanning, isFalse);
        expect(testController.selectedAddress, isNull);
      });

      test('should handle multiple dispose calls gracefully', () async {
        // Act
        await printer.dispose();
        expect(printer.isDisposed, isTrue);

        // Should not throw on second dispose
        await printer.dispose();
        expect(printer.isDisposed, isTrue);
      });

      test('should throw exception when using disposed printer', () async {
        // Arrange
        await printer.dispose();

        // Act & Assert
        await expectLater(
          printer.startScanning(),
          throwsA(
            isA<ZebraPrinterException>().having(
              (e) => e.message,
              'message',
              contains('disposed'),
            ),
          ),
        );
      });
    });

    group('Error Handling', () {
      test('should handle platform exceptions gracefully', () async {
        // Arrange
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          MethodChannel('ZebraPrinterObject$testPrinterId'),
          (MethodCall methodCall) async {
            throw PlatformException(
              code: 'TEST_ERROR',
              message: 'Test error message',
              details: {'extra': 'info'},
            );
          },
        );

        // Act & Assert
        await expectLater(
          printer.startScanning(),
          throwsA(
            isA<ZebraPrinterException>()
                .having((e) => e.code, 'code', equals('TEST_ERROR'))
                .having((e) => e.message, 'message',
                    contains('Test error message')),
          ),
        );
      });

      test('should provide meaningful error messages', () async {
        // Arrange
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          MethodChannel('ZebraPrinterObject$testPrinterId'),
          (MethodCall methodCall) async {
            throw PlatformException(
              code: 'BLUETOOTH_DISABLED',
              message: 'Bluetooth adapter is disabled',
            );
          },
        );

        // Act & Assert
        try {
          await printer.connectToPrinter(testBluetoothAddress);
          fail('Expected ZebraPrinterException');
        } catch (e) {
          expect(e, isA<ZebraPrinterException>());
          final zebraException = e as ZebraPrinterException;
          expect(zebraException.code, equals('BLUETOOTH_DISABLED'));
          expect(zebraException.message,
              contains('Bluetooth adapter is disabled'));
          expect(zebraException.originalError, isA<PlatformException>());
        }
      });
    });

    group('Threading Safety', () {
      test('should handle concurrent operations without crashes', () async {
        // Arrange
        const concurrentOperations = 10;
        final futures = <Future>[];

        // Act - Execute multiple operations concurrently
        for (int i = 0; i < concurrentOperations; i++) {
          futures.add(printer.print(data: '^XATest$i^XZ'));
          futures.add(printer.setDarkness(50));
          if (i % 2 == 0) {
            futures.add(printer.connectToPrinter('192.168.1.$i'));
          }
        }

        // Assert - All operations should complete without throwing
        await Future.wait(futures);
      });

      test('should maintain state consistency under concurrent access', () {
        fakeAsync((async) {
          // Arrange
          const iterations = 100;
          var rotationCount = 0;

          // Act - Rapidly toggle rotation from multiple "threads"
          for (int i = 0; i < iterations; i++) {
            async.flushMicrotasks();
            printer.rotate();
            rotationCount++;
          }

          // Assert - Final state should be consistent
          expect(printer.isRotated, equals(rotationCount % 2 == 1));
        });
      });
    });
  });
}

// Helper methods for simulating platform callbacks
Future<void> _simulatePrintComplete(String printerId) async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    'ZebraPrinterObject$printerId',
    const StandardMethodCodec().encodeMethodCall(
      const MethodCall('onPrintComplete', null),
    ),
    (data) {},
  );
}

Future<void> _simulatePrintError(String printerId, String error) async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    'ZebraPrinterObject$printerId',
    const StandardMethodCodec().encodeMethodCall(
      MethodCall('onPrintError', {'ErrorText': error}),
    ),
    (data) {},
  );
}

Future<void> _simulatePrinterFound(
    String printerId, Map<String, String> device) async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    'ZebraPrinterObject$printerId',
    const StandardMethodCodec().encodeMethodCall(
      MethodCall('printerFound', device),
    ),
    (data) {},
  );
}

Future<void> _simulatePrinterRemoved(
    String printerId, Map<String, String> event) async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    'ZebraPrinterObject$printerId',
    const StandardMethodCodec().encodeMethodCall(
      MethodCall('printerRemoved', event),
    ),
    (data) {},
  );
}

Future<void> _simulateDiscoveryError(
    String printerId, Map<String, String> error) async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    'ZebraPrinterObject$printerId',
    const StandardMethodCodec().encodeMethodCall(
      MethodCall('onDiscoveryError', error),
    ),
    (data) {},
  );
}
