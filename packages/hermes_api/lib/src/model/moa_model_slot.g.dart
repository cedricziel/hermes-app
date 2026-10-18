// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moa_model_slot.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MoaModelSlotCWProxy {
  MoaModelSlot provider(String? provider);

  MoaModelSlot model(String? model);

  MoaModelSlot reasoningEffort(String? reasoningEffort);

  MoaModelSlot enabled(bool? enabled);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MoaModelSlot(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MoaModelSlot(...).copyWith(id: 12, name: "My name")
  /// ```
  MoaModelSlot call({
    String? provider,
    String? model,
    String? reasoningEffort,
    bool? enabled,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfMoaModelSlot.copyWith(...)` or call `instanceOfMoaModelSlot.copyWith.fieldName(value)` for a single field.
class _$MoaModelSlotCWProxyImpl implements _$MoaModelSlotCWProxy {
  const _$MoaModelSlotCWProxyImpl(this._value);

  final MoaModelSlot _value;

  @override
  MoaModelSlot provider(String? provider) => call(provider: provider);

  @override
  MoaModelSlot model(String? model) => call(model: model);

  @override
  MoaModelSlot reasoningEffort(String? reasoningEffort) =>
      call(reasoningEffort: reasoningEffort);

  @override
  MoaModelSlot enabled(bool? enabled) => call(enabled: enabled);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MoaModelSlot(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MoaModelSlot(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  MoaModelSlot call({
    Object? provider = const $CopyWithPlaceholder(),
    Object? model = const $CopyWithPlaceholder(),
    Object? reasoningEffort = const $CopyWithPlaceholder(),
    Object? enabled = const $CopyWithPlaceholder(),
  }) {
    return MoaModelSlot(
      provider: provider == const $CopyWithPlaceholder()
          ? _value.provider
          // ignore: cast_nullable_to_non_nullable
          : provider as String?,
      model: model == const $CopyWithPlaceholder()
          ? _value.model
          // ignore: cast_nullable_to_non_nullable
          : model as String?,
      reasoningEffort: reasoningEffort == const $CopyWithPlaceholder()
          ? _value.reasoningEffort
          // ignore: cast_nullable_to_non_nullable
          : reasoningEffort as String?,
      enabled: enabled == const $CopyWithPlaceholder()
          ? _value.enabled
          // ignore: cast_nullable_to_non_nullable
          : enabled as bool?,
    );
  }
}

extension $MoaModelSlotCopyWith on MoaModelSlot {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfMoaModelSlot.copyWith(...)` or `instanceOfMoaModelSlot.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MoaModelSlotCWProxy get copyWith => _$MoaModelSlotCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MoaModelSlot _$MoaModelSlotFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MoaModelSlot', json, ($checkedConvert) {
      final val = MoaModelSlot(
        provider: $checkedConvert('provider', (v) => v as String? ?? ''),
        model: $checkedConvert('model', (v) => v as String? ?? ''),
        reasoningEffort: $checkedConvert(
          'reasoning_effort',
          (v) => v as String?,
        ),
        enabled: $checkedConvert('enabled', (v) => v as bool? ?? true),
      );
      return val;
    }, fieldKeyMap: const {'reasoningEffort': 'reasoning_effort'});

Map<String, dynamic> _$MoaModelSlotToJson(MoaModelSlot instance) =>
    <String, dynamic>{
      'provider': ?instance.provider,
      'model': ?instance.model,
      'reasoning_effort': ?instance.reasoningEffort,
      'enabled': ?instance.enabled,
    };
