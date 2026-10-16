import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

typedef ProfileAssetRequest = Future<Map<String, Object?>> Function(
  String method,
  Map<String, Object?> params,
);

/// Reads avatars through one authenticated server/account connection.
/// Dispose this repository when that connection's account or server changes.
class ProfileAvatarRepository extends ChangeNotifier {
  ProfileAvatarRepository(
    this._request, {
    required this.serverId,
    required this.accountId,
  });

  final ProfileAssetRequest _request;
  final String serverId;
  final String accountId;
  final _pending = <String, Future<Uint8List?>>{};
  final _images = <Uint8List>[];
  bool _closed = false;

  /// Returns configured PNG, JPEG or WebP bytes, or null for unavailable assets.
  /// External URLs are never fetched. Names must be canonical profile names.
  Future<Uint8List?> load(String profile) {
    if (_closed || profile.isEmpty) return Future.value();
    return _pending.putIfAbsent(profile, () => _read(profile));
  }

  Future<Uint8List?> _read(String profile) async {
    try {
      final response = await _request('profiles.get_asset', {
        'name': profile,
        'asset': 'avatar',
      });
      if (_closed || response['found'] != true) return null;
      final value = response['data'];
      if (value is! String || value.length > 7 * 1024 * 1024) return null;
      final data = UriData.parse(value);
      if (!data.isBase64 ||
          !const {
            'image/png',
            'image/jpeg',
            'image/webp',
          }.contains(data.mimeType)) {
        return null;
      }
      final bytes = data.contentAsBytes();
      if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) return null;
      _images.add(bytes);
      return bytes;
    } on Object {
      return null;
    }
  }

  @override
  void dispose() {
    _closed = true;
    _pending.clear();
    for (final bytes in _images) {
      unawaited(MemoryImage(bytes).evict());
    }
    _images.clear();
    notifyListeners();
    super.dispose();
  }
}
