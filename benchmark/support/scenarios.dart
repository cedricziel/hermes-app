// The benchmark scenarios, shared by the widget-test runner
// (benchmark/chat_render_bench_test.dart, debug JIT, fake clock) and the
// profile-mode runner (benchmark/profile/chat_render_profile.dart, AOT,
// real app window and clock). Each one drives the real ChatScreen through a
// scripted stream; see frame_stats.dart for what is measured in each mode.
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' show ChatAnimatedList;
import 'package:hermes_app/src/chat/chat_transport.dart';

import 'content.dart';
import 'frame_stats.dart';
import 'harness.dart';

const _timeout = Timeout(Duration(minutes: 30));

/// A reply event list: started, the text as deltas, completed.
List<ChatEvent> _reply(String text, {int deltaSize = 24}) => [
  const ReplyStarted(),
  for (final d in deltas(text, size: deltaSize)) ReplyDelta(d),
];

Future<void> _finish(BenchChat chat) async {
  chat.send.emit(const ReplyCompleted(''));
  await chat.tester.pump(frameStep);
  await chat.tester.pump(frameStep);
}

/// Brings the [n]th lowest match on screen (0 is the newest of several groups)
/// into view and returns it, or null when the list built fewer matches. The
/// reader first scrolls to the end, repeatedly: until the items are laid out
/// the list's end is an estimate that keeps moving. This takes about nine
/// pumps, so a scenario calls it outside the timed frame and times the tap
/// alone.
Future<Finder?> _prepareNthLowest(
  WidgetTester tester,
  Finder finder,
  int n,
) async {
  Finder? nth() {
    final matches = finder.evaluate().toList();
    if (matches.length <= n) return null;
    matches.sort((a, b) {
      final ya = tester.getCenter(find.byWidget(a.widget)).dy;
      final yb = tester.getCenter(find.byWidget(b.widget)).dy;
      return yb.compareTo(ya);
    });
    return find.byWidget(matches[n].widget);
  }

  for (var i = 0; i < 8; i++) {
    _scrollToEnd(tester);
    await tester.pump(frameStep);
  }
  final target = nth();
  if (target == null) return null;
  await tester.ensureVisible(target);
  await tester.pump(frameStep);
  return nth();
}

final _chatList = find
    .descendant(
      of: find.byType(ChatAnimatedList),
      matching: find.byType(Scrollable),
    )
    .first;

