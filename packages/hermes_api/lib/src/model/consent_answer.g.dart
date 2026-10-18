// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'consent_answer.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ConsentAnswerCWProxy {
  ConsentAnswer enabled(bool enabled);

  ConsentAnswer send(bool? send);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ConsentAnswer(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ConsentAnswer(...).copyWith(id: 12, name: "My name")
  /// ```
  ConsentAnswer call({bool enabled, bool? send});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfConsentAnswer.copyWith(...)` or call `instanceOfConsentAnswer.copyWith.fieldName(value)` for a single field.
class _$ConsentAnswerCWProxyImpl implements _$ConsentAnswerCWProxy {
  const _$ConsentAnswerCWProxyImpl(this._value);

  final ConsentAnswer _value;

  @override
  ConsentAnswer enabled(bool enabled) => call(enabled: enabled);

  @override
  ConsentAnswer send(bool? send) => call(send: send);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ConsentAnswer(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ConsentAnswer(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ConsentAnswer call({
    Object? enabled = const $CopyWithPlaceholder(),
    Object? send = const $CopyWithPlaceholder(),
  }) {
    return ConsentAnswer(
      enabled: enabled == const $CopyWithPlaceholder() || enabled == null
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
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfConsentAnswer.copyWith(...)` or `instanceOfConsentAnswer.copyWith.fieldName(...)`.
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
