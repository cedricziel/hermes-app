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
      'View': ['Back ⌘['],
      'Chat': [
        'Find… ⌘F',
        '-',
        'Pin ⇧⌘P',
        'Rename…',
        'Copy Transcript',
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

  test('the Mac keeps Delete… on Command-Delete', () {
    final delete = menuLayout
        .expand((section) => section.groupsOn(MenuPlatform.mac))
        .expand((group) => group)
        .firstWhere((entry) => entry.command == MacCommand.deleteThread);
    expect(_chord(delete.shortcutOn(MenuPlatform.mac)!), '⌘Backspace');
  });
}
