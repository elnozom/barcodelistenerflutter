import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKeyEvent);

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
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    _keyStreamSubscription.cancel();
    _logicalKeyStreamSubscription.cancel();
    _keyStreamController.close();
    _logicalKeyStreamController.close();
    super.dispose();
  }

  bool _onKeyEvent(KeyEvent event) {
    if ((!widget.useKeyDownEvent && event is KeyUpEvent) ||
        (widget.useKeyDownEvent && event is KeyDownEvent)) {
      String? char = _getCharacterFromEvent(event);
      if (char != null) {
        _keyStreamController.add(char);
      }
    }
    return true;
  }

  String? _getCharacterFromEvent(KeyEvent event) {
    final String? char = event.character;
    if (char != null && char.isNotEmpty) {
      return char;
    }
    return null;
  }

  void _handleKeyEvent(String? char) {
    _clearOldBufferedChars();
    _lastEventTime = DateTime.now();
    _bufferedChars.add(char!);
    final barcode = _bufferedChars.join();
    widget.onBarcodeScanned(barcode);
  }

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
      // Map F1-F12 keys
      return "F${logicalKey.keyId - LogicalKeyboardKey.f1.keyId + 1}";
    }
    return ""; // Return empty string if no mapping
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
    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: (KeyEvent event) {
          if (event is KeyDownEvent) {
            String? char = event.character;
            final logicalKey = event.logicalKey;
            if (char != null) {
              _keyStreamController.add(char);
            }
            _logicalKeyStreamController.add(logicalKey);
          }
        },
        child: widget.child,
      ),
    );
  }
}
