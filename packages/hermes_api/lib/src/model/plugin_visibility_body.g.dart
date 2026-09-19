// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin_visibility_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PluginVisibilityBodyCWProxy {
  PluginVisibilityBody hidden(bool hidden);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PluginVisibilityBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PluginVisibilityBody(...).copyWith(id: 12, name: "My name")
  /// ````
  PluginVisibilityBody call({bool hidden});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPluginVisibilityBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPluginVisibilityBody.copyWith.fieldName(...)`
class _$PluginVisibilityBodyCWProxyImpl
    implements _$PluginVisibilityBodyCWProxy {
  const _$PluginVisibilityBodyCWProxyImpl(this._value);

  final PluginVisibilityBody _value;

  @override
  PluginVisibilityBody hidden(bool hidden) => this(hidden: hidden);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PluginVisibilityBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PluginVisibilityBody(...).copyWith(id: 12, name: "My name")
  /// ````
  PluginVisibilityBody call({Object? hidden = const $CopyWithPlaceholder()}) {
    return PluginVisibilityBody(
      hidden: hidden == const $CopyWithPlaceholder()
          ? _value.hidden
          // ignore: cast_nullable_to_non_nullable
          : hidden as bool,
    );
  }
}

extension $PluginVisibilityBodyCopyWith on PluginVisibilityBody {
  /// Returns a callable class that can be used as follows: `instanceOfPluginVisibilityBody.copyWith(...)` or like so:`instanceOfPluginVisibilityBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PluginVisibilityBodyCWProxy get copyWith =>
      _$PluginVisibilityBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PluginVisibilityBody _$PluginVisibilityBodyFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PluginVisibilityBody', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['hidden']);
  final val = PluginVisibilityBody(
    hidden: $checkedConvert('hidden', (v) => v as bool),
  );
  return val;
});

Map<String, dynamic> _$PluginVisibilityBodyToJson(
  PluginVisibilityBody instance,
) => <String, dynamic>{'hidden': instance.hidden};
