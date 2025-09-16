// This floating mouse widgets are used to simulate a physical mouse
// when "mobile" -> "desktop" in mouse mode.
// This file does not contain a whole mouse widgets, it only contains
// parts that help to control, such as wheel scroll and wheel button.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/remote_input.dart';
import 'package:flutter_hbb/mobile/widgets/floating_mouse.dart';
import 'package:flutter_hbb/models/input_model.dart';
import 'package:flutter_hbb/models/model.dart';

// Used for the wheel button and wheel scroll widgets
const double _kSpaceToRightEdge = 25;
const double _wheelWidth = 50;
const double _wheelHeight = 162;
// Used for the left/right button widgets
const double _kSpaceToBottomEdge = 82;
const double _kSpaceBetweenLeftRightButtons = 40;
const double _kLeftRightButtonWidth = 55;
const double _kLeftRightButtonHeight = 40;
final Color _kDefaultColor = Colors.grey.withOpacity(0.7);
final Color _kTapDownColor = Colors.blue.withOpacity(0.7);

class FloatingMouseWidgets extends StatefulWidget {
  final FFI ffi;
  const FloatingMouseWidgets({
    super.key,
    required this.ffi,
  });

  @override
  State<FloatingMouseWidgets> createState() => _FloatingMouseWidgetsState();
}

class _FloatingMouseWidgetsState extends State<FloatingMouseWidgets> {
  InputModel get _inputModel => widget.ffi.inputModel;
  CursorModel get _cursorModel => widget.ffi.cursorModel;

  @override
  void initState() {
    super.initState();
    _cursorModel.blockEvents = false;
    isSpecialHoldDragActive = false;
  }

  @override
  void dispose() {
    super.dispose();
    _cursorModel.blockEvents = false;
    isSpecialHoldDragActive = false;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FloatingWheel(
          inputModel: _inputModel,
          cursorModel: _cursorModel,
        ),
        FloatingLeftRightButton(
          isLeft: true,
          inputModel: _inputModel,
          cursorModel: _cursorModel,
        ),
        FloatingLeftRightButton(
          isLeft: false,
          inputModel: _inputModel,
          cursorModel: _cursorModel,
        ),
      ],
    );
  }
}

class FloatingWheel extends StatefulWidget {
  final InputModel inputModel;
  final CursorModel cursorModel;
  const FloatingWheel(
      {super.key, required this.inputModel, required this.cursorModel});

  @override
  State<FloatingWheel> createState() => _FloatingWheelState();
}

class _FloatingWheelState extends State<FloatingWheel> {
  Offset _position = Offset.zero;
  Rect? _lastBlockedRect;

  bool _isUpDown = false;
  bool _isMidDown = false;
  bool _isDownDown = false;

  Timer? _scrollTimer;

  InputModel get _inputModel => widget.inputModel;
  CursorModel get _cursorModel => widget.cursorModel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resetPosition();
    });
  }

  void _resetPosition() {
    final size = MediaQuery.of(context).size;
    setState(() {
      _position = Offset(
        size.width - _wheelWidth - _kSpaceToRightEdge,
        (size.height - _wheelHeight) / 2,
      );
      _updateBlockedRect();
    });
  }

  void _updateBlockedRect() {
    if (_lastBlockedRect != null) {
      _cursorModel.removeBlockedRect(_lastBlockedRect!);
    }
    final newRect =
        Rect.fromLTWH(_position.dx, _position.dy, _wheelWidth, _wheelHeight);
    _cursorModel.addBlockedRect(newRect);
    _lastBlockedRect = newRect;
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    super.dispose();
  }

  Widget _buildUpDownButton(
      void Function(PointerDownEvent) onPointerDown,
      void Function(PointerUpEvent) onPointerUp,
      void Function(PointerCancelEvent) onPointerCancel,
      bool Function() flagGetter,
      BorderRadiusGeometry borderRadius,
      IconData iconData) {
    return Listener(
      onPointerDown: onPointerDown,
      onPointerUp: onPointerUp,
      onPointerCancel: onPointerCancel,
      child: Container(
        width: _wheelWidth,
        height: 55,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(
              color: flagGetter() ? _kTapDownColor : _kDefaultColor, width: 2),
          borderRadius: borderRadius,
        ),
        child: Icon(iconData, color: Colors.grey, size: 32),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: _buildWidget(context),
    );
  }

  Widget _buildWidget(BuildContext context) {
    return Container(
      width: _wheelWidth,
      height: _wheelHeight,
      child: Column(
        children: [
          _buildUpDownButton(
            (event) {
              setState(() {
                _isUpDown = true;
              });
              _startScrollTimer(1);
            },
            (event) {
              setState(() {
                _isUpDown = false;
              });
              _stopScrollTimer();
            },
            (event) {
              setState(() {
                _isUpDown = false;
              });
              _stopScrollTimer();
            },
            () => _isUpDown,
            BorderRadius.vertical(top: Radius.circular(_wheelWidth * 0.5)),
            Icons.keyboard_arrow_up,
          ),
          Listener(
            onPointerDown: (event) {
              setState(() {
                _isMidDown = true;
              });
              _inputModel.tapDown(MouseButtons.wheel);
            },
            onPointerUp: (event) {
              setState(() {
                _isMidDown = false;
              });
              _inputModel.tapUp(MouseButtons.wheel);
            },
            onPointerCancel: (event) {
              setState(() {
                _isMidDown = false;
              });
              _inputModel.tapUp(MouseButtons.wheel);
            },
            child: Container(
              width: _wheelWidth,
              height: 52,
              decoration: BoxDecoration(
                border: Border.symmetric(
                    vertical: BorderSide(
                        color: _isMidDown ? _kTapDownColor : _kDefaultColor,
                        width: 2)),
              ),
              child: Center(
                child: Container(
                  width: _wheelWidth - 10,
                  height: _wheelWidth - 10,
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: _isMidDown ? _kTapDownColor : _kDefaultColor,
                        width: 2),
                    shape: BoxShape.circle,
                  ),
                  child: CustomPaint(
                    painter: FourArrowsPainter(2.5,
                        color: _isMidDown ? _kTapDownColor : Colors.grey),
                    size: Size(_wheelWidth, 52),
                  ),
                ),
              ),
            ),
          ),
          _buildUpDownButton(
            (event) {
              setState(() {
                _isDownDown = true;
              });
              _startScrollTimer(-1);
            },
            (event) {
              setState(() {
                _isDownDown = false;
              });
              _stopScrollTimer();
            },
            (event) {
              setState(() {
                _isDownDown = false;
              });
              _stopScrollTimer();
            },
            () => _isDownDown,
            BorderRadius.vertical(bottom: Radius.circular(_wheelWidth * 0.5)),
            Icons.keyboard_arrow_down,
          ),
        ],
      ),
    );
  }

  void _startScrollTimer(int direction) {
    _scrollTimer?.cancel();
    _inputModel.scroll(direction);
    _scrollTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      _inputModel.scroll(direction);
    });
  }

  void _stopScrollTimer() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
  }
}

