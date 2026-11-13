# Notes

Your own ideas, decisions and things learned. Add a line here for each new note so any AI (or you,
on a new computer) can find it. Keep personal or private things out of this folder: it is saved to
GitHub with the project.

## Start here
- [[../PROJECT_CONTEXT]]: what the app is, the rules, the current state and every change
- [[../REVIEW]]: full inspection, 27 findings and how each was handled
- [[../SETUP]]: how to set up a new computer
- [[../AGENTS]]: the short "read this first" for any AI tool

## Decisions
- No deployment work yet (signing, store listing, privacy policy) until the owner says so
- Every APK build gets a new version
- Keep one source of truth: `PROJECT_CONTEXT.md`. Do not copy its facts into other notes

## Ideas
- Buyers commenting on a product: needs a server, a name or sign-in, moderation and spam limits; the
  "buyers send a comment, the seller approves it" idea is waiting for the owner's decision
- Connecting to the A2Z2GO website (it probably runs on Magento, server software) belongs with the future
  backend work, not with the app itself
- Sort the read comments by most liked or newest instead of the page's order (offered, not decided)

## Things learned
- Design lessons from three TikTok posts (one accent colour, real icons, loading/empty/error
  screens, small purposeful motion, keyboard-safe forms, offline handling): see
  `PROJECT_CONTEXT.md`, "Design checklist"
- The comment reader is the part that breaks most. Where to look first: `PROJECT_CONTEXT.md`, "Session log".
  Facebook, TikTok, Instagram and YouTube each load comments differently (wide layout, lazy loading, login
  limits); Instagram shows only its newest comments to logged-out visitors, so a list never matches the post
  a minute later
- The owner prefers short plain answers, "talk first" when asked, and a screenshot or the failed screen's
  report line when something does not work
