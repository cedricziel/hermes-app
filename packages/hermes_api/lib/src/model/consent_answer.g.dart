// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'consent_answer.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ConsentAnswerCWProxy {
  ConsentAnswer enabled(bool enabled);

  ConsentAnswer send(bool? send);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ConsentAnswer(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ConsentAnswer(...).copyWith(id: 12, name: "My name")
  /// ````
  ConsentAnswer call({bool enabled, bool? send});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfConsentAnswer.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfConsentAnswer.copyWith.fieldName(...)`
class _$ConsentAnswerCWProxyImpl implements _$ConsentAnswerCWProxy {
  const _$ConsentAnswerCWProxyImpl(this._value);

  final ConsentAnswer _value;

  @override
  ConsentAnswer enabled(bool enabled) => this(enabled: enabled);

  @override
  ConsentAnswer send(bool? send) => this(send: send);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ConsentAnswer(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ConsentAnswer(...).copyWith(id: 12, name: "My name")
  /// ````
  ConsentAnswer call({
    Object? enabled = const $CopyWithPlaceholder(),
    Object? send = const $CopyWithPlaceholder(),
  }) {
    return ConsentAnswer(
      enabled: enabled == const $CopyWithPlaceholder()
          ? _value.enabled
          // ignore: cast_nullable_to_non_nullable
          : enabled as bool,
      send: send == const $CopyWithPlaceholder()
          ? _value.send
          // ignore: cast_nullable_to_non_nullable
          : send as bool?,
    );
  }
}

extension $ConsentAnswerCopyWith on ConsentAnswer {
  /// Returns a callable class that can be used as follows: `instanceOfConsentAnswer.copyWith(...)` or like so:`instanceOfConsentAnswer.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ConsentAnswerCWProxy get copyWith => _$ConsentAnswerCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConsentAnswer _$ConsentAnswerFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ConsentAnswer', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['enabled']);
      final val = ConsentAnswer(
        enabled: $checkedConvert('enabled', (v) => v as bool),
        send: $checkedConvert('send', (v) => v as bool? ?? false),
      );
      return val;
    });

Map<String, dynamic> _$ConsentAnswerToJson(ConsentAnswer instance) =>
    <String, dynamic>{'enabled': instance.enabled, 'send': ?instance.send};
