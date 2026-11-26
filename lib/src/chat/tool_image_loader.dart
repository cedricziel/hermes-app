import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show ChangeNotifier, Listenable, VoidCallback;
import 'package:flutter/painting.dart';

import '../telemetry/breadcrumbs.dart';

/// How a remote image load ended, when it did not.
enum ToolImageOutcome { ok, failed, tooLarge, insecure }

class ToolImageException implements Exception {
  const ToolImageException(this.outcome);

  final ToolImageOutcome outcome;

  @override
  String toString() => 'ToolImageException($outcome)';
}

/// The one place the app requests an image from a host that is not the
/// signed-in server: an address a tool result named, loaded only after the
/// user tapped its tile (`arch.chat-network-image`).
///
/// The request is a plain GET, with no credentials, cookie or session token,
/// over `https` only, within [maxBytes] and [timeout]. A redirect to `http` is
/// not followed; one to another `https` address is, up to three times. The
/// bytes live in this object's memory, never on disk, and so do the frames
/// decoded from them in Flutter's shared image cache: [clear] drops both, and
/// runs on sign-out (which a server change is too) and when App Lock covers
/// the app. It notifies when bytes are dropped, so a tile that showed one
/// goes back to waiting for a tap.
class ToolImageLoader {
  ToolImageLoader({
    Dio? dio,
    this.breadcrumbs = Breadcrumbs.none,
    this.maxBytes = 10 * 1024 * 1024,
    this.timeout = const Duration(seconds: 15),
    this.memoryBudget = 48 * 1024 * 1024,
  }) : _dioOverride = dio;

  /// The loader the app runs: it clears itself when [signedOut] fires (a
  /// server change signs out too) and each time [lock] changes to [locked].
  factory ToolImageLoader.forApp({
    required Breadcrumbs breadcrumbs,
    required Stream<void> signedOut,
    required Listenable lock,
    required bool Function() locked,
  }) => ToolImageLoader(breadcrumbs: breadcrumbs)
    ..clearOnSignOut(signedOut)
    ..clearWhenLocked(lock, locked);

  static const _maxRedirects = 3;

  final _changes = _Changes();

  /// Notifies each time bytes are dropped: [clear], or the memory budget.
  Listenable get changes => _changes;

  final Dio? _dioOverride;
  late final Dio _dio = _dioOverride ?? Dio();
  final Breadcrumbs breadcrumbs;
  final int maxBytes;
  final Duration timeout;

  /// The most bytes kept at once; the oldest image goes first.
  final int memoryBudget;

  // Insertion order is age.
  final _bytes = <String, Uint8List>{};
  final _inflight = <String, Future<Uint8List>>{};
  final _cancels = <CancelToken>{};
  final _providers = <(String, int?), ImageProvider>{};
  var _generation = 0;
  StreamSubscription<void>? _signedOut;
  VoidCallback? _unlisten;

  /// The bytes of [uri] when it is loaded, else null.
  Uint8List? bytesOf(Uri uri) => _bytes[uri.toString()];

  /// Loads [uri], once however many ask. Throws [ToolImageException].
  Future<Uint8List> load(Uri uri) {
    final key = uri.toString();
    final cached = _bytes[key];
    if (cached != null) return Future.value(cached);
    return _inflight.putIfAbsent(key, () => _load(uri, key));
  }

  Future<Uint8List> _load(Uri uri, String key) async {
    final generation = _generation;
    final cancel = CancelToken();
    _cancels.add(cancel);
    var outcome = ToolImageOutcome.ok;
    try {
      final bytes = await _download(uri, cancel).timeout(
        timeout,
        onTimeout: () {
          cancel.cancel();
          throw const ToolImageException(ToolImageOutcome.failed);
        },
      );
      if (generation == _generation) _remember(key, bytes);
      return bytes;
    } on ToolImageException catch (e) {
      outcome = e.outcome;
      rethrow;
    } on Object {
      outcome = ToolImageOutcome.failed;
      throw const ToolImageException(ToolImageOutcome.failed);
    } finally {
      _cancels.remove(cancel);
      if (generation == _generation) unawaited(_inflight.remove(key));
      breadcrumbs('chat.tool_image.loaded', {'outcome': outcome.wire});
    }
  }

