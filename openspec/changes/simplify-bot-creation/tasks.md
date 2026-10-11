## 1. Creation flow

- [x] 1.1 Add failing widget tests for disclosure, model selection and inheritance, credential wording, automatic open, single-flight saving, validation, and partial retry. Add plain creation fields and Widgetbook cases before screen wiring.
- [x] 1.2 Wire the creation fields into the roster with existing model and bot-open contracts. Record upstream introduction findings without adding an automatic prompt. No new telemetry or API schema changes are needed; update verification guidance for profile alias isolation and explicit screenshot platforms.

## 2. Verification

- [x] 2.1 Run dart format, flutter analyze, relevant flutter tests, Widgetbook and workflow screenshots, OpenSpec validation, and the isolated verify-in-app loop. Record any environment limitations.

## 3. Grouped form alignment

- [x] 3.1 Start with failing platform layout tests, replace the narrow alert with the shared grouped settings layout, and preserve existing settings dialog actions.
- [x] 3.2 Render desktop and phone previews in both themes, verify the creation and shared grouped controls, run formatting and analysis, and update the PR.
