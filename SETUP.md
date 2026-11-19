# Setting up a new computer

Everything about the project is in this repository. Clone it, install the tools below, and read
`PROJECT_CONTEXT.md`. Nothing else is needed. Windows 11 is what this was built on; paths use
`%LOCALAPPDATA%` so they work for any user.

## 1. Get the project

```
git config --global core.longpaths true
git clone https://github.com/kyaikodev/A2Z2GO-Seller-App
cd A2Z2GO-Seller-App
```

## 2. Install the tools (per-user installs need no admin rights)

| Tool | Version used | Notes |
|------|--------------|-------|
| Flutter | 3.47.x stable (Dart 3.13) | Clone `https://github.com/flutter/flutter.git -b stable` to `%LOCALAPPDATA%\Programs\flutter`, add `bin` to PATH |
| JDK | 17 (Temurin) | Needed for Android builds. JDK 25 crashes the Android tools on the machine this was built on |
| Android SDK | platform 36, build-tools 36.0.0, NDK 28.2.13676358, CMake 3.22.1 | Install the command-line tools from Google, accept the licenses, then `sdkmanager` the packages. Quote names that contain `;` |
| Node.js | LTS | For the Claude hooks in `.claude/`, and for `test/grab_script_syntax_test.dart` (it asks Node to check the comment-reader scripts; the test is skipped when Node is missing) |
| Git | any recent | |

Then point Flutter at them:

```
flutter config --android-sdk %LOCALAPPDATA%\Android\Sdk --jdk-dir %LOCALAPPDATA%\Programs\jdk17
flutter pub get
```

## 3. Check it works

```
flutter analyze        # No issues found
flutter test           # every test passes (see PROJECT_CONTEXT.md for the count)
```

## 4. Build a test APK

Before every build, raise `version:` in `pubspec.yaml` (for example `1.0.2+3` then `1.0.3+4`).

If Java tools fail with "Unable to establish loopback connection", set these first (and create
`C:\jtmp`):

```
set JAVA_HOME=%LOCALAPPDATA%\Programs\jdk17
set JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=C:\jtmp -Djava.io.tmpdir=C:\jtmp
set ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk
flutter build apk --release
```

The APK is `build\app\outputs\flutter-apk\app-release.apk`. It is signed with the debug key, so it
is for testing only. Copy it to the Desktop as `A2Z2GO-Seller-v<version>.apk`. APKs are never
committed.

## 5. What lives outside this repository

- **Built APKs** on the Desktop (rebuild them any time) and the owner's shared Google Drive folder "A2Z2GO"
  (it holds only the newest APK). Google Drive for Desktop could not be installed on the work PC (installer
  error 1603, needs admin rights), so the upload is done in the Claude desktop app's browser pane, signed in to
  Google by the owner: a temporary local server on 127.0.0.1 serves the APK and the Drive page takes it as a
  drag-and-drop. The full routine is in the Session log of `PROJECT_CONTEXT.md`.
- **Your Claude/AI app settings and memory** (they belong to the app, not the project).
- **Obsidian settings** (`.obsidian/` is ignored by git).
- **Test data** on your phone (use Me > Back up my data in the app to move a shop to another phone;
  photos are not included).

## 6. Working with an AI

Tell it: "Read `PROJECT_CONTEXT.md` first." Claude Code does this on its own through `CLAUDE.md`;
other tools find `AGENTS.md`. The AI skills and hooks used so far are in `.claude/` and come with
the repository.

## 7. Using Obsidian

Open the project folder itself as an Obsidian vault. `PROJECT_CONTEXT.md`, `REVIEW.md`, `SETUP.md`,
`AGENTS.md` and everything in `notes/` show up as notes, and `review/screens/` shows the screenshots.
Put your own ideas and decisions in `notes/`, and add a line for each to `notes/INDEX.md`.
