// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'voice_live_session_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$VoiceLiveSessionRequestCWProxy {
  VoiceLiveSessionRequest sdp(String sdp);

  VoiceLiveSessionRequest history(List<Map<String, Object>>? history);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `VoiceLiveSessionRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// VoiceLiveSessionRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  VoiceLiveSessionRequest call({
    String sdp,
    List<Map<String, Object>>? history,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfVoiceLiveSessionRequest.copyWith(...)` or call `instanceOfVoiceLiveSessionRequest.copyWith.fieldName(value)` for a single field.
class _$VoiceLiveSessionRequestCWProxyImpl
    implements _$VoiceLiveSessionRequestCWProxy {
  const _$VoiceLiveSessionRequestCWProxyImpl(this._value);

  final VoiceLiveSessionRequest _value;

  @override
  VoiceLiveSessionRequest sdp(String sdp) => call(sdp: sdp);

  @override
  VoiceLiveSessionRequest history(List<Map<String, Object>>? history) =>
      call(history: history);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `VoiceLiveSessionRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// VoiceLiveSessionRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  VoiceLiveSessionRequest call({
    Object? sdp = const $CopyWithPlaceholder(),
    Object? history = const $CopyWithPlaceholder(),
  }) {
    return VoiceLiveSessionRequest(
      sdp: sdp == const $CopyWithPlaceholder() || sdp == null
          ? _value.sdp
          // ignore: cast_nullable_to_non_nullable
          : sdp as String,
      history: history == const $CopyWithPlaceholder()
          ? _value.history
          // ignore: cast_nullable_to_non_nullable
          : history as List<Map<String, Object>>?,
    );
  }
}

extension $VoiceLiveSessionRequestCopyWith on VoiceLiveSessionRequest {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfVoiceLiveSessionRequest.copyWith(...)` or `instanceOfVoiceLiveSessionRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$VoiceLiveSessionRequestCWProxy get copyWith =>
      _$VoiceLiveSessionRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VoiceLiveSessionRequest _$VoiceLiveSessionRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('VoiceLiveSessionRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['sdp']);
  final val = VoiceLiveSessionRequest(
    sdp: $checkedConvert('sdp', (v) => v as String),
    history: $checkedConvert(
      'history',
      (v) => (v as List<dynamic>?)
          ?.map(
            (e) => (e as Map<String, dynamic>).map(
              (k, e) => MapEntry(k, e as Object),
            ),
          )
          .toList(),
    ),
  );
  return val;
});

Map<String, dynamic> _$VoiceLiveSessionRequestToJson(
  VoiceLiveSessionRequest instance,
) => <String, dynamic>{'sdp': instance.sdp, 'history': ?instance.history};
