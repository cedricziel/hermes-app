import unittest

import base64
import io
import json
import os
import subprocess
import tempfile
import time
from contextlib import redirect_stdout
from unittest import mock

import pr_policy
from pr_policy import check, corrupted_lines, review_recorded

SHA = "a" * 40
OLD = "b" * 40
MERGE_BASE = "c" * 40

TRAILERS = (
    "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\n"
    "Claude-Session: https://claude.ai/code/session_01Abc\n"
    "🤖 Generated with [Claude Code](https://claude.com/claude-code)\n"
    "https://claude.ai/code/session_01Abc\n"
)


def body(
    behaviour="Chats open faster.",
    proof="Reverted the fix; the test fails.",
    device="Nothing",
    review=f"Reviewer: isolated-reviewer Head: {SHA} Verdict: clean\nFindings: none\n",
    extra="",
):
    return (
        f"## Behaviour changes\n{behaviour}\n\n"
        f"## Proof\n{proof}\n{extra}\n\n"
        f"## Not verified on a device\n{device}\n\n"
        f"## Review\n{review}\n"
    )


def run(
    title="feat(chat): faster open",
    b=None,
    head_ref="claude/x",
    author="cedricziel",
    files=(),
    version=False,
    same_repo=True,
):
    return check(
        title,
        body() if b is None else b,
        head_ref,
        author,
        SHA,
        list(files),
        version,
        "",
        same_repo,
    )


class TitleTest(unittest.TestCase):
    def test_every_type_passes(self):
        for t in "feat fix docs chore refactor test ci build perf style revert".split():
            extra = (
                "\nWhat would have caught this earlier? A test." if t == "fix" else ""
            )
            self.assertEqual(run(f"{t}(a_b.c/d-e): x", body(extra=extra)), [], t)

    def test_scope_optional_and_breaking(self):
        self.assertEqual(run("feat!: drop it"), [])
        self.assertEqual(run("chore: x"), [])

    def test_multi_scope_passes(self):
        self.assertEqual(run("test(providers,tools): settle checks"), [])

    def test_bad_titles_fail(self):
        for t in [
            "Add things",
            "feature: x",
            "feat(Chat): x",
            "feat:x",
            "feat: ",
            "fix (a): x",
        ]:
            self.assertTrue(any("Conventional" in f for f in run(t)), t)


class BodyTest(unittest.TestCase):
    def test_complete_body_passes(self):
        self.assertEqual(run(), [])

    def test_missing_heading(self):
        b = body().replace("## Proof", "## Evidence")
        out = run(b=b)
        self.assertTrue(any("missing '## Proof'" in f for f in out))

    def test_empty_body(self):
        self.assertTrue(any("missing" in f for f in run(b="")))
        self.assertTrue(any("missing" in f for f in check("feat: x", None, "c/x", "u", SHA, [], False)))

    def test_out_of_order(self):
        b = (
            "## Proof\nx\n\n## Behaviour changes\nx\n\n"
            "## Not verified on a device\nNothing\n\n## Review\nx\n"
        )
        self.assertTrue(any("out of order" in f for f in run(b=b)))

    def test_empty_section_fails(self):
        out = run(b=body(device=""))
        self.assertTrue(any("'## Not verified on a device' is empty" in f for f in out))

    def test_html_comment_only_counts_as_empty(self):
        out = run(b=body(proof="<!-- the mutation\nacross lines -->"))
        self.assertTrue(any("'## Proof' is empty" in f for f in out))

    def test_comment_beside_text_is_content(self):
        self.assertEqual(run(b=body(proof="<!-- hint -->\nDone.")), [])

    def test_heading_in_code_fence_ignored(self):
        b = body(proof="```\n## Review\n```\nok")
        self.assertEqual(run(b=b), [])


class FixTest(unittest.TestCase):
    def test_fix_without_question_fails(self):
        out = run("fix(chat): crash")
        self.assertTrue(any("What would have caught this earlier?" in f for f in out))

    def test_fix_with_answer_passes(self):
        b = body(extra="What would have caught this earlier? A widget test of X.")
        self.assertEqual(run("fix(chat): crash", b), [])

    def test_answer_on_next_line_passes(self):
        b = body(extra="**What would have caught this earlier?**\n\nA contract test.")
        self.assertEqual(run("fix(chat): crash", b), [])

    def test_question_without_answer_fails(self):
        b = body(extra="What would have caught this earlier?")
        self.assertTrue(any("Answer" in f for f in run("fix: crash", b)))

    def test_question_only_in_comment_fails(self):
        b = body(extra="<!-- What would have caught this earlier? an answer -->")
        self.assertTrue(run("fix: crash", b))

    def test_non_fix_not_asked(self):
        self.assertEqual(run("feat: x"), [])


class ModelNameTest(unittest.TestCase):
    def test_model_names_fail(self):
        for text in [
            "Written by claude-opus-5-5",
            "claude-3-5-sonnet-20241022",
            "Claude Sonnet 5.5 did it",
            "ran Opus 5",
            "Haiku 4.5",
            "fable-2",
            "GPT-5 review",
            "gpt4",
            "Gemini 3 Pro",
            "OPUS 5.5",
        ]:
            out = run(b=body(proof=text))
            self.assertTrue(any("model names" in f for f in out), text)

    def test_title_checked(self):
        self.assertTrue(
            any("model names" in f for f in run("feat: add Opus 5 support"))
        )

    def test_trailers_allowed(self):
        self.assertEqual(run(b=body() + "\n" + TRAILERS), [])

    def test_claude_code_allowed(self):
        self.assertEqual(
            run(b=body(proof="Tried it in Claude Code; the claude plugin.")), []
        )

    def test_words_without_versions_allowed(self):
        self.assertEqual(
            run(b=body(proof="A sonnet, a haiku, the opus of a fable.")), []
        )


