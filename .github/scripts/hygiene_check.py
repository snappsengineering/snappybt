#!/usr/bin/env python3
"""Hygiene check: block things that should never reach a remote.

Modes:
  staged                 added lines in the staged diff (+ author identity warning)
  message FILE           a commit message file
  range REV_LIST_ARGS... every commit message, author email and added line in a rev-list range
  tree [PATH]            every tracked file under PATH (default: repo root)
  history                every commit reachable from HEAD

Rules: generic patterns (below) plus an optional private denylist, kept OUTSIDE any repo:
  $HYGIENE_DENYLIST or ~/.config/hygiene_check/denylist.txt   (one regex per line, # comments)

Repo opt-outs live in `.hygiene-allow` at the repo root (legacy `.hygiene-allow` still read):
  <path glob>        skip all checks for matching paths
  rule:<name>        disable a rule for this repo (e.g. rule:denylist)
Untracked alternative for private opt-out: `git config hygiene_check.denylist false` (local config).

Output never prints the matched text, only `path:line [rule]`, so reports are safe to share.
Set HYGIENE_SKIP=1 to bypass (hooks only). Exit 1 on any finding.
"""
import fnmatch
import os
import re
import subprocess
import sys

NOREPLY = re.compile(r"@users\.noreply\.github\.com$|^noreply@github\.com$", re.I)
# Dependabot / GitHub Actions use [bot]@github.com, which is not a personal address.
BOT_EMAIL = re.compile(r"\[bot\]@|dependabot|github-actions\[bot\]", re.I)
SAFE_EMAIL_DOMAINS = ("example.com", "example.org", "example.net", "localhost", "users.noreply.github.com")

GENERIC = [
    ("email", re.compile(r"[A-Za-z0-9._%+-]+@([A-Za-z0-9-]+\.)+[A-Za-z]{2,}")),
    ("local-path", re.compile(r"/Users/[A-Za-z0-9._-]+/|/home/[A-Za-z0-9._-]+/")),
    ("home-ref", re.compile(r"~/\.cursor|~/Documents/")),
    ("cursor-attribution", re.compile(r"Co-authored-by:.*cursor|Made with Cursor|cursoragent", re.I)),
    ("secret", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----|ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}")),
    ("plan-link", re.compile(r"\.cursor/plans")),
]
FILE_RULES = [("funding-file", lambda p: os.path.basename(p).upper() == "FUNDING.YML")]
SELF_NAMES = ("hygiene_check.py", "hygiene_check.sh", "hygiene_check_test.sh")


def run(*args, cwd=None):
    r = subprocess.run(args, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True,
                       errors="replace")
    return r.stdout


def repo_root():
    out = run("git", "rev-parse", "--show-toplevel").strip()
    if not out:
        sys.exit("hygiene_check: not in a git repository")
    return out


def load_allow(root):
    paths, rules = [], set()
    for name in (".hygiene-allow", ".hygiene-allow"):
        try:
            for line in open(os.path.join(root, name), encoding="utf-8"):
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if line.startswith("rule:"):
                    rules.add(line[5:].strip())
                else:
                    paths.append(line)
        except OSError:
            pass
    return paths, rules


def load_denylist():
    legacy = os.path.expanduser("~/.config/hygiene/denylist.txt")
    default = os.path.expanduser("~/.config/hygiene_check/denylist.txt")
    path = os.environ.get("HYGIENE_DENYLIST") or os.environ.get("HYGIENE_DENYLIST")
    if not path:
        path = default if os.path.isfile(default) else legacy
    pats = []
    try:
        for line in open(path, encoding="utf-8"):
            line = line.strip()
            if line and not line.startswith("#"):
                pats.append(re.compile(line, re.I))
    except OSError:
        pass
    return pats


