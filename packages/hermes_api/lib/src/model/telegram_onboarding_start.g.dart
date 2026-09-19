// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'telegram_onboarding_start.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TelegramOnboardingStartCWProxy {
  TelegramOnboardingStart botName(String? botName);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TelegramOnboardingStart(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TelegramOnboardingStart(...).copyWith(id: 12, name: "My name")
  /// ````
  TelegramOnboardingStart call({String? botName});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfTelegramOnboardingStart.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfTelegramOnboardingStart.copyWith.fieldName(...)`
class _$TelegramOnboardingStartCWProxyImpl
    implements _$TelegramOnboardingStartCWProxy {
  const _$TelegramOnboardingStartCWProxyImpl(this._value);

  final TelegramOnboardingStart _value;

  @override
  TelegramOnboardingStart botName(String? botName) => this(botName: botName);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TelegramOnboardingStart(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TelegramOnboardingStart(...).copyWith(id: 12, name: "My name")
  /// ````
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
  /// Returns a callable class that can be used as follows: `instanceOfTelegramOnboardingStart.copyWith(...)` or like so:`instanceOfTelegramOnboardingStart.copyWith.fieldName(...)`.
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
