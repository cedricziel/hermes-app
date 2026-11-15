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

final _initPattern = RegExp(r'(?<![.\w])init[?!]?\s*\(');

/// What the launch path of one Swift file runs: the bodies of `register` and of
/// every `init(`, the stored-property statements of its top-level types, and
/// for each nested type (by name) its stored properties and `init` bodies, run
/// only when something instantiates it.
class _Launch {
  final bodies = <String>[];
  final members = <String>[];
  final nested = <String, String>{};
}

/// Whole stored-property statements start at a line of a type body: any
/// modifiers and attributes (with arguments), then `let` or `var`.
final _memberHeader = RegExp(
  r'[ \t]*((@?[\w.]+(\([^)\n]*\))?)[ \t]+)*(let|var)\s',
);
final _typeHeader = RegExp(r'\b(class|struct|enum|actor|extension)\s+(\w+)');

_Launch _launch(String source, {bool register = true}) {
  final launch = _Launch();
  if (register) {
    launch.bodies.add(
      _blockAt(source, source.indexOf('static func register(')),
    );
  }
  // Each entry is a block opened: a type name, or null for anything else.
  final stack = <String?>[];
  var boundary = 0;
  var i = 0;
  while (i < source.length) {
    final c = source[i];
    final atLineStart = _startsStatement(source, i);
    final inType = stack.isNotEmpty && stack.last != null;
    if (inType && atLineStart) {
      final header = _memberHeader.matchAsPrefix(source, i);
      if (header != null) {
        var nest = 0;
        var j = i;
        for (; j < source.length; j++) {
          final ch = source[j];
          if (nest == 0 && (ch == '}' || ch == ';')) break;
          if ('({['.contains(ch)) nest++;
          if (')}]'.contains(ch)) nest--;
          if (ch == '\n' && nest <= 0) {
            final soFar = source.substring(i, j).trimRight();
            final next = source.substring(j).trimLeft();
            final goesOn =
                soFar.endsWith('=') ||
                next.startsWith('{') ||
                next.startsWith('.');
            if (!goesOn) break;
          }
        }
        final statement = source.substring(i, j);
        if (!RegExp(r'\b(lazy|static)\b').hasMatch(header.group(0)!)) {
          _add(launch, stack, statement);
        }
        i = j;
        continue;
      }
    }
    if (inType &&
        _initPattern.matchAsPrefix(source, i) != null &&
        !_isWord(source, i - 1)) {
      _add(launch, stack, _blockAt(source, i));
    }
    if (c == '{') {
      final segment = source.substring(boundary, i);
      final type = segment.contains(RegExp(r'\bfunc\b'))
          ? null
          : _typeHeader.firstMatch(segment)?.group(2);
      stack.add(type);
      boundary = i + 1;
    } else if (c == '}') {
      if (stack.isNotEmpty) stack.removeLast();
      boundary = i + 1;
    } else if (c == ';') {
      boundary = i + 1;
    }
    i++;
  }
  return launch;
}

/// Whether a statement may begin at [index]: after a line break, `{` or `;`.
bool _startsStatement(String source, int index) {
  var back = index - 1;
  while (back >= 0 && (source[back] == ' ' || source[back] == '\t')) {
    back--;
  }
  return back < 0 || '\n{;'.contains(source[back]);
}

bool _isWord(String s, int index) =>
    index >= 0 && RegExp(r'[\w.]').hasMatch(s[index]);

void _add(_Launch launch, List<String?> stack, String text) {
  if (stack.length == 1) {
    // A top-level type: built when the plugin is, and its init runs then too.
    if (text.startsWith(RegExp(r'\s*\{'))) {
      launch.bodies.add(text);
    } else {
      launch.members.add(text);
    }
  } else {
    final name = stack.last!;
    launch.nested.update(name, (old) => '$old\n$text', ifAbsent: () => text);
  }
}

/// Function and stored-closure names -> their text, and nested type names ->
/// their stored properties and initialisers: what a call by that name runs.
Map<String, String> _callables(String source, _Launch launch) {
  final callables = <String, String>{...launch.nested};
  void add(String name, String text) =>
      callables.update(name, (old) => '$old\n$text', ifAbsent: () => text);
  for (final m in RegExp(r'\bfunc\s+(\w+)').allMatches(source)) {
    add(m.group(1)!, _blockAt(source, m.end));
  }
  for (final member in launch.members) {
    final name = RegExp(r'\b(?:let|var)\s+(\w+)').firstMatch(member)?.group(1);
    if (name != null) add(name, member);
  }
  return callables;
}

