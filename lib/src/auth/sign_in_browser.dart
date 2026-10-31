import 'dart:io';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Where a sign-in page is shown. The authorization code always comes back
/// through the loopback listener; the browser only has to show the page.
abstract class SignInBrowser {
  /// The browser for this platform: an [AuthSessionBrowser] on iOS and macOS,
  /// falling back to the external browser when the sheet cannot be shown,
  /// and the external browser elsewhere.
  factory SignInBrowser.platform() => Platform.isIOS || Platform.isMacOS
      ? FallbackSignInBrowser(AuthSessionBrowser(), const ExternalBrowser())
      : const ExternalBrowser();

  /// Shows [url]. Returns false when nothing could be opened.
  ///
  /// [onDismissed] runs when the user closes the browser before the sign-in
  /// reached the loopback listener. A browser that cannot tell never runs it.
  Future<bool> open(Uri url, {required void Function() onDismissed});

  /// Closes what [open] showed, when it is still open.
  Future<void> close();

  /// Where the loopback listener sends the browser once the sign-in reached
  /// it. Null answers with a page saying the tab can be closed. Read when the
  /// sign-in arrives, so it may change once [open] has chosen a browser.
  Uri? get finishedRedirect;
}

/// Shows the page in [primary], or in [fallback] when [primary] cannot.
///
/// AuthenticationServices sometimes refuses to start a sheet (it answers
/// `start()` with false at once) and keeps refusing until the app is
/// relaunched. Without a fallback the sign-in button then does nothing but
/// say the browser could not be opened.
class FallbackSignInBrowser implements SignInBrowser {
  FallbackSignInBrowser(this.primary, this.fallback);

  final SignInBrowser primary;
  final SignInBrowser fallback;
  SignInBrowser? _used;

  /// Whether [open] had to use [fallback].
  bool get fellBack => identical(_used, fallback);

  @override
  Future<bool> open(Uri url, {required void Function() onDismissed}) async {
    _used = primary;
    if (await primary.open(url, onDismissed: onDismissed)) return true;
    _used = fallback;
    return fallback.open(url, onDismissed: onDismissed);
  }

  @override
  Future<void> close() => (_used ?? primary).close();

  @override
  Uri? get finishedRedirect => (_used ?? primary).finishedRedirect;
}

/// Opens the sign-in page in the system's default browser.
class ExternalBrowser implements SignInBrowser {
  const ExternalBrowser();

  @override
  Future<bool> open(Uri url, {required void Function() onDismissed}) =>
      launchUrl(url, mode: LaunchMode.externalApplication);

  @override
  Future<void> close() async {}

  @override
  Uri? get finishedRedirect => null;
}

/// Shows the sign-in page in an `ASWebAuthenticationSession` sheet
/// (`WebAuthSession.swift` in the iOS and macOS runners), the way App Review
/// expects an app to sign in on the web.
///
/// Hermes only accepts a loopback redirect, so the code still reaches the
/// listener. The listener then redirects the sheet to [callbackScheme],
/// which ends the session and closes the sheet.
class AuthSessionBrowser implements SignInBrowser {
  AuthSessionBrowser({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('hermes_app/web_auth');

  static const callbackScheme = 'hermes-app-signin';

  /// The browser whose sheet the native side shows now. There is one sheet
  /// per app, so a flow that ended late must not close a newer flow's sheet
  /// or take its dismissal.
  static AuthSessionBrowser? _current;

  final MethodChannel _channel;

  @override
  Future<bool> open(Uri url, {required void Function() onDismissed}) async {
    _current = this;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'dismissed' && identical(_current, this)) {
        onDismissed();
      }
    });
    bool started;
    try {
      started =
          await _channel.invokeMethod<bool>('start', {
            'url': url.toString(),
            'callbackScheme': callbackScheme,
          }) ??
          false;
    } on PlatformException {
      started = false;
    } on MissingPluginException {
      started = false;
    }
    if (!started && identical(_current, this)) {
      _current = null;
      _channel.setMethodCallHandler(null);
    }
    return started;
  }

  @override
  Future<void> close() async {
    if (!identical(_current, this)) return;
    _current = null;
    _channel.setMethodCallHandler(null);
    await _channel.invokeMethod<void>('cancel');
  }

  @override
  Uri get finishedRedirect => Uri.parse('$callbackScheme://signed-in');
}
