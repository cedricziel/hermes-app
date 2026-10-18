// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin_visibility_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PluginVisibilityBodyCWProxy {
  PluginVisibilityBody hidden(bool hidden);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `PluginVisibilityBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// PluginVisibilityBody(...).copyWith(id: 12, name: "My name")
  /// ```
  PluginVisibilityBody call({bool hidden});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfPluginVisibilityBody.copyWith(...)` or call `instanceOfPluginVisibilityBody.copyWith.fieldName(value)` for a single field.
class _$PluginVisibilityBodyCWProxyImpl
    implements _$PluginVisibilityBodyCWProxy {
  const _$PluginVisibilityBodyCWProxyImpl(this._value);

  final PluginVisibilityBody _value;

  @override
  PluginVisibilityBody hidden(bool hidden) => call(hidden: hidden);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `PluginVisibilityBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// PluginVisibilityBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  PluginVisibilityBody call({Object? hidden = const $CopyWithPlaceholder()}) {
    return PluginVisibilityBody(
      hidden: hidden == const $CopyWithPlaceholder() || hidden == null
          ? _value.hidden
          // ignore: cast_nullable_to_non_nullable
          : hidden as bool,
    );
  }
}

extension $PluginVisibilityBodyCopyWith on PluginVisibilityBody {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfPluginVisibilityBody.copyWith(...)` or `instanceOfPluginVisibilityBody.copyWith.fieldName(...)`.
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
