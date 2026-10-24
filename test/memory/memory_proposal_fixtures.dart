// Answers of the `/memory` and `/skills` slash commands about staged writes,
// recorded from a throwaway backend at Hermes d923a5eb (the pinned revision)
// through `slash.exec`, except where a comment says they come from its source.
// Records were staged by hand in `<HERMES_HOME>/pending/` the way
// `tools/memory_tool.py` and `tools/write_approval.py` write them.

const noPendingMemory = 'No pending memory writes.';

// Hermes prints a progress line before every `/skills` answer.
const noPendingSkills =
    '⏳ Processing skills command...\nNo pending skills writes.';

/// One add cut at 120 characters.
final chatAddCut =
    'Pending memory writes (1):\n'
    '  aa000001  add to user profile: ${'x' * 120}\n'
    '\n'
    'Apply: /memory approve <id>   Reject: /memory reject <id>';

/// A chat replace and patch, a background patch and remove, a batch and a
/// replace staged before its matched entry was pinned.
const mixedMemoryPending =
    'Pending memory writes (6):\n'
    '  aa000001  add to user profile: Runs on a Mac\n'
    '  aa000002  replace in memory: entry matching: Prefers tabs\n'
    'whole entry becomes: Prefers spaces\n'
    '      replaces entry: Prefers tabs in Go\n'
    "  aa000003 [auto]  background review consolidation (patch on memory): - patch span 'tabs' -> 'spaces' (rest of the entry is kept)\n"
    '      patchs entry: Prefers tabs in Go\n'
    '  aa000004 [auto]  background review consolidation (remove on user): - remove: Likes tea\n'
    '      removes entry: Likes tea, no sugar\n'
    "  aa000005  apply 2 op(s) to user profile: - add: A\n- patch span 'b' -> 'c' (rest of the entry is kept)\n"
    '      patchs entry: b entry\n'
    '  aa000006  replace in memory: entry matching: old\n'
    'whole entry becomes: new\n'
    '      replace: unpinned legacy target — reject and recreate before approving\n'
    '\n'
    'Apply: /memory approve <id>   Reject: /memory reject <id>';

/// A chat patch, as `_STORE_ACTIONS` words it (from the source).
const chatPatchPending =
    'Pending memory writes (1):\n'
    "  aa000007  patch in user profile: entry matching: Berlin\n"
    "span 'Berlin' becomes: Hamburg (rest of the entry is kept)\n"
    '      patchs entry: Lives in Berlin\n'
    '\n'
    'Apply: /memory approve <id>   Reject: /memory reject <id>';

/// A background replace, shaped as `_batch_op_line` words it (from the
/// source), cut at 200 characters.
final backgroundReplaceCut =
    'Pending memory writes (1):\n'
    '  1a2b3c4d [auto]  ${('background review consolidation (replace on memory): - replace: ${'y' * 200}').substring(0, 200)}\n'
    '      replaces entry: Prefers tabs in Go\n'
    '\n'
    'Apply: /memory approve <id>   Reject: /memory reject <id>';

const skillsPending =
    '⏳ Processing skills command...\n'
    'Pending skills writes (2):\n'
    "  cc000001 [auto]  create 'contract-check' — Checks things (60 chars)\n"
    "  cc000002  patch 'git-helper' SKILL.md (+2/-1 lines)\n"
    '\n'
    'Apply: /skills approve <id>   Reject: /skills reject <id>\n'
    'Review full diff: /skills diff <id>';

const skillDiffCreate =
    '⏳ Processing skills command...\n'
    "# Pending skill write cc000001: create 'contract-check' — Checks things (60 chars)\n"
    '\n'
    '---\n'
    'name: contract-check\n'
    'description: Checks things\n'
    '---\n'
    'Body';

const unknownCommand =
    'Unknown command /nosuch — nothing was sent.\nType /help for the full list.';

const approvedReplace =
    'Approved 1 memory write(s).\n'
    'Overwrote entire entry (re-add anything you still need):\n'
    '  bb000002: Prefers tabs in Go';

const approvedPatch =
    'Approved 1 memory write(s).\n'
    'Patched entry (as it was before the edit):\n'
    '  bb000003: Deploys with deploy.sh';

const approvedRemove =
    'Approved 1 memory write(s).\n'
    'Removed entry (re-add anything you still need):\n'
    '  bb000004: Likes tea, no sugar';

const approvedPinnedChanged =
    'Approved 0 memory write(s).\n'
    'Failed:\n'
    "  aa000003: Entry changed since it was staged, so this write was not applied: 'Prefers tabs in Go' is no longer in memory as reviewed. Recreate the change against the current entry or reject it; the pending record has been preserved.";

const rejectedSkill =
    "⏳ Processing skills command...\nRejected pending skills write 'cc000001'.";
