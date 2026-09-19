// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin_providers_put_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PluginProvidersPutBodyCWProxy {
  PluginProvidersPutBody memoryProvider(String? memoryProvider);

  PluginProvidersPutBody contextEngine(String? contextEngine);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PluginProvidersPutBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PluginProvidersPutBody(...).copyWith(id: 12, name: "My name")
  /// ````
  PluginProvidersPutBody call({String? memoryProvider, String? contextEngine});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPluginProvidersPutBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPluginProvidersPutBody.copyWith.fieldName(...)`
class _$PluginProvidersPutBodyCWProxyImpl
    implements _$PluginProvidersPutBodyCWProxy {
  const _$PluginProvidersPutBodyCWProxyImpl(this._value);

  final PluginProvidersPutBody _value;

  @override
  PluginProvidersPutBody memoryProvider(String? memoryProvider) =>
      this(memoryProvider: memoryProvider);

  @override
  PluginProvidersPutBody contextEngine(String? contextEngine) =>
      this(contextEngine: contextEngine);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PluginProvidersPutBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PluginProvidersPutBody(...).copyWith(id: 12, name: "My name")
  /// ````
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
  /// Returns a callable class that can be used as follows: `instanceOfPluginProvidersPutBody.copyWith(...)` or like so:`instanceOfPluginProvidersPutBody.copyWith.fieldName(...)`.
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
