import 'package:dio/dio.dart';
import 'package:hermes_api/hermes_api.dart';

/// A profile's SOUL.md as the server holds it. [exists] is false when there
/// is no file, which is not the same as an empty file.
class ProfileSoul {
  const ProfileSoul({required this.content, required this.exists});

  final String content;
  final bool exists;
}

/// What a write that reached the server and was answered came to.
enum SoulWriteResult {
  /// 200 with `ok: true`.
  saved,

  /// 200 without `ok: true`: the server's word is missing, so the save is
  /// not known to have happened.
  unconfirmed,
}

enum SoulFailureKind {
  /// 404 whose detail starts "Profile '": the profile is gone.
  profileGone,

  /// Any other 404, or a 405: the server has no such route.
  unsupported,

  /// 400: the profile name was refused.
  badRequest,

  /// 422: the body was refused.
  validation,

  /// 5xx.
  server,

  /// A 200 read whose body is not `{content: string, ...}`.
  malformed,

  /// A read got no answer.
  unreachable,

  /// A write got no answer: it may or may not have gone through. Nothing is
  /// resent.
  lostAnswer,

  /// Any other status.
  unexpected,
}

/// A refused or unanswered soul request. Carries a kind and a fixed line,
/// never the response body (it can hold paths) or the text.
class SoulFailure implements Exception {
  const SoulFailure(this.kind);

  final SoulFailureKind kind;

  String get message => switch (kind) {
    SoulFailureKind.profileGone => 'The profile no longer exists.',
    SoulFailureKind.unsupported => 'The server cannot edit this file.',
    SoulFailureKind.badRequest => 'The server refused the profile name.',
    SoulFailureKind.validation => 'The server refused the text.',
    SoulFailureKind.server => 'Hermes reported a problem.',
    SoulFailureKind.malformed =>
      'The server sent an answer the app cannot read.',
    SoulFailureKind.unreachable => 'The server did not answer.',
    SoulFailureKind.lostAnswer => 'The save may have gone through.',
    SoulFailureKind.unexpected => 'The server answered unexpectedly.',
  };

  @override
  String toString() => 'SoulFailure(${kind.name})';
}

/// Reads and replaces a profile's SOUL.md on the generated [DefaultApi].
///
/// The profile name travels in the path; neither route takes a `profile`
/// query. The routes have no response schema, so the bodies are parsed by
/// hand. Nothing here retries: a write is sent once, and a 401 is rethrown as
/// the [DioException] so the sign-in path sees it.
class SoulRepository {
  SoulRepository(this._api);

  final DefaultApi _api;

  /// Throws [SoulFailure], or the [DioException] of a 401.
  Future<ProfileSoul> read(String profile) async {
    final Response<Object> response;
    try {
      response = await _api.getProfileSoulApiProfilesNameSoulGet(
        name: _segment(profile),
      );
    } on DioException catch (error) {
      throw _failure(error, noAnswer: SoulFailureKind.unreachable) ?? error;
    }
    final data = response.data;
    if (data is Map && data['content'] is String) {
      final content = data['content'] as String;
      final exists = data['exists'];
      return ProfileSoul(
        content: content,
        exists: exists is bool ? exists : content.isNotEmpty,
      );
    }
    throw const SoulFailure(SoulFailureKind.malformed);
  }

  /// Replaces the whole file with [content]. Throws [SoulFailure] (`lostAnswer`
  /// when nothing came back), or the [DioException] of a 401.
  Future<SoulWriteResult> write(String profile, String content) async {
    final Response<Object> response;
    try {
      response = await _api.updateProfileSoulApiProfilesNameSoulPut(
        name: _segment(profile),
        profileSoulUpdate: ProfileSoulUpdate(content: content),
      );
    } on DioException catch (error) {
      throw _failure(error, noAnswer: SoulFailureKind.lostAnswer) ?? error;
    }
    final data = response.data;
    return data is Map && data['ok'] == true
        ? SoulWriteResult.saved
        : SoulWriteResult.unconfirmed;
  }

  /// The generated client pastes the name into the path as it is, so a name
  /// with `/`, `?`, `#` or `..` would reach another route.
  /// `.` and `..` survive any encoding (Uri normalises `%2E`), so they are
  /// refused before anything is sent.
  String _segment(String profile) {
    if (profile == '.' || profile == '..') {
      throw const SoulFailure(SoulFailureKind.badRequest);
    }
    return Uri.encodeComponent(profile);
  }

  /// The failure for [error], or null for a 401 that must stay a
  /// [DioException].
  SoulFailure? _failure(
    DioException error, {
    required SoulFailureKind noAnswer,
  }) {
    final response = error.response;
    if (response == null) {
      // A 200 whose JSON did not parse has no response either.
      return error.error is FormatException &&
              noAnswer == SoulFailureKind.unreachable
          ? const SoulFailure(SoulFailureKind.malformed)
          : SoulFailure(noAnswer);
    }
    final status = response.statusCode ?? 0;
    return switch (status) {
      401 => null,
      404 => SoulFailure(
        _namesMissingProfile(response.data)
            ? SoulFailureKind.profileGone
            : SoulFailureKind.unsupported,
      ),
      405 => const SoulFailure(SoulFailureKind.unsupported),
      400 => const SoulFailure(SoulFailureKind.badRequest),
      422 => const SoulFailure(SoulFailureKind.validation),
      >= 500 && < 600 => const SoulFailure(SoulFailureKind.server),
      _ => const SoulFailure(SoulFailureKind.unexpected),
    };
  }

  /// Hermes answers a missing profile with `Profile 'NAME' does not
  /// exist.`; an old server's missing route has another detail.
  bool _namesMissingProfile(Object? body) =>
      body is Map && body['detail'] is String
      ? (body['detail'] as String).startsWith("Profile '")
      : false;
}
