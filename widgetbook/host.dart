import 'dart:async';

import 'package:flutter/material.dart';

/// Owns a value a screen needs (a controller, a repository) for as long as the
/// use case is on screen: builds it, shows a spinner until it is ready, and
/// disposes it afterwards. The catalog has no app around it to do that.
class Hosted<T extends Object> extends StatefulWidget {
  const Hosted({
    super.key,
    required this.create,
    required this.builder,
    this.dispose,
  });

  final FutureOr<T> Function() create;
  final Widget Function(BuildContext context, T value) builder;
  final void Function(T value)? dispose;

  @override
  State<Hosted<T>> createState() => _HostedState<T>();
}

class _HostedState<T extends Object> extends State<Hosted<T>> {
  T? _value;
  var _gone = false;

  @override
  void initState() {
    super.initState();
    Future<T>.sync(widget.create).then((value) {
      if (_gone) {
        widget.dispose?.call(value);
      } else {
        setState(() => _value = value);
      }
    });
  }

  @override
  void dispose() {
    _gone = true;
    final value = _value;
    if (value != null) widget.dispose?.call(value);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;
    if (value == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return widget.builder(context, value);
  }
}