class HardeningTest(unittest.TestCase):
    def test_revert_title_accepted(self):
        self.assertEqual(run('Revert "feat(chat): faster open"'), [])
        self.assertTrue(run("Revert it"))
        self.assertTrue(run('Revert ""'))

    def test_placeholder_sections_are_empty(self):
        for text in ["TODO", "tbd", "n/a", "N/A.", "-", "...", "…", "- TODO", "* n/a"]:
            out = run(b=body(proof=text))
            self.assertTrue(any("'## Proof' is empty" in f for f in out), text)

    def test_nothing_and_real_text_valid(self):
        self.assertEqual(run(b=body(device="Nothing")), [])
        self.assertEqual(run(b=body(proof="TODO: none left, tested it")), [])

    def test_placeholder_fix_answer_fails(self):
        for text in ["TBD", "n/a", "-", "..."]:
            b = body(extra=f"What would have caught this earlier? {text}")
            self.assertTrue(any("Answer" in f for f in run("fix: x", b)), text)

    def test_fix_answer_must_be_in_proof(self):
        b = body(device="What would have caught this earlier? A test.")
        self.assertTrue(any("in ## Proof" in f for f in run("fix: x", b)))

    def test_inline_and_fenced_code_skipped(self):
        for text in ["see `claude-opus-4-1` ids", "```\nGPT-5 output\n```"]:
            self.assertEqual(run(b=body(proof=text)), [], text)

    def test_generated_with_line_only_exact(self):
        out = run(b=body(proof="Generated with Opus 4 by hand"))
        self.assertTrue(any("model names" in f for f in out))
        out = run(b=body(extra="Generated with [Claude Code] on Sonnet 4.5"))
        self.assertTrue(any("model names" in f for f in out))

    def test_opus_codec_not_a_model(self):
        for text in ["Opus 1.5 codec", "opus 2", "Opus 48000 Hz"]:
            self.assertEqual(run(b=body(proof=text)), [], text)

    def test_versions_3_and_up_are_models(self):
        for text in [
            "Opus 4",
            "Sonnet 4.5",
            "haiku-3",
            "claude-opus-4-1",
            "claude-3-sonnet",
        ]:
            out = run(b=body(proof=text))
            self.assertTrue(any("model names" in f for f in out), text)

    def test_invisible_characters_normalized(self):
        for text in ["Opus 4", "Op​us 4", "GP​T-5", "Son­net 4"]:
            out = run(b=body(proof=text))
            self.assertTrue(any("model names" in f for f in out), repr(text))


class VersionAndRoadmapTest(unittest.TestCase):
    def test_version_bump_fails(self):
        out = run(version=True)
        self.assertTrue(any("release-please bumps the version" in f for f in out))

    def test_version_bump_ok_on_release_branch(self):
        ref = "release-please--branches--main--components--hermes-app"
        self.assertEqual(
            run("chore(main): release 0.1.79", "", ref, "cedricziel", version=True), []
        )

    def test_roadmap_fails(self):
        out = run(files=["lib/a.dart", "docs/roadmap.md"])
        self.assertTrue(any("orchestrator" in f for f in out))

    def test_roadmap_ok_for_orchestrator(self):
        self.assertEqual(
            run(head_ref="claude/quirky-einstein-1", files=["docs/roadmap.md"]), []
        )

    def test_other_docs_ok(self):
        self.assertEqual(run(files=["docs/architecture/chat.md"]), [])


RP = "release-please--branches--main--components--hermes-app"


class BotExemptionTest(unittest.TestCase):
    def test_exact_automation_branches_exempt(self):
        for ref in [
            RP,
            "chore/update-flutter",
            "chore/update-hermes-contracts",
            "chore/readme-screenshots-12345",
        ]:
            self.assertEqual(run("whatever", "", ref, "cedricziel"), [], ref)

    def test_dependabot_needs_its_author(self):
        ref = "dependabot/gradle/android/x"
        self.assertEqual(run("Bump x", "", ref, "dependabot[bot]"), [])
        self.assertTrue(run("Bump x", "", ref, "cedricziel"))

    def test_lookalike_branches_not_exempt(self):
        for ref in [
            "release-please--branches--main",
            "release-please--x",
            "chore/update-flutter-2",
            "chore/update-flutter/x",
            "chore/update-claude-plugins",
            "chore/readme-screenshots-",
            "chore/readme-screenshots-12a",
            "xchore/update-flutter",
            "dependabot",
        ]:
            self.assertTrue(run("whatever", "", ref, "cedricziel"), ref)

    def test_plain_bot_author_not_exempt(self):
        self.assertTrue(run("whatever", "", "some/branch", "renovate[bot]"))

    def test_fork_never_exempt(self):
        for ref, author in [
            (RP, "cedricziel"),
            ("chore/update-flutter", "cedricziel"),
            ("dependabot/pub/x", "dependabot[bot]"),
        ]:
            self.assertTrue(run("whatever", "", ref, author, same_repo=False), ref)

    def test_fork_version_and_roadmap(self):
        out = run(head_ref=RP, version=True, same_repo=False)
        self.assertTrue(any("release-please bumps" in f for f in out))
        out = run(
            head_ref="claude/quirky-einstein-1",
            files=["docs/roadmap.md"],
            same_repo=False,
        )
        self.assertTrue(any("orchestrator" in f for f in out))

    def test_bot_still_gets_roadmap_and_version(self):
        out = run(
            "chore: x", "", "chore/update-flutter", "x", ["docs/roadmap.md"], True
        )
        self.assertEqual(len(out), 2)

    def test_human_not_exempt(self):
        self.assertTrue(run("whatever", "", "chore/other", "cedricziel"))


def diff_of(removed, added):
    out = ["diff --git a/CLAUDE.md b/CLAUDE.md", "--- a/CLAUDE.md", "+++ b/CLAUDE.md"]
    out.append("@@ -1,1 +1,1 @@")
    out += ["-" + x for x in removed] + ["+" + x for x in added]
    return "\n".join(out)


class CorruptionTest(unittest.TestCase):
    def test_x86_star_64(self):
        self.assertEqual(
            corrupted_lines(diff_of(["a x86_64 b"], ["a x86*64 b"])), ["a x86*64 b"]
        )

    def test_pure_addition_odd_backticks(self):
        self.assertEqual(len(corrupted_lines(diff_of([], ["use `flutter run"]))), 1)

    def test_pure_addition_even_ok(self):
        self.assertEqual(corrupted_lines(diff_of([], ["use `flutter run`"])), [])

    def test_replaced_even_to_odd_flagged(self):
        self.assertEqual(len(corrupted_lines(diff_of(["a `b` c"], ["a `b c"]))), 1)

    def test_replaced_odd_to_odd_ok(self):
        self.assertEqual(corrupted_lines(diff_of(["a `b c"], ["a `b c d"])), [])

    def test_pairing_is_positional(self):
        d = diff_of(["`a`", "`b`"], ["`a`", "`b"])
        self.assertEqual(corrupted_lines(d), ["`b"])

    def test_fence_lines_ignored(self):
        self.assertEqual(corrupted_lines(diff_of([], ["```bash", "```"])), [])

    def test_double_backtick_span_valid(self):
        self.assertEqual(corrupted_lines(diff_of([], ["use ``a`b`` here"])), [])
        self.assertEqual(len(corrupted_lines(diff_of([], ["use ``a`b`` and `c"]))), 1)

    def test_removed_dashes_line_is_content_not_header(self):
        d = diff_of(["-- a `b` c"], ["-- a `b c"])
        self.assertEqual(corrupted_lines(d), ["-- a `b c"])
        d = diff_of(["-- x"], ["- fine `ok`"])
        self.assertEqual(corrupted_lines(d), [])

    def test_removed_lines_not_checked(self):
        self.assertEqual(corrupted_lines(diff_of(["x86*64 `"], [])), [])

    def test_check_reports_it(self):
        out = check(
            "feat: x", body(), "claude/x", "u", SHA, [], False, diff_of([], ["x86*64"])
        )
        self.assertTrue(any("corrupted by a Markdown formatter" in f for f in out))

    def test_check_without_diff_ok(self):
        self.assertEqual(run(), [])


