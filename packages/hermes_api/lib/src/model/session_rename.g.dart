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

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SessionRename(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SessionRename(...).copyWith(id: 12, name: "My name")
  /// ````
  SessionRename call({
    String? title,
    bool? archived,
    bool? hidden,
    bool? pinned,
    bool? unread,
    String? profile,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSessionRename.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSessionRename.copyWith.fieldName(...)`
class _$SessionRenameCWProxyImpl implements _$SessionRenameCWProxy {
  const _$SessionRenameCWProxyImpl(this._value);

  final SessionRename _value;

  @override
  SessionRename title(String? title) => this(title: title);

  @override
  SessionRename archived(bool? archived) => this(archived: archived);

  @override
  SessionRename hidden(bool? hidden) => this(hidden: hidden);

  @override
  SessionRename pinned(bool? pinned) => this(pinned: pinned);

  @override
  SessionRename unread(bool? unread) => this(unread: unread);

  @override
  SessionRename profile(String? profile) => this(profile: profile);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SessionRename(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SessionRename(...).copyWith(id: 12, name: "My name")
  /// ````
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
  /// Returns a callable class that can be used as follows: `instanceOfSessionRename.copyWith(...)` or like so:`instanceOfSessionRename.copyWith.fieldName(...)`.
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
