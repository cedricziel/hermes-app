//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'session_rename.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SessionRename {
  /// Returns a new [SessionRename] instance.
  SessionRename({
    this.title,

    this.archived,

    this.hidden,

    this.pinned,

    this.unread,

    this.profile,
  });

  @JsonKey(name: r'title', required: false, includeIfNull: false)
  final String? title;

  @JsonKey(name: r'archived', required: false, includeIfNull: false)
  final bool? archived;

  @JsonKey(name: r'hidden', required: false, includeIfNull: false)
  final bool? hidden;

  @JsonKey(name: r'pinned', required: false, includeIfNull: false)
  final bool? pinned;

  @JsonKey(name: r'unread', required: false, includeIfNull: false)
  final bool? unread;

  @JsonKey(name: r'profile', required: false, includeIfNull: false)
  final String? profile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionRename &&
          other.title == title &&
          other.archived == archived &&
          other.hidden == hidden &&
          other.pinned == pinned &&
          other.unread == unread &&
          other.profile == profile;

  @override
  int get hashCode =>
      (title == null ? 0 : title.hashCode) +
      (archived == null ? 0 : archived.hashCode) +
      (hidden == null ? 0 : hidden.hashCode) +
      (pinned == null ? 0 : pinned.hashCode) +
      (unread == null ? 0 : unread.hashCode) +
      (profile == null ? 0 : profile.hashCode);

  factory SessionRename.fromJson(Map<String, dynamic> json) =>
      _$SessionRenameFromJson(json);

  Map<String, dynamic> toJson() => _$SessionRenameToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
