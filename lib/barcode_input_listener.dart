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
      // Extract the character if it exists
      String? char = event.logicalKey.keyLabel;
      if (char != null && char.isNotEmpty) {
        _keyStreamController.add(char);
      }
      // Extract the logical key
      LogicalKeyboardKey logicalKey = event.logicalKey;
      if (logicalKey != LogicalKeyboardKey.unidentified) {
        _logicalKeyStreamController.add(logicalKey);
      }
    }
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
    } else if (logicalKey == LogicalKeyboardKey.period) {
      return ".";
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
