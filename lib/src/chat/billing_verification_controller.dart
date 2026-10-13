import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_otel/flutter_otel.dart';
import 'package:url_launcher/url_launcher.dart';

import '../telemetry/breadcrumbs.dart';
import 'browser_verification_url.dart';
import 'gateway/gateway_rpc_client.dart';

typedef BillingStepUpRequest = Future<Map<String, Object?>> Function(
  Map<String, Object?> params,
);

enum BillingVerificationStatus {
  idle,
  pending,
  granted,
  refused,
  unavailable,
  failed,
}

class BillingVerificationScope {
  const BillingVerificationScope({
    required this.connection,
    required this.attachment,
    required this.sessionId,
    this.profile,
  });
  final Object connection, attachment;
  final String sessionId;
  final String? profile;
  @override
  bool operator ==(Object other) =>
      other is BillingVerificationScope &&
      connection == other.connection &&
      attachment == other.attachment &&
      sessionId == other.sessionId &&
      profile == other.profile;
  @override
  int get hashCode => Object.hash(connection, attachment, sessionId, profile);
}

class BillingVerificationDetails {
  const BillingVerificationDetails(this.verificationUrl, this.userCode);
  final String verificationUrl, userCode;
  Uri? get browserUri => browserVerificationUrl(verificationUrl);
  static BillingVerificationDetails? decode(Object? raw) {
    if (raw is! Map ||
        raw['verification_url'] is! String ||
        raw['user_code'] is! String) {
      return null;
    }
    return BillingVerificationDetails(
      raw['verification_url'] as String,
      raw['user_code'] as String,
    );
  }
}

