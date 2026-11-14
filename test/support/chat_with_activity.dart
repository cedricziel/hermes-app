import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/activity/bound_activity_panel.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';

/// [threadView] with [chat]'s Activity panel beside it, as a wide window
/// shows them, so a test sees everything the chat draws.
Widget chatWithActivity(ChatController chat, Widget threadView) => Row(
  children: [
    Expanded(child: threadView),
    SizedBox(
      width: 380,
      child: BoundActivityPanel(chat: chat, thread: chat.selectedThread),
    ),
  ],
);

/// Lets the panel's read of the chat's agents (made when it opens or the chat
/// changes) land, so a test does not end with a request in flight.
Future<void> settleActivityPanel(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(pumpEventQueue);
  await tester.pump();
}