class Checker:
    def __init__(self, root):
        self.root = root
        self.allow_paths, self.disabled = load_allow(root)
        off = (
            run("git", "config", "--bool", "hygiene_check.denylist").strip() == "false"
            or run("git", "config", "--bool", "hygiene.denylist").strip() == "false"
        )
        self.deny = [] if ("denylist" in self.disabled or off) else load_denylist()
        self.findings = []  # (where, line, rule)

    def path_allowed(self, path):
        base = os.path.basename(path)
        if base in SELF_NAMES or base in (".hygiene-allow", ".hygiene-allow"):
            return True
        return any(fnmatch.fnmatch(path, g) or fnmatch.fnmatch(base, g) for g in self.allow_paths)

    def add(self, where, line, rule):
        if rule not in self.disabled:
            self.findings.append((where, line, rule))

    def check_text(self, text, where, line=0, is_message=False):
        for rule, pat in GENERIC:
            for m in pat.finditer(text):
                if rule == "email" and m.group(0).lower().endswith(SAFE_EMAIL_DOMAINS):
                    continue
                self.add(where, line, rule)
                break
        for pat in self.deny:
            if pat.search(text):
                self.add(where, line, "denylist")
                break

    def check_path(self, path):
        for rule, fn in FILE_RULES:
            if fn(path):
                self.add(path, 0, rule)

    def check_identity(self, label, email):
        if not email or NOREPLY.search(email) or BOT_EMAIL.search(email):
            return
        self.add(label, 0, "identity-email")

    def check_diff(self, diff_text, prefix=""):
        path, lineno = None, 0
        for raw in diff_text.splitlines():
            if raw.startswith("+++ "):
                path = raw[6:] if raw.startswith("+++ b/") else None
                if path:
                    self.check_path(path)
            elif raw.startswith("@@"):
                m = re.search(r"\+(\d+)", raw)
                lineno = int(m.group(1)) - 1 if m else 0
            elif raw.startswith("+") and not raw.startswith("+++"):
                lineno += 1
                if path and not self.path_allowed(path):
                    self.check_text(raw[1:], prefix + path, lineno)
            elif raw.startswith(" "):
                lineno += 1

    def report(self):
        if not self.findings:
            return 0
        seen = set()
        print("hygiene_check: blocked (matched text is not printed)")
        for where, line, rule in self.findings:
            key = (where, line, rule)
            if key in seen:
                continue
            seen.add(key)
            print("  %s%s [%s]" % (where, (":%d" % line) if line else "", rule))
        print("Fix, or add an opt-out to .hygiene-allow. Bypass once: HYGIENE_SKIP=1")
        return 1


def commit_checks(chk, sha, label=None):
    label = label or sha[:8]
    ident = run("git", "log", "-1", "--format=%ae%n%ce", sha).split("\n")
    if any(BOT_EMAIL.search(e.strip()) for e in ident[:2] if e.strip()):
        chk.check_diff(run("git", "show", "-U0", "--format=", "--no-color", sha), "%s: " % label)
        return
    msg = run("git", "log", "-1", "--format=%B", sha)
    chk.check_text(msg, "commit %s message" % label, 0, True)
    for e in ident[:2]:
        chk.check_identity("commit %s author/committer" % label, e.strip())
    chk.check_diff(run("git", "show", "-U0", "--format=", "--no-color", sha), "%s: " % label)


def main(argv):
    if os.environ.get("HYGIENE_SKIP") == "1" or os.environ.get("HYGIENE_SKIP") == "1":
        if argv and argv[0] in ("staged", "message", "range"):
            return 0
        return 0
    if not argv:
        print(__doc__)
        return 2
    mode, rest = argv[0], argv[1:]
    root = repo_root()
    os.chdir(root)
    chk = Checker(root)

    if mode == "staged":
        chk.check_diff(run("git", "diff", "--cached", "-U0", "--no-color", "--diff-filter=ACMR"))
        email = run("git", "config", "user.email").strip()
        if email and not NOREPLY.search(email):
            print("hygiene_check: warning: git user.email is not a noreply address")
    elif mode == "message":
        chk.check_text(open(rest[0], encoding="utf-8", errors="replace").read(), "commit message", 0, True)
    elif mode == "range":
        for sha in run("git", "rev-list", "--reverse", *rest).split():
            commit_checks(chk, sha)
    elif mode == "history":
        for sha in run("git", "rev-list", "--reverse", "HEAD").split():
            commit_checks(chk, sha)
    elif mode == "tree":
        base = rest[0] if rest else "."
        for path in run("git", "ls-files", "-z", "--", base).split("\0"):
            if not path or chk.path_allowed(path) or not os.path.isfile(path):
                continue
            chk.check_path(path)
            try:
                text = open(path, encoding="utf-8").read()
            except (UnicodeDecodeError, OSError):
                continue  # binary
            for i, line in enumerate(text.splitlines(), 1):
                chk.check_text(line, path, i)
    else:
        print(__doc__)
        return 2
    return chk.report()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