class FloatingLeftRightButton extends StatefulWidget {
  final bool isLeft;
  final InputModel inputModel;
  final CursorModel cursorModel;
  const FloatingLeftRightButton(
      {super.key,
      required this.isLeft,
      required this.inputModel,
      required this.cursorModel});

  @override
  State<FloatingLeftRightButton> createState() =>
      _FloatingLeftRightButtonState();
}

class _FloatingLeftRightButtonState extends State<FloatingLeftRightButton> {
  Offset _position = Offset.zero;
  bool _isDown = false;
  Rect? _lastBlockedRect;

  bool get _isLeft => widget.isLeft;
  InputModel get _inputModel => widget.inputModel;
  CursorModel get _cursorModel => widget.cursorModel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resetPosition();
    });
  }

  @override
  void dispose() {
    if (_lastBlockedRect != null) {
      _cursorModel.removeBlockedRect(_lastBlockedRect!);
    }
    super.dispose();
  }

  double _getOffsetX(double w) {
    if (_isLeft) {
      return (w - _kLeftRightButtonWidth * 2 - _kSpaceBetweenLeftRightButtons) *
          0.5;
    } else {
      return (w + _kSpaceBetweenLeftRightButtons) * 0.5;
    }
  }

  void _resetPosition() {
    final size = MediaQuery.of(context).size;
    setState(() {
      _position = Offset(_getOffsetX(size.width),
          size.height - _kSpaceToBottomEdge - _kLeftRightButtonHeight);
      _updateBlockedRect();
    });
  }

  void _updateBlockedRect() {
    if (_lastBlockedRect != null) {
      _cursorModel.removeBlockedRect(_lastBlockedRect!);
    }
    final newRect = Rect.fromLTWH(_position.dx, _position.dy,
        _kLeftRightButtonWidth, _kLeftRightButtonHeight);
    _cursorModel.addBlockedRect(newRect);
    _lastBlockedRect = newRect;
  }

  void _onMoveUpdateDelta(Offset delta) {
    final context = this.context;
    final size = MediaQuery.of(context).size;
    Offset newPosition = _position + delta;
    double minX = 0;
    double minY = 0;
    double maxX = size.width - _kLeftRightButtonWidth - _kSpaceToRightEdge;
    double maxY = size.height - _kLeftRightButtonHeight - _kSpaceToBottomEdge;
    newPosition = Offset(
      newPosition.dx.clamp(minX, maxX),
      newPosition.dy.clamp(minY, maxY),
    );
    setState(() {
      final isPositionChanged = !(isDoubleEqual(newPosition.dx, _position.dx) &&
          isDoubleEqual(newPosition.dy, _position.dy));
      _position = newPosition;
      if (isPositionChanged) {
        _updateBlockedRect();
      }
    });
  }

  void _onBodyPointerMoveUpdate(PointerMoveEvent event) =>
      _onMoveUpdateDelta(event.delta);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: Listener(
        onPointerMove: _onBodyPointerMoveUpdate,
        onPointerDown: (event) async {
          setState(() {
            _isDown = true;
          });
          isSpecialHoldDragActive = true;
          // Sync cursor position to avoid the jumpy behavior.
          await _cursorModel.syncCursorPosition();
          await _inputModel.tapDown(_isLeft ? MouseButtons.left : MouseButtons.right);
        },
        onPointerUp: (event) {
          setState(() {
            _isDown = false;
          });
          isSpecialHoldDragActive = false;
          _inputModel.tapUp(_isLeft ? MouseButtons.left : MouseButtons.right);
        },
        onPointerCancel: (event) {
          setState(() {
            _isDown = false;
          });
          isSpecialHoldDragActive = false;
          _inputModel.tapUp(_isLeft ? MouseButtons.left : MouseButtons.right);
        },
        child: Container(
          width: _kLeftRightButtonWidth,
          height: _kLeftRightButtonHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(
                color: _isDown ? _kTapDownColor : _kDefaultColor, width: 2),
            borderRadius: _isLeft
                ? BorderRadius.horizontal(
                    left: Radius.circular(_kLeftRightButtonHeight * 0.5))
                : BorderRadius.horizontal(
                    right: Radius.circular(_kLeftRightButtonHeight * 0.5)),
          ),
        ),
      ),
    );
  }
}
