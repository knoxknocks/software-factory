"""Tests for sync_with_base in factory/bin/job (the pre-gate merge of the base branch).

Run from the repo root:  python3 -m unittest discover -s factory/tests -v

Each test builds throwaway git repos: a bare "origin", a clone that plays someone
else pushing to main, and a job worktree on a factory/ branch. Nothing touches the
real repo, GitHub or factory/jobs.
"""

import importlib.machinery
import importlib.util
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

JOB = Path(__file__).resolve().parents[1] / "bin" / "job"
IDENTITY = {
    "GIT_AUTHOR_NAME": "t",
    "GIT_AUTHOR_EMAIL": "t@example.com",
    "GIT_COMMITTER_NAME": "t",
    "GIT_COMMITTER_EMAIL": "t@example.com",
    "GIT_CONFIG_GLOBAL": os.devnull,
    "GIT_CONFIG_SYSTEM": os.devnull,
}


def load_job():
    loader = importlib.machinery.SourceFileLoader("factory_job", str(JOB))
    spec = importlib.util.spec_from_loader("factory_job", loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def sh(cwd, *cmd, check=True):
    res = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if check and res.returncode != 0:
        raise AssertionError(f"{' '.join(cmd)} failed: {res.stderr or res.stdout}")
    return res.stdout.strip()


class SyncWithBase(unittest.TestCase):
    def setUp(self):
        env = mock.patch.dict(os.environ, IDENTITY)
        env.start()
        self.addCleanup(env.stop)
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = Path(tmp.name)

        self.job = load_job()
        self.job.BASE = "main"
        self.job.CONFIG = dict(self.job.CONFIG)  # don't leak a changed flag into other tests

        origin = root / "origin.git"
        sh(root, "git", "init", "-q", "--bare", "-b", "main", str(origin))
        self.dev = root / "dev"  # someone else pushing to main
        sh(root, "git", "clone", "-q", str(origin), str(self.dev))
        self.write(self.dev, "a.txt", "one\n", "init")
        sh(self.dev, "git", "push", "-q", "origin", "main")

        self.wt = root / "wt"  # the job's worktree
        sh(root, "git", "clone", "-q", str(origin), str(self.wt))
        sh(self.wt, "git", "checkout", "-q", "-b", "factory/x")
        self.write(self.wt, "b.txt", "branch\n", "branch work")
        sh(self.wt, "git", "push", "-q", "-u", "origin", "factory/x")
        self.j = {"worktree": str(self.wt), "branch": "factory/x"}

    @staticmethod
    def write(repo, name, text, message):
        (repo / name).write_text(text)
        sh(repo, "git", "add", ".")
        sh(repo, "git", "commit", "-q", "-m", message)

    def main_moves(self, name, text):
        self.write(self.dev, name, text, f"main: {name}")
        sh(self.dev, "git", "push", "-q", "origin", "main")

    def head(self):
        return sh(self.wt, "git", "rev-parse", "HEAD")

    def remote_branch(self):
        return sh(self.wt, "git", "ls-remote", "origin", "refs/heads/factory/x").split()[0]

    def test_already_current_does_nothing(self):
        before = self.head()
        self.assertFalse(self.job.sync_with_base(self.j))
        self.assertEqual(self.head(), before)

    def test_merges_new_main_commit_and_pushes_without_rewriting_history(self):
        before = self.head()
        self.main_moves("c.txt", "from main\n")
        self.assertTrue(self.job.sync_with_base(self.j))
        self.assertTrue((self.wt / "c.txt").exists())
        self.assertTrue((self.wt / "b.txt").exists())
        # a merge, not a rebase: the old tip is still an ancestor, so a plain push was enough
        sh(self.wt, "git", "merge-base", "--is-ancestor", before, "HEAD")
        sh(self.wt, "git", "merge-base", "--is-ancestor", "origin/main", "HEAD")
        self.assertEqual(self.remote_branch(), self.head())
        self.assertEqual(sh(self.wt, "git", "status", "--porcelain"), "")

    def test_second_call_is_a_no_op(self):
        self.main_moves("c.txt", "from main\n")
        self.assertTrue(self.job.sync_with_base(self.j))
        merged = self.head()
        self.assertFalse(self.job.sync_with_base(self.j))
        self.assertEqual(self.head(), merged)

    def test_conflict_is_refused_and_leaves_the_branch_untouched(self):
        self.main_moves("a.txt", "main wrote this\n")
        self.write(self.wt, "a.txt", "branch wrote this\n", "branch edits a.txt")
        sh(self.wt, "git", "push", "-q", "origin", "factory/x")
        before, remote_before = self.head(), self.remote_branch()

        with self.assertRaises(self.job.Refused) as ctx:
            self.job.sync_with_base(self.j)

        message = str(ctx.exception)
        self.assertIn("a.txt", message)
        self.assertIn("git merge origin/main", message)
        self.assertIn("no force-push", message)
        self.assertEqual(self.head(), before)
        self.assertEqual(self.remote_branch(), remote_before)
        self.assertEqual(sh(self.wt, "git", "status", "--porcelain"), "")
        still_merging = subprocess.run(
            ["git", "rev-parse", "-q", "--verify", "MERGE_HEAD"], cwd=self.wt, capture_output=True
        )
        self.assertNotEqual(still_merging.returncode, 0, "the aborted merge left MERGE_HEAD behind")

    def test_can_be_turned_off_in_config(self):
        self.job.CONFIG["sync_before_gate"] = False
        before = self.head()
        self.main_moves("c.txt", "from main\n")
        self.assertFalse(self.job.sync_with_base(self.j))
        self.assertEqual(self.head(), before)
        self.assertFalse((self.wt / "c.txt").exists())


if __name__ == "__main__":
    unittest.main()
