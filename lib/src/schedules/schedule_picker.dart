import 'package:flutter/material.dart';
import 'package:hermes_app/src/widgets/adaptive_pickers.dart';
import 'package:flutter/services.dart';

import '../theme/platform_chrome.dart';
import '../widgets/grouped_form.dart';
import '../widgets/grouped_list.dart';
import '../widgets/shrink_to_fit_text.dart';
import 'schedule_spec.dart';
import 'schedule_widgets.dart';

enum WhenMode {
  every('Every'),
  daily('Daily'),
  weekly('Weekly'),
  once('Once'),
  cron('Cron');

  const WhenMode(this.label);

  final String label;

  static WhenMode of(ScheduleSpec spec) => switch (spec) {
    EverySpec() => every,
    DailySpec() => daily,
    WeeklySpec() => weekly,
    OnceSpec() => once,
    CronSpec() => cron,
  };
}

/// "When" as a group: the five ways to say it, the rows of the chosen one
/// and, where the phone can work it out, the next runs as its footer.
class SchedulePicker extends StatefulWidget {
  const SchedulePicker({
    super.key,
    required this.spec,
    required this.onChanged,
    required this.now,
  });

  final ScheduleSpec spec;
  final ValueChanged<ScheduleSpec> onChanged;
  final DateTime now;

  @override
  State<SchedulePicker> createState() => _SchedulePickerState();
}

class _SchedulePickerState extends State<SchedulePicker> {
  late final TextEditingController _amount;
  late final TextEditingController _cron;

