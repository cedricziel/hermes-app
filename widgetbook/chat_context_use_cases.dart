import 'package:flutter/material.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/context/context_models.dart';
import 'package:hermes_app/src/chat/context/context_state.dart';
import 'package:hermes_app/src/chat/context/widgets/compress_confirmation.dart';
import 'package:hermes_app/src/chat/context/widgets/compress_outcome_note.dart';
import 'package:hermes_app/src/chat/context/widgets/context_category_list.dart';
import 'package:hermes_app/src/chat/context/widgets/context_format.dart';
import 'package:hermes_app/src/chat/context/widgets/context_row.dart';
import 'package:hermes_app/src/chat/context/widgets/context_summary.dart';
import 'package:hermes_app/src/chat/widgets/transcript_outcome_line.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

// Invented figures; nothing here comes from a server.
ContextFigures _figures(int percent, {int max = 200000, bool? estimated}) =>
    ContextFigures(
      used: max * percent ~/ 100,
      max: max,
      percent: percent,
      estimated: estimated,
      source: estimated == true
          ? ContextSource.localEstimate
          : ContextSource.providerUsage,
    );

const _over = ContextFigures(
  used: 212000,
  max: 200000,
  percent: 100,
  estimated: false,
  source: ContextSource.providerUsage,
);

const _eight = [
  ContextCategory(ContextCategoryKind.conversation, 61200),
  ContextCategory(ContextCategoryKind.toolDefinitions, 28400),
  ContextCategory(ContextCategoryKind.systemPrompt, 9800),
  ContextCategory(ContextCategoryKind.skills, 6100),
  ContextCategory(ContextCategoryKind.rules, 3300),
  ContextCategory(ContextCategoryKind.mcp, 2400),
  ContextCategory(ContextCategoryKind.memory, 900),
  ContextCategory(ContextCategoryKind.subagentDefinitions, 250),
];

Widget _scaled(BuildContext context, double scale, Widget child) => MediaQuery(
  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
  child: child,
);

Widget _row(
  ContextFigures figures, {
  bool notUpToDate = false,
  bool locked = false,
  bool compressing = false,
  bool suggestion = false,
}) => frame(
  maxWidth: 380,
  ContextRow(
    figures: figures,
    level: contextLevelOf(figures),
    notUpToDate: notUpToDate,
    locked: locked,
    compressing: compressing,
    suggestionVisible: suggestion,
    onOpen: locked ? null : () {},
    onCompress: () {},
    onDismissSuggestion: () {},
  ),
);

Widget _summary(
  ContextFigures figures, {
  bool notUpToDate = false,
  String? model = 'example-model-large',
}) => frame(
  maxWidth: 380,
  ContextSummary(
    figures: figures,
    level: contextLevelOf(figures),
    notUpToDate: notUpToDate,
    model: model,
  ),
);

Widget _categories(
  ContextCategoryListState state, {
  List<ContextCategory> categories = _eight,
  double width = 380,
}) => frame(
  maxWidth: width,
  ContextCategoryList(state: state, categories: categories, onRetry: () {}),
);

/// A sheet-like surface with the bounded height a sheet or dialog gives,
/// placed by the shared frame.
Widget _sheet(BuildContext context, Widget child) => frame(
  ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height - 64,
    ),
    child: Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: child,
    ),
  ),
  maxWidth: 520,
);

Widget _confirmation({
  bool replyStarted = false,
  String focus = '',
  bool open = false,
}) => CompressConfirmation(
  replyStarted: replyStarted,
  initialFocus: focus,
  advancedInitiallyOpen: open,
  onConfirm: (_) {},
  onCancel: () {},
);

WidgetbookUseCase _note(String name, CompressOutcome outcome) =>
    WidgetbookUseCase(
      name: name,
      builder: (_) =>
          frame(CompressOutcomeNote(outcome: outcome, onTryAgain: () {})),
    );

