// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin_providers_put_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PluginProvidersPutBodyCWProxy {
  PluginProvidersPutBody memoryProvider(String? memoryProvider);

  PluginProvidersPutBody contextEngine(String? contextEngine);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `PluginProvidersPutBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// PluginProvidersPutBody(...).copyWith(id: 12, name: "My name")
  /// ```
  PluginProvidersPutBody call({String? memoryProvider, String? contextEngine});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfPluginProvidersPutBody.copyWith(...)` or call `instanceOfPluginProvidersPutBody.copyWith.fieldName(value)` for a single field.
class _$PluginProvidersPutBodyCWProxyImpl
    implements _$PluginProvidersPutBodyCWProxy {
  const _$PluginProvidersPutBodyCWProxyImpl(this._value);

  final PluginProvidersPutBody _value;

  @override
  PluginProvidersPutBody memoryProvider(String? memoryProvider) =>
      call(memoryProvider: memoryProvider);

  @override
  PluginProvidersPutBody contextEngine(String? contextEngine) =>
      call(contextEngine: contextEngine);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `PluginProvidersPutBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// PluginProvidersPutBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  PluginProvidersPutBody call({
    Object? memoryProvider = const $CopyWithPlaceholder(),
    Object? contextEngine = const $CopyWithPlaceholder(),
  }) {
    return PluginProvidersPutBody(
      memoryProvider: memoryProvider == const $CopyWithPlaceholder()
          ? _value.memoryProvider
          // ignore: cast_nullable_to_non_nullable
          : memoryProvider as String?,
      contextEngine: contextEngine == const $CopyWithPlaceholder()
          ? _value.contextEngine
          // ignore: cast_nullable_to_non_nullable
          : contextEngine as String?,
    );
  }
}

extension $PluginProvidersPutBodyCopyWith on PluginProvidersPutBody {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfPluginProvidersPutBody.copyWith(...)` or `instanceOfPluginProvidersPutBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PluginProvidersPutBodyCWProxy get copyWith =>
      _$PluginProvidersPutBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PluginProvidersPutBody _$PluginProvidersPutBodyFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'PluginProvidersPutBody',
  json,
  ($checkedConvert) {
    final val = PluginProvidersPutBody(
      memoryProvider: $checkedConvert('memory_provider', (v) => v as String?),
      contextEngine: $checkedConvert('context_engine', (v) => v as String?),
    );
    return val;
  },
  fieldKeyMap: const {
    'memoryProvider': 'memory_provider',
    'contextEngine': 'context_engine',
  },
);

Map<String, dynamic> _$PluginProvidersPutBodyToJson(
  PluginProvidersPutBody instance,
) => <String, dynamic>{
  'memory_provider': ?instance.memoryProvider,
  'context_engine': ?instance.contextEngine,
};
