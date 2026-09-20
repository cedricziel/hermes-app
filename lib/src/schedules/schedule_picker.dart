import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

/// "When": the five ways to say it, the inputs of the chosen one and, where
/// the phone can work it out, the next runs.
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
  // Monday first, as a week reads; the numbers are cron's, Sunday 0.
  static const _week = [
    ('Mon', 1),
    ('Tue', 2),
    ('Wed', 3),
    ('Thu', 4),
    ('Fri', 5),
    ('Sat', 6),
    ('Sun', 0),
  ];

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
    final picked = await showTimePicker(
      context: context,
      initialTime: once != null
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
    final picked = await showDatePicker(
      context: context,
      initialDate: at.isBefore(today) ? today : at,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365 * 5)),
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
    final theme = Theme.of(context);
    final mode = WhenMode.of(_spec);
    final (hour, minute) = _time;
    final runs = _spec.validate(widget.now) == null
        ? _spec.nextRuns(widget.now, 3)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final m in WhenMode.values)
              ChoiceChip(
                label: Text(m.label),
                selected: m == mode,
                onSelected: (_) => _mode(m),
              ),
          ],
        ),
        switch (_spec) {
          EverySpec(:final unit) => Row(
            spacing: 12,
            children: [
              SizedBox(
                width: 90,
                child: TextField(
                  key: const Key('when-amount'),
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Every'),
                  onChanged: (text) => widget.onChanged(
                    EverySpec(int.tryParse(text) ?? 0, unit),
                  ),
                ),
              ),
              DropdownButton<EveryUnit>(
                key: const Key('when-unit'),
                value: unit,
                items: [
                  for (final u in EveryUnit.values)
                    DropdownMenuItem(value: u, child: Text(u.label)),
                ],
                onChanged: (u) => widget.onChanged(
                  EverySpec(int.tryParse(_amount.text) ?? 0, u ?? unit),
                ),
              ),
            ],
          ),
          DailySpec() => _timeButton('${_two(hour)}:${_two(minute)}'),
          WeeklySpec(:final days) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Wrap(
                spacing: 6,
                children: [
                  for (final (label, day) in _week)
                    FilterChip(
                      label: Text(label),
                      selected: days.contains(day),
                      onSelected: (on) => widget.onChanged(
                        WeeklySpec(
                          on ? {...days, day} : ({...days}..remove(day)),
                          hour,
                          minute,
                        ),
                      ),
                    ),
                ],
              ),
              _timeButton('${_two(hour)}:${_two(minute)}'),
            ],
          ),
          OnceSpec(:final at) => Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                key: const Key('when-date'),
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(
                  MaterialLocalizations.of(context).formatShortDate(at),
                ),
              ),
              _timeButton('${_two(at.hour)}:${_two(at.minute)}'),
            ],
          ),
          CronSpec() => TextField(
            key: const Key('when-cron'),
            controller: _cron,
            style: const TextStyle(fontFamily: 'monospace'),
            decoration: const InputDecoration(
              labelText: 'Schedule',
              helperText: 'A five-field cron expression, for example 0 9 * * 1-5, or a phrase like every monday 9am',
              helperMaxLines: 2,
            ),
            onChanged: (text) => widget.onChanged(CronSpec(text)),
          ),
        },
        if (runs != null && runs.isNotEmpty)
          Text(
            'Next runs: ${runs.map((t) => formatTime(context, t)).join(', ')}',
            key: const Key('when-preview'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else if (_spec is CronSpec)
          Text(
            'The server works out the next run when you save.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  Widget _timeButton(String label) => Align(
    alignment: Alignment.centerLeft,
    child: OutlinedButton.icon(
      key: const Key('when-time'),
      onPressed: _pickTime,
      icon: const Icon(Icons.access_time, size: 18),
      label: Text(label),
    ),
  );
}
