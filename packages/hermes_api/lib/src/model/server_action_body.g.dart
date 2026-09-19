// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_action_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ServerActionBodyCWProxy {
  ServerActionBody action(String action);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ServerActionBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ServerActionBody(...).copyWith(id: 12, name: "My name")
  /// ````
  ServerActionBody call({String action});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfServerActionBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfServerActionBody.copyWith.fieldName(...)`
class _$ServerActionBodyCWProxyImpl implements _$ServerActionBodyCWProxy {
  const _$ServerActionBodyCWProxyImpl(this._value);

  final ServerActionBody _value;

  @override
  ServerActionBody action(String action) => this(action: action);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ServerActionBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ServerActionBody(...).copyWith(id: 12, name: "My name")
  /// ````
  ServerActionBody call({Object? action = const $CopyWithPlaceholder()}) {
    return ServerActionBody(
      action: action == const $CopyWithPlaceholder()
          ? _value.action
          // ignore: cast_nullable_to_non_nullable
          : action as String,
    );
  }
}

extension $ServerActionBodyCopyWith on ServerActionBody {
  /// Returns a callable class that can be used as follows: `instanceOfServerActionBody.copyWith(...)` or like so:`instanceOfServerActionBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ServerActionBodyCWProxy get copyWith => _$ServerActionBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ServerActionBody _$ServerActionBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ServerActionBody', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['action']);
      final val = ServerActionBody(
        action: $checkedConvert('action', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$ServerActionBodyToJson(ServerActionBody instance) =>
    <String, dynamic>{'action': instance.action};
