import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'drag_file_format.dart';
import 'drag_out_item.dart';
import 'drag_out_source.dart';
import 'drag_out_telemetry.dart';

/// The channel `macos/Runner/DragOut.swift` listens on.
const dragOutChannelName = 'hermes_app/drag_out';

/// How far the pointer moves with the button down before a drag starts, in
/// logical pixels. A click, or a small slip while clicking, stays a click.
const dragOutSlop = 6.0;

/// The drag-out source of the macOS app: a drag out of a widget starts a
/// native dragging session in the Flutter view through [dragOutChannelName].
///
/// A file goes out as a file promise: the receiver names the folder, and the
/// bytes are produced by [DragOutFile.read] only then. Text goes out as plain
/// text and Markdown. Nothing is left on the pasteboard after the drag.
///
/// Everything else in the app goes through [DragOutSource], so this class and
/// the Swift file are the only platform code.
class MacDragOutSource implements DragOutSource {
  MacDragOutSource({
    this.telemetry = const DragOutTelemetry(),
    this._channel = const MethodChannel(dragOutChannelName),
  }) {
    _channel.setMethodCallHandler(_onCall);
  }

  final DragOutTelemetry telemetry;
  final MethodChannel _channel;
  final _drags = <int, _Drag>{};
  var _lastId = 0;

  /// Whether this platform can drag out: macOS only. `main.dart` provides a
  /// source only where this holds.
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Widget wrap({
    required DragOutKind kind,
    required DragOutItem? Function() item,
    required Widget child,
  }) => _DragStarter(
    item: item,
    onDrag: (item) => unawaited(_begin(kind, item)),
    child: child,
  );

  Future<void> _begin(DragOutKind kind, DragOutItem item) async {
    final id = ++_lastId;
    final arguments = switch (item) {
      DragOutFile() => {
        'id': id,
        'type': 'file',
        'name': item.name,
        'fileType': dragFileType(item.name),
      },
      DragOutText() => {'id': id, 'type': 'text', 'text': item.text},
    };
    _drags[id] = _Drag(kind, item is DragOutFile ? item : null);
    try {
      final began =
          await _channel.invokeMethod<bool>('startDrag', arguments) ?? false;
      if (began) {
        telemetry.started(kind);
      } else {
        _drags.remove(id);
      }
    } on Object {
      // A drag the system refuses is not started; the click still works.
      _drags.remove(id);
    }
  }

  Future<Object?> _onCall(MethodCall call) async {
    final arguments = call.arguments;
    switch (call.method) {
      case 'readFile':
        return _read(arguments as int);
      case 'fileWritten':
        _written(arguments as Map);
      case 'ended':
        _ended(arguments as Map);
      default:
        throw MissingPluginException(call.method);
    }
    return null;
  }

  /// The receiver asked for a promised file: produce its bytes, or fail the
  /// request so the receiver gets no file.
  Future<Uint8List> _read(int id) async {
    final drag = _drags[id];
    final file = drag?.file;
    if (drag == null || file == null) {
      throw PlatformException(code: 'gone');
    }
    drag.reading = true;
    Uint8List? bytes;
    await telemetry.promise(drag.kind, () async {
      try {
        bytes = await file.read();
        return DragOutOutcome.delivered;
      } on Object {
        return DragOutOutcome.failed;
      }
    });
    final read = bytes;
    if (read == null) {
      _drags.remove(id);
      telemetry.completed(
        drag.kind,
        DragOutOutcome.failed,
        failure: DragOutFailure.fetch,
      );
      throw PlatformException(code: 'fetch');
    }
    return read;
  }

  void _written(Map arguments) {
    final drag = _drags.remove(arguments['id']);
    if (drag == null) return;
    final ok = arguments['ok'] == true;
    telemetry.completed(
      drag.kind,
      ok ? DragOutOutcome.delivered : DragOutOutcome.failed,
      failure: ok ? null : DragOutFailure.write,
    );
  }

  /// The session ended. Text is done: a receiver took it or none did. A file
  /// is done only when no receiver took it; otherwise it waits for the write.
  void _ended(Map arguments) {
    final id = arguments['id'];
    final drag = _drags[id];
    if (drag == null) return;
    final copied = arguments['copied'] == true;
    if (drag.file != null && (copied || drag.reading)) return;
    _drags.remove(id);
    telemetry.completed(
      drag.kind,
      copied ? DragOutOutcome.delivered : DragOutOutcome.cancelled,
    );
  }
}

class _Drag {
  _Drag(this.kind, this.file);

  final DragOutKind kind;

  /// Null for text.
  final DragOutFile? file;

  /// The receiver has asked for the bytes.
  var reading = false;
}

/// Watches the pointer over its child and starts a drag when the primary
/// mouse button moves [dragOutSlop] while down. It sits in the pointer
/// stream, not the gesture arena, so taps, selection and scrolling in and
/// around the child behave as without it.
class _DragStarter extends StatefulWidget {
  const _DragStarter({
    required this.item,
    required this.onDrag,
    required this.child,
  });

  final DragOutItem? Function() item;
  final ValueChanged<DragOutItem> onDrag;
  final Widget child;

  @override
  State<_DragStarter> createState() => _DragStarterState();
}

class _DragStarterState extends State<_DragStarter> {
  Offset? _origin;

  void _down(PointerDownEvent event) {
    final primary =
        event.kind == PointerDeviceKind.mouse &&
        event.buttons == kPrimaryMouseButton;
    _origin = primary ? event.position : null;
  }

  void _move(PointerMoveEvent event) {
    final origin = _origin;
    if (origin == null || (event.position - origin).distance < dragOutSlop) {
      return;
    }
    // Once per press, whether or not there is anything to drag.
    _origin = null;
    final item = widget.item();
    if (item != null) widget.onDrag(item);
  }

  void _end(PointerEvent event) => _origin = null;

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _down,
    onPointerMove: _move,
    onPointerUp: _end,
    onPointerCancel: _end,
    child: widget.child,
  );
}