  ScheduleSpec get _spec => widget.spec;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
      text: switch (_spec) {
        EverySpec(:final amount) => '$amount',
        _ => '1',
      },
    );
    _cron = TextEditingController(
      text: switch (_spec) {
        CronSpec(:final text) => text,
        _ => '',
      },
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    _cron.dispose();
    super.dispose();
  }

  (int, int) get _time => switch (_spec) {
    DailySpec(:final hour, :final minute) => (hour, minute),
    WeeklySpec(:final hour, :final minute) => (hour, minute),
    _ => (8, 0),
  };

  void _mode(WhenMode mode) {
    if (mode == WhenMode.of(_spec)) return;
    final (hour, minute) = _time;
    final next = switch (mode) {
      WhenMode.every => EverySpec(
        int.tryParse(_amount.text) ?? 1,
        switch (_spec) {
          EverySpec(:final unit) => unit,
          _ => EveryUnit.hours,
        },
      ),
      WhenMode.daily => DailySpec(hour, minute),
      WhenMode.weekly => WeeklySpec({1, 2, 3, 4, 5}, hour, minute),
      WhenMode.once => OnceSpec(
        DateTime(widget.now.year, widget.now.month, widget.now.day + 1, 9),
      ),
      WhenMode.cron => CronSpec(
        _cron.text.isNotEmpty
            ? _cron.text
            : switch (_spec) {
                DailySpec() || WeeklySpec() => _spec.toSchedule(),
                _ => '0 9 * * *',
              },
      ),
    };
    if (next is CronSpec) _cron.text = next.text;
    widget.onChanged(next);
  }

  Future<void> _pickTime() async {
    final (hour, minute) = _time;
    final once = _spec is OnceSpec ? (_spec as OnceSpec).at : null;
    final picked = await pickTime(
      context,
      initial: once != null
          ? TimeOfDay.fromDateTime(once)
          : TimeOfDay(hour: hour, minute: minute),
    );
    if (picked == null) return;
    widget.onChanged(switch (_spec) {
      DailySpec() => DailySpec(picked.hour, picked.minute),
      WeeklySpec(:final days) => WeeklySpec(days, picked.hour, picked.minute),
      OnceSpec(:final at) => OnceSpec(
        DateTime(at.year, at.month, at.day, picked.hour, picked.minute),
      ),
      final other => other,
    });
  }

  Future<void> _pickDate() async {
    final at = (_spec as OnceSpec).at;
    final today = DateTime(widget.now.year, widget.now.month, widget.now.day);
    final picked = await pickDate(
      context,
      initial: at.isBefore(today) ? today : at,
      first: today,
      last: today.add(const Duration(days: 365 * 5)),
    );
    if (picked == null) return;
    widget.onChanged(
      OnceSpec(
        DateTime(picked.year, picked.month, picked.day, at.hour, at.minute),
      ),
    );
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final mode = WhenMode.of(_spec);
    final (hour, minute) = _time;
    final runs = _spec.validate(widget.now) == null
        ? _spec.nextRuns(widget.now, 3)
        : null;
    final hasRuns = runs != null && runs.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupedSection(
          header: 'When',
          children: [
            GroupedSegmentedRow<WhenMode>(
              key: const Key('when-mode'),
              value: mode,
              segments: {for (final m in WhenMode.values) m: m.label},
              onChanged: _mode,
            ),
            ...switch (_spec) {
              EverySpec(:final unit) => [
                GroupedTextFieldRow(
                  key: const Key('when-amount'),
                  label: 'Every',
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (text) => widget.onChanged(
                    EverySpec(int.tryParse(text) ?? 0, unit),
                  ),
                ),
                GroupedMenuRow<EveryUnit>(
                  key: const Key('when-unit'),
                  title: 'Unit',
                  options: EveryUnit.values,
                  labelOf: (u) => u.label,
                  selected: unit,
                  onSelected: (u) => widget.onChanged(
                    EverySpec(int.tryParse(_amount.text) ?? 0, u),
                  ),
                ),
              ],
              DailySpec() => [_timeRow('${_two(hour)}:${_two(minute)}')],
              WeeklySpec(:final days) => [
                _DayToggles(
                  days: days,
                  onChanged: (days) =>
                      widget.onChanged(WeeklySpec(days, hour, minute)),
                ),
                _timeRow('${_two(hour)}:${_two(minute)}'),
              ],
              OnceSpec(:final at) => [
                GroupedValueRow(
                  key: const Key('when-date'),
                  title: 'Date',
                  value: MaterialLocalizations.of(context).formatShortDate(at),
                  onTap: _pickDate,
                ),
                _timeRow('${_two(at.hour)}:${_two(at.minute)}'),
              ],
              CronSpec() => [
                GroupedTextFieldRow(
                  key: const Key('when-cron'),
                  label: 'Schedule',
                  hint: '0 9 * * 1-5',
                  controller: _cron,
                  autocorrect: false,
                  monospace: true,
                  onChanged: (text) => widget.onChanged(CronSpec(text)),
                ),
              ],
            },
          ],
        ),
        if (_spec is CronSpec)
          const GroupedFooter(
            'A five-field cron expression, for example 0 9 * * 1-5, or a '
            'phrase like every monday 9am.',
          ),
        if (hasRuns)
          GroupedFooter(
            'Next runs: ${runs.map((t) => formatTime(context, t)).join(', ')}',
            key: const Key('when-preview'),
          )
        else if (_spec is CronSpec)
          const GroupedFooter(
            'The server works out the next run when you save.',
          ),
      ],
    );
  }

  Widget _timeRow(String time) => GroupedValueRow(
    key: const Key('when-time'),
    title: 'Time',
    value: time,
    onTap: _pickTime,
  );
}

/// The days of a weekly schedule, Monday first as a week reads, each a
/// toggle; the numbers are cron's, Sunday 0.
class _DayToggles extends StatelessWidget {
  const _DayToggles({required this.days, required this.onChanged});

  static const _week = [
    ('Mon', 1),
    ('Tue', 2),
    ('Wed', 3),
    ('Thu', 4),
    ('Fri', 5),
    ('Sat', 6),
    ('Sun', 0),
  ];

  final Set<int> days;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final scheme = Theme.of(context).colorScheme;
    final mac = platformChromeOf(context) == PlatformChrome.macos;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: metrics.rowPadding,
        vertical: 8,
      ),
      child: Row(
        spacing: 4,
        children: [
          for (final (label, day) in _week)
            if (days.contains(day) case final on)
              Expanded(
                child: Semantics(
                  button: true,
                  toggled: on,
                  child: Material(
                    color: on ? scheme.primary : scheme.surfaceContainerHighest,
                    shape: const StadiumBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => onChanged(
                        on ? ({...days}..remove(day)) : {...days, day},
                      ),
                      child: SizedBox(
                        height: mac ? 24 : 32,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: ShrinkToFitText(
                              label,
                              style: TextStyle(
                                fontSize: mac ? 11 : 13,
                                fontWeight: on
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: on ? scheme.onPrimary : scheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
