import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/tools/widgets/toolset_key_form.dart';
import 'package:hermes_app/src/widgets/app_banner.dart';

import 'pump_tools.dart';

class _Form extends StatefulWidget {
  const _Form({
    this.phase = ToolsetKeyFormPhase.idle,
    this.text = '',
    this.isSet = false,
    this.hasLink = true,
    this.onSave,
    this.onReplace,
    this.onGetKey,
  });

  final ToolsetKeyFormPhase phase;
  final String text;
  final bool isSet;
  final bool hasLink;
  final VoidCallback? onSave;
  final ValueChanged<ToolsetKeyField>? onReplace;
  final ValueChanged<ToolsetKeyField>? onGetKey;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  late final _controller = TextEditingController(text: widget.text);

  @override
  Widget build(BuildContext context) => ToolsetKeyForm(
    provider: 'Brightfetch',
    profile: 'work',
    phase: widget.phase,
    hideSignal: 0,
    fields: [
      ToolsetKeyField(
        label: 'Brightfetch API key',
        controller: _controller,
        isSet: widget.isSet,
        hasLink: widget.hasLink,
      ),
    ],
    onSave: widget.onSave,
    onReplace: widget.onReplace ?? (_) {},
    onGetKey: widget.onGetKey ?? (_) {},
  );
}

/// Text widgets only: a field's own content also matches `find.text`.
Finder _plainText(String text) =>
    find.byWidgetPredicate((w) => w is Text && (w.data ?? '').contains(text));

Finder get _filled => find.byWidgetPredicate(
  (w) => w is FilledButton,
  description: 'a FilledButton',
);

