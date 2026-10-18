import 'package:hermes_app/src/voice/voice_player.dart';

class FakeVoicePlayer extends VoicePlayer {
  @override
  bool playing = false;
  @override
  bool completed = false;
  @override
  bool failed = false;
  @override
  Duration position = Duration.zero;
  @override
  Duration duration = const Duration(seconds: 48);

  final loaded = <String>[];
  final seeks = <Duration>[];
  int plays = 0;
  int pauses = 0;
  bool disposed = false;
  bool failLoad = false;

  @override
  Future<void> load(String path) async {
    if (failLoad) throw StateError('decoder failed');
    loaded.add(path);
    position = Duration.zero;
    completed = failed = false;
    notifyListeners();
  }

  @override
  Future<void> play() async {
    plays++;
    playing = true;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    pauses++;
    playing = false;
    notifyListeners();
  }

  @override
  Future<void> seek(Duration value) async {
    seeks.add(value);
    position = value;
    completed = false;
    notifyListeners();
  }

  void finish() {
    completed = true;
    playing = false;
    position = duration;
    notifyListeners();
  }

  void fail() {
    failed = true;
    playing = false;
    notifyListeners();
  }

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}
