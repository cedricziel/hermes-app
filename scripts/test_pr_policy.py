import unittest

import io
import json
import os
import tempfile
from contextlib import redirect_stdout

import pr_policy
from pr_policy import check, corrupted_lines, review_recorded

SHA = "a" * 40
OLD = "b" * 40

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

    def test_reviewer_name_with_spaces(self):
        r = f"Reviewer: isolated reviewer 2 Head: {SHA} Verdict: clean"
        self.assertEqual(self.rv(r), [])

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

    def run_main(self, mode, event, files=()):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "event.json")
            with open(path, "w") as f:
                json.dump(event, f)
            old = os.environ.get("GITHUB_EVENT_PATH")
            os.environ["GITHUB_EVENT_PATH"] = path
            calls = []

            def fetch(repo, number):
                calls.append((repo, number))
                return list(files)

            buf = io.StringIO()
            try:
                with redirect_stdout(buf):
                    code = pr_policy.main(["x", mode], fetch)
            finally:
                if old is None:
                    del os.environ["GITHUB_EVENT_PATH"]
                else:
                    os.environ["GITHUB_EVENT_PATH"] = old
            return code, buf.getvalue(), calls

    def test_policy_ok(self):
        code, out, calls = self.run_main(
            "policy", self.event(), [{"filename": "a.dart"}]
        )
        self.assertEqual((code, out.strip(), calls), (0, "ok", [("o/r", 7)]))

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

    def test_review_mode_uses_event_only(self):
        code, out, calls = self.run_main("review", self.event())
        self.assertEqual((code, calls), (0, []))
        code, out, _ = self.run_main("review", self.event(body=body(review="")))
        self.assertEqual(code, 1)
        self.assertIn("::error::No isolated review recorded", out)

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
