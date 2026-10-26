# CodeEdit — Nightly builds

A working **nightly build** of [CodeEdit](https://github.com/CodeEditApp/CodeEdit), the open-source
macOS code editor, plus the fixes needed to make it build and run on current macOS.

This is a **fork** of [`CodeEditApp/CodeEdit`](https://github.com/CodeEditApp/CodeEdit) at
[`fa2aebd`](https://github.com/CodeEditApp/CodeEdit/commit/fa2aebd86373211c78626074b53ab75010767575).
Upstream is unchanged — problem reports and pull requests for the editor itself belong there.

| | |
|---|---|
| **Download** | **[CodeEdit-0.3.6-pre.47-fa2aebd.dmg](https://github.com/neg2sode/CodeEdit/releases/latest)** |
| Version | CodeEdit `0.3.6` (build `47`, nightly `-pre`) |
| Requirements | macOS 14.0 or later · Apple silicon or Intel |
| Signature | ad-hoc signed, **not notarized** — see [Security](#security-what-you-should-know) |

---

## Install

**Option 1 — one command (recommended)**

```bash
curl -fsSL https://raw.githubusercontent.com/neg2sode/CodeEdit/main/install-codeedit-nightly.sh | bash
```

It downloads the disk image, **verifies the SHA-256 before installing anything**, copies CodeEdit
to `/Applications`, and clears the quarantine flag. Read it first if you like — it's
[one small shell script](install-codeedit-nightly.sh).

**Option 2 — by hand**

1. Download the [latest DMG](https://github.com/neg2sode/CodeEdit/releases/latest).
2. Open it and drag **CodeEdit** into **Applications**.
3. Launch it. macOS will warn that the developer cannot be verified, because the build is not
   notarized:

   > **Right-click → Open** (not double-click), then confirm **Open** once. This is only needed
   > the first time. Alternatively: `xattr -dr com.apple.quarantine /Applications/CodeEdit.app`

**Verify your download** (optional but a good habit):

```bash
shasum -a 256 CodeEdit-0.3.6-pre.47-fa2aebd.dmg
# ec8148b9f77140454e2967971f72f295e37218174efdfef1cb7ac6f1a6c358ba
```

---

## What's fixed in this build

Upstream does not build or run correctly out of the box on macOS 26/27 with Xcode 27. Five
defects were fixed; each is documented in
[BUILD-NOTES.md](BUILD-NOTES.md) with the evidence.

1. **The integrated terminal was unusable** — `zsh` could not read `~/.zprofile`, could not set a
   tty process group, could not lock `~/.zsh_history`, and `xcrun` refused to run at all. Cause:
   the App Sandbox. This nightly disables the sandbox **for the nightly configuration only**;
   `Alpha`/`Beta`/`Release` remain sandboxed.
2. **Two Swift 6.4 compile errors** — an ambiguous `.opacity` overload and a `@State`
   assignment in an initialiser that Swift 6.4 rejects.
3. **The app icon was completely empty** — `AppIconPre` was referenced by the build settings but
   never existed in the asset catalog; the artwork only shipped as unreferenced Icon Composer
   bundles. A real macOS iconset (16→1024 px) was generated from the project's own artwork.
4. **The `Pre` configuration referenced `Alpha.xcconfig`** (upstream bug), so the nightly was
   stamped `-alpha`. `Pre.xcconfig` was dead code and is now used.

A full build report — toolchain, verification steps, exact diffs — is in
[BUILD-NOTES.md](BUILD-NOTES.md), and the source changes are the commits on this branch.

---

## Security: what you should know

This build is **not** from the CodeEdit team and is **not** signed with a paid Apple Developer ID,
so macOS cannot verify its provenance for you. That is the honest trade-off:

* **No notarization.** Apple has not scanned this binary. Gatekeeper will warn; the instructions
  above get past the warning.
* **The App Sandbox is disabled** in this nightly so the terminal can run a real shell. A sandboxed
  terminal cannot work at all, but it does mean CodeEdit has the same filesystem access as your
  user account. Upstream's shipping builds keep the sandbox.
* **Everything is public and reproducible.** The source, the entitlements file and the exact
  compiler invocation are all in this repository — see [BUILD-NOTES.md](BUILD-NOTES.md). You can
  build it yourself with `xcodebuild` rather than trusting my binary.

### Verify it yourself, end to end

```bash
# 1. The download matches the published checksum
shasum -a 256 CodeEdit-0.3.6-pre.47-fa2aebd.dmg

# 2. What is it signed with?
codesign -dv --verbose=2 /Applications/CodeEdit.app

# 3. Which entitlements does it request? (no app-sandbox in this nightly)
codesign -d --entitlements - --xml /Applications/CodeEdit.app | plutil -p -

# 4. Or build it from this source
xcodebuild -scheme CodeEdit -configuration Pre archive
```

If any of that looks wrong to you, don't install it — build it instead.

---

## Build it yourself

```bash
git clone https://github.com/neg2sode/CodeEdit.git
cd CodeEdit

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer  # if xcode-select points at CommandLineTools
export DISABLE_SWIFTLINT=1   # Xcode 27 + SwiftLint 0.59.1 plugin crash; see BUILD-NOTES.md

xcodebuild -scheme CodeEdit -configuration Pre \
  -derivedDataPath ./DerivedData \
  -archivePath ./CodeEdit.xcarchive \
  -skipPackagePluginValidation -skipMacroValidation archive
```

Requires Xcode 27 / Swift 6.4. The app lands in
`CodeEdit.xcarchive/Products/Applications/CodeEdit.app`.

---

## Licence

CodeEdit is MIT licensed — see [LICENSE.md](LICENSE.md). This fork keeps the same licence and
credit: the editor, its artwork and its design are the work of the
[CodeEdit contributors](https://github.com/CodeEditApp/CodeEdit/graphs/contributors).
