import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

typedef BarcodeScannedVoidCallBack = void Function(String barcode);

class BarcodeInputListener extends StatefulWidget {
  final Widget child;
  final BarcodeScannedVoidCallBack onBarcodeScanned;
  final Duration bufferDuration;
  final bool useKeyDownEvent;

  const BarcodeInputListener({
    super.key,
    required this.child,
    required this.onBarcodeScanned,
    this.bufferDuration = const Duration(milliseconds: 100),
    this.useKeyDownEvent = false,
  });

  @override
  State<BarcodeInputListener> createState() => _BarcodeInputListenerState();
}

class _BarcodeInputListenerState extends State<BarcodeInputListener> {
  final List<String> _bufferedChars = [];
  DateTime? _lastEventTime;

  late StreamSubscription<String?> _keyStreamSubscription;
  late StreamSubscription<LogicalKeyboardKey?> _logicalKeyStreamSubscription;

  final StreamController<String?> _keyStreamController =
      StreamController<String?>();

  final StreamController<LogicalKeyboardKey?> _logicalKeyStreamController =
      StreamController<LogicalKeyboardKey?>();

  @override
  void initState() {
    super.initState();
    if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // For Web, Windows, Linux, and macOS, set up keyboard event listeners
      RawKeyboard.instance.addListener(_onKeyEvent);
    }
    // Listen for character stream
    _keyStreamSubscription = _keyStreamController.stream
        .where((char) => char != null)
        .listen(_handleKeyEvent);
    // Listen for logical key stream
    _logicalKeyStreamSubscription = _logicalKeyStreamController.stream
        .where((key) => key != null)
        .listen(_handleLogicalKeyEvent);
  }

  @override
  void dispose() {
    RawKeyboard.instance.removeListener(_onKeyEvent);
    _keyStreamSubscription.cancel();
    _logicalKeyStreamSubscription.cancel();
    _keyStreamController.close();
    _logicalKeyStreamController.close();
    super.dispose();
  }

  // This function captures both physical keys and logical keys
  void _onKeyEvent(RawKeyEvent event) {
    if ((!widget.useKeyDownEvent && event is RawKeyUpEvent) ||
        (widget.useKeyDownEvent && event is RawKeyDownEvent)) {
      // Extract the logical key
      LogicalKeyboardKey logicalKey = event.logicalKey;

      if (logicalKey != LogicalKeyboardKey.unidentified) {
        String barcode = _getBarcodeForLogicalKey(logicalKey);
        if (barcode.isNotEmpty) {
          _keyStreamController.add(barcode);
        }
      }
    }
  }

  // Handling key event and sending barcode string
  void _handleKeyEvent(String? char) {
    _clearOldBufferedChars();
    _lastEventTime = DateTime.now();
    _bufferedChars.add(char!);
    final barcode = _bufferedChars.join();
    widget.onBarcodeScanned(barcode);
  }

  // Handling logical key events like Backspace, Enter, etc.
  void _handleLogicalKeyEvent(LogicalKeyboardKey? logicalKey) {
    if (logicalKey != null) {
      String barcodeEvent = _getBarcodeForLogicalKey(logicalKey);
      if (barcodeEvent.isNotEmpty) {
        widget.onBarcodeScanned(barcodeEvent);
      }
    }
  }

  String _getBarcodeForLogicalKey(LogicalKeyboardKey logicalKey) {
    // Map each logical key to a barcode string
    if (logicalKey == LogicalKeyboardKey.backspace) {
      return "backspace";
    } else if (logicalKey == LogicalKeyboardKey.enter) {
      return "enter";
    } else if (logicalKey == LogicalKeyboardKey.space) {
      return "space";
    } else if (logicalKey == LogicalKeyboardKey.tab) {
      return "tab";
    } else if (logicalKey == LogicalKeyboardKey.numpad0) {
      return "0";
    } else if (logicalKey == LogicalKeyboardKey.numpad1) {
      return "1";
    } else if (logicalKey == LogicalKeyboardKey.numpad2) {
      return "2";
    } else if (logicalKey == LogicalKeyboardKey.numpad3) {
      return "3";
    } else if (logicalKey == LogicalKeyboardKey.numpad4) {
      return "4";
    } else if (logicalKey == LogicalKeyboardKey.numpad5) {
      return "5";
    } else if (logicalKey == LogicalKeyboardKey.numpad6) {
      return "6";
    } else if (logicalKey == LogicalKeyboardKey.numpad7) {
      return "7";
    } else if (logicalKey == LogicalKeyboardKey.numpad8) {
      return "8";
    } else if (logicalKey == LogicalKeyboardKey.numpad9) {
      return "9";
    } else if (logicalKey == LogicalKeyboardKey.shiftLeft ||
        logicalKey == LogicalKeyboardKey.shiftRight) {
      return "shift";
    } else if (logicalKey == LogicalKeyboardKey.altLeft ||
        logicalKey == LogicalKeyboardKey.altRight) {
      return "alt";
    } else if (logicalKey == LogicalKeyboardKey.controlLeft ||
        logicalKey == LogicalKeyboardKey.controlRight) {
      return "ctrl";
    }
    // Return key label for alphanumeric keys
    return logicalKey.keyLabel.isNotEmpty ? logicalKey.keyLabel : '';
  }

  void _clearOldBufferedChars() {
    if (_lastEventTime != null &&
        _lastEventTime!
            .isBefore(DateTime.now().subtract(widget.bufferDuration))) {
      _bufferedChars.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode(), // Ensure focus node
      onKey: (RawKeyEvent event) {
        _onKeyEvent(event); // Handle the key event
      },
      child: widget.child,
    );
  }
}
