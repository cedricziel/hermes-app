import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import ci_gate  # noqa: E402

LABEL = "ci:full"
RELEASE = "release-please--branches--main--components--hermes-app"


def pr(labels, base="main", head="claude/feature"):
    return ci_gate.decide("pull_request", base, labels, head_ref=head)


class PullRequestShapes(unittest.TestCase):
    """One case per event shape. The decision depends on the label set only,
    never on the action, so an event and its label set give the same answer."""

    def check(self, result, mode, reason):
        self.assertEqual(result, (mode, reason))

    def test_opened_without_label(self):
        self.check(pr([]), "deferred", ci_gate.REASON_DEFERRED)

    def test_opened_with_label(self):
        self.check(pr([LABEL]), "full", ci_gate.REASON_LABEL)

    def test_labeled_with_ci_full(self):
        self.check(pr([LABEL]), "full", ci_gate.REASON_LABEL)

    def test_labeled_unrelated_without_ci_full_stays_deferred(self):
        self.check(pr(["bot"]), "deferred", ci_gate.REASON_DEFERRED)

    def test_labeled_unrelated_with_ci_full_stays_full(self):
        self.check(pr([LABEL, "bot"]), "full", ci_gate.REASON_LABEL)

    def test_unlabeled_ci_full_becomes_deferred(self):
        self.check(pr([]), "deferred", ci_gate.REASON_DEFERRED)

    def test_unlabeled_unrelated_while_ci_full_stays(self):
        self.check(pr([LABEL]), "full", ci_gate.REASON_LABEL)

    def test_synchronize_with_label(self):
        self.check(pr([LABEL, "other"]), "full", ci_gate.REASON_LABEL)

    def test_synchronize_without_label(self):
        self.check(pr(["other"]), "deferred", ci_gate.REASON_DEFERRED)

    def test_label_match_is_exact(self):
        for name in ("ci:Full", "ci:full ", "ci:full-ish", "ci", "full"):
            with self.subTest(name=name):
                self.check(pr([name]), "deferred", ci_gate.REASON_DEFERRED)

    def test_base_not_main(self):
        self.check(pr([], base="claude/other"), "full", ci_gate.REASON_STACKED)

    def test_base_not_main_wins_over_missing_label(self):
        self.check(pr(["bot"], base="release/1"), "full", ci_gate.REASON_STACKED)

    def test_release_please_branch_is_full_without_label(self):
        self.check(pr([], head=RELEASE), "full", ci_gate.REASON_RELEASE)

    def test_release_please_lookalike_is_deferred(self):
        self.check(pr([], head=RELEASE + "-2"), "deferred", ci_gate.REASON_DEFERRED)

    def test_dependabot_is_deferred_like_any_pr(self):
        self.check(
            pr([], head="dependabot/pub/dio-5.9.0"),
            "deferred",
            ci_gate.REASON_DEFERRED,
        )


class OtherEvents(unittest.TestCase):
    def test_push(self):
        self.assertEqual(ci_gate.decide("push", "", []), ("full", ci_gate.REASON_EVENT))

    def test_workflow_dispatch(self):
        self.assertEqual(
            ci_gate.decide("workflow_dispatch", "", []),
            ("full", ci_gate.REASON_EVENT),
        )

    def test_merge_group(self):
        self.assertEqual(
            ci_gate.decide("merge_group", "", []), ("full", ci_gate.REASON_EVENT)
        )


class FailClosed(unittest.TestCase):
    def test_error_flag(self):
        self.assertEqual(
            ci_gate.decide("pull_request", "main", [], error=True),
            ("full", ci_gate.REASON_ERROR),
        )

    def test_unknown_event(self):
        for event in ("", None, "schedule", "pull_request_target"):
            with self.subTest(event=event):
                self.assertEqual(
                    ci_gate.decide(event, "main", []),
                    ("full", ci_gate.REASON_UNKNOWN_EVENT),
                )

    def test_missing_base(self):
        for base in ("", None, 7):
            with self.subTest(base=base):
                self.assertEqual(
                    ci_gate.decide("pull_request", base, []),
                    ("full", ci_gate.REASON_MISSING),
                )

    def test_missing_or_malformed_labels(self):
        for labels in (None, "ci:full", 5, [LABEL, 3], {LABEL}):
            with self.subTest(labels=labels):
                self.assertEqual(
                    ci_gate.decide("pull_request", "main", labels),
                    ("full", ci_gate.REASON_MISSING),
                )


class FromEnvironment(unittest.TestCase):
    def test_opened_without_label(self):
        env = {"EVENT_NAME": "pull_request", "BASE_REF": "main", "LABELS": ""}
        self.assertEqual(ci_gate.from_env(env), ("deferred", ci_gate.REASON_DEFERRED))

    def test_labels_are_one_per_line(self):
        env = {
            "EVENT_NAME": "pull_request",
            "BASE_REF": "main",
            "LABELS": "bot\nci:full\n",
        }
        self.assertEqual(ci_gate.from_env(env), ("full", ci_gate.REASON_LABEL))

    def test_label_names_may_contain_spaces(self):
        env = {
            "EVENT_NAME": "pull_request",
            "BASE_REF": "main",
            "LABELS": "good first issue",
        }
        self.assertEqual(ci_gate.from_env(env), ("deferred", ci_gate.REASON_DEFERRED))

    def test_label_lookup_failed(self):
        env = {
            "EVENT_NAME": "pull_request",
            "BASE_REF": "main",
            "LABELS": "",
            "LABELS_ERROR": "true",
        }
        self.assertEqual(ci_gate.from_env(env), ("full", ci_gate.REASON_ERROR))

    def test_unset_labels_on_a_pull_request(self):
        env = {"EVENT_NAME": "pull_request", "BASE_REF": "main"}
        self.assertEqual(ci_gate.from_env(env), ("full", ci_gate.REASON_MISSING))

    def test_unexpected_error_flag_value(self):
        env = {
            "EVENT_NAME": "pull_request",
            "BASE_REF": "main",
            "LABELS": "",
            "LABELS_ERROR": "maybe",
        }
        self.assertEqual(ci_gate.from_env(env), ("full", ci_gate.REASON_ERROR))

    def test_empty_environment(self):
        self.assertEqual(ci_gate.from_env({}), ("full", ci_gate.REASON_UNKNOWN_EVENT))

    def test_push_needs_no_labels(self):
        self.assertEqual(
            ci_gate.from_env({"EVENT_NAME": "push"}), ("full", ci_gate.REASON_EVENT)
        )

    def test_release_branch_from_head_ref(self):
        env = {
            "EVENT_NAME": "pull_request",
            "BASE_REF": "main",
            "HEAD_REF": RELEASE,
            "LABELS": "",
        }
        self.assertEqual(ci_gate.from_env(env), ("full", ci_gate.REASON_RELEASE))

    def test_output_lines(self):
        self.assertEqual(
            ci_gate.output_lines("deferred", "because"),
            ["full=false", "gate_reason=because"],
        )
        self.assertEqual(
            ci_gate.output_lines("full", "because"),
            ["full=true", "gate_reason=because"],
        )


if __name__ == "__main__":
    unittest.main()
