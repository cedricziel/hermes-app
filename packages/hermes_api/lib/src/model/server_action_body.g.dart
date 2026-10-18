// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_action_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ServerActionBodyCWProxy {
  ServerActionBody action(String action);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ServerActionBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ServerActionBody(...).copyWith(id: 12, name: "My name")
  /// ```
  ServerActionBody call({String action});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfServerActionBody.copyWith(...)` or call `instanceOfServerActionBody.copyWith.fieldName(value)` for a single field.
class _$ServerActionBodyCWProxyImpl implements _$ServerActionBodyCWProxy {
  const _$ServerActionBodyCWProxyImpl(this._value);

  final ServerActionBody _value;

  @override
  ServerActionBody action(String action) => call(action: action);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ServerActionBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ServerActionBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ServerActionBody call({Object? action = const $CopyWithPlaceholder()}) {
    return ServerActionBody(
      action: action == const $CopyWithPlaceholder() || action == null
          ? _value.action
          // ignore: cast_nullable_to_non_nullable
          : action as String,
    );
  }
}

extension $ServerActionBodyCopyWith on ServerActionBody {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfServerActionBody.copyWith(...)` or `instanceOfServerActionBody.copyWith.fieldName(...)`.
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
