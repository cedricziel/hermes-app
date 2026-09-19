import 'dart:async';

import 'package:hermes_app/src/share/share_inbox.dart';
import 'package:hermes_app/src/share/shared_item.dart';

class FakeShareInbox implements ShareInbox {
  FakeShareInbox([this.initial = const []]);

  final List<SharedItem> initial;
  final _controller = StreamController<List<SharedItem>>.broadcast();
  int resetCount = 0;

  @override
  Future<List<SharedItem>> initialItems() async => initial;

  @override
  Stream<List<SharedItem>> get items => _controller.stream;

  @override
  Future<void> reset() async => resetCount++;

  void emit(List<SharedItem> items) => _controller.add(items);
}
