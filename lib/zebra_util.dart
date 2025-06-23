import 'dart:async';

import 'package:flutter/services.dart';
import 'package:zebrautil/zebra_printer.dart';

class ZebraUtil {
  static const MethodChannel _channel = const MethodChannel('zebrautil');

  static Future<ZebraPrinter> getPrinterInstance(
      {OnDiscoveryError? onDiscoveryError,
      OnPermissionDenied? onPermissionDenied,
      OnPrintComplete? onPrintComplete,
      OnPrintError? onPrintError,
      ZebraController? controller}) async {
    String id = await _channel.invokeMethod("getInstance");
    ZebraPrinter printer = ZebraPrinter(id,
        controller: controller,
        onDiscoveryError: onDiscoveryError,
        onPermissionDenied: onPermissionDenied,
        onPrintComplete: onPrintComplete,
        onPrintError: onPrintError);
    return printer;
  }
}
