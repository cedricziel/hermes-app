import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Swift side of `test/app_audio_launch_test.dart`: a plugin's `register`
/// and `init` run at launch, and building an audio engine, an audio session
/// setting or a CallKit object there interrupts the music or video playing in
/// another app. SwiftPM cannot build these packages without Flutter, so the
/// rule is pinned on the source text: whatever a class declares or runs at
/// construction must not name these.
const _calls =
    'packages/hermes_calls/ios/hermes_calls/Sources/hermes_calls/HermesCallsPlugin.swift';
const _callAudio =
    'packages/hermes_calls/ios/hermes_calls/Sources/hermes_calls/CallAudio.swift';
const _speech =
    'packages/hermes_speech/darwin/hermes_speech/Sources/hermes_speech/HermesSpeechPlugin.swift';

final _forbidden = RegExp(
  r'CallAudio\(|CXProvider\(|CXCallController\(|AVAudioEngine\(|AVAudioRecorder\(|'
  r'AVAudioPlayer\(|mainMixerNode|inputNode|outputNode|setCategory|setActive|'
  r'setVoiceProcessingEnabled|requestRecordPermission',
);

/// What runs at launch may not call a helper that builds either: the
/// `make...` factories and any use of the engine count as building.
final _launchForbidden = RegExp(
  '${_forbidden.pattern}|\\bmake\\w*\\(|\\bengine\\.',
);

String _stripComments(String source) =>
    source.replaceAll(RegExp(r'//[^\n]*'), '');

/// Every brace block that opens after an `init(` of any signature.
Iterable<String> _initBlocks(String source) => [
  for (final match in RegExp(r'\binit\(').allMatches(source))
    _block(source, source.substring(match.start)),
];

/// The text of the brace block that opens after [header].
String _block(String source, String header) {
  final start = source.indexOf(header);
  expect(start, isNonNegative, reason: '$header not found');
  final open = source.indexOf('{', start);
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}' && --depth == 0) return source.substring(open, i);
  }
  fail('$header is not closed');
}

/// Stored properties declared at class level, one per line starting `private
/// let`/`private var`/`let`/`var` at two spaces of indent.
String _members(String source) => source
    .split('\n')
    .where(
      (line) => RegExp(r'^  (private |fileprivate )?(let|var) ').hasMatch(line),
    )
    .join('\n');

void main() {
  test('the calls plugin builds nothing audio or CallKit at launch', () {
    final source = _stripComments(File(_calls).readAsStringSync());

    expect(
      _block(source, 'static func register('),
      isNot(contains(_launchForbidden)),
    );
    final inits = _initBlocks(source);
    expect(inits, isNotEmpty);
    for (final body in inits) {
      expect(body, isNot(contains(_launchForbidden)));
    }
    expect(_members(source), isNot(contains(_launchForbidden)));
  });

  test('call audio wires its engine only when started', () {
    final source = _stripComments(File(_callAudio).readAsStringSync());

    for (final body in _initBlocks(source)) {
      expect(body, isNot(contains(_launchForbidden)));
    }
    expect(source, isNot(contains(RegExp(r'\binit\('))));
    expect(_block(source, 'func start()'), contains('mainMixerNode'));
    expect(
      _members(source).replaceAll('AVAudioEngine()', ''),
      isNot(contains(_forbidden)),
    );
  });

  test('the speech plugin builds no audio at launch', () {
    final source = _stripComments(File(_speech).readAsStringSync());

    expect(
      _block(source, 'static func register('),
      isNot(contains(_launchForbidden)),
    );
    for (final body in _initBlocks(source)) {
      expect(body, isNot(contains(_launchForbidden)));
    }
    expect(_members(source), isNot(contains(_forbidden)));
  });

  test('the app delegates set no audio session', () {
    for (final path in [
      'ios/Runner/AppDelegate.swift',
      'macos/Runner/AppDelegate.swift',
    ]) {
      final file = File(path);
      if (!file.existsSync()) continue;
      expect(
        file.readAsStringSync(),
        isNot(contains(RegExp(r'AVAudioSession|AVAudioEngine|CXProvider'))),
        reason: path,
      );
    }
  });
}
