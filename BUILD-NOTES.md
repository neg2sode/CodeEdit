# Build notes — how this nightly was produced

**Status:** ✅ Build, sign (ad-hoc), package and launch verified. Integrated-terminal sandbox
defects and the missing app icon fixed and verified.

| | |
|---|---|
| Upstream | https://github.com/CodeEditApp/CodeEdit |
| Commit | `fa2aebd86373211c78626074b53ab75010767575` (`fa2aebd`) |
| Commit date | 2026-08-18 · *"macOS Tahoe Navigator, Inspector, and Utility Area (#2126)"* |
| Build config | `Pre` (CodeEdit's pre-release / nightly configuration) |
| Version | `0.3.6` (build `47`, postfix `-pre`) |
| Bundle ID | `app.codeedit.CodeEdit` |
| Deployment target | macOS 14.0 |
| Architectures | `arm64` + `x86_64` (universal) |
| Toolchain | Xcode 27.0 (27A266a) · Swift 6.4 · macOS 27.2 (26B5101f) |
| Signature | ad-hoc (`Signature=adhoc`), hardened runtime, **not notarized** |
| DMG SHA-256 | `8f9293851710f8cde81a2776cb6fe8e7cda86c0e0259f096089f71527b8aec67` |

## Where the artifact lives

The disk image is published on the [releases page](https://github.com/neg2sode/CodeEdit/releases).
The DMG is 33 MB and contains `CodeEdit.app`; the SHA-256 above is the value the installer script
verifies before installing. `CodeEdit.xcarchive` (including 4 dSYMs) is kept locally by whoever
builds it and is not committed to this repository.

## How it was built

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer   # xcode-select points at CommandLineTools
export DISABLE_SWIFTLINT=1   # Xcode 27 + SwiftLint 0.59.1 plugin crash; see issue 6

xcodebuild -scheme CodeEdit -configuration Pre \
  -derivedDataPath ./DerivedData \
  -archivePath ./CodeEdit.xcarchive \
  -skipPackagePluginValidation -skipMacroValidation \
  archive
```

No `CE_VERSION_POSTFIX` override is needed any more: fixing issue 4 below made the `Pre`
configuration read `Pre.xcconfig`, so `-pre` and `AppIconPre` now come from that one file as
intended.

## Problems fixed

### 1. Integrated terminal was unusable (the reported bug)

The screenshot showed four distinct failures, all with a single root cause — the App Sandbox
(`CodeEdit/CodeEdit.entitlements` declared `com.apple.security.app-sandbox`):

```
zsh: operation not permitted: ~/.zprofile
zsh: operation not permitted: ~/.zshrc
zsh: locking failed for ~/.zsh_history: operation not permitted; reading anyway
zsh: can't set tty pgrp: operation not permitted
xcrun: error: cannot be used within an App Sandbox.
```

A terminal emulator runs an arbitrary interactive login shell, which the sandbox fundamentally
cannot support: the shell cannot read the user's dotfiles, cannot `setpgid()` for job control,
cannot lock its history file, and **every** process it spawns inherits the sandbox (`xcrun`
refuses outright because it cannot read `/var/db/xcode_select_link`).

**Fix.** The `Pre` (nightly) configuration now signs with a new
`CodeEdit/CodeEdit-nightly.entitlements` that omits the sandbox, and the `Pre` build
configuration sets `ENABLE_APP_SANDBOX = NO` (that setting injects the entitlement
independently of the file, and its project-level value overrides xcconfig — hence it is set
directly in the project). `Alpha`, `Beta`, `Release` and `Debug` are untouched and remain
sandboxed, as they ship to the App Store / are notarized. `OpenWithCodeEdit.appex` is untouched
too: note it never declared `com.apple.security.app-sandbox` upstream (its entitlements file
carries only `application-groups`), so this change does not affect it either way.

**Verification (direct, OS-level).** `sandbox_check(2)` was called against the running app for
exactly the paths from the screenshot, with the method validated first against a known-sandboxed
process (`Notes` → denied) and a known-unsandboxed one (→ allowed):

| Path | Before | After (this build) |
|---|---|---|
| `~/.zprofile` | DENIED | **allowed** |
| `~/.zshrc` | DENIED | **allowed** |
| `~/.zsh_history` | DENIED | **allowed** |
| `/usr/bin/xcrun` | DENIED | **allowed** |

The app's entitlements went from
`{app-sandbox, application-groups, bookmarks, files.user-selected, network.client, allow-jit, disable-library-validation}`
to `{files.user-selected.read-write, network.client, allow-jit, disable-library-validation}`.
CodeEdit's real shell-integration scripts were also exercised with `zsh -l -i` and a
`ZDOTDIR`/`USER_ZDOTDIR` pair mirroring the app's own setup: the shell starts clean, sources
dotfiles and exits 0.

### 2. Two genuine Swift 6.4 / macOS 27 SDK compile errors

The project does not compile as-is under Swift 6.4. Both fixes preserve behaviour exactly:

* **`CodeEdit/Features/Editor/TabBar/Tabs/Views/EditorTabsOverflowShadow.swift:38`** —
  `error: ambiguous use of 'opacity'`. A nested ternary passed directly to `.opacity(...)` is no
  longer resolvable. Extracted into an explicitly-typed `private var shadowOpacity: Double`.

* **`CodeEdit/Features/CodeEditUI/Views/KeyValueTable.swift:40`** —
  `error: variable 'self.keyColumnName' used before being initialized`. The initialiser assigned
  `self.key`/`self.value` (both `@State`) *before* the plain stored properties. For a `@State`
  property that assignment is a no-op, and Swift 6.4 rejects it as a use of `self` pre-init.
  Switched to the canonical backing-storage form `_key = State(initialValue:)`.

### 3. Codesigning failed: `resource fork, Finder information, or similar detritus not allowed`

`~/Documents` is managed by the **iCloud Drive file provider (FPFS)**, which continuously
re-applies `com.apple.FinderInfo` / `com.apple.fileprovider.fpfs#P` xattrs to build products, and
`codesign` rejects any bundle carrying `com.apple.FinderInfo`. The build tree was therefore
relocated outside the iCloud-managed directory, and
the DMG build runs `xattr -cr` on the staged bundle before creating the image.

### 4. Upstream bug: the `Pre` configuration referenced `Alpha.xcconfig`

In `CodeEdit.xcodeproj/project.pbxproj` every `Pre` build configuration was wired to
**`Alpha.xcconfig`**; the string `Pre.xcconfig` appeared nowhere in the project, so
`Configs/Pre.xcconfig` was dead code. Consequences: the `Pre` config inherited Alpha's
`CE_VERSION_POSTFIX`, stamping the nightly `0.3.6-alpha`. **The project's own CI nightly is
affected by this.**

All five `Pre` configurations now reference `Pre.xcconfig`, so the `-pre` stamp and the nightly
entitlements come from the correct file (this also removed the need for the
`CE_VERSION_POSTFIX=-pre` command-line override used in the first build).
The repository owner may want to apply this upstream.

> The app icon was initially assumed to be part of this. It is a **separate** defect — see
> issue 5. The `Pre` config did resolve `CE_APPICON_NAME = AppIconPre` correctly; the asset it
> names simply did not exist.

### 5. App icon was completely empty

The built app had **no icon at all**: no `CFBundleIconName`, no `CFBundleIconFile`, no `.icns`
in `Contents/Resources`, and no `AppIconPre` image in `Assets.car`.

Root cause: `ASSETCATALOG_COMPILER_APPICON_NAME = AppIconPre` points at an asset-catalog entry
that does not exist. `CodeEdit/Assets.xcassets` contained only `AccentColor`, `Icons` and a few
imagesets. The repository does ship the artwork, but only as **Icon Composer bundles** at
`ProductIcons/CodeEdit*Icon.icon` — modern macOS 26+ layered-icon bundles referenced by nothing
in the project, and therefore never compiled into the app.

`actool` will not rasterize a loose `.icon` bundle from the command line (it silently emits just
an empty partial plist) and `qlmanage` hangs on one, so the artwork had to be composed
explicitly. `render-appicon.py` does that: it reads
`ProductIcons/CodeEditPreIcon.icon/icon.json`, applies the squircle fill gradient, composites the
code-line texture, the 3D pen and the `PRE` pill from the bundle's own SVG/PNG assets, and emits a
1024×1024 master. A standard macOS `AppIconPre.appiconset` (16→1024, including the 1024 marketing
icon) was generated from it into `CodeEdit/Assets.xcassets`.

`actool` now emits `AppIconPre.icns` plus the catalog entry and injects
`CFBundleIconName`/`CFBundleIconFile = AppIconPre`.

**Verification:** the built bundle reports `CFBundleIconName = AppIconPre`, ships
`AppIconPre.icns` (49 KB) and `AppIconPre` in `Assets.car`, and the catalog carries every size
from 16×16 to 1024×1024. `NSWorkspace.icon(forFile:)` — the same LaunchServices path Finder uses —
returns the icon with 32 representations, and rendering it shows the blue squircle with the pen
and `PRE` badge rather than a generic document placeholder.

This is a **nightly-only** addition: `Alpha`/`Beta`/`Release` reference an `AppIcon` set that is
also absent from this repository, and were deliberately left alone.

### 6. SwiftLint build-tool plugin crashed the build (worked around, not patched)

All 9 `Apply build tool plug-in "SwiftLint"` invocations aborted with:

```
SourceKittenFramework/library_wrapper.swift:58: Fatal error:
Loading sourcekitdInProc.framework/Versions/A/sourcekitdInProc failed
```

SwiftLint 0.59.1's SourceKitten locates `sourcekitdInProc.framework` relative to
`TOOLCHAIN_DIR`, which Xcode 27 does not export to build-tool plugin processes; the plugin fell
back to the **Command Line Tools** toolchain, whose `sourcekitd` is ABI-incompatible →
`SIGTRAP`. Neither `TOOLCHAIN_DIR` nor `DYLD_FRAMEWORK_PATH` survives into Xcode's sandboxed
plugin environment, even as build settings.

The plugin ships a documented opt-out that it honours before building any command
(`SwiftLintPlugin/Plugins/SwiftLint/main.swift:32`, `DISABLE_SWIFTLINT`), so
`DISABLE_SWIFTLINT=1` was used. Linting is diagnostics-only and has **no effect on the shipped
binary**; upstream CI runs it separately via `.github/workflows/lint.yml`.

### 7. About window presented the fork as upstream CodeEdit

The About window showed only "Version 0.3.6-pre (47)" and a footer linking to
`CodeEditApp/CodeEdit` — with no indication that this is an unofficial fork running a nightly.
Anyone hitting a bug would reasonably have reported it upstream.

A `CE_BUILD_IDENTITY` / `CE_BUILD_IDENTITY_URL` pair is now set in `Configs/Pre.xcconfig` only
(empty in `Alpha`/`Beta`/`Release`, so official builds are unchanged and simply omit the line).
The About footer renders:

```
Unofficial nightly build · MIT License
Copyright © 2022-2025 CodeEdit
```

with the first entry linking to these build notes. The upstream copyright and licence stay
untouched — this only adds provenance.

Implementation note: a URL cannot be written literally in an xcconfig, because `//` starts a
comment. The scheme separator is assembled from a variable (`CE_SLASHES = /`) so the value
resolves to a full `https://…` URL.

## Verification performed

* `** ARCHIVE SUCCEEDED **`, exit code 0 (full transcript in `logs/archive-unsandboxed.log`).
* Entitlements asserted on both the archived app and the app inside the mounted DMG
  (no `app-sandbox`); `OpenWithCodeEdit.appex` confirmed untouched.
* `codesign --verify --deep --strict` → OK, in the archive and inside the DMG.
* Info.plist assertions: `app.codeedit.CodeEdit`, version `0.3.6`, build `47`,
  `CE_VERSION_POSTFIX = -pre`, minimum system `14.0`.
* Universal binary confirmed via `lipo -info` (x86_64 + arm64).
* All 4 dSYMs generated (`CodeEdit.app`, `CodeEditKit`, `OpenWithCodeEdit`, `Sparkle`).
* Bundled payload present: `CodeEditKit.framework`, `CodeLanguages_Container.framework`,
  `Sparkle.framework`, `OpenWithCodeEdit.appex`.
* DMG mounts, contains `CodeEdit.app` + `/Applications` drop link + background image, `UDZO`
  compressed; the app launches and stays alive from inside it.
* `sandbox_check` matrix and shell-integration test as described in issue 1.
* App icon: `CFBundleIconName = AppIconPre`; `AppIconPre.icns` present; `AppIconPre` in
  `Assets.car` at 16→1024 px; `NSWorkspace.icon(forFile:)` returns the real icon (32
  representations), rendered and visually confirmed (issue 5).

## Caveats

* **Not signed with an Apple Developer ID and not notarized.** Those CI steps require secrets
  private to the CodeEdit organisation (`DEV_CERT`, `MAC_CERT`, `CODESIGN_SIGN`, `APPLE_ID`,
  `APPLE_TEAM_ID`, `SPARKLE_KEY`), so the app is ad-hoc signed and `spctl` rejects it. To run:
  right-click → **Open**, or
  `xattr -dr com.apple.quarantine /Applications/CodeEdit.app`.
* **The nightly build is not sandboxed.** That is the deliberate cost of a working terminal;
  once the App Sandbox is removed, `com.apple.security.application-groups` and app-scope
  bookmarks are dropped as well, since they are sandbox constructs and would be invalid without
  a team ID. The sandboxed shipping configurations are unaffected.
* **No Sparkle appcast** was generated (needs the private `SPARKLE_KEY`). The app's `SUFeedURL`
  still points at the official CodeEdit release feed, so it will not auto-update from this
  nightly.
* The SwiftLint diagnostics pass did **not** run (issue 6) and the test suite
  (`.github/workflows/tests.yml`) was **not** run — this build was not gated on it.
* Only `--depth 1` history was fetched, so this is a snapshot of `main` at `fa2aebd`.