void main() {
  testWidgets('shows the section, the field, the helper and the quiet line', (
    t,
  ) async {
    await pumpTools(t, _Form(onSave: () {}));
    // The iOS header is set in capitals.
    expect(find.text('KEY FOR BRIGHTFETCH'), findsOneWidget);
    expect(find.text('Brightfetch API key'), findsOneWidget);
    expect(
      find.text("Saved on your server for work. The app doesn't keep it."),
      findsOneWidget,
    );
    expect(find.text('Get a key'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(
      find.text('To remove a key, edit it on your server.'),
      findsOneWidget,
    );
  });

  testWidgets('German copy', (t) async {
    await pumpTools(t, _Form(onSave: () {}), locale: const Locale('de'));
    expect(find.text('SCHLÜSSEL FÜR BRIGHTFETCH'), findsOneWidget);
    expect(find.text('Speichern'), findsOneWidget);
    expect(find.text('Schlüssel besorgen'), findsOneWidget);
  });

  testWidgets('the key is obscured and the count line appears when typed', (
    t,
  ) async {
    await pumpTools(t, _Form(text: 'abcdefghijklmno', onSave: () {}));
    expect(
      t.widget<EditableText>(find.byType(EditableText)).obscureText,
      isTrue,
    );
    expect(find.text('15 characters entered'), findsOneWidget);
    expect(find.text('Show key'), findsNothing);
    final handle = t.ensureSemantics();
    expect(find.bySemanticsLabel('Show key'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('no count line while empty', (t) async {
    await pumpTools(t, const _Form());
    expect(find.textContaining('characters entered'), findsNothing);
  });

  group('the one filled button', () {
    for (final (name, form, filled) in [
      ('empty', const _Form(), 1),
      ('typed', const _Form(text: 'secret-value'), 1),
      ('saving', const _Form(phase: ToolsetKeyFormPhase.saving, text: 'x'), 1),
      (
        'failed',
        const _Form(phase: ToolsetKeyFormPhase.failed, text: 'secret-value'),
        1,
      ),
      ('checking', const _Form(phase: ToolsetKeyFormPhase.checking), 0),
      (
        'unconfirmed',
        const _Form(phase: ToolsetKeyFormPhase.unconfirmed, isSet: true),
        0,
      ),
      ('not saved', const _Form(phase: ToolsetKeyFormPhase.notSaved), 1),
      (
        'saved, key set',
        const _Form(phase: ToolsetKeyFormPhase.saved, isSet: true),
        0,
      ),
    ]) {
      testWidgets('$name: $filled', (t) async {
        await pumpTools(t, form);
        expect(_filled, findsNWidgets(filled));
        if (filled == 1) expect(find.text(_saveWords(form)), findsOneWidget);
      });
    }

    testWidgets('Save is the only filled button and Replace is outlined', (
      t,
    ) async {
      await pumpTools(
        t,
        const _Form(isSet: true, phase: ToolsetKeyFormPhase.saved),
      );
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Replace'), findsOneWidget);
      expect(_filled, findsNothing);
    });
  });

  testWidgets('Save is disabled until something is typed', (t) async {
    await pumpTools(t, const _Form());
    expect(t.widget<FilledButton>(_filled).onPressed, isNull);
    var saves = 0;
    await pumpTools(t, _Form(onSave: () => saves++, text: 'x'));
    await t.tap(find.text('Save'));
    expect(saves, 1);
  });

  testWidgets('saving shows a spinner, "Saving…" and cannot be pressed', (
    t,
  ) async {
    var saves = 0;
    await pumpTools(
      t,
      _Form(
        phase: ToolsetKeyFormPhase.saving,
        text: 'x',
        onSave: () => saves++,
      ),
    );
    expect(find.text('Saving…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(t.widget<FilledButton>(_filled).onPressed, isNull);
    // A shown value hides when a save starts: the field is obscured and its
    // toggle is off.
    expect(
      t.widget<EditableText>(find.byType(EditableText)).obscureText,
      isTrue,
    );
  });

  testWidgets('saved: a banner, Already set and Replace, no field', (t) async {
    await pumpTools(
      t,
      const _Form(phase: ToolsetKeyFormPhase.saved, isSet: true),
    );
    expect(find.byType(AppBanner), findsOneWidget);
    expect(find.text('Saved.'), findsOneWidget);
    expect(find.text('Applies from your next chat.'), findsOneWidget);
    expect(find.text('Already set'), findsOneWidget);
    expect(find.byType(EditableText), findsNothing);
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('Replace calls back with the field and is named', (t) async {
    final replaced = <String>[];
    await pumpTools(
      t,
      _Form(isSet: true, onReplace: (field) => replaced.add(field.label)),
    );
    await t.tap(find.text('Replace'));
    expect(replaced, ['Brightfetch API key']);
    final handle = t.ensureSemantics();
    expect(
      find.bySemanticsLabel('Replace Brightfetch API key'),
      findsOneWidget,
    );
    handle.dispose();
  });

  for (final (platform, min) in [
    (TargetPlatform.iOS, 44.0),
    (TargetPlatform.android, 48.0),
    (TargetPlatform.macOS, 28.0),
  ]) {
    testWidgets('Replace and Get a key are at least $min on $platform', (
      t,
    ) async {
      await pumpTools(t, const _Form(isSet: true), platform: platform);
      expect(
        t.getSize(find.widgetWithText(OutlinedButton, 'Replace')).height,
        greaterThanOrEqualTo(min),
      );
      expect(
        t.getSize(find.widgetWithText(TextButton, 'Get a key')).height,
        greaterThanOrEqualTo(min),
      );
      await pumpTools(t, const _Form(text: 'x'), platform: platform);
      expect(
        t.getSize(find.widgetWithText(FilledButton, 'Save')).height,
        greaterThanOrEqualTo(min),
      );
    });
  }

  testWidgets(
    'Get a key has the link colour, an external icon and calls back',
    (t) async {
      final links = <String>[];
      await pumpTools(t, _Form(onGetKey: (field) => links.add(field.label)));
      await t.tap(find.text('Get a key'));
      expect(links, ['Brightfetch API key']);
      final handle = t.ensureSemantics();
      expect(
        t.getSemantics(find.text('Get a key')),
        isSemantics(
          label: 'Get a key',
          isButton: true,
          isLink: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    },
  );

  testWidgets('no link, no Get a key', (t) async {
    await pumpTools(t, const _Form(hasLink: false));
    expect(find.text('Get a key'), findsNothing);
  });

  testWidgets('failed keeps the typed value, hidden, with the error under it', (
    t,
  ) async {
    await pumpTools(
      t,
      const _Form(phase: ToolsetKeyFormPhase.failed, text: 'secret-value'),
    );
    expect(find.text("Couldn't save the key. Try again."), findsOneWidget);
    expect(
      t.widget<EditableText>(find.byType(EditableText)).controller.text,
      'secret-value',
    );
    expect(
      t.widget<EditableText>(find.byType(EditableText)).obscureText,
      isTrue,
    );
    expect(_plainText('secret-value'), findsNothing);
  });

  testWidgets('a lost answer replaces Save with a spinner and a live region', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    await pumpTools(t, const _Form(phase: ToolsetKeyFormPhase.checking));
    expect(find.text('May have saved. Checking…'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      t.getSemantics(find.bySemanticsLabel('May have saved. Checking…')),
      isSemantics(label: 'May have saved. Checking…', isLiveRegion: true),
    );
    handle.dispose();
  });

  testWidgets('a lost answer with reduced motion shows no spinner', (t) async {
    await pumpTools(
      t,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: const _Form(phase: ToolsetKeyFormPhase.checking),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('could not confirm and not saved are lines with live regions', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    await pumpTools(
      t,
      const _Form(phase: ToolsetKeyFormPhase.unconfirmed, isSet: true),
    );
    expect(find.text("Couldn't confirm. Pull to refresh."), findsOneWidget);
    expect(
      t.getSemantics(
        find.bySemanticsLabel("Couldn't confirm. Pull to refresh."),
      ),
      isSemantics(
        label: "Couldn't confirm. Pull to refresh.",
        isLiveRegion: true,
      ),
    );
    await pumpTools(t, const _Form(phase: ToolsetKeyFormPhase.notSaved));
    expect(find.text("The key wasn't saved. Paste it again."), findsOneWidget);
    handle.dispose();
  });

  testWidgets('wraps at 3x in German without overflow', (t) async {
    for (final form in const [
      _Form(text: 'secret-value'),
      _Form(isSet: true, phase: ToolsetKeyFormPhase.saved),
      _Form(phase: ToolsetKeyFormPhase.failed, text: 'x'),
    ]) {
      await pumpTools(t, form, textScale: 3, locale: const Locale('de'));
      expect(t.takeException(), isNull);
    }
  });

  testWidgets('the form never writes the typed text anywhere on screen', (
    t,
  ) async {
    await pumpTools(t, const _Form(text: 'secret-value'));
    expect(_plainText('secret-value'), findsNothing);
  });
}

String _saveWords(_Form form) =>
    form.phase == ToolsetKeyFormPhase.saving ? 'Saving…' : 'Save';