class ReviewTest(unittest.TestCase):
    def rv(self, review):
        return review_recorded(body(review=review), SHA)

    def test_clean_review_passes(self):
        self.assertEqual(review_recorded(body(), SHA), [])

    def test_uppercase_sha_matches(self):
        self.assertEqual(self.rv(f"Reviewer: r Head: {SHA.upper()} Verdict: clean"), [])

    def test_reviewer_name_is_one_word(self):
        r = f"Reviewer: isolated reviewer Head: {SHA} Verdict: clean"
        self.assertTrue(self.rv(r)[0].startswith("No isolated"))

    def test_second_pair_packed_into_the_name(self):
        r = (
            f"Reviewer: x Head: {OLD} Verdict: changes-requested "
            f"Head: {SHA} Verdict: clean"
        )
        self.assertTrue(self.rv(r)[0].startswith("No isolated"))
        r = f"Reviewer: Head: {SHA} Verdict: clean Head: {SHA} Verdict: clean"
        self.assertTrue(self.rv(r)[0].startswith("No isolated"))

    def test_missing_section(self):
        out = review_recorded("## Proof\nx\n", SHA)
        self.assertTrue(
            out[0].startswith(
                f"No isolated review recorded for {SHA}: run the isolated-reviewer "
                "agent on this head and paste its block into ## Review"
            )
        )

    def test_comment_only_section(self):
        out = self.rv(f"<!-- Reviewer: r Head: {SHA} Verdict: clean -->")
        self.assertTrue(out[0].startswith("No isolated review recorded"))

    def test_sha_mismatch(self):
        self.assertEqual(
            self.rv(f"Reviewer: r Head: {OLD} Verdict: clean"),
            [f"The review is for {OLD}, the head is {SHA}: review the new commits."],
        )

    def test_short_sha_is_not_recorded(self):
        out = self.rv(f"Reviewer: r Head: {SHA[:7]} Verdict: clean")
        self.assertTrue(out[0].startswith("No isolated"))

    def test_changes_requested(self):
        out = self.rv(f"Reviewer: r Head: {SHA} Verdict: changes-requested")
        self.assertIn("changes-requested", out[0])

    def test_quoted_clean_in_changes_requested_block(self):
        r = (
            f"Reviewer: r Head: {SHA} Verdict: changes-requested\n"
            "Findings: the PR says Verdict: clean but the test is missing.\n"
            "- Verdict: clean was claimed in the description\n"
        )
        self.assertIn("changes-requested", self.rv(r)[0])

    def test_stale_block_plus_later_head_line(self):
        r = f"Reviewer: r Head: {OLD} Verdict: clean\nHead: {SHA}\nVerdict: clean\n"
        self.assertEqual(
            self.rv(r),
            [f"The review is for {OLD}, the head is {SHA}: review the new commits."],
        )

    def test_head_and_verdict_on_other_lines_not_recorded(self):
        out = self.rv(f"Reviewer: r\nHead: {SHA}\nVerdict: clean\n")
        self.assertTrue(out[0].startswith("No isolated"))

    def test_clean_ish_is_not_clean(self):
        for v in ["clean-ish", "cleanish", "clean | changes-requested", "clean."]:
            out = self.rv(f"Reviewer: r Head: {SHA} Verdict: {v}")
            self.assertTrue(out[0].startswith("No isolated"), v)

    def test_two_blocks_fail(self):
        r = (
            f"Reviewer: r Head: {SHA} Verdict: clean\n"
            f"Reviewer: s Head: {SHA} Verdict: clean\n"
        )
        self.assertIn("2 review lines", self.rv(r)[0])

    def test_fenced_block_ignored(self):
        r = f"```\nReviewer: r Head: {SHA} Verdict: clean\n```\n"
        self.assertTrue(self.rv(r)[0].startswith("No isolated"))

    def test_indented_or_quoted_line_not_recorded(self):
        for prefix in ["> ", "- ", "  "]:
            out = self.rv(f"{prefix}Reviewer: r Head: {SHA} Verdict: clean")
            self.assertTrue(out[0].startswith("No isolated"), prefix)

    def test_empty_body(self):
        self.assertTrue(review_recorded("", SHA))
        self.assertTrue(review_recorded(None, SHA))


