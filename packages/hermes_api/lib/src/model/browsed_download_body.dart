//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'browsed_download_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class BrowsedDownloadBody {
  /// Returns a new [BrowsedDownloadBody] instance.
  BrowsedDownloadBody({required this.repo, required this.paths});

  @JsonKey(name: r'repo', required: true, includeIfNull: false)
  final String repo;

  @JsonKey(name: r'paths', required: true, includeIfNull: false)
  final List<String> paths;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrowsedDownloadBody &&
          other.repo == repo &&
          other.paths == paths;

  @override
  int get hashCode => repo.hashCode + paths.hashCode;

  factory BrowsedDownloadBody.fromJson(Map<String, dynamic> json) =>
      _$BrowsedDownloadBodyFromJson(json);

  Map<String, dynamic> toJson() => _$BrowsedDownloadBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
