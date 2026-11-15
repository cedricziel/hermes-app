import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/theme/material_ui_bridge.dart';
import 'package:hermes_app/src/widgets/bounded_markdown.dart';

import '../support/screenshot_recorder.dart';

const _reply = '''
The config the agent reads, and the script that checks it:

```json
{
  "plot": "A",
  "moisture": 14.2,
  "valid": true,
  "readings": [14.2, 11.8, null],
  "note": "rounded to one decimal"
}
```

```python
def moisture(readings):
    # the mean, in percent
    return sum(readings) / len(readings)
```

```yaml
plot: A
valid: true
readings: [14.2, 11.8]
```
''';

/// Fenced code blocks of a chat reply, the shared code palette in both themes.
void main() {
  for (final brightness in Brightness.values) {
    testWidgets('code blocks in a reply, ${brightness.name}', (tester) async {
      final shots = ScreenshotRecorder('code-blocks-${brightness.name}');
      await shots.start(tester, phoneSize, pixelRatio: 2);
      final theme = withScreenshotFont(
        brightness == Brightness.dark
            ? buildHermesDarkTheme()
            : buildHermesLightTheme(),
      );
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          builder: (context, child) => MaterialUiThemeScope(child: child!),
          home: shots.frame(
            Scaffold(
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: const BoundedMarkdown(_reply),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await shots.capture(tester, 'reply');
    });
  }
}