WidgetbookFolder chatContextNode() => WidgetbookFolder(
  name: 'Chat context',
  children: [
    WidgetbookComponent(
      name: 'ContextRow',
      useCases: [
        WidgetbookUseCase(
          name: '12%',
          builder: (_) => _row(_figures(12, estimated: false)),
        ),
        WidgetbookUseCase(
          name: '62% estimated',
          builder: (_) => _row(_figures(62, estimated: true)),
        ),
        WidgetbookUseCase(
          name: '62% measured',
          builder: (_) => _row(_figures(62, estimated: false)),
        ),
        ...onEachPlatform(
          '82% nearly full',
          (_) => _row(_figures(82, estimated: false)),
        ),
        WidgetbookUseCase(
          name: '97% nearly full, error colour',
          builder: (_) => _row(_figures(97, estimated: false)),
        ),
        WidgetbookUseCase(
          name: '100% over the window',
          builder: (_) => _row(_over),
        ),
        ...onEachPlatform(
          'Suggestion',
          (_) => _row(_figures(88, estimated: false), suggestion: true),
        ),
        WidgetbookUseCase(
          name: 'Compressing',
          builder: (_) =>
              _row(_figures(91, estimated: false), compressing: true),
        ),
        WidgetbookUseCase(
          name: 'Not up to date',
          builder: (_) =>
              _row(_figures(82, estimated: false), notUpToDate: true),
        ),
        WidgetbookUseCase(
          name: 'App Lock',
          builder: (_) => _row(_figures(82, estimated: false), locked: true),
        ),
        WidgetbookUseCase(
          name: 'Largest text, nearly full with suggestion',
          builder: (context) => _scaled(
            context,
            3,
            _row(_figures(82, estimated: true), suggestion: true),
          ),
        ),
        WidgetbookUseCase(
          name: 'Largest text, over the window, not up to date',
          builder: (context) =>
              _scaled(context, 3, _row(_over, notUpToDate: true)),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ContextSummary',
      useCases: [
        WidgetbookUseCase(
          name: '62%',
          builder: (_) => _summary(_figures(62, estimated: true)),
        ),
        WidgetbookUseCase(
          name: '82%',
          builder: (_) => _summary(_figures(82, estimated: false)),
        ),
        WidgetbookUseCase(
          name: 'Over the window',
          builder: (_) => _summary(_over),
        ),
        WidgetbookUseCase(
          name: 'Not up to date',
          builder: (_) =>
              _summary(_figures(82, estimated: false), notUpToDate: true),
        ),
        WidgetbookUseCase(
          name: 'No model',
          builder: (_) => _summary(_figures(62, estimated: true), model: null),
        ),
        WidgetbookUseCase(
          name: 'Largest text',
          builder: (context) =>
              _scaled(context, 3, _summary(_figures(82, estimated: true))),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ContextCategoryList',
      useCases: [
        WidgetbookUseCase(
          name: 'Eight categories',
          builder: (_) => _categories(ContextCategoryListState.loaded),
        ),
        WidgetbookUseCase(
          name: 'Long labels wrap',
          builder: (context) => _scaled(
            context,
            2,
            _categories(
              ContextCategoryListState.loaded,
              width: 280,
              categories: const [
                ContextCategory(ContextCategoryKind.conversation, 1234567),
                ContextCategory(ContextCategoryKind.subagentDefinitions, 98765),
                ContextCategory(ContextCategoryKind.mcp, 4321),
                ContextCategory(ContextCategoryKind.other, 12),
              ],
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Loading',
          builder: (_) => _categories(ContextCategoryListState.loading),
        ),
        WidgetbookUseCase(
          name: 'Failed',
          builder: (_) => _categories(ContextCategoryListState.failed),
        ),
        WidgetbookUseCase(
          name: 'Unsupported (draws nothing)',
          builder: (_) => _categories(ContextCategoryListState.unsupported),
        ),
        WidgetbookUseCase(
          name: 'Largest text',
          builder: (context) =>
              _scaled(context, 3, _categories(ContextCategoryListState.loaded)),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'CompressConfirmation',
      useCases: [
        ...onEachPlatform(
          'Default',
          (context) => _sheet(context, _confirmation()),
        ),
        ...onEachPlatform(
          'Focus on open',
          (context) => _sheet(
            context,
            _confirmation(open: true, focus: 'the token refresh'),
          ),
        ),
        ...onEachPlatform(
          'Focus refused',
          (context) => _sheet(
            context,
            _confirmation(open: true, focus: '--preview the schema'),
          ),
        ),
        ...onEachPlatform(
          'Reply started',
          (context) => _sheet(context, _confirmation(replyStarted: true)),
        ),
        WidgetbookUseCase(
          name: 'Largest text, body scrolls and buttons stack',
          builder: (context) =>
              _scaled(context, 3, _sheet(context, _confirmation())),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'CompressOutcomeNote',
      useCases: [
        _note(
          'Compressed',
          const CompressOutcome(
            CompressOutcomeKind.compressed,
            beforeMessages: 42,
            afterMessages: 9,
            beforeTokens: 120000,
            afterTokens: 30000,
          ),
        ),
        _note(
          'Compressed, summary failed',
          const CompressOutcome(
            CompressOutcomeKind.compressed,
            beforeMessages: 42,
            afterMessages: 9,
            beforeTokens: 120000,
            afterTokens: 30000,
            fallbackUsed: true,
          ),
        ),
        _note(
          'Compressed, no counts',
          const CompressOutcome(CompressOutcomeKind.compressed),
        ),
        _note(
          'Nothing to compress',
          const CompressOutcome(CompressOutcomeKind.nothingToCompress),
        ),
        _note(
          'Would not shrink',
          const CompressOutcome(CompressOutcomeKind.wouldNotShrink),
        ),
        _note(
          'Summary failed',
          const CompressOutcome(CompressOutcomeKind.aborted),
        ),
        _note(
          'Busy replying',
          const CompressOutcome(CompressOutcomeKind.busyReplying),
        ),
        _note(
          'Busy compressing',
          const CompressOutcome(CompressOutcomeKind.busyCompressing),
        ),
        _note('Lock held', const CompressOutcome(CompressOutcomeKind.lockHeld)),
        _note(
          'Pending in the background',
          const CompressOutcome(CompressOutcomeKind.pending),
        ),
        _note(
          'No answer',
          const CompressOutcome(CompressOutcomeKind.couldntConfirm),
        ),
        _note('Failed', const CompressOutcome(CompressOutcomeKind.failed)),
        _note(
          'Unsupported (draws nothing)',
          const CompressOutcome(CompressOutcomeKind.unsupported),
        ),
        WidgetbookUseCase(
          name: 'Largest text, no answer',
          builder: (context) => _scaled(
            context,
            3,
            frame(
              CompressOutcomeNote(
                outcome: const CompressOutcome(
                  CompressOutcomeKind.couldntConfirm,
                ),
                onTryAgain: () {},
              ),
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Transcript line',
          builder: (context) => frame(
            TranscriptOutcomeLine(
              text:
                  transcriptLineForCompress(
                    context.l10n,
                    const CompressOutcome(
                      CompressOutcomeKind.compressed,
                      beforeMessages: 42,
                      afterMessages: 9,
                    ),
                  ) ??
                  '',
            ),
          ),
        ),
      ],
    ),
  ],
);
