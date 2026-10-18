import 'package:dio/dio.dart';

import '../voice_support.dart';
import 'call_readiness.dart';

class CallInput {
  const CallInput({required this.useDevice, this.installed = true});
  final bool useDevice, installed;
}

/// Bounded, non-mutating checks. Permission prompts and setup requests belong
/// to explicit UI actions, never to this checker.
class CallReadinessChecker {
  CallReadinessChecker({
    required this.microphone,
    required this.input,
    required this.configuration,
    required this.connection,
    required this.isCurrent,
    this.beforeCheck,
    this.timeout = const Duration(seconds: 8),
  });
  final Future<bool> Function() microphone;
  final Future<CallInput> Function() input;
  final Future<VoiceSupport> Function() configuration;
  final Future<void> Function() connection;
  final Future<void> Function()? beforeCheck;
  final bool Function() isCurrent;
  final Duration timeout;

  Future<CallReadiness> check({void Function(CallReadiness)? onUpdate}) async {
    final checks = List.of(CallReadiness.checking.checks);
    var device = false;
    CallReadiness report() =>
        CallReadiness(List.unmodifiable(checks), useDeviceSpeech: device);
    void update(CallCheck check) {
      checks[check.id.index] = check;
      if (isCurrent()) onUpdate?.call(report());
    }

    await beforeCheck?.call().timeout(timeout);
    if (!isCurrent()) return report();
    try {
      final allowed = await microphone().timeout(timeout);
      update(
        CallCheck(
          CallCheckId.microphone,
          allowed ? CallCheckStatus.ready : CallCheckStatus.needsSetup,
          allowed
              ? 'Microphone access is allowed.'
              : 'Allow Hermes to use your microphone.',
          action: allowed ? null : CallSetupAction.microphone,
        ),
      );
    } on Object {
      update(
        const CallCheck(
          CallCheckId.microphone,
          CallCheckStatus.unavailable,
          'Microphone access could not be checked. Try again.',
          action: CallSetupAction.microphone,
        ),
      );
    }
    if (!isCurrent()) return report();
    try {
      final choice = await input().timeout(timeout);
      device = choice.useDevice;
      if (device) {
        update(
          CallCheck(
            CallCheckId.input,
            choice.installed
                ? CallCheckStatus.ready
                : CallCheckStatus.needsSetup,
            choice.installed
                ? 'Apple on-device recognition is ready.'
                : 'Install your speech language in Dictation settings.',
            action: choice.installed ? null : CallSetupAction.dictation,
          ),
        );
      }
    } on Object {
      update(
        const CallCheck(
          CallCheckId.input,
          CallCheckStatus.unavailable,
          'Speech recognition could not be checked. Open Dictation settings.',
          action: CallSetupAction.dictation,
        ),
      );
    }
    if (!isCurrent()) return report();
    var configured = false;
    try {
      final support = await configuration().timeout(timeout);
      configured = support.configurationKnown;
      if (!configured) {
        throw const FormatException('Speech configuration unavailable');
      }
      update(
        CallCheck(
          CallCheckId.output,
          support.textToSpeech
              ? CallCheckStatus.ready
              : CallCheckStatus.needsSetup,
          support.textToSpeech
              ? 'Hermes speech output is configured.'
              : 'Configure a speech provider on Hermes.',
          action: support.textToSpeech ? null : CallSetupAction.hermes,
        ),
      );
      if (!device &&
          checks[CallCheckId.input.index].status == CallCheckStatus.checking) {
        update(
          CallCheck(
            CallCheckId.input,
            support.speechToText
                ? CallCheckStatus.ready
                : CallCheckStatus.needsSetup,
            support.speechToText
                ? 'Hermes speech recognition is configured.'
                : 'Configure speech recognition on Hermes.',
            action: support.speechToText ? null : CallSetupAction.hermes,
          ),
        );
      }
    } on Object catch (error) {
      final status = error is DioException ? error.response?.statusCode : null;
      final auth = status == 401 || status == 403;
      final old = status == 404 || status == 405;
      final detail = auth
          ? 'Sign in to Hermes again to check speech settings.'
          : old
          ? 'Update Hermes to enable voice calls.'
          : 'Hermes speech settings could not be checked. Try again.';
      final action = auth ? null : CallSetupAction.hermes;
      update(
        CallCheck(
          CallCheckId.output,
          old ? CallCheckStatus.needsSetup : CallCheckStatus.unavailable,
          detail,
          action: action,
        ),
      );
      if (checks[CallCheckId.input.index].status == CallCheckStatus.checking) {
        update(
          CallCheck(
            CallCheckId.input,
            CallCheckStatus.unavailable,
            detail,
            action: action,
          ),
        );
      }
      update(
        CallCheck(
          CallCheckId.connection,
          CallCheckStatus.unavailable,
          'Speech settings must be available before checking the voice connection.',
          action: action,
        ),
      );
    }
    if (!isCurrent()) return report();
    if (configured) {
      try {
        await connection().timeout(timeout);
        update(
          const CallCheck(
            CallCheckId.connection,
            CallCheckStatus.ready,
            'The voice service is reachable.',
          ),
        );
      } on Object {
        update(
          const CallCheck(
            CallCheckId.connection,
            CallCheckStatus.unavailable,
            'The voice service could not be reached. Check your connection or update Hermes.',
            action: CallSetupAction.hermes,
          ),
        );
      }
    }
    return report();
  }
}
