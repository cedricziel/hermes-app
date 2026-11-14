import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/server_care/widgets/closes_with.dart';

class _Signal extends ChangeNotifier {
  void fire() => notifyListeners();
}

/// Fires [signal] while it is being taken down, after its siblings were
/// deactivated and before they are disposed: the moment a page that fires as
/// it is removed lands in.
class _FiresOnDispose extends StatefulWidget {
  const _FiresOnDispose(this.signal);

  final _Signal signal;

  @override
  State<_FiresOnDispose> createState() => _FiresOnDisposeState();
}

class _FiresOnDisposeState extends State<_FiresOnDispose> {
  @override
  void dispose() {
    widget.signal.fire();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  testWidgets('a signal that fires while the popup is out of the tree does '
      'nothing and throws nothing', (tester) async {
    final signal = _Signal();
    addTearDown(signal.dispose);
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FiresOnDispose(signal),
              ClosesWith(closer: signal, child: const Text('question')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('question'), findsOneWidget);

    // Taking the dialog down from outside deactivates the popup's content,
    // and the sibling then fires the signal before the content is disposed.
    Navigator.of(context).pop();
    await tester.pumpAndSettle();

    expect(find.text('question'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the same signal while it is in the tree closes the dialog', (
    tester,
  ) async {
    final signal = _Signal();
    addTearDown(signal.dispose);
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          content: ClosesWith(closer: signal, child: const Text('question')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    signal.fire();
    await tester.pumpAndSettle();
    expect(find.text('question'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
