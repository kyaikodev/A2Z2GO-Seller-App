# Instructions for AI assistants

1. **Read `PROJECT_CONTEXT.md` before doing anything** (`AGENTS.md` is the same pointer for other AI tools; `SETUP.md` explains a new computer; `notes/INDEX.md` lists the owner's notes). It holds the app's
   purpose, layout, the owner's rules, current state and change history.
2. **Update `PROJECT_CONTEXT.md` before every commit, in the same commit as the change.** Always:
   - add a **Session log** entry (section 5): what the owner asked, what changed (files), why, what was
     learned (the clues) and what is still open. A future session must be able to rebuild the story from it;
   - add a row to the change log (section 8) with the date, commit and what changed;
   - update "Current state" (section 5): test count, audit and checklist tables,
     anything now working or no longer true;
   - update the layout (section 3) if files or folders moved, and section 7 if
     next steps changed.
   Keep it short, factual and current. Fix anything that is no longer true.
   Never put secrets, passwords, emails or personal paths in it.
3. Follow the owner's rules in section 2 (especially: no deployment work yet, ask
   before any force push).
4. Before committing run `flutter analyze` and `flutter test`; both must pass. `flutter test` includes
   `test/project_context_test.dart`, which fails when the `pubspec.yaml` version is not written in
   `PROJECT_CONTEXT.md`: bump the version, write the entry, then commit.
5. **Lessons that cost time before** (see the Session log in `PROJECT_CONTEXT.md`):
   - Never write JavaScript or regex patterns through a shell heredoc or an inline node string: backslashes are
     lost and the whole comment-reader script becomes invalid. Use the Edit/Write tools. A test checks the
     scripts parse (it needs Node).
   - A website looks different at a narrow window. Set the browser pane to 1280 px wide before judging
     Instagram, TikTok or YouTube.
   - Do not send requests that pose as another program or crawler.
6. **After every APK build:** copy it to the Desktop as `A2Z2GO-Seller-v<version>.apk` and replace the old
   APK in the owner's shared Google Drive folder (upload the new one first, then move the old one to the Bin;
   only APK files in that folder; stop the temporary local server afterwards). The method is in the Session
   log. If the browser pane is signed out of Google, ask the owner to sign in themselves.
7. **"Commit push force no old files"** means the owner's standing routine: update the notes, mark the
   change-log rows as squashed, make one fresh orphan commit (nothing from the nested `A2Z2GO-Seller-App/`
   notes folder, no APK or build files) and `git push --force-with-lease origin main`.
8. **Screens must not be taken over by one block.** Fold long text (`ExpandableText`), keep the top of a page to the few things that matter, group the rest into sections, and check every screen at a small phone size with large text. This is the ui-ux-pro-max / TikTok-checklist rule that was missed on the product page.
