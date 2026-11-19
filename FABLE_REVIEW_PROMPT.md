# Prompt for the full inspection (paste everything below the line into a Fable 5.2 session)

How to use: open a NEW session in this project folder, run `/model claude-fable-5-2`,
turn on plan mode (so it cannot edit code), then paste the prompt. When it finishes,
come back to the normal session and say "fix REVIEW.md items 1, 4, 7" (or "fix all
Must fix"). The fixing session reads `REVIEW.md` and does the work.

---

You are a principal engineer, product designer and QA lead doing a full independent
inspection of a mobile app. Your job is to FIND problems and opportunities and to
document them so well that another engineer can fix each one without asking you
anything. **You do not fix anything.** Do not edit, create or delete any file in the
project except the two output files named below.

## 0. Read the rules first
Read `CLAUDE.md` and `PROJECT_CONTEXT.md` fully before anything else. Obey the owner's
rules in section 2 of `PROJECT_CONTEXT.md`. In particular: **no deployment work** (no
release signing, store listing, privacy policy, CI for publishing). Do not propose
those as findings; if you notice such a gap, list it once under "Deferred by owner".
Never put secrets, emails or personal paths in your output.

## 1. What the app is
A2Z2GO Seller: an Android seller app in Flutter. Local-only (no backend yet), data kept
in `shared_preferences` through one class (`AppStore`), per-seller account by phone
number, demo OTP shown on screen. Features: products, inventory moves, orders,
returns/refunds, expenses, loyalty points, dashboard, analytics, link import, social
comment import. The owner wants it to feel like a polished product built by a large,
experienced team. They are building it step by step, so judge it as "a serious v1 that
will later get a backend", not as a finished store release.

## 2. Setup (do this, it is allowed)
Follow `PROJECT_CONTEXT.md` section 4 for the toolchain. Run `flutter pub get`,
`flutter analyze`, `flutter test` and record the results. A debug/release Android build
is possible on this machine; do not rebuild unless you need to.
If you need to run or screenshot the UI, do NOT change the project: copy the whole
folder to a scratch directory, add web support there (`flutter create . --platforms web`),
and run it in a browser at phone width (360x800), a small phone (320x568) and a large
phone/tablet (600x900 and 1024x768). Some plugins (camera, web view) will not work on
web; note that instead of calling it a bug. Screenshots go in `review/screens/`
(this folder is the only place besides REVIEW.md you may write in the project).

## 3. Read everything
Read EVERY file in `lib/` and `test/`, plus `pubspec.yaml`, `analysis_options.yaml`,
the Android manifest and Gradle files. Do not skim. At the end of `REVIEW.md`, list any
file you did not fully read and why. Trace each main flow end to end:
sign-in, create product, stock in/out, create order, advance order, cancel/delete order,
return and refund, expense, loyalty earn/redeem/adjust, dashboard and analytics
numbers, sample data, erase all, delete account, link import, comment import.

## 4. Inspect these areas (be exhaustive, look for what a quick review misses)

**A. Correctness and data integrity**
- Money: floating-point rounding, discounts, refunds, totals vs line items, profit and
  cost math, reports that disagree with each other or with the order screens.
- Stock: every path that changes stock (sale, cancel, delete, return, adjust, product
  delete). Can stock or history ever stop adding up? Negative stock? Double restore?
- Loyalty points: earn, reversal, redeem, delete of orders/returns; balance drift.
- Dates and time: time zones, midnight edges, "today / last 7 days" boundaries, DST,
  devices set to a non-local time zone, sorting by date.
- Save/load: partial writes, crashes between saves, corrupt data, old saved data
  after a model change (migration), very large data, concurrent async saves.
- Identity: ID collisions, order counter, SKU rules, phone normalization edge cases.
- Account switching and sign-out: can one seller ever see or overwrite another's data?

**B. State and lifecycle**
- Stale UI after changes elsewhere, objects mutated in place before validation,
  listeners not disposed, controllers not disposed, setState after dispose, `mounted`
  checks, async gaps using `BuildContext`.
- Back button, rotation, app killed and restored mid-form, double taps (double submit),
  slow taps during async work.

**C. Security and privacy (local app scope)**
- Plain-text storage of sensitive data, OTP handling, brute force limits, what happens
  with the demo OTP, web view JavaScript exposure, link import fetching arbitrary URLs
  (size, redirects, schemes), file paths and image handling, logging of personal data.

**D. Performance and scale**
- Cost per action as data grows (1,000 / 10,000 orders, 1,000 products). Whole-store
  serialization on every change, O(n^2) loops in builders, work inside `build`, large
  images not downsized, list views that are not lazy, jank on low-end phones.
- Give rough numbers or reasoning, not vague worries.

**E. Tests**
- Which risky logic has no test that would fail if it broke? Which tests pass but
  assert too little? Flaky or order-dependent tests? Missing screen-level tests?
  Propose the specific tests worth adding (name, setup, assertion), most valuable first.

**F. Architecture and maintainability**
- Layering, duplicated logic, giant files and widgets, naming, dead code, unused
  options, inconsistent patterns, error handling style, magic numbers/strings.
- What will hurt when a backend is added (what must change, how big is the blast radius)?
- Dependencies: unused, outdated, risky, replaceable by the platform.

**G. UX and product quality (from screenshots and code)**
Judge like a senior product designer. For each screen and for the app overall:
- First impression: does anything look amateur, template-like, cluttered or unfinished?
- Visual system: consistent color use, type scale and weights, spacing grid, corner
  radii, elevation, icon style, density. Name each inconsistency with the screens.
- Hierarchy: is the most important thing on each screen obvious? Is the primary action
  clear and reachable with one thumb?
- States: loading, empty, error, offline, success feedback, destructive confirmations,
  undo. Anything silent or confusing?
- Forms: labels, validation timing and wording, keyboard types, autofill, focus order,
  what happens on errors, long text, large fonts.
- Content: copy tone, jargon, truncation, number/currency/date formats, localisation
  readiness (hard-coded strings, peso formatting, Filipino/English).
- Navigation: depth, back behaviour, discoverability, where common tasks start.
- Responsiveness: small phones, large fonts, landscape, tablets.
- Accessibility: touch targets (48dp), contrast (WCAG AA), screen-reader labels,
  focus, text scaling, color-only meaning, motion sensitivity.
- Motion and polish: transitions, press states, skeleton loaders, haptics, anything
  that feels abrupt. Motion must be purposeful, never decorative.
- Name the 5 changes that would most raise perceived quality, in order.

**H. Product gaps (proposals only)**
Features or flows a serious seller app would normally have that are missing or weak
(for example search, filters, export, backup/restore, receipts, barcode scan, undo,
onboarding, reminders). Keep these separate from bugs, mark each "proposal", and say
which are cheap and which need a backend.

## 5. Output: write `REVIEW.md` in the project root

Structure, in this order:
1. **Summary** (10 lines max): overall health, the 5 most important things, toolchain
   results (analyze, tests, build), what you could and could not verify.
2. **Findings table**: one row per finding: ID, severity, area, title, files.
3. **Findings in detail**, grouped Must fix / Should fix / Polish / Proposals / Deferred
   by owner. Number them across groups (F1, F2, ...). Every finding has ALL of:
   - **Where:** `file:line` (and screenshot path if visual).
   - **What is wrong:** plain English, one or two sentences.
   - **Proof:** the concrete input or situation and the wrong result, or the exact
     visual problem. If you could not reproduce it, say "unverified" and why.
   - **Fix:** the smallest change that works, concrete enough to implement.
   - **Test:** the test that would catch it (or "visual check").
   - **Risk / effort:** S/M/L, and what else it could break.
   - **Depends on:** other finding IDs, if any.
4. **UI/UX assessment**: the overall verdict, a short design-system proposal (color
   roles, type scale, spacing scale, radii, shared components that should exist), and a
   screen-by-screen list of what to change, most impactful first.
5. **Suggested fix order**: batches of 3 to 6 findings that can be done and tested
   together, safest and highest value first, with notes on what to re-test.
6. **Blind spots and questions for the owner**: assumptions you made, decisions only the
   owner can make (brand, scope, features), and anything you want clarified.
7. **Not read / not verified**: files, flows and claims you did not check.

## 6. Standards for your own work
- Every finding must be real. No concrete case means no finding. No style taste, no
  "consider", no padding. Fewer, proven findings beat a long vague list.
- Before calling code unused, grep the whole tree (tests, strings, dynamic uses).
- Before calling something a bug, re-read the code path once more and try to disprove it.
- Mark confidence honestly: "confirmed" (reproduced or proven by reading), "likely",
  or "unverified".
- Be specific about the numbers you ran (test count, analyzer output).
- If something is good, say so briefly in the summary so the fixer does not "improve" it.
- When finished, reply with a 5-line summary and the path to `REVIEW.md`. Do not paste
  the whole review into the chat.
