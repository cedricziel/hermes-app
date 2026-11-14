import io
import unittest

import coverage_summary as cs

A = "SF:lib/src/chat/a.dart\nDA:1,1\nDA:2,0\nend_of_record\n"
B = "SF:lib/src/chat/a.dart\nDA:1,0\nDA:2,3\nend_of_record\n"
C = (
    "SF:lib/src/auth/b.dart\nDA:1,0\nend_of_record\n"
    "SF:lib/src/auth/b.g.dart\nDA:1,1\nend_of_record\n"
    "SF:packages/hermes_api/lib/x.dart\nDA:1,1\nend_of_record\n"
)


class CoverageSummaryTest(unittest.TestCase):
    def test_merge_adds_hits_and_drops_generated_code(self):
        files = cs.merge([A, B, C])
        self.assertEqual(sorted(files), ["lib/src/auth/b.dart", "lib/src/chat/a.dart"])
        self.assertEqual(dict(files["lib/src/chat/a.dart"]), {1: 1, 2: 3})

    def test_summary_lists_lowest_directory_first(self):
        text = cs.summarize(cs.merge([A, B, C]))
        self.assertIn("**66.7%** (2 of 3 lines", text)
        self.assertLess(text.index("`auth`"), text.index("`chat`"))

    def test_lcov_round_trips(self):
        out = io.StringIO()
        cs.write_lcov(cs.merge([A, B]), out)
        self.assertEqual(dict(cs.merge([out.getvalue()])["lib/src/chat/a.dart"]), {1: 1, 2: 3})


if __name__ == "__main__":
    unittest.main()
