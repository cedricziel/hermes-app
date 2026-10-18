// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'toolset_model_select.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ToolsetModelSelectCWProxy {
  ToolsetModelSelect model(String model);

  ToolsetModelSelect provider(String? provider);

  ToolsetModelSelect profile(String? profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ToolsetModelSelect(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ToolsetModelSelect(...).copyWith(id: 12, name: "My name")
  /// ```
  ToolsetModelSelect call({String model, String? provider, String? profile});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfToolsetModelSelect.copyWith(...)` or call `instanceOfToolsetModelSelect.copyWith.fieldName(value)` for a single field.
class _$ToolsetModelSelectCWProxyImpl implements _$ToolsetModelSelectCWProxy {
  const _$ToolsetModelSelectCWProxyImpl(this._value);

  final ToolsetModelSelect _value;

  @override
  ToolsetModelSelect model(String model) => call(model: model);

  @override
  ToolsetModelSelect provider(String? provider) => call(provider: provider);

  @override
  ToolsetModelSelect profile(String? profile) => call(profile: profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ToolsetModelSelect(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ToolsetModelSelect(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ToolsetModelSelect call({
    Object? model = const $CopyWithPlaceholder(),
    Object? provider = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return ToolsetModelSelect(
      model: model == const $CopyWithPlaceholder() || model == null
          ? _value.model
          // ignore: cast_nullable_to_non_nullable
          : model as String,
      provider: provider == const $CopyWithPlaceholder()
          ? _value.provider
          // ignore: cast_nullable_to_non_nullable
          : provider as String?,
      profile: profile == const $CopyWithPlaceholder()
          ? _value.profile
          // ignore: cast_nullable_to_non_nullable
          : profile as String?,
    );
  }
}

extension $ToolsetModelSelectCopyWith on ToolsetModelSelect {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfToolsetModelSelect.copyWith(...)` or `instanceOfToolsetModelSelect.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ToolsetModelSelectCWProxy get copyWith =>
      _$ToolsetModelSelectCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ToolsetModelSelect _$ToolsetModelSelectFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ToolsetModelSelect', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['model']);
      final val = ToolsetModelSelect(
        model: $checkedConvert('model', (v) => v as String),
        provider: $checkedConvert('provider', (v) => v as String?),
        profile: $checkedConvert('profile', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$ToolsetModelSelectToJson(ToolsetModelSelect instance) =>
    <String, dynamic>{
      'model': instance.model,
      'provider': ?instance.provider,
      'profile': ?instance.profile,
    };