class BillingVerificationController extends ChangeNotifier {
  BillingVerificationController({
    DateTime Function()? now,
    Future<bool> Function(Uri)? openBrowser,
    Future<void> Function(String)? copyCode,
    this.events = noopAppEventLogger,
    this.breadcrumbs = Breadcrumbs.none,
  }) : _now = now ?? DateTime.now,
       _openBrowser =
           openBrowser ??
           ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication)),
       _copyCode =
           copyCode ?? ((code) => Clipboard.setData(ClipboardData(text: code)));
  final DateTime Function() _now;
  final Future<bool> Function(Uri) _openBrowser;
  final Future<void> Function(String) _copyCode;
  final AppEventLogger events;
  final Breadcrumbs breadcrumbs;
  BillingVerificationScope? _scope;
  BillingStepUpRequest? _request;
  bool Function()? _authorize, _isSupported;
  Timer? _retryTimer;
  int _generation = 0;
  bool _supported = true, _locked = false, _disposed = false;
  BillingVerificationStatus status = BillingVerificationStatus.idle;
  BillingVerificationDetails? verification;
  DateTime? retryAt;
  String? message;
  int get generation => _generation;
  bool get locked => _locked;
  bool get supported => _supported && (_isSupported?.call() ?? true);
  bool get canStart =>
      !_disposed &&
      !_locked &&
      supported &&
      _scope?.sessionId.isNotEmpty == true &&
      _scope?.profile?.isNotEmpty == true &&
      (_authorize?.call() ?? true) &&
      _request != null &&
      status != BillingVerificationStatus.pending &&
      (retryAt == null || !_now().isBefore(retryAt!));
  bool get canOpenVerification =>
      !_disposed &&
      !_locked &&
      _scope != null &&
      (_authorize?.call() ?? true) &&
      verification?.browserUri != null;
  bool get canCopyCode =>
      !_disposed &&
      !_locked &&
      _scope != null &&
      (_authorize?.call() ?? true) &&
      verification?.userCode.isNotEmpty == true;

  void bind(
    BillingVerificationScope? scope, {
    BillingStepUpRequest? request,
    bool Function()? authorize,
    bool Function()? supported,
  }) {
    if (_disposed) return;
    _authorize = authorize;
    _isSupported = supported;
    final hadRequest = _request != null;
    _request = request;
    if (_scope == scope) {
      if (hadRequest != (_request != null)) notifyListeners();
      return;
    }
    if (_scope?.connection != scope?.connection) _supported = true;
    _generation++;
    _scope = scope;
    verification = null;
    status = BillingVerificationStatus.idle;
    message = null;
    retryAt = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    notifyListeners();
  }

  bool acceptVerification(Object? payload, {required Object attachment}) {
    if (_disposed ||
        _locked ||
        _scope == null ||
        _scope!.attachment != attachment ||
        _authorize?.call() == false) {
      return false;
    }
    final details = BillingVerificationDetails.decode(payload);
    if (details == null) {
      _log('malformed');
      return false;
    }
    final generation = _generation;
    verification = details;
    if (status != BillingVerificationStatus.pending) {
      status = BillingVerificationStatus.idle;
    }
    _log('details');
    if (_disposed ||
        _locked ||
        generation != _generation ||
        !identical(verification, details) ||
        _authorize?.call() == false) {
      return false;
    }
    notifyListeners();
    return true;
  }

  void setLocked(bool locked) {
    if (_disposed || _locked == locked) return;
    _locked = locked;
    if (locked) verification = null;
    notifyListeners();
  }

  Future<void> start({int? expectedGeneration}) async {
    if ((expectedGeneration != null && expectedGeneration != _generation) ||
        !canStart) {
      return;
    }
    final scope = _scope!, request = _request!, generation = _generation;
    status = BillingVerificationStatus.pending;
    verification = null;
    message = null;
    retryAt = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _action('verify');
    if (_disposed || generation != _generation) return;
    notifyListeners();
    try {
      if (_disposed ||
          generation != _generation ||
          _locked ||
          _scope != scope ||
          !identical(request, _request) ||
          _authorize?.call() == false ||
          !supported) {
        if (!_disposed &&
            generation == _generation &&
            status == BillingVerificationStatus.pending) {
          status = BillingVerificationStatus.idle;
        }
        return;
      }
      final result = await request({
        'session_id': scope.sessionId,
        if (scope.profile != null) 'profile': scope.profile,
      });
      if (_disposed || generation != _generation) return;
      verification = null;
      if (result['ok'] is! bool ||
          (result['granted'] != null && result['granted'] is! bool)) {
        status = BillingVerificationStatus.failed;
        message = 'The server returned an unreadable billing response.';
      } else if (result['ok'] == true && result['granted'] == true) {
        status = BillingVerificationStatus.granted;
      } else {
        status = BillingVerificationStatus.refused;
        message = 'The server did not grant billing access.';
      }
      final retry = result['retry_after'];
      if (status != BillingVerificationStatus.granted &&
          retry is num &&
          retry.isFinite &&
          retry >= 0 &&
          retry <= 8640000000000) {
        try {
          retryAt = _now().add(Duration(milliseconds: (retry * 1000).ceil()));
          final delay = retryAt!.difference(_now());
          if (delay > Duration.zero) {
            _retryTimer = Timer(delay, () {
              if (!_disposed && generation == _generation) notifyListeners();
            });
          }
        } on RangeError {
          status = BillingVerificationStatus.failed;
          message = 'The server returned an unreadable retry time.';
        }
      }
      _log(status.name);
    } on Object catch (error) {
      if (_disposed || generation != _generation) return;
      verification = null;
      if (error is GatewayRpcException &&
          error.code == kGatewayMethodNotFound) {
        _supported = false;
        status = BillingVerificationStatus.unavailable;
        message = 'Billing verification is unavailable on this connection.';
      } else {
        status = BillingVerificationStatus.failed;
        message =
            'Billing verification was refused or the connection was lost.';
      }
      _log(status.name);
    } finally {
      if (!_disposed && generation == _generation) notifyListeners();
    }
  }

  bool _currentDetails(BillingVerificationDetails? expected, int? generation) =>
      !_disposed &&
      (_authorize?.call() ?? true) &&
      (expected == null || identical(expected, verification)) &&
      (generation == null || generation == _generation);
  Future<void> openVerification({
    BillingVerificationDetails? expectedDetails,
    int? expectedGeneration,
  }) async {
    if (!canOpenVerification ||
        !_currentDetails(expectedDetails, expectedGeneration)) {
      return;
    }
    final details = verification!, generation = _generation;
    _action('browser');
    if (!canOpenVerification || !_currentDetails(details, generation)) return;
    try {
      final opened = await _openBrowser(details.browserUri!);
      if (_disposed || _locked || !_currentDetails(details, generation)) return;
      if (!opened) message = 'Could not open the browser.';
      _log(opened ? 'browser_opened' : 'browser_failed');
    } on Object {
      if (_disposed || _locked || !_currentDetails(details, generation)) return;
      message = 'Could not open the browser.';
      _log('browser_failed');
    }
    if (!_disposed && generation == _generation) notifyListeners();
  }

  Future<void> copyVerificationCode({
    BillingVerificationDetails? expectedDetails,
    int? expectedGeneration,
  }) async {
    if (!canCopyCode || !_currentDetails(expectedDetails, expectedGeneration)) {
      return;
    }
    final details = verification!, generation = _generation;
    final code = details.userCode;
    _action('copy_code');
    if (!canCopyCode || !_currentDetails(details, generation)) return;
    try {
      await _copyCode(code);
      if (_disposed || _locked || !_currentDetails(details, generation)) return;
      _log('copied');
    } on Object {
      if (_disposed || _locked || !_currentDetails(details, generation)) return;
      message = 'Could not copy the code.';
      _log('copy_failed');
      notifyListeners();
    }
  }

  void detailsOpened() => _action('details');
  void _action(String action) => breadcrumbs('chat.visibility_action', {
    'feature': 'billing_verification',
    'action': action,
  });
  void _log(String outcome) {
    try {
      events('gateway.visibility_outcome', {
        'feature': 'billing_verification',
        'outcome': outcome,
      });
    } on Object {
      return;
    }
  }

  int _notificationDepth = 0;

  @override
  void notifyListeners() {
    if (_disposed) return;
    _notificationDepth++;
    try {
      super.notifyListeners();
    } finally {
      _notificationDepth--;
      if (_disposed && _notificationDepth == 0) super.dispose();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    verification = null;
    _retryTimer?.cancel();
    if (_notificationDepth == 0) super.dispose();
  }
}
