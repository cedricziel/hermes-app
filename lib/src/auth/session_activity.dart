import 'package:flutter/foundation.dart';

import 'auth_controller.dart';
import 'verified_session_owner.dart';

/// Captures one session owner; retirement is permanent even after later sign-in.
class SessionActivity extends ChangeNotifier implements ValueListenable<bool> {
  SessionActivity(this._auth)
    : _owner = _auth.verifiedOwner,
      _ownerGeneration = _auth.ownerGeneration,
      _expiryGeneration = _auth.sessionExpiryGeneration {
    _auth.addListener(_changed);
    _changed();
  }

  final AuthController _auth;
  final VerifiedSessionOwner? _owner;
  final int _ownerGeneration;
  int _expiryGeneration;
  bool _value = false;
  bool _retired = false;
  bool _recovering = false;

  @override
  bool get value => _value;
  bool get retired => _retired;

  void _changed() {
    if (_retired) return;
    final ready = _auth.state == HermesConnectionState.ready;
    final authorized = _auth.protectedRequestsAllowed;
    if (_owner == null || _auth.ownerGeneration != _ownerGeneration) {
      _retired = true;
    } else if (!authorized) {
      final freshExpiry = _auth.sessionExpiryGeneration > _expiryGeneration;
      if (freshExpiry) {
        if (_auth.expiredOwner != _owner) {
          _retired = true;
        } else {
          _recovering = true;
          _expiryGeneration = _auth.sessionExpiryGeneration;
        }
      } else if (!_recovering) {
        _retired = true;
      }
    } else if (_auth.verifiedOwner != _owner) {
      _retired = true;
    } else if (ready) {
      _recovering = false;
      _expiryGeneration = _auth.sessionExpiryGeneration;
    }
    _setValue(!_retired && ready && authorized);
  }

  void _setValue(bool next) {
    if (_value == next) return;
    _value = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _auth.removeListener(_changed);
    _retired = true;
    _setValue(false);
    super.dispose();
  }
}