/// Whether [text] names something forbidden, or calls (with parentheses or a
/// trailing closure) something of the same file that does, however deep.
bool _builds(String text, Map<String, String> callables, [Set<String>? seen]) {
  seen ??= {};
  if (text.contains(_forbidden)) return true;
  for (final entry in callables.entries) {
    if (!RegExp('(?<![.\\w])${entry.key}\\s*[({]').hasMatch(text) &&
        !RegExp('\\.${entry.key}\\s*[({]').hasMatch(text)) {
      continue;
    }
    if (!seen.add(entry.key)) continue;
    if (_builds(entry.value, callables, seen)) return true;
  }
  return false;
}

void _expectSilentAtLaunch(String source, {bool register = true}) {
  final launch = _launch(source, register: register);
  final callables = _callables(source, launch);
  if (register) expect(launch.bodies, isNotEmpty);
  for (final text in [...launch.bodies, ...launch.members]) {
    expect(_builds(text, callables), isFalse, reason: text);
  }
}

void main() {
  test('the calls plugin builds nothing audio or CallKit at launch', () {
    _expectSilentAtLaunch(_clean(File(_calls).readAsStringSync()));
  });

  test('call audio wires its engine only when started', () {
    final source = _clean(File(_callAudio).readAsStringSync());

    final launch = _launch(source, register: false);
    expect(launch.bodies, isEmpty);
    expect(source, isNot(contains(_initPattern)));
    expect(
      _blockAt(source, source.indexOf('func start(')),
      contains('mainMixerNode'),
    );
    final callables = _callables(source, launch);
    for (final member in launch.members) {
      expect(
        _builds(member.replaceAll('AVAudioEngine()', ''), callables),
        isFalse,
        reason: member,
      );
    }
  });

  test('the speech plugin builds no audio at launch', () {
    _expectSilentAtLaunch(_clean(File(_speech).readAsStringSync()));
  });

  group('the guard sees what it claims to', () {
    bool flags(String type) {
      final source = _clean('final class A {\n$type\n}');
      final launch = _launch(source, register: false);
      final callables = _callables(source, launch);
      return [
        ...launch.bodies,
        ...launch.members,
      ].any((text) => _builds(text, callables));
    }

    final bypasses = {
      'a multi-line closure initialiser':
          'private var a: CallAudio? = {\n let b = CallAudio()\n return b\n}()',
      'a value on the line after the equals sign':
          'let eng =\n  AVAudioEngine()',
      'a closure on the line after the equals sign, run in init':
          'let warm: () -> Void =\n  { _ = CallAudio() }\ninit() { warm() }',
      'a public let': 'public let c = CXCallController()',
      'private(set)': 'private(set) var p = CXProvider(configuration: c)',
      'fileprivate(set)':
          'fileprivate(set) var p = CXProvider(configuration: c)',
      'nonisolated(unsafe)':
          'nonisolated(unsafe) var p = CXProvider(configuration: c)',
      '@objc dynamic': '@objc dynamic var p = CXProvider(configuration: c)',
      'an attribute with arguments':
          '@available(iOS 17, *) var p = CXProvider(configuration: c)',
      'a helper reached from init': 'init() { prepare() }\nfunc prepare() { warm() }\nfunc warm() { _ = engine.inputNode }',
      'init with a space': 'init () { _ = CallAudio() }',
      'a failable init': 'init?() { _ = CallAudio() }',
      'a trailing closure call':
          'init() { warm { } }\nfunc warm(_ f: () -> Void) { _ = CallAudio() }',
      'a nested type built in init':
          'struct W { let engine = AVAudioEngine() }\ninit() { _ = W() }',
      'a nested type init built in init':
          'struct W { init() { _ = CallAudio() } }\ninit() { _ = W() }',
      'a free function in a property': 'private let wired = wireGraph()\nfunc wireGraph() { _ = engine.mainMixerNode }',
    };
    for (final entry in bypasses.entries) {
      test('flags ${entry.key}', () => expect(flags(entry.value), isTrue));
    }

    final fine = {
      'lazy': 'lazy var later = CXProvider(configuration: c)',
      'static': 'static let shared = CallAudio()',
      'plain members': 'var plain = 0\nprivate let tag = "init( CallAudio()"',
      'a nested type nobody builds':
          'struct W { let engine = AVAudioEngine() }\ninit() { }',
      'a function nobody calls': 'init() { }\nfunc later() { _ = CallAudio() }',
    };
    for (final entry in fine.entries) {
      test('lets ${entry.key} pass', () => expect(flags(entry.value), isFalse));
    }
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