class Repo:
    """A throwaway git repository: `main` is the base branch, and origin/main
    is set so main() finds it."""

    def __init__(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.dir = self._tmp.name
        self.git("init", "-q", "-b", "main")
        self.git("config", "user.email", "t@example.com")
        self.git("config", "user.name", "T")
        self.git("config", "commit.gpgsign", "false")
        self.git("config", "merge.renames", "true")
        self.n = 0

    def close(self):
        self._tmp.cleanup()

    def git(self, *args, check=True):
        r = subprocess.run(
            ["git", *args],
            cwd=self.dir,
            capture_output=True,
            text=True,
            env=dict(
                os.environ, GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1"
            ),
        )
        if check and r.returncode != 0:
            raise AssertionError(f"git {args}: {r.stdout}{r.stderr}")
        return r

    def write(self, name, text):
        path = os.path.join(self.dir, name)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write(text)

    def commit(self, name=None, text=None, msg="c"):
        """Commits one file change (or an empty-ish unique change)."""
        self.n += 1
        name = name or f"f{self.n}.txt"
        self.write(name, text if text is not None else f"{self.n}\n")
        self.git("add", name)
        self.git("commit", "-q", "-m", msg)
        return self.head()

    def head(self):
        return self.git("rev-parse", "HEAD").stdout.strip()

    def branch(self, name, start):
        self.git("checkout", "-q", "-B", name, start)

    def merge(self, other):
        """A plain `git merge`; asserts it merged without conflict."""
        self.git("merge", "-q", "--no-ff", "-m", f"Merge {other}", other)
        return self.head()

    def sync_origin(self):
        self.git(
            "update-ref",
            "refs/remotes/origin/main",
            self.git("rev-parse", "main").stdout.strip(),
        )

    def tip(self):
        return self.git("rev-parse", "main").stdout.strip()

    def pr_git(self):
        return pr_policy.Git(self.dir)


def blk(commit, base, reviewer="isolated-reviewer", verdict="clean", rng=True):
    out = f"Reviewer: {reviewer} Head: {commit} Verdict: {verdict}\n"
    if rng:
        out += f"Range: {base}..{commit}\n"
    return out + "Findings: none\n"


class MergeReviewTest(unittest.TestCase):
    """Rule (a) and (b) against real repositories."""

    def setUp(self):
        self.r = Repo()
        self.addCleanup(self.r.close)
        r = self.r
        r.write("a.txt", "one\ntwo\nthree\n")
        r.write("b.txt", "b\n")
        r.git("add", "a.txt", "b.txt")
        r.git("commit", "-q", "-m", "root")
        self.root = r.head()
        r.branch("pr", self.root)
        self.rev = r.commit("pr1.txt")  # the reviewed commit R

    def advance_main(self, name=None, text=None):
        self.r.git("checkout", "-q", "main")
        sha = self.r.commit(name, text, msg="main moves")
        self.r.git("checkout", "-q", "pr")
        self.r.sync_origin()
        return sha

    def review(self, head, review, base=None):
        return review_recorded(body(review=review), head, self.r.pr_git(), self.r.tip())

    # --- rule (a) ---------------------------------------------------------

    def test_reviewed_non_merge_head_passes(self):
        self.r.sync_origin()
        out = self.review(self.rev, blk(self.rev, self.root))
        self.assertEqual(out, [])

    def test_unreviewed_non_merge_head_fails(self):
        self.r.sync_origin()
        out = self.review(self.rev, "")
        self.assertEqual(len(out), 1)
        self.assertIn(f"No isolated review recorded for head {self.rev}", out[0])
        self.assertIn("full review", out[0])
        self.assertIn(f"Range: {self.r.tip()}..{self.rev}", out[0])
        self.assertIn(f"Head: {self.rev}", out[0])

    def test_block_for_another_head_fails(self):
        self.r.sync_origin()
        out = self.review(self.rev, blk(OLD, self.root))
        self.assertIn(f"The review is for {OLD}", out[0])
        self.assertIn(
            f"needs one: ask the isolated reviewer for a full review of {self.rev}",
            out[0],
        )
        self.assertIn(f"Range: {self.r.tip()}..{self.rev}", out[0])

    def test_changes_requested_fails(self):
        self.r.sync_origin()
        out = self.review(
            self.rev, blk(self.rev, self.root, verdict="changes-requested")
        )
        self.assertIn("latest review of", out[0])
        self.assertIn("requested changes", out[0])

    def test_old_one_line_format_passes_for_non_merge_head(self):
        self.r.sync_origin()
        self.assertEqual(self.review(self.rev, blk(self.rev, self.root, rng=False)), [])

    def test_old_format_rejected_once_the_transition_ends(self):
        self.r.sync_origin()
        with mock.patch.object(pr_policy, "ACCEPT_LEGACY_REVIEW_BLOCK", False):
            out = self.review(self.rev, blk(self.rev, self.root, rng=False))
        self.assertIn("has no Range line", out[0])
        self.assertIn(f"Range: {self.r.tip()}..{self.rev}", out[0])

    def test_range_base_not_an_ancestor_fails(self):
        later = self.advance_main()  # on main, not an ancestor of R
        out = self.review(self.rev, blk(self.rev, later))
        self.assertIn(
            f"starts at {later}, which is not an ancestor of {self.rev}", out[0]
        )
        self.assertIn("Paste the reviewer's block verbatim", out[0])

    def test_range_base_unknown_commit_fails(self):
        self.r.sync_origin()
        out = self.review(self.rev, blk(self.rev, OLD))
        self.assertIn("is not an ancestor", out[0])

    def test_range_head_differs_from_head_fails(self):
        self.r.sync_origin()
        other = self.r.commit("pr2.txt")
        out = self.review(
            other,
            f"Reviewer: r Head: {other} Verdict: clean\nRange: {self.root}..{self.rev}\n",
        )
        self.assertIn(f"ends at {self.rev}, not at its Head", out[0])

    def test_range_malformed_fails(self):
        self.r.sync_origin()
        out = self.review(
            self.rev,
            f"Reviewer: r Head: {self.rev} Verdict: clean\nRange: main..{self.rev}\n",
        )
        self.assertIn("is not '<base sha>..<head sha>'", out[0])

    def test_range_valid_but_present_in_old_block_for_other_commit_ignored(self):
        # The Range belongs to the block opened last; one before any block is
        # not taken as another block's.
        self.r.sync_origin()
        out = self.review(
            self.rev,
            f"Range: {self.root}..{self.rev}\n" + blk(self.rev, self.root, rng=False),
        )
        self.assertEqual(out, [])

    def test_several_plain_blocks_one_per_reviewed_head(self):
        self.r.sync_origin()
        later = self.r.commit("pr2.txt")
        both = blk(self.rev, self.root) + blk(later, self.root)
        self.assertEqual(self.review(later, both), [])
        self.assertEqual(self.review(self.rev, both), [])

    def test_blocks_for_other_heads_do_not_accept_this_one(self):
        self.r.sync_origin()
        out = self.review(self.rev, blk(OLD, self.root) + blk("d" * 40, self.root))
        self.assertIn(f"The review is for {OLD}, {'d' * 40}", out[0])

    def test_changes_requested_outweighs_clean_in_either_order(self):
        self.r.sync_origin()
        bad = blk(self.rev, self.root, verdict="changes-requested")
        good = blk(self.rev, self.root)
        for review in (bad + good, good + bad):
            out = self.review(self.rev, review)
            self.assertIn("The latest review of", out[0])
            self.assertIn("requested changes", out[0])

    def test_changes_needed_is_a_non_clean_verdict(self):
        self.r.sync_origin()
        out = self.review(self.rev, blk(self.rev, self.root, verdict="changes-needed"))
        self.assertIn("requested changes", out[0])
        out = review_recorded(body(review=blk(self.rev, self.root, verdict="changes-needed")), self.rev)
        self.assertIn("says changes-needed", out[0])

    def test_indented_lines_are_not_a_block(self):
        self.r.sync_origin()
        text = blk(self.rev, self.root)
        for pad in ("    ", "\t", "        "):
            indented = "".join(pad + line + "\n" for line in text.splitlines())
            out = self.review(self.rev, indented)
            self.assertIn("No isolated review recorded", out[0], repr(pad))
        shallow = "".join("   " + line + "\n" for line in text.splitlines())
        self.assertEqual(self.review(self.rev, shallow), [])

    def test_paste_hint_has_real_newlines(self):
        self.r.sync_origin()
        out = self.review(self.rev, "")
        self.assertIn(
            f"in this format:\nReviewer: isolated-reviewer  Head: {self.rev}  "
            f"Verdict: clean\nRange: {self.r.tip()}..{self.rev}",
            out[0],
        )

    def test_empty_range_fails(self):
        self.r.sync_origin()
        out = self.review(
            self.rev,
            f"Reviewer: r Head: {self.rev} Verdict: clean\nRange: {self.rev}..{self.rev}\n",
        )
        self.assertIn("is empty", out[0])

    def test_range_covering_one_commit_of_two_fails(self):
        self.r.sync_origin()
        second = self.r.commit("pr2.txt")
        out = self.review(
            second,
            f"Reviewer: r Head: {second} Verdict: clean\nRange: {self.rev}..{second}\n",
        )
        self.assertIn("covers only part of the branch", out[0])
        # The fork point, or any base-branch commit, is a full range.
        self.assertEqual(self.review(second, blk(second, self.root)), [])
        self.assertEqual(self.review(second, blk(second, self.r.tip())), [])

    def test_diff_tree_failure_raises(self):
        with self.assertRaises(ValueError):
            self.r.pr_git().changed_files("0" * 40, "1" * 40)

    def test_conflicted_merge_tree_committed_as_is_fails(self):
        r = self.r
        r.git("checkout", "-q", "main")
        r.commit("a.txt", "one\nMAIN\nthree\n")
        r.sync_origin()
        r.git("checkout", "-q", "pr")
        reviewed = r.commit("a.txt", "one\nPR\nthree\n")
        res = r.git("merge", "--no-ff", "-m", "Merge main", "main", check=False)
        self.assertNotEqual(res.returncode, 0)
        # Commit exactly what merge-tree wrote, conflict markers and all.
        _, tree, _ = r.pr_git().merge_tree(reviewed, r.tip())
        r.write("a.txt", r.git("show", f"{tree}:a.txt").stdout)
        r.git("add", "a.txt")
        r.git("commit", "-q", "--no-edit")
        h = r.head()
        self.assertEqual(tree, r.pr_git().tree(h))  # the tree is merge-tree's
        out = self.review(h, blk(reviewed, self.root))
        self.assertIn(f"Merge {h} is not a clean automatic merge", out[0])
        self.assertIn("a.txt", out[0])

    def test_chain_through_later_reviewed_head(self):
        r = self.r
        later = r.commit("pr2.txt")
        self.advance_main("m1.txt")
        h = r.merge("main")
        both = blk(self.rev, self.root) + blk(later, self.root)
        self.assertEqual(self.review(h, both), [])
        # P is the later head: only the first reviewed commit is not enough.
        out = self.review(h, blk(self.rev, self.root))
        self.assertIn(f"commit {later} (reached from head {h}", out[0])

    # --- the transition: a legacy block naming a merge head --------------

    def test_legacy_block_naming_clean_merge_head_passes(self):
        h = self.clean_merge_of_main()
        self.assertEqual(self.review(h, blk(h, self.root, rng=False)), [])

    def test_legacy_merge_head_with_unreviewed_first_parent_passes_only_in_transition(self):
        self.advance_main("m1.txt")
        self.r.commit("late.txt")
        late = self.r.head()
        h = self.r.merge("main")
        legacy = blk(h, self.root, rng=False)
        self.assertEqual(self.review(h, legacy), [])
        with mock.patch.object(pr_policy, "ACCEPT_LEGACY_REVIEW_BLOCK", False):
            out = self.review(h, legacy)
        self.assertIn(f"but commit {late} (reached from head {h}", out[0])
        self.assertIn(f"Head: {late}", out[0])
        self.assertIn(f"Range: {self.r.tip()}..{late}", out[0])

    def test_legacy_block_with_flag_off_passes_once_p_has_a_block(self):
        h = self.clean_merge_of_main()
        with mock.patch.object(pr_policy, "ACCEPT_LEGACY_REVIEW_BLOCK", False):
            out = self.review(h, blk(h, self.root, rng=False) + blk(self.rev, self.root))
        self.assertEqual(out, [])

    def test_range_block_naming_a_clean_merge_does_not_accept_it(self):
        self.advance_main("m1.txt")
        self.r.commit("late.txt")
        h = self.r.merge("main")
        out = self.review(h, blk(h, self.root))
        self.assertIn(f"commit {self.r.git('rev-parse', h + '^1').stdout.strip()} (reached", out[0])

    def test_legacy_block_does_not_accept_a_dirty_merge(self):
        r = self.r
        self.advance_main("m1.txt")
        r.git("merge", "-q", "--no-ff", "--no-commit", "main")
        r.write("evil.txt", "payload\n")
        r.git("add", "evil.txt")
        r.git("commit", "-q", "-m", "Merge main")
        h = r.head()
        out = self.review(h, blk(h, self.root, rng=False))
        self.assertIn("evil.txt", out[0])

    def test_legacy_block_does_not_accept_a_foreign_second_parent(self):
        r = self.r
        r.git("checkout", "-q", "-B", "other", self.root)
        r.commit("other.txt")
        r.git("checkout", "-q", "pr")
        r.sync_origin()
        h = r.merge("other")
        out = self.review(h, blk(h, self.root, rng=False))
        self.assertIn("is not on the base branch", out[0])

    def test_legacy_clean_and_changes_requested_for_a_merge_head_in_either_order(self):
        self.advance_main("m1.txt")
        self.r.commit("late.txt")  # first parent unreviewed
        h = self.r.merge("main")
        good = blk(h, self.root, rng=False)
        bad = blk(h, self.root, rng=False, verdict="changes-requested")
        self.assertEqual(self.review(h, good), [])
        for review in (good + bad, bad + good):
            self.assertTrue(self.review(h, review))

    def test_legacy_changes_requested_does_not_accept_a_merge(self):
        h = self.clean_merge_of_main()
        out = self.review(h, blk(h, self.root, rng=False, verdict="changes-requested"))
        self.assertTrue(out)

    def test_head_missing_from_checkout_fails(self):
        self.r.sync_origin()
        out = self.review(OLD, blk(OLD, self.root))
        self.assertIn("is not in the checkout", out[0])

    # --- rule (b1) --------------------------------------------------------

    def clean_merge_of_main(self):
        self.advance_main("m1.txt")
        return self.r.merge("main")

    def test_clean_merge_of_main_needs_no_new_line(self):
        h = self.clean_merge_of_main()
        self.assertEqual(
            len(self.r.git("rev-list", "--parents", "-n1", h).stdout.split()), 3
        )
        self.assertEqual(self.review(h, blk(self.rev, self.root)), [])

    def test_clean_merge_chain_of_two_passes(self):
        self.advance_main("m1.txt")
        self.r.merge("main")
        self.advance_main("m2.txt")
        h = self.r.merge("main")
        self.assertEqual(self.review(h, blk(self.rev, self.root)), [])

    def test_clean_merge_over_unreviewed_first_parent_fails(self):
        self.advance_main("m1.txt")
        self.r.commit("late.txt")  # pushed after the review
        late = self.r.head()
        h = self.r.merge("main")
        out = self.review(h, blk(self.rev, self.root))
        self.assertIn(f"commit {late} (reached from head {h}", out[0])
        self.assertIn(f"Head: {late}", out[0])

    def test_hand_resolved_conflict_merge_fails_naming_files(self):
        r = self.r
        r.git("checkout", "-q", "main")
        r.commit("a.txt", "one\nMAIN\nthree\n")
        r.sync_origin()
        r.git("checkout", "-q", "pr")
        r.commit("a.txt", "one\nPR\nthree\n")
        reviewed = r.head()
        res = r.git("merge", "--no-ff", "-m", "Merge main", "main", check=False)
        self.assertNotEqual(res.returncode, 0)
        r.write("a.txt", "one\nBOTH\nthree\n")
        r.git("add", "a.txt")
        r.git("commit", "-q", "--no-edit")
        h = r.head()
        out = self.review(h, blk(reviewed, self.root))
        self.assertEqual(len(out), 1)
        self.assertIn(f"Merge {h} is not a clean automatic merge", out[0])
        self.assertIn(f"first parent {reviewed}", out[0])
        self.assertIn(f"second parent {r.tip()}", out[0])
        self.assertIn("a.txt", out[0])
        self.assertIn("Merge-review: a.txt", out[0])
        self.assertIn("merge-only review", out[0])

    def test_evil_merge_extra_file_fails_naming_it(self):
        r = self.r
        self.advance_main("m1.txt")
        r.git("merge", "-q", "--no-ff", "--no-commit", "main")
        r.write("evil.txt", "payload\n")
        r.git("add", "evil.txt")
        r.git("commit", "-q", "-m", "Merge main")
        h = r.head()
        out = self.review(h, blk(self.rev, self.root))
        self.assertIn("evil.txt", out[0])
        self.assertNotIn("m1.txt,", out[0].split("differs from")[1].split("Redo")[0])

    def test_evil_merge_edit_of_existing_file_fails(self):
        r = self.r
        self.advance_main("m1.txt")
        r.git("merge", "-q", "--no-ff", "--no-commit", "main")
        r.write("b.txt", "tampered\n")
        r.git("add", "b.txt")
        r.git("commit", "-q", "-m", "Merge main")
        out = self.review(r.head(), blk(self.rev, self.root))
        self.assertIn("b.txt", out[0])

    def test_forged_review_line_for_dirty_merge_head_still_fails(self):
        r = self.r
        self.advance_main("m1.txt")
        r.git("merge", "-q", "--no-ff", "--no-commit", "main")
        r.write("evil.txt", "payload\n")
        r.git("add", "evil.txt")
        r.git("commit", "-q", "-m", "Merge main")
        h = r.head()
        out = self.review(h, blk(h, self.root))
        self.assertIn(f"Merge {h} is not a clean automatic merge", out[0])
        self.assertIn("evil.txt", out[0])

    def test_forged_line_for_dirty_merge_as_first_parent_fails(self):
        r = self.r
        self.advance_main("m1.txt")
        r.git("merge", "-q", "--no-ff", "--no-commit", "main")
        r.write("evil.txt", "payload\n")
        r.git("add", "evil.txt")
        r.git("commit", "-q", "-m", "Merge main")
        dirty = r.head()
        self.advance_main("m2.txt")
        h = r.merge("main")
        out = self.review(h, blk(dirty, self.root))
        self.assertIn(f"Merge {dirty} is not a clean automatic merge", out[0])

    def test_second_parent_not_on_base_fails(self):
        r = self.r
        r.git("checkout", "-q", "-B", "other", self.root)
        other = r.commit("other.txt")
        r.git("checkout", "-q", "pr")
        r.sync_origin()
        h = r.merge("other")
        out = self.review(h, blk(self.rev, self.root))
        self.assertIn(f"second parent {other} is not on the base branch", out[0])
        self.assertIn("merge only the base branch", out[0])

    def test_depth_cap_fails(self):
        for i in range(3):
            self.advance_main(f"m{i}.txt")
            h = self.r.merge("main")
        with mock.patch.object(pr_policy, "MAX_MERGE_DEPTH", 2):
            out = self.review(h, blk(self.rev, self.root))
        p2 = self.r.git("rev-parse", f"{h}^1^1").stdout.strip()
        self.assertIn(f"2 clean merges in a row lie between head {h} and {p2}", out[0])
        self.assertIn(f"merge review of {p2}", out[0])
        self.assertIn(f"Merge-review: <files>\nReviewer: isolated-reviewer  Head: {p2}", out[0])
        with mock.patch.object(pr_policy, "MAX_MERGE_DEPTH", 2):
            anchored = (
                blk(self.rev, self.root)
                + f"Merge-review: x.txt\nReviewer: r Head: {p2} Verdict: clean\nRange: {self.root}..{p2}\n"
            )
            self.assertEqual(self.review(h, anchored), [])
        with mock.patch.object(pr_policy, "MAX_MERGE_DEPTH", 3):
            self.assertEqual(self.review(h, blk(self.rev, self.root)), [])

    def test_default_depth_cap_is_twenty(self):
        self.assertEqual(pr_policy.MAX_MERGE_DEPTH, 20)

    def test_octopus_merge_fails_closed(self):
        r = self.r
        r.git("checkout", "-q", "main")
        r.git("checkout", "-q", "-b", "x", self.root)
        r.commit("x.txt")
        r.git("checkout", "-q", "-b", "y", self.root)
        r.commit("y.txt")
        r.git("checkout", "-q", "pr")
        r.git(
            "update-ref",
            "refs/remotes/origin/main",
            r.git("rev-parse", "x").stdout.strip(),
        )
        r.git("merge", "-q", "--no-ff", "-m", "octopus", "x", "y")
        h = r.head()
        self.assertEqual(
            len(r.git("rev-list", "--parents", "-n1", h).stdout.split()), 4
        )
        out = review_recorded(
            body(review=blk(self.rev, self.root)),
            h,
            r.pr_git(),
            r.git("rev-parse", "x").stdout.strip(),
        )
        self.assertIn("octopus merge (3 parents)", out[0])
        self.assertNotIn("Merge-review", out[0])

    # --- rule (b2) --------------------------------------------------------

    def dirty_merge(self):
        r = self.r
        r.git("checkout", "-q", "main")
        r.commit("a.txt", "one\nMAIN\nthree\n")
        r.sync_origin()
        r.git("checkout", "-q", "pr")
        r.commit("a.txt", "one\nPR\nthree\n")
        r.git("merge", "--no-ff", "-m", "Merge main", "main", check=False)
        r.write("a.txt", "one\nBOTH\nthree\n")
        r.git("add", "a.txt")
        r.git("commit", "-q", "--no-edit")
        return r.head()

    def merge_review(
        self, h, files="a.txt", verdict="clean", rng=True, reviewer_head=None
    ):
        out = f"Merge-review: {files}\n"
        out += f"Reviewer: isolated-reviewer Head: {reviewer_head or h} Verdict: {verdict}\n"
        if rng:
            out += f"Range: {self.root}..{h}\n"
        return out

    def p_block(self, h):
        p = self.r.git("rev-parse", f"{h}^1").stdout.strip()
        return blk(p, self.root)

    def test_dirty_merge_with_merge_review_passes(self):
        h = self.dirty_merge()
        out = self.review(h, self.p_block(h) + "\n" + self.merge_review(h))
        self.assertEqual(out, [])

    def test_merge_review_needs_the_first_parent_accepted(self):
        h = self.dirty_merge()
        p = self.r.git("rev-parse", f"{h}^1").stdout.strip()
        out = self.review(h, self.merge_review(h))
        self.assertIn(f"No isolated review recorded for commit {p}", out[0])
        self.assertIn(f"Head: {p}", out[0])

    def test_merge_review_must_list_every_differing_file(self):
        h = self.dirty_merge()
        out = self.review(h, self.p_block(h) + self.merge_review(h, files="b.txt"))
        self.assertIn("does not list a.txt", out[0])
        self.assertIn("Merge-review: a.txt, b.txt", out[0])

    def test_merge_review_may_list_extra_files(self):
        h = self.dirty_merge()
        out = self.review(h, self.p_block(h) + self.merge_review(h, files="a.txt, b.txt"))
        self.assertEqual(out, [])

    def test_merge_review_lists_evil_merge_extra_file(self):
        r = self.r
        self.advance_main("m1.txt")
        r.git("merge", "-q", "--no-ff", "--no-commit", "main")
        r.write("evil.txt", "payload\n")
        r.git("add", "evil.txt")
        r.git("commit", "-q", "-m", "Merge main")
        h = r.head()
        out = self.review(h, blk(self.rev, self.root) + self.merge_review(h, files="m1.txt"))
        self.assertIn("does not list evil.txt", out[0])
        out = self.review(h, blk(self.rev, self.root) + self.merge_review(h, files="evil.txt"))
        self.assertEqual(out, [])

    def test_merge_review_for_another_commit_does_not_help(self):
        h = self.dirty_merge()
        out = self.review(h, self.merge_review(OLD))
        self.assertIn(f"Merge {h} is not a clean automatic merge", out[0])

    def test_merge_review_without_range_fails(self):
        h = self.dirty_merge()
        out = self.review(h, self.merge_review(h, rng=False))
        self.assertIn("has no Range line", out[0])

    def test_merge_review_with_bad_range_fails(self):
        h = self.dirty_merge()
        later = OLD
        bad = (
            f"Merge-review: a.txt\nReviewer: r Head: {h} Verdict: clean\n"
            f"Range: {later}..{h}\n"
        )
        out = self.review(h, bad)
        self.assertIn("is not an ancestor", out[0])

    def test_merge_review_changes_requested_fails(self):
        h = self.dirty_merge()
        out = self.review(h, self.merge_review(h, verdict="changes-requested"))
        self.assertIn("latest merge review of", out[0])
        self.assertIn("requested changes", out[0])

    def test_merge_review_naming_no_files_fails(self):
        h = self.dirty_merge()
        out = self.review(h, self.merge_review(h, files=""))
        self.assertIn("names no files", out[0])

    def test_plain_block_after_merge_review_is_its_own_block(self):
        h = self.dirty_merge()
        review = self.merge_review(h) + self.p_block(h)
        self.assertEqual(self.review(h, review), [])

    def test_foreign_second_parent_merge_review_must_list_everything_brought_in(self):
        r = self.r
        r.git("checkout", "-q", "-B", "other", self.root)
        r.commit("other.txt")
        r.commit("evil.txt")
        r.git("checkout", "-q", "pr")
        r.sync_origin()
        h = r.merge("other")
        out = self.review(h, blk(self.rev, self.root) + self.merge_review(h, files="other.txt"))
        self.assertIn("does not list evil.txt", out[0])
        both = self.merge_review(h, files="other.txt, evil.txt")
        self.assertEqual(self.review(h, blk(self.rev, self.root) + both), [])
        out = self.review(h, blk(self.rev, self.root))
        self.assertIn("lists every file the merge brings into", out[0])
        self.assertIn("evil.txt", out[0])

    def test_fifteen_merge_review_chain_over_unreviewed_bottom_is_fast(self):
        r = self.r
        blocks = ""
        for i in range(15):
            self.advance_main(f"m{i}.txt")
            h = r.merge("main")
            blocks += (
                f"Merge-review: x.txt\nReviewer: isolated-reviewer Head: {h} Verdict: clean\n"
                f"Range: {self.root}..{h}\n"
            )
        calls = []
        git = r.pr_git()
        real = git.run

        def counting(*args):
            calls.append(args)
            if len(calls) > 3000:
                raise AssertionError("the chain walk is not linear")
            return real(*args)

        git.run = counting
        start = time.monotonic()
        out = review_recorded(body(review=blocks), h, git, r.tip())
        self.assertLess(time.monotonic() - start, 2.0)
        self.assertEqual(len(out), 1)
        self.assertIn(f"No isolated review recorded for commit {self.rev}", out[0])

    def test_merge_review_also_rescues_a_foreign_second_parent(self):
        r = self.r
        r.git("checkout", "-q", "-B", "other", self.root)
        r.commit("other.txt")
        r.git("checkout", "-q", "pr")
        r.sync_origin()
        h = r.merge("other")
        review = blk(self.rev, self.root) + self.merge_review(h, files="other.txt")
        self.assertEqual(self.review(h, review), [])


class GitReviewMainTest(unittest.TestCase):
    """main() in review mode with a real checkout."""

    def run_review(self, repo, event_body, head):
        pr = {
            "number": 7,
            "title": "feat: x",
            "body": event_body,
            "user": {"login": "cedricziel"},
            "head": {"ref": "claude/x", "sha": head, "repo": {"full_name": "o/r"}},
            "base": {"ref": "main", "sha": OLD, "repo": {"full_name": "o/r"}},
        }
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "event.json")
            with open(path, "w") as f:
                json.dump({"pull_request": pr}, f)
            old = os.environ.get("GITHUB_EVENT_PATH")
            os.environ["GITHUB_EVENT_PATH"] = path
            buf = io.StringIO()
            try:
                with redirect_stdout(buf):
                    code = pr_policy.main(["x", "review"], git=repo.pr_git())
            finally:
                if old is None:
                    del os.environ["GITHUB_EVENT_PATH"]
                else:
                    os.environ["GITHUB_EVENT_PATH"] = old
        return code, buf.getvalue()

    def setUp(self):
        self.r = Repo()
        self.addCleanup(self.r.close)
        self.root = self.r.commit("a.txt", "x\n")
        self.r.branch("pr", self.root)
        self.rev = self.r.commit("p.txt")

    def test_pass_and_fail_through_main(self):
        self.r.sync_origin()
        code, out = self.run_review(
            self.r, body(review=blk(self.rev, self.root)), self.rev
        )
        self.assertEqual((code, out.strip()), (0, "ok"))
        code, out = self.run_review(self.r, body(review=""), self.rev)
        self.assertEqual(code, 1)
        self.assertIn("::error::No isolated review recorded", out)

    def test_missing_base_branch_fails_closed(self):
        code, out = self.run_review(
            self.r, body(review=blk(self.rev, self.root)), self.rev
        )
        self.assertEqual(code, 1)
        self.assertIn("base branch 'main' is not in the checkout", out)
