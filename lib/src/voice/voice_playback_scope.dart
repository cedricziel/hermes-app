import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'voice_playback.dart';
import 'voice_player.dart';

/// A transcript's player survives row recycling, and stops when the thread
/// is replaced or the app becomes inactive. It is never created by rendering
/// a message; the first tap on Play creates the native audio player.
class VoicePlaybackScope extends StatefulWidget {
  const VoicePlaybackScope({super.key, required this.child, this.createPlayer});

  final Widget child;
  final VoicePlayer Function()? createPlayer;

  @override
  State<VoicePlaybackScope> createState() => _VoicePlaybackScopeState();
}

class _VoicePlaybackScopeState extends State<VoicePlaybackScope>
    with WidgetsBindingObserver {
  late final _playback = VoicePlayback(createPlayer: widget.createPlayer);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_playback.pause());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ChangeNotifierProvider.value(value: _playback, child: widget.child);
}
