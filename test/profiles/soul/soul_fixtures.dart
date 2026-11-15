/// Answers of Hermes `d923a5eb` to `/api/profiles/{name}/soul`, recorded from
/// a throwaway dashboard (see `openspec/changes/profile-soul/design.md`,
/// "Recorded answers"). Names and text are invented.
library;

const soulProfile = 'atlas';
const soulPath = '/api/profiles/$soulProfile/soul';

/// GET with text. A BOM in the file is dropped by the server (`utf-8-sig`).
const soulWithText = {'content': 'You are Quill.\nBe brief.\n', 'exists': true};

/// GET with no SOUL.md on disk.
const soulAbsent = {'content': '', 'exists': false};

/// GET with an empty SOUL.md.
const soulEmptyFile = {'content': '', 'exists': true};

/// PUT answered 200.
const soulSaved = {'ok': true};

/// 404 for a profile that does not exist (GET and PUT).
const soulProfileMissing = {'detail': "Profile 'atlas' does not exist."};

/// 404 an old server gives for a route it lacks.
const soulRouteMissing = {'detail': 'No such API endpoint: /api/profiles/x'};

/// 400 for an invalid profile name.
const soulBadName = {
  'detail':
      "'Bad_Name' is not a valid profile name. Use lowercase letters, "
      "numbers, '-' or '_', starting with a letter or number, up to 64 "
      'characters (for example: bad_name). '
      'Then run `hermes profile create bad_name`.',
};

/// 422 for a body without `content` (FastAPI's list).
const soulMissingContent = {
  'detail': [
    {
      'type': 'missing',
      'loc': ['body', 'content'],
      'msg': 'Field required',
      'input': <String, Object?>{},
    },
  ],
};

/// 500 for an unhandled error (invalid UTF-8 in the file): plain text.
const soulPlainServerError = 'Internal Server Error';

/// 401 without a session.
const soulUnauthorized = {'detail': 'Unauthorized'};