class MainTest(unittest.TestCase):
    """Runs main() against a saved event JSON and a fake file listing."""

    def event(self, **over):
        pr = {
            "number": 7,
            "title": "feat(chat): faster open",
            "body": body(),
            "user": {"login": "cedricziel"},
            "head": {"ref": "claude/x", "sha": SHA, "repo": {"full_name": "o/r"}},
            "base": {"sha": OLD, "repo": {"full_name": "o/r"}},
        }
        pr.update(over)
        return {"pull_request": pr}

    def run_main(self, mode, event, files=(), blobs=None, current=SHA):
        """blobs maps (path, ref) to file text; a missing one raises."""
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "event.json")
            with open(path, "w") as f:
                json.dump(event, f)
            old = os.environ.get("GITHUB_EVENT_PATH")
            os.environ["GITHUB_EVENT_PATH"] = path
            calls = []

            def api(p):
                calls.append(p)
                if p == "repos/o/r/pulls/7":
                    return {"head": {"sha": current}}
                if p.startswith("repos/o/r/pulls/7/files"):
                    return list(files)
                if p.startswith("repos/o/r/compare/"):
                    return {"merge_base_commit": {"sha": MERGE_BASE}}
                if p.startswith("repos/o/r/contents/"):
                    name, ref = p[len("repos/o/r/contents/"):].split("?ref=")
                    text = (blobs or {})[(name, ref)]
                    return {
                        "encoding": "base64",
                        "content": base64.b64encode(text.encode()).decode(),
                    }
                raise AssertionError(p)

            buf = io.StringIO()
            try:
                with redirect_stdout(buf):
                    code = pr_policy.main(["x", mode], api)
            finally:
                if old is None:
                    del os.environ["GITHUB_EVENT_PATH"]
                else:
                    os.environ["GITHUB_EVENT_PATH"] = old
            return code, buf.getvalue(), calls

    def test_patchless_pubspec_version_change_detected(self):
        files = [{"filename": "pubspec.yaml", "status": "modified"}]
        blobs = {
            ("pubspec.yaml", MERGE_BASE): "name: x\nversion: 1.0.0\n",
            ("pubspec.yaml", SHA): "name: x\nversion: 1.0.1\n",
        }
        code, out, _ = self.run_main("policy", self.event(), files, blobs)
        self.assertEqual(code, 1)
        self.assertIn("release-please bumps", out)

    def test_patchless_pubspec_without_version_change_ok(self):
        files = [{"filename": "pubspec.yaml", "status": "modified"}]
        blobs = {
            ("pubspec.yaml", MERGE_BASE): "name: x\nversion: 1.0.0\n",
            ("pubspec.yaml", SHA): "name: y\nversion: 1.0.0\n",
        }
        self.assertEqual(self.run_main("policy", self.event(), files, blobs)[0], 0)

    def test_patchless_large_claude_md_reflow_checked(self):
        old = "".join(f"line {i} with `code`\n" for i in range(3000))
        new = old.replace("line 2999 with `code`", "line 2999 on x86*64 with `code")
        files = [{"filename": "CLAUDE.md", "status": "modified"}]
        blobs = {("CLAUDE.md", MERGE_BASE): old, ("CLAUDE.md", SHA): new}
        code, out, _ = self.run_main("policy", self.event(), files, blobs)
        self.assertEqual(code, 1)
        self.assertIn("corrupted by a Markdown formatter", out)

    def test_patchless_added_file_diffed_against_empty(self):
        files = [{"filename": "CLAUDE.md", "status": "added"}]
        blobs = {("CLAUDE.md", SHA): "use `flutter run\n"}
        self.assertEqual(self.run_main("policy", self.event(), files, blobs)[0], 1)

    def test_patchless_unfetchable_fails_closed(self):
        files = [{"filename": "docs/roadmap.md", "status": "modified"}]
        code, out, _ = self.run_main("policy", self.event(), files, {})
        self.assertEqual(code, 1)
        self.assertIn("too large to check", out)

    def test_removed_or_other_patchless_files_not_fetched(self):
        files = [
            {"filename": "CLAUDE.md", "status": "removed"},
            {"filename": "lib/big.dart", "status": "modified"},
        ]
        code, _, calls = self.run_main("policy", self.event(), files, {})
        self.assertFalse([c for c in calls if "contents" in c])

    def test_too_many_files(self):
        ev = self.event(changed_files=3001)
        code, out, _ = self.run_main("policy", ev, [{"filename": "a.dart"}])
        self.assertEqual(code, 1)
        self.assertIn("Too many files to check", out)

    def test_changed_files_equal_ok(self):
        ev = self.event(changed_files=1)
        self.assertEqual(self.run_main("policy", ev, [{"filename": "a.dart"}])[0], 0)

    def test_moved_head_fails_closed(self):
        code, out, calls = self.run_main("policy", self.event(), current=OLD)
        self.assertEqual(code, 1)
        self.assertIn(
            f"The PR head moved ({SHA} → {OLD}); the run on the newer head decides",
            out,
        )
        self.assertEqual(len(calls), 1)

    def test_review_not_superseded_check(self):
        ev = self.event(body=body(review=""))
        code, _, calls = self.run_main("review", ev, current=OLD)
        self.assertEqual((code, calls), (1, []))

    def test_policy_ok(self):
        code, out, calls = self.run_main(
            "policy", self.event(), [{"filename": "a.dart"}]
        )
        self.assertEqual((code, out.strip()), (0, "ok"))
        self.assertEqual(calls[0], "repos/o/r/pulls/7")

    def test_policy_fails_on_roadmap_and_version(self):
        files = [
            {"filename": "docs/roadmap.md", "patch": "@@ -1 +1 @@\n-a\n+b"},
            {
                "filename": "pubspec.yaml",
                "patch": "@@ -1 +1 @@\n-version: 1.0.0\n+version: 1.0.1",
            },
        ]
        code, out, _ = self.run_main("policy", self.event(), files)
        self.assertEqual(code, 1)
        self.assertIn("::error::Only the orchestrator", out)
        self.assertIn("::error::pubspec.yaml", out)

    def test_policy_renamed_roadmap(self):
        files = [{"filename": "docs/old.md", "previous_filename": "docs/roadmap.md"}]
        self.assertEqual(self.run_main("policy", self.event(), files)[0], 1)

    def test_policy_corruption_from_patch(self):
        files = [{"filename": "CLAUDE.md", "patch": "@@ -1 +1 @@\n-x86_64\n+x86*64"}]
        self.assertIn("corrupted", self.run_main("policy", self.event(), files)[1])

    def test_review_mode_makes_no_api_calls(self):
        # Review mode reads the event and git objects only; the checkout here
        # has no origin/<base> for the event, so the run fails closed.
        code, out, calls = self.run_main("review", self.event())
        self.assertEqual((code, calls), (1, []))
        self.assertIn("is not in the checkout", out)

    def test_fork_head_not_exempt(self):
        fork = {
            "ref": "chore/update-flutter",
            "sha": SHA,
            "repo": {"full_name": "evil/r"},
        }
        self.assertEqual(self.run_main("policy", self.event(title="x", head=fork))[0], 1)
        self.assertEqual(self.run_main("review", self.event(body="", head=fork))[0], 1)

    def test_unknown_mode(self):
        self.assertEqual(self.run_main("nope", self.event())[0], 2)


if __name__ == "__main__":
    unittest.main()
