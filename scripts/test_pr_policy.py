import unittest

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
    review=f"Reviewer: x\nHead: {SHA}\nVerdict: clean\n",
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
):
    return check(
        title, body() if b is None else b, head_ref, author, SHA, list(files), version
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


class BotExemptionTest(unittest.TestCase):
    def test_bot_author_exempt_from_body_rules(self):
        self.assertEqual(
            run("Bump x from 1 to 2", "", "dependabot/pub/x", "dependabot[bot]"), []
        )
        self.assertEqual(run("whatever", "", "some/branch", "renovate[bot]"), [])

    def test_automation_branches_exempt(self):
        for ref in [
            "release-please--branches--main--components--hermes-app",
            "chore/update-flutter",
            "chore/update-hermes-contracts",
            "chore/update-claude-plugins",
            "chore/readme-screenshots-12345",
            "dependabot/gradle/android/x",
        ]:
            self.assertEqual(
                run("chore(main): release 1", "", ref, "cedricziel"), [], ref
            )

    def test_bot_still_gets_roadmap_and_version(self):
        out = run(
            "chore: x", "", "chore/update-flutter", "x[bot]", ["docs/roadmap.md"], True
        )
        self.assertEqual(len(out), 2)

    def test_human_not_exempt(self):
        self.assertTrue(run("whatever", "", "chore/other", "cedricziel"))


def diff_of(removed, added):
    out = ["--- a/CLAUDE.md", "+++ b/CLAUDE.md", "@@ -1,1 +1,1 @@"]
    out += ["-" + x for x in removed] + ["+" + x for x in added]
    return "\n".join(out)


class CorruptionTest(unittest.TestCase):
    def test_x86_star_64(self):
        self.assertEqual(corrupted_lines(diff_of(["a x86_64 b"], ["a x86*64 b"])), ["a x86*64 b"])

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
    def test_clean_review_passes(self):
        self.assertEqual(review_recorded(body(), SHA), [])

    def test_formatted_review_passes(self):
        r = f"**Reviewer:** x\n**Head:** `{SHA}`\n**Verdict:** clean\n"
        self.assertEqual(review_recorded(body(review=r), SHA), [])

    def test_uppercase_sha_matches(self):
        r = f"Head: {SHA.upper()}\nVerdict: clean"
        self.assertEqual(review_recorded(body(review=r), SHA), [])

    def test_missing_section(self):
        out = review_recorded("## Proof\nx\n", SHA)
        self.assertEqual(
            out,
            [
                f"No isolated review recorded for {SHA}: run the isolated-reviewer "
                "agent on this head and paste its block into ## Review"
            ],
        )

    def test_comment_only_section(self):
        out = review_recorded(
            body(review="<!-- Head: " + SHA + " Verdict: clean -->"), SHA
        )
        self.assertTrue(out[0].startswith("No isolated review recorded"))

    def test_sha_mismatch(self):
        r = f"Head: {OLD}\nVerdict: clean"
        self.assertEqual(
            review_recorded(body(review=r), SHA),
            [f"The review is for {OLD}, the head is {SHA}: review the new commits."],
        )

    def test_short_sha_is_not_recorded(self):
        r = f"Head: {SHA[:7]}\nVerdict: clean"
        self.assertTrue(
            review_recorded(body(review=r), SHA)[0].startswith("No isolated")
        )

    def test_changes_requested(self):
        r = f"Head: {SHA}\nVerdict: changes-requested"
        self.assertIn("changes-requested", review_recorded(body(review=r), SHA)[0])

    def test_template_placeholder_verdict_is_not_clean(self):
        r = f"Head: {SHA}\nVerdict: clean | changes-requested"
        self.assertTrue(review_recorded(body(review=r), SHA))

    def test_empty_body(self):
        self.assertTrue(review_recorded("", SHA))
        self.assertTrue(review_recorded(None, SHA))


if __name__ == "__main__":
    unittest.main()
