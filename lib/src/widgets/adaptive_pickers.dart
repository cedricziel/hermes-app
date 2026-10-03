import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hermes_app/src/theme/platform_chrome.dart';

/// Picks a time of day: a [CupertinoDatePicker] in a bottom popup on iOS and
/// macOS, Material's [showTimePicker] elsewhere. Null when cancelled.
Future<TimeOfDay?> pickTime(
  BuildContext context, {
  required TimeOfDay initial,
}) async {
  if (!platformChromeOf(context).isApple) {
    return showTimePicker(context: context, initialTime: initial);
  }
  final now = DateTime.now();
  final picked = await _showPopup(
    context,
    initial: DateTime(
      now.year,
      now.month,
      now.day,
      initial.hour,
      initial.minute,
    ),
    builder: (value, onChanged) => CupertinoDatePicker(
      mode: CupertinoDatePickerMode.time,
      initialDateTime: value,
      use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      onDateTimeChanged: onChanged,
    ),
  );
  return picked == null ? null : TimeOfDay.fromDateTime(picked);
}

/// Picks a date between [first] and [last]: a [CupertinoDatePicker] in a
/// bottom popup on iOS and macOS, Material's [showDatePicker] elsewhere.
/// Null when cancelled.
Future<DateTime?> pickDate(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
}) async {
  if (!platformChromeOf(context).isApple) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
  }
  final picked = await _showPopup(
    context,
    initial: initial,
    builder: (value, onChanged) => CupertinoDatePicker(
      mode: CupertinoDatePickerMode.date,
      initialDateTime: value,
      minimumDate: first,
      maximumDate: last,
      onDateTimeChanged: onChanged,
    ),
  );
  return picked == null
      ? null
      : DateTime(picked.year, picked.month, picked.day);
}

Future<DateTime?> _showPopup(
  BuildContext context, {
  required DateTime initial,
  required Widget Function(DateTime value, ValueChanged<DateTime> onChanged)
  builder,
}) => showCupertinoModalPopup<DateTime>(
  context: context,
  builder: (popup) => _PickerPopup(initial: initial, builder: builder),
);

class _PickerPopup extends StatefulWidget {
  const _PickerPopup({required this.initial, required this.builder});

  final DateTime initial;
  final Widget Function(DateTime value, ValueChanged<DateTime> onChanged)
  builder;

  @override
  State<_PickerPopup> createState() => _PickerPopupState();
}

class _PickerPopupState extends State<_PickerPopup> {
  late DateTime _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: DefaultTextStyle(
        style: CupertinoTheme.of(context).textTheme.textStyle,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 300,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    CupertinoButton(
                      onPressed: () => Navigator.of(context).pop(_value),
                      child: const Text(
                        'Done',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: widget.builder(widget.initial, (v) => _value = v),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
