# CodeEdit nightly builds

**There is no official CodeEdit nightly.** That's why this repo exists: upstream
([`CodeEditApp/CodeEdit`](https://github.com/CodeEditApp/CodeEdit)) publishes stable and alpha
builds, but nothing tracks `main` — and at commit
[`fa2aebd`](https://github.com/CodeEditApp/CodeEdit/commit/fa2aebd86373211c78626074b53ab75010767575)
it doesn't build or run correctly on macOS 26/27 with Xcode 27.

So this fork builds `main` and fixes what's broken.

**[⬇ Download the latest nightly](https://github.com/neg2sode/CodeEdit/releases/latest)**

| | |
|---|---|
| Version | CodeEdit `0.3.6` (build `47`, `-pre`) from `fa2aebd` |
| Needs | macOS 14.0+ · Apple silicon or Intel |
| Signed | ad-hoc, **not notarized** (see [Security](#security)) |

## Install

One command — downloads, verifies the SHA-256, installs to `/Applications`:

```bash
curl -fsSL https://raw.githubusercontent.com/neg2sode/CodeEdit/main/install-codeedit-nightly.sh | bash
```

Or [download the DMG](https://github.com/neg2sode/CodeEdit/releases/latest), drag CodeEdit to
Applications, then **right-click → Open** the first time. macOS blocks unnotarized apps on
double-click; this is expected.

Verify a manual download:

```bash
shasum -a 256 CodeEdit-0.3.6-pre.47-fa2aebd.dmg
# 8f9293851710f8cde81a2776cb6fe8e7cda86c0e0259f096089f71527b8aec67
```

## What's fixed

| | |
|---|---|
| **Terminal works** | Upstream's App Sandbox breaks it completely: no dotfiles, no tty job control, no `~/.zsh_history`, and `xcrun` refuses to run. Sandbox is off for nightly configs only. |
| **Builds on Swift 6.4** | Ambiguous `.opacity` overload; `@State` assigned before stored properties are initialised. |
| **Icon restored** | Build settings referenced an `AppIconPre` asset that never existed — upstream shipped with no icon. Full 16→1024 px set now generated from its own artwork. |
| **`-pre` version** | Upstream's `Pre` config pointed at `Alpha.xcconfig` (so nightlies were stamped `-alpha`). `Pre.xcconfig` was unused. |
| **About says nightly** | About no longer presents this as upstream CodeEdit — it shows "Unofficial nightly build" linking to the build notes. |

Full details, evidence and diffs: [BUILD-NOTES.md](BUILD-NOTES.md).

## Security

Read this before installing.

- **Unofficial.** Not made or endorsed by the CodeEdit team. Don't report bugs upstream.
- **Not notarized.** No Apple Developer ID, so Gatekeeper warns and Apple hasn't scanned it.
- **Sandbox is off** in this build so the terminal can run a real shell. CodeEdit therefore has
  the same file access as your user account. Official builds keep the sandbox — a terminal cannot
  work with it.
- **All source is public.** Every change is a commit here, so you can audit or build it yourself
  instead of trusting the binary.

```bash
shasum -a 256 CodeEdit-0.3.6-pre.47-fa2aebd.dmg                    # matches release?
codesign -d --entitlements - --xml /Applications/CodeEdit.app | plutil -p -   # no app-sandbox
xcodebuild -scheme CodeEdit -configuration Pre archive              # build it yourself
```

## Build it yourself

```bash
git clone https://github.com/neg2sode/CodeEdit.git && cd CodeEdit
export DISABLE_SWIFTLINT=1   # Xcode 27 + SwiftLint 0.59.1 plugin crash
xcodebuild -scheme CodeEdit -configuration Pre \
  -derivedDataPath ./DerivedData -archivePath ./CodeEdit.xcarchive \
  -skipPackagePluginValidation -skipMacroValidation archive
```

Needs Xcode 27 / Swift 6.4. App lands in `CodeEdit.xcarchive/Products/Applications/CodeEdit.app`.

## Licence

MIT — see [LICENSE.md](LICENSE.md). The editor is the work of the
[CodeEdit contributors](https://github.com/CodeEditApp/CodeEdit/graphs/contributors); this repo
only carries the build fixes. Upstream's own README is kept as
[README-upstream.md](README-upstream.md).
