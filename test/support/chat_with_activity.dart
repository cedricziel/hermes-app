import 'package:flutter/material.dart';
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