void _scrollToEnd(WidgetTester tester) {
  final scrollable = tester.state<ScrollableState>(
    find
        .descendant(
          of: find.byType(ChatAnimatedList),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
}

void _scenario(
  String id,
  String name, {
  List<(String, Size)>? only,
  required Future<void> Function(WidgetTester tester, String width, Size size)
  body,
}) {
  for (final (label, size) in only ?? widths) {
    final filter = scenarioFilter;
    final skip = filter != null && !filter.hasMatch(id);
    testWidgets(
      '$id $name @ $label',
      (tester) => body(tester, label, size),
      skip: skip,
      timeout: _timeout,
    );
  }
}

void registerScenarios() {
  // JIT warm-up, not recorded: small versions of every kind of content, so the
  // first measured scenario is not paying for compiling the app.
  for (final (label, size) in widths) {
    testWidgets('warm-up @ $label', (tester) async {
      final chat = await openBenchChat(
        tester,
        size: size,
        history: historyRows(60),
      );
      await chat.submit('warm up');
      final r = Random(9);
      final events = <ChatEvent>[
        ..._reply(markdownReply(400, seed: 9)),
        ..._reply(codeReply(blocks: 3, bigIndex: 1, bigLines: 150)).skip(1),
        ..._reply(tableReply(tables: 2, rows: 10)).skip(1),
        ..._reply(listReply(lists: 3, items: 10)).skip(1),
        for (var i = 0; i < 3; i++) ...[
          ToolStarted(
            id: 'w$i',
            name: 'read_file',
            summary: 'warm $i',
            args: bigJson(r, keys: 8, depth: 0),
          ),
          ToolFinished(
            id: 'w$i',
            name: 'read_file',
            result: 'ok',
            resultData: bigJson(r, keys: 8, depth: 0),
          ),
        ],
      ];
      await streamEvents(chat, FrameLog(), events, warmup: 1 << 30);
      await _finish(chat);
    }, timeout: _timeout);
  }

  _scenario(
    's1-markdown',
    '300 messages, 6,000-word Markdown reply',
    body: (tester, width, size) async {
      final chat = await openBenchChat(
        tester,
        size: size,
        history: historyRows(300),
      );
      final log = FrameLog();
      await chat.submit('Write the long guide.');
      await streamEvents(chat, log, _reply(markdownReply(6000)));
      await _finish(chat);
      await record('s1-markdown', width, log);
    },
  );

  _scenario(
    's2-code-blocks',
    '12 fenced code blocks, one of 2,000 lines',
    body: (tester, width, size) async {
      final chat = await openBenchChat(
        tester,
        size: size,
        history: historyRows(300),
      );
      final log = FrameLog();
      await chat.submit('Show me the code.');
      // Larger deltas: the code is ~110 KB, and a line is a typical token burst.
      await streamEvents(chat, log, _reply(codeReply(), deltaSize: 64));
      await _finish(chat);
      await record('s2-code-blocks', width, log);
    },
  );

  // Empty fences: a reply that opens and closes a code block with nothing in it,
  // over and over. A code field per fence is what this stresses.
  for (final count in [100, 300, 1000]) {
    _scenario(
      's2b-fences-$count',
      '$count empty code fences',
      body: (tester, width, size) async {
        final chat = await openBenchChat(
          tester,
          size: size,
          history: historyRows(300),
        );
        final log = FrameLog();
        await chat.submit('Show me the blocks.');
        await streamEvents(
          chat,
          log,
          _reply(emptyFenceReply(count), deltaSize: 40),
        );
        await _finish(chat);
        await record('s2b-fences-$count', width, log);
      },
    );
  }

  _scenario(
    's3-tool-calls',
    '40 tool calls with large JSON, some opened',
    body: (tester, width, size) async {
      final chat = await openBenchChat(
        tester,
        size: size,
        history: historyRows(300),
      );
      final log = FrameLog();
      final r = Random(7);
      await chat.submit('Audit the repository.');
      chat.send.emit(const ReplyStarted());
      await tester.pump(frameStep);
      const names = [
        'read_file',
        'terminal',
        'web_search',
        'patch',
        'execute_code',
      ];
      var frame = 0;
      Future<void> tick([Future<void> Function()? before]) async {
        frame < 6
            ? await log.warm(tester, before: before)
            : await log.frame(tester, before: before);
        frame++;
      }

      // Opening a disclosure animates for about 200 ms; measure every frame.
      // The scroll that brings the target into view is not measured: only the
      // tap is inside the timed frame. A target the list did not build is not
      // counted; the scenario fails below unless every one of the six taps
      // landed.
      var opened = 0;
      Future<void> open(Finder finder, int n) async {
        final target = await _prepareNthLowest(tester, finder, n);
        if (target == null) return;
        await tick(() => tester.tap(target));
        opened++;
        for (var k = 0; k < 14; k++) {
          await tick();
        }
      }

      // Eight runs of five calls, each closed by a line of text, so each run
      // shows as one "Used 5 tools" group. The first group is opened while it
      // streams, as a reader watching the work would.
      final firsts = <String>[];
      for (var run = 0; run < 8; run++) {
        for (var j = 0; j < 5; j++) {
          final i = run * 5 + j;
          final name = names[i % names.length];
          final summary = 'Call $i ${sentence(r, min: 3, max: 5)}';
          if (j == 0) firsts.add(summary);
          final args = bigJson(r, keys: 40);
          final data = bigJson(r, keys: 70);
          await tick(
            () async => chat.send.emit(
              ToolStarted(id: 't$i', name: name, summary: summary, args: args),
            ),
          );
          await tick(
            () async => chat.send.emit(
              ToolFinished(
                id: 't$i',
                name: name,
                result: const JsonEncoder.withIndent('  ').convert(data),
                resultData: data,
                duration: const Duration(milliseconds: 420),
              ),
            ),
          );
        }
        await tick(() async => chat.send.emit(ReplyDelta('${sentence(r)} ')));
        if (run == 0) {
          await open(find.text('Used 5 tools'), 0);
          await open(find.text(firsts[0]), 0);
          // Opening a disclosure stops the list following; scrolling back to
          // the end resumes it.
          await tick(() async => _scrollToEnd(tester));
        }
      }
      // Then the reader opens the last two groups and the first call of
      // each. Both headers first, and the older group's call before the
      // newer one's: an opened call is thousands of pixels tall and pushes
      // the other group out of the built range.
      await open(find.text('Used 5 tools'), 0);
      await open(find.text('Used 5 tools'), 1);
      await open(find.text(firsts[6]), 0);
      await open(find.text(firsts[7]), 0);
      chat.send.emit(ReplyCompleted(markdownReply(80, seed: 8)));
      await tick();
      await _finish(chat);
      expect(opened, 6, reason: 'every disclosure tap must land');
      await record(
        's3-tool-calls',
        width,
        log,
        extra: {'disclosures_opened': opened},
      );
    },
  );

  _scenario(
    's4a-tables',
    'table-heavy reply',
    body: (tester, width, size) async {
      final chat = await openBenchChat(
        tester,
        size: size,
        history: historyRows(300),
      );
      final log = FrameLog();
      await chat.submit('Compare everything.');
      await streamEvents(chat, log, _reply(tableReply(), deltaSize: 40));
      await _finish(chat);
      await record('s4a-tables', width, log);
    },
  );

  _scenario(
    's4b-lists',
    'list-heavy reply',
    body: (tester, width, size) async {
      final chat = await openBenchChat(
        tester,
        size: size,
        history: historyRows(300),
      );
      final log = FrameLog();
      await chat.submit('List everything.');
      await streamEvents(chat, log, _reply(listReply(), deltaSize: 40));
      await _finish(chat);
      await record('s4b-lists', width, log);
    },
  );

  _scenario(
    's5-open-2000',
    'open a 2,000-message chat, scroll up through pages',
    body: (tester, width, size) async {
      const marker = 'Closing remarks of the long audit.';
      final history = historyRows(2000, closing: '$marker ');
      final open = FrameLog();
      // The mount frame is the first measured one, so the window runs from
      // mounting the screen to the newest message on it.
      final chat = await openBenchChat(
        tester,
        size: size,
        history: history,
        settle: false,
        mountLog: open,
      );
      var tapped = false;
      var frames = 0;
      bool shown() =>
          find.textContaining(marker, findRichText: true).evaluate().isNotEmpty;
      while (!shown() && frames < 300) {
        await open.frame(
          tester,
          before: () async {
            // On a phone the chat list comes first; the reader taps the row.
            if (!tapped && composerField.evaluate().isEmpty) {
              final row = find.text('Benchmark chat');
              if (row.evaluate().isNotEmpty) {
                tapped = true;
                await tester.tap(row);
              }
            }
          },
        );
        frames++;
      }
      expect(shown(), isTrue, reason: 'the newest message never appeared');
      final openWallMs = open.wallMs;
      // Let the open finish, unmeasured, so the scroll starts from rest.
      await tester.pumpAndSettle();
      await record(
        's5a-open-2000',
        width,
        open,
        // The real time from mounting the screen to the newest message on it,
        // read before the unmeasured settle.
        extra: {'open_wall_ms': openWallMs},
      );

      final scroll = FrameLog();
      final before = chat.server
          .requestsTo('GET', '/api/sessions/$threadId/messages')
          .length;
      // A fast flick, scripted: a held drag moves the list 600 px per frame
      // towards the oldest message. Loading a page remounts the list under the
      // finger, which drops the drag, so a stalled drag starts again.
      final centre = tester.getCenter(_chatList);
      var gesture = await tester.startGesture(centre);
      await gesture.moveBy(const Offset(0, 20));
      var last = -1.0;
      for (var i = 0; i < 500; i++) {
        final pixels = tester.state<ScrollableState>(_chatList).position.pixels;
        if (pixels == last) {
          await gesture.up();
          gesture = await tester.startGesture(centre);
          await gesture.moveBy(const Offset(0, 20));
        }
        last = pixels;
        Future<void> flick() => gesture.moveBy(const Offset(0, 600));
        i < 10
            ? await scroll.warm(tester, before: flick)
            : await scroll.frame(tester, before: flick);
      }
      await gesture.up();
      await tester.pumpAndSettle();
      final pages =
          chat.server
              .requestsTo('GET', '/api/sessions/$threadId/messages')
              .length -
          before;
      expect(
        pages,
        greaterThan(3),
        reason: 'scrolling never reached older pages',
      );
      await record(
        's5b-scroll-older',
        width,
        scroll,
        extra: {'older_pages': pages},
      );
    },
  );

  _scenario(
    's6-typing',
    'typing in the composer while a reply streams',
    body: (tester, width, size) async {
      final chat = await openBenchChat(
        tester,
        size: size,
        history: historyRows(300),
      );
      final log = FrameLog();
      await chat.submit('Write the long guide.');
      // Look the field up once; each frame then sets its text directly, so the
      // measurement does not pay for a finder walking the whole tree.
      final composer = chat.composer..setText('');
      final typed = sentence(Random(6), min: 60, max: 60) * 3;
      var chars = 0;
      await streamEvents(
        chat,
        log,
        _reply(markdownReply(1500, seed: 6)),
        alsoEachFrame: (frame) async {
          if (chars < typed.length) {
            chars++;
            composer.setText(typed.substring(0, chars));
          }
        },
      );
      await _finish(chat);
      await record('s6-typing', width, log, extra: {'chars_typed': chars});
    },
  );

  _scenario(
    's7-mac-sidebar',
    'Mac sidebar with 500 chats while a reply streams',
    only: [widths[1]],
    body: (tester, width, size) async {
      final r = Random(10);
      final chats = [
        for (var i = 0; i < 500; i++)
          sessionRow(
            id: 'chat-$i',
            title: '${sentence(r, min: 3, max: 7)} $i',
            lastActive: 1780099000.0 - i * 7000,
            startedAt: 1780099000.0 - i * 7000,
          ),
      ];
      final chat = await openBenchChat(
        tester,
        size: size,
        history: historyRows(300),
        chats: chats,
        macSidebar: true,
      );
      final log = FrameLog();
      await chat.submit('Write the long guide.');
      await streamEvents(chat, log, _reply(markdownReply(1500, seed: 7)));
      await _finish(chat);
      await record('s7-mac-sidebar', width, log);
    },
  );
}
