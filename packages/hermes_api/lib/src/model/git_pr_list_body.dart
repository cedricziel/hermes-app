//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'git_pr_list_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class GitPrListBody {
  /// Returns a new [GitPrListBody] instance.
  GitPrListBody({
    required this.path,

    this.branches = const [],

    this.numbers = const [],
  });

  @JsonKey(name: r'path', required: true, includeIfNull: false)
  final String path;

  @JsonKey(
    defaultValue: [],
    name: r'branches',
    required: false,
    includeIfNull: false,
  )
  final List<String>? branches;

  @JsonKey(
    defaultValue: [],
    name: r'numbers',
    required: false,
    includeIfNull: false,
  )
  final List<int>? numbers;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GitPrListBody &&
          other.path == path &&
          other.branches == branches &&
          other.numbers == numbers;

  @override
  int get hashCode => path.hashCode + branches.hashCode + numbers.hashCode;

  factory GitPrListBody.fromJson(Map<String, dynamic> json) =>
      _$GitPrListBodyFromJson(json);

  Map<String, dynamic> toJson() => _$GitPrListBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
