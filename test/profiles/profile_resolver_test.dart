import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/profiles/profile_resolver.dart';

DioException _status(int code) {
  final options = RequestOptions(path: '/api/profiles/active');
  return DioException(
    requestOptions: options,
    response: Response<Object?>(requestOptions: options, statusCode: code),
  );
}

void main() {
  test('current beats active', () async {
    final resolver = ProfileResolver(
      () async => (active: 'main', current: 'work'),
    );

    expect(await resolver.load(), 'work');
    expect(resolver.launch, 'work');
    expect(resolver.resolve(null), 'work');
  });

  test('active is used only when the server sends no current', () async {
    final resolver = ProfileResolver(() async => (active: 'main', current: ''));

    expect(await resolver.load(), 'main');
  });

  test('a chat profile wins over the launch profile', () async {
    final resolver = ProfileResolver.known('work');

    expect(resolver.resolve('home'), 'home');
    expect(resolver.resolve(''), 'work');
  });

  test('nothing resolves before the launch profile is read', () {
    final resolver = ProfileResolver(
      () async => (active: 'main', current: 'work'),
    );

    expect(resolver.resolve(null), isNull);
    expect(resolver.resolve('home'), 'home');
  });

  test('a 404 gives null, is not kept and is asked again', () async {
    var calls = 0;
    final resolver = ProfileResolver(() async {
      calls++;
      throw _status(404);
    });

    expect(await resolver.load(), isNull);
    expect(resolver.resolve(null), isNull);
    expect(await resolver.load(), isNull);
    expect(calls, 2);
  });

  test('another error is rethrown and tried again on the next call', () async {
    var calls = 0;
    final resolver = ProfileResolver(() async {
      if (calls++ == 0) throw _status(500);
      return (active: 'main', current: 'work');
    });

    await expectLater(resolver.load(), throwsA(isA<DioException>()));
    expect(resolver.resolve(null), isNull);
    expect(await resolver.load(), 'work');
    expect(calls, 2);
  });

  test('concurrent loads share one read, and a known one reads none', () async {
    var calls = 0;
    final gate = Completer<void>();
    final resolver = ProfileResolver(() async {
      calls++;
      await gate.future;
      return (active: 'main', current: 'work');
    });

    final first = resolver.load();
    final second = resolver.load();
    gate.complete();

    expect(await Future.wait([first, second]), ['work', 'work']);
    expect(await resolver.load(), 'work');
    expect(calls, 1);
  });

  test('listeners hear the launch profile once it is read', () async {
    final resolver = ProfileResolver(
      () async => (active: 'main', current: 'work'),
    );
    var heard = 0;
    resolver.addListener(() => heard++);

    await resolver.load();
    await resolver.load();

    expect(heard, 1);
  });
}
