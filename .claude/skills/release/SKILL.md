---
name: release
description: Use when cutting, checking or shipping a hermes-app release — merging the release-please PR, following the TestFlight and Linux builds, re-running a failed upload for an existing tag, or shipping the latest pre-release to App Review with combined release notes since the release marked Latest. Not for retaking screenshots (store-screenshots).
---

# Release hermes-app

A release goes through three steps, each started by a person:

1. **Cut**: merge the release-please PR. The tag `vX.Y.Z` and a GitHub
   **pre-release** are created, and `release-please.yml` uploads the build to
   TestFlight (iOS and macOS, external group "Public beta") and attaches the Linux
   tar.gz and .deb (x86_64, arm64).
2. **Test**: testers use the TestFlight build.
3. **Ship**: promote the pre-release to a full release. `app-store.yml` then
   submits that version's TestFlight build to App Review on iOS and macOS. It does
   not rebuild. `automatic_release: true` in the `submit` lane makes an approved
   version go live without further action.

Merging the release PR and promoting a release are outward steps. Do them only
when the user asks for that release.

## Cut a release

```bash
gh pr list --label "autorelease: pending" --json number,title,headRefName
gh pr view <n> --json mergeStateStatus,statusCheckRollup
```

The version and `CHANGELOG.md` come from Conventional Commits on `main`
(`release-please-config.json`; only `feat`, `fix`, `perf`, `revert` and `docs`
appear in the changelog). Don't edit `pubspec.yaml`'s version, the manifest or the
changelog by hand. A pre-release keeps release-please's generated body. The
notes are rewritten when the release ships (see below). TestFlight and App
Store "What's New" are both read from that body (`scripts/plain_release_notes.py`
removes the Markdown and cuts the text to 4000 characters).

Merge the PR when `Analyze & test` is green. The PR is opened with
`RELEASE_PLEASE_TOKEN`, a PAT, so CI runs on it. If CI did not run, the token is
missing or expired.

## Follow the builds

```bash
gh run list --workflow release-please.yml --limit 3
gh run watch <run-id>
gh release view vX.Y.Z --json assets --jq '.assets[].name'
```

The run after a release merge takes about 15 minutes. A normal push to `main` runs
only the release-please job and takes about 20 seconds. The build number is the
commit count at the tag (`git rev-list --count HEAD`), so a rebuild of the same tag
gets the same number.

If an upload failed, rebuild one part of an existing tag without cutting a new one:

```bash
gh workflow run release-please.yml -f tag=vX.Y.Z -f only=testflight   # or linux, or all
```

The `flutter-ci` skill covers diagnosing a failed job.

## Ship to the App Store

Ship the newest **pre-release** unless the user names a different tag. The notes
cover everything since the release GitHub marks **Latest**. That is the last one
that went to the store, because a pre-release is never marked Latest. Store users
have seen none of the pre-releases since.

```bash
gh release view --json tagName --jq .tagName      # Latest: the baseline
gh release list --limit 20 --json tagName,isPrerelease --jq '[.[]|select(.isPrerelease)][0].tagName'   # newest pre-release: the target
```

1. Read every release body from the one after Latest up to the
   target, for example with `gh release view <tag> --json body --jq .body`.
   `git log --oneline <last-full>..<target>` fills gaps.
2. Write the combined notes with the `oss:release-notes` skill. App Store and
   TestFlight show plain text and stop at 4000 characters, so keep it well under
   that. Show the user the draft before you publish it.
3. Replace the target release's body:
   `gh release edit <target> --notes-file <file>`. Do this before you promote:
   `app-store.yml` reads "What's New" from the body when it runs.
4. Promote it. The `released` event starts `app-store.yml`:

```bash
gh release edit <target> --prerelease=false --latest
gh run list --workflow app-store.yml --limit 3
```

- The job waits up to 60 minutes for the TestFlight build to finish processing. If
  that build never uploaded, rebuild it first (see above).
- A version that is already in review or released is skipped. Promoting a version
  you submitted by hand is safe.
- A newer submission replaces an older version still waiting for review
  (`reject_if_possible`). The workflow's `concurrency` group keeps two submissions
  from running at the same time.
- Submission needs the `ASC_*`, `REVIEW_CONTACT_*` and `REVIEW_DEMO_*` secrets. The
  demo server must be up for App Review to sign in.

To update the listing and notes without submitting, run the workflow by hand.
`dry_run` defaults to true:

```bash
gh workflow run app-store.yml -f tag=vX.Y.Z               # dry run
gh workflow run app-store.yml -f tag=vX.Y.Z -f dry_run=false
```

Listing text lives in `fastlane/metadata/`. Screenshots are uploaded separately
(the `store-screenshots` skill).

## Where things are

- `.github/workflows/release-please.yml`: release PR, TestFlight, Linux.
- `.github/workflows/app-store.yml`: App Review submission.
- `fastlane/Fastfile`: lanes `ios release`, `mac release`, `submit`, `sync_metadata`.
- `release-please-config.json`, `.release-please-manifest.json`.
