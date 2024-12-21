import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
      // Handle NumPad keys and standard keys
      LogicalKeyboardKey logicalKey = event.logicalKey;

      // Add logical key events to the stream
      if (logicalKey != LogicalKeyboardKey.unidentified) {
        _logicalKeyStreamController.add(logicalKey);
      }
      String? char = logicalKey.keyLabel;
      if (kIsWeb ||
          Platform.isWindows ||
          Platform.isLinux ||
          Platform.isMacOS) {
        if (char == null || char.isEmpty) {
          // Handle NumPad keys explicitly
          char = _getNumPadKeyLabel(logicalKey);
        }
      }
      // Extract character for standard keys
      if (char != null && char.isNotEmpty) {
        _keyStreamController.add(char);
      }
    }
  }

  String _getNumPadKeyLabel(LogicalKeyboardKey logicalKey) {
    if (logicalKey == LogicalKeyboardKey.numpad0) return '0';
    if (logicalKey == LogicalKeyboardKey.numpad1) return '1';
    if (logicalKey == LogicalKeyboardKey.numpad2) return '2';
    if (logicalKey == LogicalKeyboardKey.numpad3) return '3';
    if (logicalKey == LogicalKeyboardKey.numpad4) return '4';
    if (logicalKey == LogicalKeyboardKey.numpad5) return '5';
    if (logicalKey == LogicalKeyboardKey.numpad6) return '6';
    if (logicalKey == LogicalKeyboardKey.numpad7) return '7';
    if (logicalKey == LogicalKeyboardKey.numpad8) return '8';
    if (logicalKey == LogicalKeyboardKey.numpad9) return '9';
    if (logicalKey == LogicalKeyboardKey.numpadDecimal) return '.';
    if (logicalKey == LogicalKeyboardKey.numpadEnter) return 'enter';
    return '';
  }

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
    if (logicalKey == LogicalKeyboardKey.backspace) {
      return "backspace";
    } else if (logicalKey == LogicalKeyboardKey.enter) {
      return "enter";
    } else if (logicalKey == LogicalKeyboardKey.space) {
      return "space";
    } else if (logicalKey.keyId >= LogicalKeyboardKey.f1.keyId &&
        logicalKey.keyId <= LogicalKeyboardKey.f12.keyId) {
      return "F${logicalKey.keyId - LogicalKeyboardKey.f1.keyId + 1}";
    }
    return "";
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
    if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: (RawKeyEvent event) {
          _onKeyEvent(event);
        },
        child: widget.child,
      );
    } else {
      final focusNode = FocusNode();
      focusNode.requestFocus();
      return GestureDetector(
        onTap: () => focusNode.requestFocus(),
        child: Focus(
          autofocus: true,
          focusNode: focusNode,
          onKey: (FocusNode node, RawKeyEvent event) {
            _onKeyEvent(event);
            return KeyEventResult.handled;
          },
          child: widget.child,
        ),
      );
    }
  }
}
