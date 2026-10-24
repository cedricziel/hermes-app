// Shapes of the `memory` tool's tool.complete result and of the
// `/memory approve|reject` slash-command answers, as Hermes' source
// describes them (design of memory-tool-calls, Hermes 71d34bad). They are
// not recorded from a live backend.

const savedResult = {
  'success': true,
  'target': 'user',
  'usage': '66% — 912/1,375 chars',
  'entry_count': 4,
  'message': 'Entry added.',
};

const stagedResult = {
  'success': true,
  'staged': true,
  'pending_id': '1a2b3c4d',
  'message': 'Staged for approval.',
};

const fullResult = {
  'success': false,
  'error': 'Memory at 2,180/2,200 chars; adding this entry would exceed it.',
  'current_entries': ['Uses tabs', 'Lives in Berlin'],
  'usage': '2,180/2,200',
};

const otherErrorResult = {'success': false, 'error': 'No entry matched'};

const addArgs = {
  'action': 'add',
  'target': 'user',
  'content': 'Prefers short answers',
};

const replaceArgs = {
  'action': 'replace',
  'target': 'memory',
  'old_text': 'Uses tabs',
  'content': 'Uses spaces',
};

const patchArgs = {
  'action': 'patch',
  'target': 'memory',
  'old_text': 'Uses tabs',
  'content': 'Uses spaces',
};

const removeArgs = {
  'action': 'remove',
  'target': 'memory',
  'old_text': 'Uses tabs',
};

const operationsArgs = {
  'action': 'patch',
  'target': 'memory',
  'operations': [
    {'action': 'add', 'content': 'Likes tea'},
    {'action': 'replace', 'old_text': 'Uses tabs', 'content': 'Uses spaces'},
    {'action': 'remove', 'old_text': 'Lives in Berlin'},
  ],
};

const approvedAnswer = 'Approved 1 memory write(s).';
const approvedButFailedAnswer =
    'Approved 0 memory write(s).\nFailed:\n  1a2b3c4d: The entry changed since it was staged.';
const failedForOtherIdAnswer =
    'Approved 1 memory write(s).\nFailed:\n  ffffffff: Entry not found.';
const rejectedAnswer = "Rejected pending memory write '1a2b3c4d'.";
const unknownIdAnswer = "No pending memory write with id '1a2b3c4d'.";
