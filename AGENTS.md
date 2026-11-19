# Start here (any AI assistant)

This file is for AI tools that look for `AGENTS.md` (Codex, Cursor, Gemini and others).
Claude Code reads `CLAUDE.md`, which says the same thing.

1. **Read `PROJECT_CONTEXT.md` first.** It explains the app, the owner's rules, the current state,
   what changed and why, and what is still open.
2. **Read `REVIEW.md`** for the full list of known problems and how each was handled.
3. **To set up a computer, read `SETUP.md`.**
4. **Update `PROJECT_CONTEXT.md` before every commit, in the same commit as the change**: a Session log
   entry (what was asked, what changed, why, the clues, what is open), a change-log row, and "Current state".
   Run `flutter analyze` and `flutter test` before committing; a test fails if the `pubspec.yaml` version is
   not written in `PROJECT_CONTEXT.md`.
5. **Follow the owner's rules** in section 2 of `PROJECT_CONTEXT.md`. Most important: no deployment
   work yet (no release signing, store listing or privacy policy), bump the version for every APK
   build, and ask before a force push unless the owner says "commit push force no old files" (their standing
   routine: one fresh commit with no history, `--force-with-lease`, the nested `A2Z2GO-Seller-App/` notes
   folder never committed). Every new APK also goes to the owner's shared Google Drive folder (see the
   session log in `PROJECT_CONTEXT.md`).
6. **Hard-won lessons** (details in the session log): never write JavaScript or regex patterns through a
   shell heredoc (backslashes get lost, a whole reader script broke once); judge a website only with the
   browser pane at 1280 px wide; never send requests that pose as another program.

Never put secrets, passwords, emails or personal file paths in these files.
