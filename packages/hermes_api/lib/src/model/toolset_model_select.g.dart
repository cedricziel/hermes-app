// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'toolset_model_select.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ToolsetModelSelectCWProxy {
  ToolsetModelSelect model(String model);

  ToolsetModelSelect provider(String? provider);

  ToolsetModelSelect profile(String? profile);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ToolsetModelSelect(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ToolsetModelSelect(...).copyWith(id: 12, name: "My name")
  /// ````
  ToolsetModelSelect call({String model, String? provider, String? profile});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfToolsetModelSelect.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfToolsetModelSelect.copyWith.fieldName(...)`
class _$ToolsetModelSelectCWProxyImpl implements _$ToolsetModelSelectCWProxy {
  const _$ToolsetModelSelectCWProxyImpl(this._value);

  final ToolsetModelSelect _value;

  @override
  ToolsetModelSelect model(String model) => this(model: model);

  @override
  ToolsetModelSelect provider(String? provider) => this(provider: provider);

  @override
  ToolsetModelSelect profile(String? profile) => this(profile: profile);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ToolsetModelSelect(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ToolsetModelSelect(...).copyWith(id: 12, name: "My name")
  /// ````
  ToolsetModelSelect call({
    Object? model = const $CopyWithPlaceholder(),
    Object? provider = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return ToolsetModelSelect(
      model: model == const $CopyWithPlaceholder()
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
  /// Returns a callable class that can be used as follows: `instanceOfToolsetModelSelect.copyWith(...)` or like so:`instanceOfToolsetModelSelect.copyWith.fieldName(...)`.
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
