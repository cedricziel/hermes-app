import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';
import 'package:hermes_app/src/macos/menu_layout.dart';

String _chord(SingleActivator activator) =>
    '${activator.control ? '⌃' : ''}${activator.alt ? '⌥' : ''}'
    '${activator.shift ? '⇧' : ''}${activator.meta ? '⌘' : ''}'
    '${activator.trigger.keyLabel}';

void main() {
  const ipad = MenuPlatform.ipad;

  List<String> items(MenuSection section) => [
    for (final (index, group) in section.groupsOn(ipad).indexed) ...[
      if (index > 0) '-',
      for (final entry in group)
        entry.shortcutOn(ipad) == null
            ? entry.label
            : '${entry.label} ${_chord(entry.shortcutOn(ipad)!)}',
    ],
  ];

  test('the iPad layout lists the sections, items and chords of the spec', () {
    final sections = {
      for (final section in menuLayout) section.label: items(section),
    };
    expect(sections, {
      'Hermes': [
        'About Hermes',
        '-',
        'Settings… ⌘,',
        '-',
        'Connection Details',
        'Sign Out…',
      ],
      'File': ['New Chat ⌘N'],
      'View': ['Reload ⌘R', '-', 'Back ⌘[', 'Enclosing Folder'],
      'Chat': [
        'Find… ⌘F',
        '-',
        'Pin ⇧⌘P',
        'Rename…',
        'Copy Transcript',
        'Export Chat as JSON…',
        '-',
        'Archive',
        'Delete…',
      ],
      'Help': ['Hermes Help'],
    });
  });

  test('the iPad layout leaves out the commands of the Mac windows', () {
    final commands = {
      for (final section in menuLayout)
        for (final group in section.groupsOn(ipad))
          for (final entry in group) entry.command,
    };
    expect(
      commands.intersection({
        MacCommand.openInNewWindow,
        MacCommand.closeWindow,
        MacCommand.showMainWindow,
        MacCommand.toggleSidebar,
        MacCommand.toggleInspector,
      }),
      isEmpty,
    );
  });

  test('no iPad chord repeats or takes a text editing key', () {
    final chords = [
      for (final section in menuLayout)
        for (final group in section.groupsOn(ipad))
          for (final entry in group)
            if (entry.shortcutOn(ipad) case final activator?) _chord(activator),
    ];
    expect(chords.toSet(), hasLength(chords.length));
    expect(
      chords.toSet().intersection({
        '⌘C',
        '⌘V',
        '⌘X',
        '⌘A',
        '⌘Z',
        '⇧⌘Z',
        '⌘Backspace',
      }),
      isEmpty,
    );
  });

  test(
    'the Mac lists Reload, Enclosing Folder and the change steps in View',
    () {
      final view = menuLayout.firstWhere((section) => section.id == 'view');
      final entries = {
        for (final group in view.groupsOn(MenuPlatform.mac))
          for (final entry in group) entry.command: entry,
      };
      String chord(MacCommand command) =>
          _chord(entries[command]!.shortcutOn(MenuPlatform.mac)!);
      expect(chord(MacCommand.reload), '⌘R');
      expect(chord(MacCommand.enclosingFolder), '⌘Arrow Up');
      expect(chord(MacCommand.previousChange), '⌥Arrow Up');
      expect(chord(MacCommand.nextChange), '⌥Arrow Down');
      expect(entries[MacCommand.previousChange]!.label, 'Previous Change');
      expect(entries[MacCommand.nextChange]!.label, 'Next Change');
    },
  );

  test('the iPad keeps the arrow keys for text and has no change steps', () {
    final entries = {
      for (final section in menuLayout)
        for (final group in section.groupsOn(ipad))
          for (final entry in group) entry.command: entry,
    };
    expect(entries[MacCommand.enclosingFolder]!.shortcutOn(ipad), isNull);
    expect(entries.containsKey(MacCommand.previousChange), isFalse);
    expect(entries.containsKey(MacCommand.nextChange), isFalse);
  });

  test('the Mac keeps Delete… on Command-Delete', () {
    final delete = menuLayout
        .expand((section) => section.groupsOn(MenuPlatform.mac))
        .expand((group) => group)
        .firstWhere((entry) => entry.command == MacCommand.deleteThread);
    expect(_chord(delete.shortcutOn(MenuPlatform.mac)!), '⌘Backspace');
  });
}
