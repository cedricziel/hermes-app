// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_rename.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SessionRenameCWProxy {
  SessionRename title(String? title);

  SessionRename archived(bool? archived);

  SessionRename hidden(bool? hidden);

  SessionRename pinned(bool? pinned);

  SessionRename unread(bool? unread);

  SessionRename profile(String? profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `SessionRename(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// SessionRename(...).copyWith(id: 12, name: "My name")
  /// ```
  SessionRename call({
    String? title,
    bool? archived,
    bool? hidden,
    bool? pinned,
    bool? unread,
    String? profile,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfSessionRename.copyWith(...)` or call `instanceOfSessionRename.copyWith.fieldName(value)` for a single field.
class _$SessionRenameCWProxyImpl implements _$SessionRenameCWProxy {
  const _$SessionRenameCWProxyImpl(this._value);

  final SessionRename _value;

  @override
  SessionRename title(String? title) => call(title: title);

  @override
  SessionRename archived(bool? archived) => call(archived: archived);

  @override
  SessionRename hidden(bool? hidden) => call(hidden: hidden);

  @override
  SessionRename pinned(bool? pinned) => call(pinned: pinned);

  @override
  SessionRename unread(bool? unread) => call(unread: unread);

  @override
  SessionRename profile(String? profile) => call(profile: profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `SessionRename(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// SessionRename(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  SessionRename call({
    Object? title = const $CopyWithPlaceholder(),
    Object? archived = const $CopyWithPlaceholder(),
    Object? hidden = const $CopyWithPlaceholder(),
    Object? pinned = const $CopyWithPlaceholder(),
    Object? unread = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return SessionRename(
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String?,
      archived: archived == const $CopyWithPlaceholder()
          ? _value.archived
          // ignore: cast_nullable_to_non_nullable
          : archived as bool?,
      hidden: hidden == const $CopyWithPlaceholder()
          ? _value.hidden
          // ignore: cast_nullable_to_non_nullable
          : hidden as bool?,
      pinned: pinned == const $CopyWithPlaceholder()
          ? _value.pinned
          // ignore: cast_nullable_to_non_nullable
          : pinned as bool?,
      unread: unread == const $CopyWithPlaceholder()
          ? _value.unread
          // ignore: cast_nullable_to_non_nullable
          : unread as bool?,
      profile: profile == const $CopyWithPlaceholder()
          ? _value.profile
          // ignore: cast_nullable_to_non_nullable
          : profile as String?,
    );
  }
}

extension $SessionRenameCopyWith on SessionRename {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfSessionRename.copyWith(...)` or `instanceOfSessionRename.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SessionRenameCWProxy get copyWith => _$SessionRenameCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionRename _$SessionRenameFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SessionRename', json, ($checkedConvert) {
      final val = SessionRename(
        title: $checkedConvert('title', (v) => v as String?),
        archived: $checkedConvert('archived', (v) => v as bool?),
        hidden: $checkedConvert('hidden', (v) => v as bool?),
        pinned: $checkedConvert('pinned', (v) => v as bool?),
        unread: $checkedConvert('unread', (v) => v as bool?),
        profile: $checkedConvert('profile', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$SessionRenameToJson(SessionRename instance) =>
    <String, dynamic>{
      'title': ?instance.title,
      'archived': ?instance.archived,
      'hidden': ?instance.hidden,
      'pinned': ?instance.pinned,
      'unread': ?instance.unread,
      'profile': ?instance.profile,
    };
