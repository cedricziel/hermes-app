// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'telegram_onboarding_start.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TelegramOnboardingStartCWProxy {
  TelegramOnboardingStart botName(String? botName);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `TelegramOnboardingStart(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// TelegramOnboardingStart(...).copyWith(id: 12, name: "My name")
  /// ```
  TelegramOnboardingStart call({String? botName});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfTelegramOnboardingStart.copyWith(...)` or call `instanceOfTelegramOnboardingStart.copyWith.fieldName(value)` for a single field.
class _$TelegramOnboardingStartCWProxyImpl
    implements _$TelegramOnboardingStartCWProxy {
  const _$TelegramOnboardingStartCWProxyImpl(this._value);

  final TelegramOnboardingStart _value;

  @override
  TelegramOnboardingStart botName(String? botName) => call(botName: botName);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `TelegramOnboardingStart(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// TelegramOnboardingStart(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  TelegramOnboardingStart call({
    Object? botName = const $CopyWithPlaceholder(),
  }) {
    return TelegramOnboardingStart(
      botName: botName == const $CopyWithPlaceholder()
          ? _value.botName
          // ignore: cast_nullable_to_non_nullable
          : botName as String?,
    );
  }
}

extension $TelegramOnboardingStartCopyWith on TelegramOnboardingStart {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfTelegramOnboardingStart.copyWith(...)` or `instanceOfTelegramOnboardingStart.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$TelegramOnboardingStartCWProxy get copyWith =>
      _$TelegramOnboardingStartCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TelegramOnboardingStart _$TelegramOnboardingStartFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('TelegramOnboardingStart', json, ($checkedConvert) {
  final val = TelegramOnboardingStart(
    botName: $checkedConvert('bot_name', (v) => v as String?),
  );
  return val;
}, fieldKeyMap: const {'botName': 'bot_name'});

Map<String, dynamic> _$TelegramOnboardingStartToJson(
  TelegramOnboardingStart instance,
) => <String, dynamic>{'bot_name': ?instance.botName};