  Future<Uint8List> _download(Uri first, CancelToken cancel) async {
    var uri = first;
    for (var hop = 0; ; hop++) {
      if (uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        throw const ToolImageException(ToolImageOutcome.insecure);
      }
      final response = await _dio.getUri<ResponseBody>(
        uri,
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
          validateStatus: (_) => true,
          headers: const {'accept': 'image/*'},
        ),
      );
      final status = response.statusCode ?? 0;
      final body = response.data!;
      if (status >= 300 && status < 400) {
        _discard(body);
        final to = response.headers.value('location');
        if (to == null || hop >= _maxRedirects) {
          throw const ToolImageException(ToolImageOutcome.failed);
        }
        uri = uri.resolve(to);
        continue;
      }
      if (status != 200) {
        _discard(body);
        throw const ToolImageException(ToolImageOutcome.failed);
      }
      final announced = int.tryParse(
        response.headers.value('content-length') ?? '',
      );
      if (announced != null && announced > maxBytes) {
        _discard(body);
        throw const ToolImageException(ToolImageOutcome.tooLarge);
      }
      final bytes = BytesBuilder(copy: false);
      final done = Completer<Uint8List>();
      late final StreamSubscription<Uint8List> reading;
      reading = body.stream.listen(
        (chunk) {
          bytes.add(chunk);
          if (bytes.length > maxBytes && !done.isCompleted) {
            // Not awaited: the rest of the body is never read.
            unawaited(reading.cancel());
            done.completeError(
              const ToolImageException(ToolImageOutcome.tooLarge),
            );
          }
        },
        onError: (Object error) {
          if (!done.isCompleted) done.completeError(error);
        },
        onDone: () {
          if (!done.isCompleted) done.complete(bytes.takeBytes());
        },
        cancelOnError: true,
      );
      return done.future;
    }
  }

  /// Drops the rest of a response that is not wanted, without waiting for it.
  void _discard(ResponseBody body) =>
      unawaited(body.stream.listen(null).cancel());

  void _remember(String key, Uint8List bytes) {
    _bytes[key] = bytes;
    var total = _bytes.values.fold(0, (sum, b) => sum + b.length);
    while (total > memoryBudget && _bytes.length > 1) {
      final oldest = _bytes.keys.first;
      total -= _bytes.remove(oldest)!.length;
      _forgetProviders((k) => k == oldest);
      _changes.notify();
    }
  }

  /// The image of a loaded [uri], decoded at [width] pixels when given (the
  /// tile's size) and in full otherwise (the viewer). The loader keeps the
  /// provider so [clear] can evict its decoded frames from the image cache.
  ImageProvider? imageFor(Uri uri, {int? width}) {
    final bytes = _bytes[uri.toString()];
    if (bytes == null) return null;
    // Widths in steps of 64 px, so a window being resized decodes a few
    // times, not once per pixel.
    final step = width == null ? null : (width + 63) ~/ 64 * 64;
    return _providers[(uri.toString(), step)] ??= ResizeImage.resizeIfNeeded(
      step,
      null,
      MemoryImage(bytes),
    );
  }

  /// Removes the providers of the images [forget] names, and their decoded
  /// frames from the shared image cache.
  Future<void> _forgetProviders(bool Function(String key) forget) {
    final cache = PaintingBinding.instance.imageCache;
    final gone = [
      for (final entry in _providers.entries)
        if (forget(entry.key.$1)) entry.key,
    ];
    return Future.wait([
      for (final key in gone) _providers.remove(key)!.evict(cache: cache),
    ]);
  }

  /// Forgets every image: its bytes, its requests and its decoded frames.
  Future<void> clear() {
    _generation++;
    for (final cancel in _cancels) {
      cancel.cancel();
    }
    _cancels.clear();
    _inflight.clear();
    _bytes.clear();
    _changes.notify();
    return _forgetProviders((_) => true);
  }

  /// Calls [clear] each time [signedOut] fires; a server change signs out.
  void clearOnSignOut(Stream<void> signedOut) {
    _signedOut?.cancel();
    _signedOut = signedOut.listen((_) => unawaited(clear()));
  }

  /// Calls [clear] each time [lock] changes to [locked].
  void clearWhenLocked(Listenable lock, bool Function() locked) {
    _unlisten?.call();
    var was = locked();
    void changed() {
      final now = locked();
      if (now && !was) unawaited(clear());
      was = now;
    }

    lock.addListener(changed);
    _unlisten = () => lock.removeListener(changed);
  }

  void dispose() {
    _signedOut?.cancel();
    _unlisten?.call();
    _changes.dispose();
  }
}

extension on ToolImageOutcome {
  String get wire => switch (this) {
    ToolImageOutcome.ok => 'ok',
    ToolImageOutcome.failed => 'failed',
    ToolImageOutcome.tooLarge => 'too_large',
    ToolImageOutcome.insecure => 'insecure',
  };
}

class _Changes extends ChangeNotifier {
  void notify() => notifyListeners();
}
