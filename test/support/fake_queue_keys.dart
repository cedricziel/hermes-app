import 'package:hermes_app/src/chat/queue_storage/queue_keys.dart';

class FakeQueueKeys implements QueueKeys {
  final values = <String, List<int>>{};
  bool unavailable = false;
  @override
  Future<List<int>?> read(String account) async {
    if (unavailable) throw StateError('Queue keys unavailable');
    return values[account];
  }

  @override
  Future<void> write(String account, List<int> key) async {
    if (unavailable) throw StateError('Queue keys unavailable');
    values[account] = key;
  }

  @override
  Future<void> delete(String account) async {
    if (unavailable) throw StateError('Queue keys unavailable');
    values.remove(account);
  }
}
