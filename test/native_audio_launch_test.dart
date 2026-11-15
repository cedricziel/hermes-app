import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Swift side of `test/app_audio_launch_test.dart`: a plugin's `register`
/// and `init` run at launch, and building an audio engine, an audio session
/// setting or a CallKit object there interrupts the music or video playing in
/// another app. SwiftPM cannot build these packages without Flutter, so the
/// rule is pinned on the source text: what `register`, any `init` and any
/// stored-property initialiser run, directly or through a function of the same
/// file, must not name these. The check leans to false positives.
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

/// Source without comments, and with the inside of string literals blanked,
/// so a `//` in a string is not a comment and a brace in one is not a block.
String _clean(String source) {
  final out = StringBuffer();
  var i = 0;
  while (i < source.length) {
    final c = source[i];
    if (source.startsWith('//', i)) {
      while (i < source.length && source[i] != '\n') {
        i++;
      }
    } else if (source.startsWith('/*', i)) {
      final end = source.indexOf('*/', i + 2);
      i = end < 0 ? source.length : end + 2;
    } else if (c == '"') {
      out.write('"');
      i++;
      while (i < source.length && source[i] != '"' && source[i] != '\n') {
        if (source[i] == r'\') i++;
        i++;
      }
      out.write('"');
      i++;
    } else {
      out.write(c);
      i++;
    }
  }
  return out.toString();
}

/// The brace block that opens at or after [from].
String _blockAt(String source, int from) {
  final open = source.indexOf('{', from);
  expect(open, isNonNegative, reason: 'no block after $from');
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}' && --depth == 0) return source.substring(open, i);
  }
  fail('block at $from is not closed');
}

/// Bodies of `static func register(` and every `init(`.
List<String> _launchBodies(String source, {bool register = true}) => [
  if (register) _blockAt(source, source.indexOf('static func register(')),
  for (final m in RegExp(r'\binit\(').allMatches(source))
    _blockAt(source, m.start),
];

/// Function name -> the text of every body with that name.
Map<String, String> _functions(String source) {
  final functions = <String, String>{};
  for (final m in RegExp(r'\bfunc\s+(\w+)').allMatches(source)) {
    functions.update(
      m.group(1)!,
      (old) => '$old\n${_blockAt(source, m.end)}',
      ifAbsent: () => _blockAt(source, m.end),
    );
  }
  return functions;
}

/// Whether [text] names something forbidden, or calls a function of the same
/// file that does, however deep.
bool _builds(String text, Map<String, String> functions, [Set<String>? seen]) {
  seen ??= {};
  if (text.contains(_forbidden)) return true;
  for (final entry in functions.entries) {
    if (!RegExp('\\b${entry.key}\\s*\\(').hasMatch(text)) continue;
    if (!seen.add(entry.key)) continue;
    if (_builds(entry.value, functions, seen)) return true;
  }
  return false;
}

/// Whole stored-property statements declared directly in a type, parentheses
/// and braces balanced, with any modifier; `lazy` and `static` ones run later.
List<String> _members(String source) {
  final members = <String>[];
  final header = RegExp(
    r'^[ \t]*((@\w+|public|private(\(set\))?|fileprivate|internal|open|final|'
    r'lazy|static|class|weak|unowned|nonisolated)\s+)*(let|var)\s',
    multiLine: true,
  );
  var depth = 0;
  var i = 0;
  while (i < source.length) {
    final c = source[i];
    if (depth == 1 && (i == 0 || source[i - 1] == '\n')) {
      final m = header.matchAsPrefix(source, i);
      if (m != null) {
        var nest = 0;
        var j = i;
        for (; j < source.length; j++) {
          if ('({['.contains(source[j])) nest++;
          if (')}]'.contains(source[j])) nest--;
          if (source[j] == '\n' && nest <= 0) break;
        }
        final statement = source.substring(i, j);
        if (!RegExp(r'\b(lazy|static)\b').hasMatch(m.group(0)!)) {
          members.add(statement);
        }
        i = j;
        continue;
      }
    }
    if (c == '{') depth++;
    if (c == '}') depth--;
    i++;
  }
  return members;
}

void _expectSilentAtLaunch(String source, {bool register = true}) {
  final functions = _functions(source);
  final bodies = _launchBodies(source, register: register);
  if (register) expect(bodies, isNotEmpty);
  for (final body in bodies) {
    expect(_builds(body, functions), isFalse, reason: body);
  }
  for (final member in _members(source)) {
    expect(_builds(member, functions), isFalse, reason: member);
  }
}

void main() {
  test('the calls plugin builds nothing audio or CallKit at launch', () {
    _expectSilentAtLaunch(_clean(File(_calls).readAsStringSync()));
  });

  test('call audio wires its engine only when started', () {
    final source = _clean(File(_callAudio).readAsStringSync());

    expect(_launchBodies(source, register: false), isEmpty);
    expect(source, isNot(contains(RegExp(r'\binit\('))));
    expect(
      _blockAt(source, source.indexOf('func start(')),
      contains('mainMixerNode'),
    );
    for (final member in _members(source)) {
      expect(
        member.replaceAll('AVAudioEngine()', ''),
        isNot(contains(_forbidden)),
        reason: member,
      );
    }
  });

  test('the speech plugin builds no audio at launch', () {
    _expectSilentAtLaunch(_clean(File(_speech).readAsStringSync()));
  });

  test('the guard sees what it claims to', () {
    final source = _clean('''
final class A {
  public let eager = CXCallController()
  private var audio: CallAudio? = {
    let built = CallAudio()
    return built
  }()
  private(set) var other = CXProvider(configuration: c)
  lazy var later = CXProvider(configuration: c)
  static let shared = CallAudio()
  var plain = 0
  init() { prepare() }
  func prepare() { warm() }
  func warm() { _ = engine.inputNode }
}''');

    expect(_members(source), hasLength(4));
    expect(
      _members(source).where((m) => _builds(m, _functions(source))),
      hasLength(3),
    );
    expect(
      _builds(
        _launchBodies(source, register: false).single,
        _functions(source),
      ),
      isTrue,
    );
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
