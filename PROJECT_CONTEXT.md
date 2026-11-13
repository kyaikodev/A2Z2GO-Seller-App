# PROJECT_CONTEXT: read this first, update it with every change

This file is the shared memory for any AI (or person) who opens this repo.
It says what the app is, what state it is in, what the owner has decided, and
what changed. **Every change must also update this file** (see `CLAUDE.md`).
Last updated: 2026-11-11.

## 1. What this is

A2Z2GO Seller: an Android seller app built with Flutter (Dart 3.13, Flutter
3.47). It manages products, stock, orders, returns/refunds, expenses and loyalty
points, with a dashboard and analytics.

- **No backend yet.** Everything is saved on the phone (`shared_preferences`).
- Sign-in is a mobile number + one-time code (OTP). There is no SMS service, so
  the code is **shown on screen** (test mode). Real SMS goes in a class that
  implements `OtpSender` (`lib/data/auth.dart`).
- Money is in pesos. Phone numbers are Philippine mobiles, stored as `+639XXXXXXXXX`.
- `README.md` is the user-facing summary. This file is the working context.

## 2. Owner's rules (decided by the owner, follow them)

1. This folder is a **local working copy**. Edit and test here, then publish to
   GitHub (`kyaikodev/A2Z2GO-Seller-App`, branch `main`).
2. **No deployment work yet.** Do not add release signing, privacy-policy pages,
   store listings, version bumps for release, or CI for publishing. The app is
   still being built. (An attempt to add these was reverted on request.)
3. Keep the repo clean: no built files (the `apk/` folder is git-ignored; share
   builds through GitHub Releases later). Do not commit secrets or keystores.
4. Force-pushing rewrites history. The owner asked for it once to start clean
   (see change log). **Ask before any force push.** Normal pushes are fine when asked.
5. Prefer the smallest change that fully works. Every behaviour change needs a
   test when it has logic (branch, parser, money, data writes).
6. **Every APK build gets a new version.** Bump `version:` in `pubspec.yaml` (name+build number, for example
   1.0.1+2 then 1.0.2+3) before building, and name the Desktop copy `A2Z2GO-Seller-v<version>.apk`.

## 3. Layout

```
lib/
  main.dart                  app start, auth gate
  core/format.dart           money/phone/date helpers, newId()
  core/theme.dart            Brand colors + theme (change colors here only)
  data/store.dart            AppStore: ALL reads/writes of shop data (one JSON document per account)
  data/storage.dart          where that document lives: files on the phone (`FileStorage`), or preferences (tests, web)
  data/models.dart           Product, Order, ReturnRequest, Expense, LoyaltyTxn, ...
  data/auth.dart             accounts, OTP, sessions (AuthController)
  data/reports.dart          dashboard and analytics numbers
  data/link_import.dart      reads a public product page (title, price, photos)
  data/comment_tools.dart    parses social-post comments (readGrabbed: no page-text fallback for TikTok,
                             Instagram, YouTube)
  screens/products/grab_script.dart   JavaScript run inside the in-app page to read comments (Facebook, TikTok,
                             Instagram, YouTube); import_comments_screen.dart is the reader screen
  data/sample_data.dart      demo shop loaded from Me > Load sample data
  screens/                   dashboard, products, orders, store (Me, backup.dart), auth, buyer, analytics
  widgets/                   shared UI (EmptyState, Skeleton, FormActionBar, charts); pick_field.dart (red-star labels,
                             PickOrAddField, scrollToFirstError); social.dart (platform badges,
                             avatar, links, groupByPlatform); proof_cards.dart (the social tabs, comment bubbles,
                             "See all" sheet)
test/                        logic, app flow, layout, import, social tabs, reader-script syntax (needs Node)
                             and notes (project_context_test.dart) tests
android/                     Android project (applicationId com.a2z2go.a2z2go_seller)
.claude/                     AI skills and hooks (see section 6)
```

Key design facts:
- Data is per account: key `data_<phone>` in shared preferences. A corrupt save is
  copied to `data_<phone>_backup` and the store starts empty.
- `AppStore._commit()` saves everything after every change (fine now; slow with
  many thousands of records, a known limit).
- Stock changes always go through `_move()` so history adds up to the stock count.
- To move to a real database later, only `AppStore` (and `AuthController` for
  accounts) need to change.

## 4. How to work here

Windows machine. Tools are installed per-user (no admin):
- Flutter: `%LOCALAPPDATA%\Programs\flutter\bin` (on the user PATH)
- Node.js: `%LOCALAPPDATA%\Programs\nodejs` (needed by the hooks in `.claude/`)
- Android SDK: `%LOCALAPPDATA%\Android\Sdk` (platform 36, build-tools 36.0.0, NDK
  28.2.13676358, CMake 3.22.1). JDK 17 (Temurin): `%LOCALAPPDATA%\Programs\jdk17`.
  Flutter is configured to use both (`flutter config`).
- **Java quirk on this PC:** Java tools crash ("Unable to establish loopback
  connection") unless these are set before running them:
  `JAVA_HOME=%LOCALAPPDATA%\Programs\jdk17`,
  `JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=C:\jtmp -Djava.io.tmpdir=C:\jtmp`
  (the folder `C:\jtmp` must exist). Quote SDK package names with semicolons
  when calling `sdkmanager` from PowerShell (use `cmd /c` with escaped quotes).

```
flutter pub get
flutter analyze        # must report: No issues found
flutter test           # 109 tests, must all pass
flutter build apk --release   # test APK, about 8 min first time, signed with the DEBUG key
```

Run analyze and test before every commit. The test APK is copied to the owner's
Desktop as `A2Z2GO-Seller.apk` (never committed; `apk/` and `build/` are ignored).

## 5. Current state (update this section when it changes)

- Analyzer clean. **122 tests pass** (last run 2026-11-12). A release APK builds
  (55 MB). It has not been installed or tested on a phone by the AI yet.
- Working: sign-in/out, new-seller setup, products with photos, inventory moves,
  orders (Pending > Packed > Shipped > Completed, cancel, delete), returns and
  refunds, expenses, loyalty points, dashboard, analytics, sample data, erase all
  data, delete account.
- Social proof: the comment reader works for Facebook, TikTok and Instagram (checked on the owner's phone for
  Facebook and TikTok; Instagram checked on the live page, not yet on the phone; YouTube has code but is
  untested). Buyer page: one tab per social (tap, swipe, or the next one opens after 6 idle seconds), 3 comment
  bubbles, "See all" sheet. Adding comments yourself works for any site; Shopee, Lazada and other links have no reader and say so in plain words.
- APKs: every build is copied to the owner's Desktop and to the shared Google Drive folder (see the session log).
- Reader status on the owner's phone: **the owner confirmed "everything works" on 1.0.28+29** (Facebook, TikTok,
  Instagram, YouTube). Facebook and TikTok read the linked post; TikTok needs the Chrome-desktop identity;
  Instagram reads the newest comments (a list never matches the post a minute later); YouTube needed the
  lazy-load and real-clock time fixes.
- Not done on purpose (owner's rule 2): release signing (release builds still use
  debug keys), privacy policy page, store listing.
- Not done, needs a backend: real OTP sending, sign-in protection, multi-device.

### Audit status (full repo audit, 2026-11-11)
| # | Item | Status |
|---|------|--------|
| 1 | Failed product edit still changed the product (duplicate SKU) | Fixed, `AppStore.skuTaken`, checked before editing |
| 2 | Deleting one return removed points of other returns | Fixed, `LoyaltyTxn.returnId` |
| 3 | Corrupt saved data loaded half and was overwritten | Fixed, all-or-nothing load |
| 4 | Release signing uses debug key | Deferred (owner rule 2) |
| 5 | 58 MB APK committed in git | Fixed, removed and `apk/` ignored |
| 6 | OTP shown on screen (no real protection) | Open, needs backend |
| 7 | Whole store re-saved on every change | Open, limit noted, fix with a database |
| 8 | Missing tests for 1-3 | Fixed, 3 tests added |
| 9 | Unused `cupertino_icons` | Fixed, removed |
| 10 | Link import reads any page size | Open, risky to change decoding |
| 11 | Backup copy left after delete/erase | Fixed |

Parts of the app not read in the audit: dashboard, analytics, loyalty, order
screens, `models.dart`, `reports.dart`, `comment_tools.dart`, `grab_script.dart`.

### Full inspection (REVIEW.md, 2026-11-11)
`REVIEW.md` lists 27 findings with proof, fix and test each; screenshots in `review/screens/`.
Fixed: **F1 to F5, F7 to F13, F15 to F19, F21, F22** (see the status table at the top of REVIEW.md).
Key behaviours now: return refunds are capped at what is left on the order
(`AppStore.refundableLeft`); points reversal follows the points earned (cumulative); the comment tone
filter matches whole words and handles negation; "Mark completed" has an Undo
(`AppStore.undoCompletion`) and deleting a completed order can put the stock back; a product used by an
open order cannot be deleted (it is hidden instead, `AppStore.productInUse`); saved data has
`"version": 1` and UTC times; reports are cached per change (`AppStore.report` / `snapshot`) and only
opened tabs are built; web-view logins are cleared on sign-out and delete-account; debug buttons only
show in debug builds; startup errors show a retry screen; remote photos are saved on the phone when a
product is saved; link import caps page size, reads UTF-8 and skips non-peso prices.
Second pass: **F6** shop data now lives in one file per seller (atomic write, grouped saves, one-time
move from preferences; `FileStorage`), **F20** every inline font size snapped to a 9-step scale
(12/13/14/16/18/20/24/32/40), **F23** Me > Back up my data / Restore a backup (share sheet and file
picker; photos are not included), **F24** order details can be edited, **F25** Undo after deleting an
expense or removing a comment, **F26** loyalty points can be used on an order (they become a discount and
come back if the order is cancelled or deleted), **F27** the share link uses the product id.
**Still open (small):** F6 is still one whole document per save (a real database is a backend-time
decision); F14 linked-post and comment list edits still happen inside screens; F20 sizes are snapped but
not yet taken from theme text styles; F12 the invisible OTP input is unchanged on purpose; F13 prices and
totals stay brand red; F16 demo records are untagged (the tool only shows on an empty shop); F23 does not
back up photos; F25 undo covers only expenses and comments, not product/order/return deletes. The comment picker still auto-ticks
"positive" comments; the seller reviews them before adding.

### Social proof by platform (2026-11-12)
Comments are grouped into one section per social (Facebook, TikTok, ...) with the platform name, its
comment count and a divider line, on the buyer page and in the seller's Social proof screen. Buyers see at
most 5 comments per social, then "Show more (N)" / "Show fewer"; the seller sees all of them. TikTok
reading was checked against a live video (a2z2go-unrelated public post): TikTok's current page exposes
`[data-e2e^="comment-level"]` and `comment-username` exactly as `grab_script.dart` expects (20 of 31
comments loaded before scrolling, names and text all present). It was tested in a desktop browser, not in
the app's Android web view, where TikTok may show a login wall (backups: "Show the page", "Paste
comments"). The tone filter also learned Tagalog "ma-" forms (mabango, mabilis). Sample expenses were
scaled down so the sample shop's weekly profit is positive.

**Phone bug found by the owner (2026-11-12):** a TikTok *short* link (`vt.tiktok.com/...`) ended in
"That took too long". Cause (found by following the link: it 301-redirects to the real video): the reader
started once, on the first page that loaded (the redirect), and was destroyed when the real page opened, so
no result ever came back. Fix: short links (vt./vm. TikTok, /t/ links, fb.me, fb.watch) are followed to the
real page first (`resolveShortLink`; the post keeps the real address), the reader restarts whenever the
page address changes, and the give-up time is 60 s instead of 100 s. Not yet confirmed on the phone; if it
still fails, use "Show the page" > "Grab comments" or "Paste comments".

### Session log (newest first). Add an entry here before EVERY commit.
Each entry: what the owner asked, what changed (files), why, what was learned (the clues), what is still open.
`test/project_context_test.dart` fails if the current `pubspec.yaml` version is not written in this file.

**2026-11-13, product page tidy-up** (version 1.0.31+32)
- *Asked (phone screenshot of the product page):* the page is messy: one long description took most of the screen and everything else was pushed down; "stuff like this seems unprofessional", is it not in the skills?
- *Cause:* the description was shown in full in the header card. It is in the design rules (ui-ux-pro-max: content hierarchy and progressive disclosure; TikTok checklist: one thing to look at, the rest quiet) and had not been applied to this screen.
- *Changed:* new `ExpandableText` in `widgets/common.dart` (three lines, then "Read more" / "Show less", no button for short text, calm size change that respects "reduce animations"), used for the description on the seller's product page and the buyer page. Cost of zero now shows "Not set" and a dash for margin instead of a made-up 100%. 1 new test (122 total).
- *Rule for next time:* no screen may be taken over by one long block. Fold long text, keep the top of each page to the few things that matter (name, price, stock), put the rest in sections.
- *Open:* the owner said other screens feel the same ("takes a huge amount of screen and scroll"); asked for screenshots of the worst ones before a wider clean-up.

**2026-11-13, one connected app: pick lists, required fields, share check** (version 1.0.30+31)
- *Asked:* the app felt like separate pieces (Category and Brand typed by hand, other forms with drop-downs); required fields should be clear, "description and stuff" matter; on submit, empty required fields should turn red and the screen should scroll to the first one; the comment name must be required. The owner told the AI to decide (be the expert) and keep replies short.
- *Decisions (AI's, owner delegated):* two levels. To save a product: name, category, SKU (auto), price, cost, stock, low-stock alert. To share it with buyers: at least one photo and a description of at least 20 letters (`minDescriptionLength`). Brand stays optional. Customers on orders stay optional (walk-in buyers). Comment name is required.
- *Changed:*
  - New `lib/widgets/pick_field.dart`: `reqLabel` (red star), `optLabel` ("(optional)"), `PickOrAddField` (looks like a drop-down; a sheet lists what exists, with search and "Add new"), `scrollToFirstError`.
  - Store: `categoryOptions` (used categories first, then `starterCategories`), `brands`, `customerPhones`.
  - Product form: Category and Brand use the pick field (the old free-text box, chips and the silent "General" default are gone); red stars on name, category, SKU, price, cost, stock, low-stock; a failed save shows red messages, scrolls to the first missing field and keeps checking as the seller types. The list now builds every field (`scrollCacheExtent` 100000): a lazily built list skips fields far below the screen when validating, so a required field could have slipped through empty.
  - `Product.missingForBuyers` / `readyForBuyers`; the product page's Share row says "Not ready yet. Needs a photo and a description..." and refuses to open until both exist.
  - Order form: customer name is a pick list of past customers (picking one fills the mobile number); expense and return forms got the same red stars.
  - Comment box: Name and Comment both required, each with its own red message; the "<Site> user" fallback remains only for "Paste many at once".
- *Tests:* new `pick_field_test.dart`, `product_required_test.dart`; flow and comment tests updated; 121 in total.
- *Open:* existing products with no photo or a short description now show "Not ready" until edited; the owner has not yet seen this on the phone.

**2026-11-13, plain words, add-by-hand box, sorting** (version 1.0.29+30)
- *Asked:* (1) sites the reader does not know (Shopee, Lazada, other links) must say so instead of showing junk page text; (2) sort the read comments; (3) tuck away the "Copy debug info" and "Reader saw..." lines and drop IT words; (4) make the paste box simpler (how to give a name and a comment). Apply the skills (ponytail: smallest change; humanizer: plain words; ui-ux-pro-max: 48 dp buttons, calm look) and the TikTok design checklist (clear empty/error screens).
- *Changed (`import_comments_screen.dart`, `test/import_comments_test.dart`):*
  - `_supported`: only Facebook, TikTok, Instagram and YouTube have a reader; other sites go straight to "We can't read comments from this site yet. Add them yourself instead." with one button, no page-text guessing.
  - The failed screen uses plain sentences ("This is taking too long...", "We couldn't find any comments on this post. They may be turned off, or hidden until you log in."), buttons "Try again", "Add comments yourself", "See the page", "Open in <site>". The technical report line is kept in `_details` and shown only behind a small "More details" link (a dialog with Copy). "Copy debug info" is only shown in debug builds.
  - New `_AddCommentsSheet` replaces the old paste box: Name (optional) + Comment + "Add this comment", a running "Added so far (N)" list with remove buttons, "Done (N comments)", and a "Paste many at once" mode (the old smart parser, with one plain help line). What the seller types is all ticked on the review list. A blank name becomes "<Site> user".
  - The review list has a "Positive first" chip next to "Show positive only" (positive ones on top, each group keeps the post's order). "Most liked" and "newest" need the reader to save likes and times, which it does not yet.
  - Wording: "Grab comments" became "Read comments", "Show the page" became "See the page", the Instagram note and the "some of these may not be real comments" note are in everyday words.
- *Tests:* import tests rewritten for the new flow (add one by one, paste many, unsupported site) and 113 in total.
- *Open:* confirm on the phone; sorting by likes or time would need new reading code per site.
- *Google Drive sign-in (same day):* the browser pane forgets the Google sign-in between sessions, so the owner signs in again each session, with a throwaway Google account (the folder allows anyone with the link to edit). The AI must never type, paste or inject a password, or store account details, even when asked. Upload of 1.0.29+30 worked with that account; on "Shared with me" the Delete key says "File removed" (the old APK leaves the folder but is not necessarily in the owner's Bin). Files uploaded by the throwaway are owned by it and vanish if it is deleted. The Claude in Chrome extension (own Chrome stays signed in) was offered; none was connected.

**2026-11-12, end of this long session: housekeeping** (version 1.0.28+29)
- *Asked:* commit and push with no old files, and update all the markdown files and context for the future.
- *Updated:* `AGENTS.md`, `CLAUDE.md` (lessons, the Drive routine, what "commit push force no old files" means), `SETUP.md`
  (Node is also needed for the script test; where the APKs live; why Drive for Desktop was not used),
  `notes/INDEX.md` (ideas and lessons), `REVIEW.md` (a pointer to this log), the layout in section 3 and "Current state".
- *Everything this session, in one line each (details in the entries below):* TikTok short links, the chat-button
  toggle bug, the lost-backslash regression, Connect TikTok (built, then removed), Chrome-desktop identity for
  TikTok, the wrong-video fix, the caption fix, the social redesign and tabs, swipe and auto-swap, Instagram, Google
  Drive routine, notes rule and its test, tabs that fit, YouTube lazy loading and diagnostics, YouTube time fix.
- *Confirmed by the owner after this entry:* "everything works" on 1.0.28+29 (the YouTube time fix, Instagram, the tabs).
- *Open:* buyer comments and the sort-order idea (most liked or newest first) are waiting for the owner's decision.

**2026-11-12, YouTube: time fix** (version 1.0.28+29)
- *Asked:* with the new report line the owner sent two results. Video 1 (6gTqXrmRp1o, 94 comments): worked, 83 comments read, matching the page (the page's order changes between loads; replies are not read). Video 2 (ZdBI-cMabKs, "Shield Bath Soap Radio Commercial", 60 comments): "That took too long. (Page: www.youtube.com / 1280 / 20 / 2)": 20 comment boxes and 2 comment sections were on the page, so it is a time problem, not a matching problem.
- *Cause:* `waitFor` counted only its own pauses, not the time spent checking the page; on a phone each check is slow, so a "25 s" wait stretched past the 60 s limit. Also, a timeout threw away comments that were already loaded.
- *Fix (`grab_script.dart`, `import_comments_screen.dart`):* `waitFor` now uses the real clock; the YouTube wait is 20 s; the scrolling loop stops when 45 s of the script's time is used and reads what is loaded; on the 60 s timeout the app asks the page once more for "whatever is there now" (a "quick" run with no waiting, 20 s to answer) before showing "took too long". All sites share the clock fix; the quick retry also applies to all.
- *Open:* confirm on the phone that video 2 now reads (about 20 to 60 comments).

**2026-11-12, YouTube follow-up: diagnostics** (version 1.0.27+28)
- *Asked:* the owner is on 1.0.26+27 (the lazy-load fix) and YouTube still does not work; they pasted debug info for `youtube.com/watch?v=6gTqXrmRp1o` ("SHIELD BATH SOAP TVC", 94 comments).
- *Clue from the paste:* `youtube: 20` (20 `ytd-comment-thread-renderer` boxes on the page), 20 "Like this comment" labels, real authors in the page text. So the comments are on the page; the reader still reports nothing, and the paste does not say why.
- *Change (no fix yet, to see the cause):* the failed screen now ends with a "Reader saw: N comment boxes, read N, YouTube boxes N, with text N, with author N, page width N" line (or "Reader error: ..."), and the "took too long" message ends with a "Page: host / width / boxes / comments section" line; the debug report also carries a snippet of the first YouTube comment's markup (`ytSample`). The owner is asked to send that line from the next failure.
- *Open:* the real cause of the YouTube failure.

**2026-11-12, YouTube fix** (version 1.0.26+27)
- *Asked (phone screenshot):* YouTube does not work when a video link is put in; the in-app page showed the video with "94 Comments" but the reader fell to "Show the page".
- *Cause (best evidence, not proven on the phone):* YouTube loads its comments only when the comments section is on screen, and the page is short while it loads, so the reader's scroll-to-bottom never triggered it and it gave up after 5 s. In my browser the `ytd-comments` section was a placeholder with a spinner until reached.
- *Fix (`grab_script.dart`, YouTube only):* it now scrolls the `ytd-comments` section into view and waits up to 25 s for comments to appear, then reads as before. Facebook, TikTok and Instagram are unchanged.
- *Clue:* my browser pane is in YouTube "Restricted Mode", which hides all comments ("Restricted Mode has hidden comments for this video"), so I could not read comments there; the fix is verified only as far as the lazy loading. If YouTube still fails, use "Copy debug info" on the failed screen and send it.

**2026-11-12, earlier: tabs fixed, Instagram polish** (version 1.0.25+26)
- *Asked (from phone screenshots):* the tabs are cut off ("Ins..."), fix the UI; the Instagram comments differ from the post; touch only Instagram, not Facebook/TikTok.
- *Tabs (changed `proof_cards.dart`):* up to four tabs now share the width equally (icon + count pill on top, name below, name scales down on big fonts); more than four slide sideways at 96 px each. A new test checks three tabs fit a 320 px phone. This also fixes the seller's Social proof screen (same widget).
- *Instagram caption (`usefulCaption` in `link_import.dart`):* Instagram's description starts with "381K likes, 7,520 comments - name on <date>:" then the caption in quotes; only the quoted caption is kept, nothing if there is none.
- *Instagram reading (`grab_script.dart`):* only for Instagram, each scroll round waits 2.5 s (was 1 s) and it needs 3 quiet rounds (was 2), because the phone got only 8 comments where the browser got 25.
- *"Different comments" (clue, no code fix possible):* Instagram shows a logged-out visitor only its newest comments (times like 4s, 1m, 2m), and a busy reel gets a new one every few seconds. Two loads minutes apart in my browser had completely different people. So the app's list can never match the post a minute later. The results screen now says so for Instagram. Making it match would need a login, which the owner dropped.
- *Rule learned:* do not send requests that pose as another program (I tried a crawler identity with curl; it was blocked and was wrong). Use only what the app itself receives.
- *Open:* check on the phone that three tabs look right and that Instagram now reads more than 8.

**2026-11-12, later: Instagram, auto-swap, Google Drive, notes rule** (versions 1.0.23+24 and 1.0.24+25)
- *Asked:* try an Instagram reel link and make the reader get its comments; make the social tabs swap by
  themselves after 6 idle seconds; upload each new APK to the owner's shared Google Drive folder; keep this
  file updated before every commit.
- *Instagram (changed `grab_script.dart`, `import_comments_screen.dart`, `comment_tools.dart`, test
  `instagram_test.dart`):* I first told the owner Instagram hides comments, which was wrong. My browser pane
  was 583 px wide so Instagram showed its narrow layout. At 1280 px, Instagram shows about 25 comments to a
  logged-out visitor in a side panel; scrolling loads them (7, 11, 16, 21, 25) and "Load more comments" gives
  nothing more without a login. Each comment has a "Reply" button; the comment is the largest block around it
  that holds only one Reply, and its lines read: name, time, text, likes, Reply. The reader now uses the
  computer identity and 1280 px width for Instagram too, scrolls the panel, reads that way, and never falls
  back to page text for Instagram. The owner also said: no need to read all comments, just as many as the app
  can. **Clue: judge a site only after setting the browser pane to a wide size (1280).**
- *Auto-swap (changed `lib/widgets/proof_cards.dart`, `buyer_product_screen.dart`, test
  `social_sections_test.dart`):* `SocialTabs(autoSwap: true)` counts idle seconds with a 1 s timer; any pointer
  event anywhere on the screen resets it (a global pointer route); at 6 it opens the next tab (wraps to the
  first). It holds still when another route covers the page (the "See all" sheet), with one social, or when the
  phone asks for fewer animations. Buyer page only.
- *Google Drive:* the owner asked to auto-upload APKs. No Drive connection exists in this session and the
  upload tools cap at 10 MB (the APK is about 59 MB). First tried Google Drive for Desktop: the installer
  (downloaded from dl.google.com, signature checked) failed with error 1603 "Create Application directory
  failed" (this work PC probably needs admin rights); the installer, a partial download and a log were deleted.
  What works: the owner signs in to Google inside the built-in browser pane; a temporary local server on
  127.0.0.1 serves the APK; the Drive page fetches it and the file is dropped onto the folder; then the old APK
  is moved to the Drive Bin. Done once for 1.0.24+25. Rule: upload first, delete the old one only after the
  upload succeeds, touch only APK files in that folder, stop the local server afterwards.
- *Also discussed (no code):* Magento is server software (the A2Z2GO website probably runs on it); it is not
  something to add to the app, connecting to its API belongs with future backend work. Buyer comments: the
  owner wants buyers to be able to comment; needs a server, sign-in or a name, moderation and spam limits.
  The idea of "buyers send a comment, the seller approves it" was proposed; the owner has not decided yet.
- *Notes rule:* this file must be updated before every commit (see `CLAUDE.md`); the new test enforces the
  version part.
- *Open:* confirm on the phone: Instagram reading, the auto-swap feel (6 s may be short for reading), and the
  plain fade when changing tabs.

**2026-11-12, earlier: TikTok and Facebook reading, redesign** (versions 1.0.6 to 1.0.22): see the story below.

### What happened in the earlier 2026-11-12 sessions (TikTok and Facebook reading, redesign)
Read this before touching the comment reader. Order of events and what was learned:
1. **TikTok short links** timed out (the reader started on the redirect page). Fixed by following the
   short link first and restarting the reader when the page address changes.
2. **The reader pressed TikTok's chat button every 250 ms.** It toggles the panel, so it kept closing it.
   Now it presses at most 3 times, 2.5 s apart, and clicks the "Comments" tab itself.
3. **I broke every site in 1.0.7:** while writing the TikTok fix, the backslashes of a JavaScript pattern
   were lost (a shell heredoc ate them). The whole reader script was invalid JavaScript, so Facebook also
   waited forever. Fixed in 1.0.10. **Lesson: never write JavaScript or regex patterns through a shell
   heredoc; use the Edit/Write tools.** `test/grab_script_syntax_test.dart` now asks Node to check both
   scripts parse (skipped when Node is missing).
4. **TikTok on the phone** first showed a narrow layout with no comments panel, then asked to log in.
   A "Connect TikTok" login screen was built and then **removed at the owner's request** (Google refuses
   sign-in inside an app's web page: "This browser or app may not be secure"). The owner then found that
   Chrome's Desktop-site mode on the same phone shows the comments without logging in. So the real cause
   was how the in-app page introduced itself. Fix (kept): it now sends Chrome Desktop mode's identity with
   the phone's real Chrome version (`desktopAgentLike` in `link_import.dart`), tells the page it is 1280 px
   wide, and leaves out the app-name request header. **TikTok comments now read correctly on the phone.**
5. **Wrong comments** (a different video each time): TikTok's desktop page is a feed (the linked video plus
   the next). The reader now waits for the linked video's own box, presses only its comment button, never
   scrolls the feed and drops the result if the page moved to another video.
6. **Facebook** was fine again once item 3 was fixed. If the reader finds no comment boxes it falls back to
   page text (orange warning) and "Copy debug info" is offered; TikTok and YouTube never use that fallback
   (it produced junk).
7. **Caption bug:** TikTok's page title is always "TikTok - Make Your Day". The real caption is the first
   `"desc"` in the page data; generic titles are hidden (`usefulCaption`).
8. **Redesign:** one tab per social (browser-style, swipe left/right or tap, dots show where you are), 3
   comments as chat bubbles, "See all N comments" in a scrolling bottom sheet, on the buyer page and the
   seller's proof section. See `lib/widgets/proof_cards.dart`.
9. **Instagram** works the same way as TikTok (see the change log): wide layout, about 25 comments logged out. **Lesson: a result from my own browser pane depends on its width; set it to 1280 px before judging a site.**
10. **Not done, decided or asked:** buyers commenting (to be discussed first: needs a server, moderation and
   rules, see section 7); Magento (the A2Z2GO website likely runs on it; it is server software, not
   something to add to the app; connecting to its API is for when a backend exists).
Working style notes: the owner wants short plain answers, "talk first" when asked, an APK on the Desktop for
every build with a bumped version, and "commit push force no old files" means one fresh orphan commit
(the nested `A2Z2GO-Seller-App/` notes folder is never committed).
Every new APK is also put in the owner's shared Google Drive folder "A2Z2GO" (the old APK there is moved to the Drive Bin only after the new upload succeeds). It is done in the built-in browser pane while the owner is signed in to Google: a temporary local server on 127.0.0.1 serves the APK, the Drive page fetches it and the file is dropped onto the folder (the upload tools cap at 10 MB, the APK is about 59 MB). The server is stopped afterwards. If the pane is signed out, ask the owner to sign in themselves.

### Real sample shop, sharing, offline and permissions (2026-11-12)
- **Sample data** ("Load sample data" on Me, only on an empty shop) is now 20 real listings from
  a2z2go.com (name, price, description, real page link). Photos are bundled in `assets/sample/` (about
  1.2 MB, 640 px JPEGs) and written `asset:assets/sample/<SKU>.jpg`, so they show without internet.
  Stock and cost are made up (cost is 70% of the price). One product is a hidden example. The old SKUs
  (A2G-FD-001 and so on) were kept so the sample orders still work.
- **Share screen:** Messenger, Facebook, Viber and WhatsApp buttons (they open the app, text and link
  only) plus "More" (the phone's share menu, with the cover photo attached: Instagram, TikTok, Telegram,
  email). A product with a website link shares that real page; others share a placeholder link marked
  "Preview only". The "This is how buyers will see your product" banner is now a short message that
  disappears by itself.
- **Offline:** the app is local-first. Orders, stock, returns, expenses, loyalty, reports, backup and
  the sample shop all work without internet. Internet is only needed for autofill from a link, importing
  comments, web photos, and sharing to other apps.
- **Permissions:** the built APK requests only INTERNET (no pop-up for it). Camera and gallery use the
  phone's own camera and photo picker, so the app does not ask for those permissions.

### UI cleanup pass (owner's list of 16 items, all done)
One home per action: Home quick actions are now only "Add product" and "New order" (Expenses and Loyalty
live in the Me tab; Insights has no "+ Expense"); panel "View all" text links became a small arrow and the
whole header row taps; the product page lost its QR icon (one "Share and preview" row), and its Delete is
inside a "more" menu; the order page has Edit and Delete in one "more" menu and "Cancel order" is a quiet
link under the one main button; Inventory value moved from Me to Insights; Backup is one row (sheet with
back up / restore); Erase all data and Delete account sit under a "Danger zone" heading. Sign-in: steps
slide and fade, digits pop in, a wrong code shakes the boxes with a buzz, the right code shows a green
"Code verified" moment before moving on, and the duplicate "Use a different number" link is gone (the
back arrow does it). Haptics and the shake are untested on a real phone.

### Design checklist (from three TikTok posts by @buildwithfarhan, plus a design-tool promo)
| Point | Status in this app |
|-------|--------------------|
| One accent color, no purple gradients | OK: red brand color, no gradients |
| Real icons, not emoji | OK (emoji exist only in comment-filter lists) |
| One big number, rest quiet | OK on dashboard |
| Loading, empty, error screens | OK: EmptyState widget, Skeleton loader |
| Small purposeful motion only | OK: kept minimal on purpose |
| Keyboard never hides the main button | OK: `FormActionBar`, sheets use viewInsets, points sheet now scrolls |
| Safe areas, small and large phones | OK: layout tests for tiny phone + largest fonts |
| Offline handling with retry | OK for link import and comments import |
| No API keys in the app | OK: none |
| Store-ready (privacy link, etc.) | Deferred (owner rule 2) |
| Accessibility labels | Fixed: tooltips added to icon buttons; tabs announce "name, N comments" and "selected" |
| Touch targets 48 dp | OK: tabs are 48 dp tall, the "See all" button is 48 dp |
| Gestures that do not fight scrolling | OK: swipe changes tabs only on a fast horizontal swipe; vertical scroll is untouched |
| Calm motion, respects "reduce animations" | OK: changing tab is a plain 0.1 s fade (no slide, no height animation, owner found the slide dizzy); the fade is off when the phone asks for it |

The fourth video was a promo for a paid design MCP (`seenry.design`). Not installed.

## 6. AI tooling in this repo (`.claude/`)

- `.claude/skills/`: `humanizer`, `i-have-adhd`, `ponytail` (+ `-audit`, `-debt`,
  `-gain`, `-help`, `-review`), `ui-ux-pro-max`. Reviewed for safety before install.
- `.claude/settings.json` enables hooks (`.claude/hooks/`): ponytail loads at
  session start and on each prompt; i-have-adhd is opt-in (`/i-have-adhd`). They
  need Node.js. They write small state files under the user's `~/.claude` and
  `~/.config`, and make no network calls.
- Ponytail mode is on by default: terse answers, smallest working change, end each
  reply with what was skipped or unchecked. Say "stop ponytail" to turn it off.
- Skills not auto-applied: use `/ponytail-audit` for a repo audit and `/ponytail-review`
  for a change review.

## 7. Known gaps and next ideas

- **Buyer comments** (owner's idea, not started, talk first): real buyer comments need a server to store
  them, buyer sign-in or a name, moderation and report buttons, and spam limits. Without a server the app
  can only keep a buyer's note on that buyer's own phone. Decide the approach with the owner first.
- Connecting to the A2Z2GO website (likely Magento) belongs with the backend work below.
- Pick the next feature or fix with the owner.
- When a backend exists: real `OtpSender`, replace local storage in `AppStore`.
- Before publishing (not now): release keystore via git-ignored `android/key.properties`,
  privacy policy hosted at a public URL, privacy/data page in app, store listing.

## 8. Change log (newest first; add an entry for every change)

| Date | Commit | What changed |
|------|--------|--------------|
| 2026-11-12 | squashed | **Fixed a regression I caused in 1.0.7:** a pattern in the reader script lost its backslashes, so the whole script was invalid JavaScript and read nothing on every site (Facebook too). Fixed, and a new test (needs Node; skipped without it) checks the scripts parse; 109 tests; version 1.0.10+11 |
| 2026-11-12 | squashed | "Copy debug info" now shows on the failed-reading screen in the normal app (temporary, to diagnose a Facebook reading problem); version 1.0.10+11 |
| 2026-11-12 | squashed | Facebook safety: the reader no longer restarts when only the query part of the address changes, and Facebook keeps the old 100 s limit (60 s only for TikTok/YouTube); version 1.0.9+10 |
| 2026-11-12 | squashed | Phone showed TikTok in a narrow layout with no comments panel (screenshots from the owner): the page is now told it is 1280 px wide from the moment it starts loading, so the web view shows the computer layout shrunk to fit; version 1.0.8+9. Not yet confirmed on the phone |
| 2026-11-12 | squashed | TikTok reader: the comment button is pressed only a few times (it toggles the panel, so repeated presses closed it), the "Comments" tab is clicked until real comments show, no more page-text fallback for TikTok/YouTube (it produced junk); 1 new test (99 total); version 1.0.7+8 |
| 2026-11-12 | squashed | Fixed TikTok short links timing out on the phone (follow the redirect first, restart the reader when the page changes, 60 s limit); 3 new tests (98 total); version 1.0.6+7 |
| 2026-11-12 | squashed | Social proof grouped by platform with dividers, 5 comments per social + Show more (buyer page), TikTok reading verified on a live video, Tagalog "ma-" words in the tone filter, smaller sample expenses; 4 new tests (95 total); version 1.0.5+6 |
| 2026-11-12 | squashed | Real sample shop (20 a2z2go.com listings with bundled photos), social share buttons (Messenger, Facebook, Viber, WhatsApp, More) sharing the real product page, buyer-preview banner became a brief message, "asset:" photo support; 4 new tests (91 total); version 1.0.4+5 |
| 2026-11-12 | squashed | UI cleanup pass (owner's 16 items): one home per action, "more" menus, Danger zone, one Backup row, Inventory value moved to Insights, animated sign-in (slide, digit pop, shake, Code verified); 3 new tests (87 total); version 1.0.3+4 |
| 2026-11-12 | squashed | Clean-up from a ponytail review: signing out / deleting the account now also clears the saved "TikTok connected" flag, the browser-identity strings live once in link_import.dart, the disconnect text says it clears all web logins; 2 new tests (102 total); version 1.0.13+14 |
| 2026-11-12 | squashed | Connect TikTok: owner reported the login did not carry over to the reader; the login page now uses the same computer identity as the reader, and "I'm logged in" checks that TikTok really shows a logged-in page before saying connected; version 1.0.12+13 |
| 2026-11-12 | squashed | Added **Connect TikTok** (Me tab): TikTok only shows comments to logged-in people, so the owner logs in once inside the app's own page (the app never sees the login) and the reader reuses it; Disconnect and Sign out clear it; version 1.0.11+12. Not yet confirmed on the phone |
| 2026-11-12 | squashed | **Removed Connect TikTok** at the owner's request (Google refuses sign-in inside an app page, and the owner wants the app as it was before the login idea). Gone: connect_tiktok.dart, its test (109 tests), the Me row and the failed-screen hint. Kept: the reader fixes, wide layout for TikTok, shared browser-identity constants, Copy debug info. (Later found: the login was not needed, see the TikTok story below.) Version 1.0.15+16 |
| 2026-11-12 | squashed | Owner found TikTok comments show in Chrome's Desktop-site mode on the same phone but not in the app's page, so the in-app page now sends Chrome Desktop mode's identity with the phone's real Chrome version, and leaves out the web view's app-name request header on the first request; 1 new test (101 total); version 1.0.16+17. Untested on the phone, may not be enough |
| 2026-11-12 | squashed | "Copy debug info" is also shown on the results screen when the comments came from the page text (owner's Facebook post gave 71 junk lines with the 3 real comments inside), to find what that Facebook page looks like to the reader; version 1.0.17+18 |
| 2026-11-12 | squashed | TikTok read comments of a different video each time: TikTok's page is a feed (the linked video plus the next one). The reader now waits (up to 15 s) for the linked video's own box, presses only that box's comment button, never scrolls the feed (only the comment list), and drops the result if the page moved to another video. Checked on the live page; version 1.0.18+19. Not yet confirmed on the phone |
| 2026-11-12 | squashed | **YouTube time fix**: the reader's waits now use the real clock, the scroll loop stops at 45 s and reads what is loaded, and a timeout asks the page once for the comments already on it before failing (the owner's second YouTube video timed out with 20 comment boxes on the page); version 1.0.28+29 |
| 2026-11-12 | squashed | **YouTube diagnostics**: failure messages now say what the reader saw (comment boxes found, read, with text/author, page width) and the debug report carries a YouTube comment markup sample, because YouTube still fails on the owner's phone although the page has the comments; no fix yet; version 1.0.27+28 |
| 2026-11-12 | squashed | **YouTube fix**: the reader now brings YouTube's comments section into view and waits up to 25 s for the comments to load (YouTube loads them only when the section is on screen); YouTube only; no test can reach a live YouTube page, the script syntax test covers the code; version 1.0.26+27. Not yet confirmed on the phone |
| 2026-11-12 | squashed | **Tabs fixed and Instagram polish** (owner's phone screenshots): tabs share the width (icon + count, name below) so none is cut off, on both the buyer page and the seller's Social proof; Instagram caption keeps only the quoted caption; Instagram scrolling is more patient; a note on the Instagram results screen explains that Instagram shows only its newest comments, which change every few seconds; 2 new tests (111 total); version 1.0.25+26 |
| 2026-11-12 | squashed | **Notes rule enforced** (owner's request): added a Session log section (newest first, written before every commit) with the Instagram, auto-swap, Google Drive and Magento/buyer-comments story; `CLAUDE.md` now requires a session-log entry before every commit; new `test/project_context_test.dart` fails when the pubspec version is missing from this file (2 new tests, 109 total); no app change, no new APK, version stays 1.0.24+25 |
| 2026-11-12 | squashed | **Auto-swap tabs** (owner's request): on the buyer page, if nothing on the screen is touched for 6 seconds the next social tab opens by itself (and wraps to the first); any touch anywhere on the screen starts the 6 seconds again. It holds still while the "See all" sheet or another screen covers the page, when there is only one social, and when the phone asks for fewer animations. Only the buyer page does this, not the seller's proof section. 1 new test (107 total); version 1.0.24+25 |
| 2026-11-12 | squashed | **Instagram comments** (owner's test link): I first wrongly said Instagram hides comments; my browser pane was only 583 px wide, so Instagram showed its narrow layout. At a wide size (1280 px) Instagram shows about 25 comments to a logged-out visitor; scrolling loads them (7, 11, 16, 21, 25) and more needs a login. The reader now treats Instagram like TikTok: computer identity and 1280 px width, scrolls the comment panel, and reads each comment from its "Reply" button (name, time, text); no page-text fallback. It reads as many as the page gives and does not chase the full count (owner: "just view as much as the app can"). 2 new tests (106 total); version 1.0.23+24. Checked on the live page; not yet on the phone |
| 2026-11-12 | squashed | Swipe transition simplified at the owner's request: no slide and no height animation, just a plain 0.1 s fade; dots change instantly; version 1.0.22+23 |
| 2026-11-12 | squashed | **Swipe and polish** (owner's request): swiping the "What people are saying" area left or right changes the social tab (fast horizontal swipe only; the first and last tab stop the swipe), with a plain 0.1 s fade (the first version slid and animated the height; the owner found it dizzy and it was removed in 1.0.22), a dot row showing the position, a count pill on each tab, ripple on tabs, tinted source-post row with the platform icon when there is no picture, "Comments N" heading, "See all" button with an arrow, empty state with an icon, a note with a shield icon, soft shadow; animations off when the phone asks for reduced motion. The session story was written into this file. 1 test extended for swiping (104 total); version 1.0.21+22. Not seen on the phone yet |
| 2026-11-12 | squashed | Social tabs (owner's request): the socials sit side by side as browser-style tabs (icon, name, comment count; the chosen tab is white with a coloured top edge) on both the buyer page and the seller's proof section, so other socials need no scrolling; the tab strip scrolls sideways if many; `PlatformSectionHeader` removed; version 1.0.20+21 |
| 2026-11-12 | squashed | **Social proof redesign** (owner's request): the buyer page shows one quiet card per social (platform pill + count, source post with picture, 2-line caption and "View original", then 3 comments as soft chat bubbles, then "See all N comments" which opens a bottom sheet that scrolls by itself); the seller's post card uses the same bubbles and sheet (remove button kept). TikTok's caption now comes from the page data instead of the generic "TikTok - Make Your Day" (old saved titles like that are hidden). Avatars take the first whole letter (fancy letters no longer break into a box) or a person icon. New `lib/widgets/proof_cards.dart`; `CommentAvatar` moved to `widgets/social.dart`; 3 new tests (104 total); version 1.0.19+20. Not checked by eye on the phone yet |
| 2026-11-13 | squashed | **Product page tidy-up**: long descriptions fold to three lines with Read more (seller and buyer pages), a cost of zero shows "Not set" instead of a 100% margin; version 1.0.31+32, 122 tests |
| 2026-11-13 | squashed | **One connected app**: Category, Brand and Customer are pick lists of what already exists (with Add new and a starter category list); required fields have a red star and a failed save scrolls to the first missing one; a product needs a photo and a 20-letter description before it can be shared; comment name required; version 1.0.30+31, 122 tests |
| 2026-11-13 | squashed | **Plain words, add-by-hand box, sorting**: unsupported sites (Shopee, Lazada, other links) say so instead of showing junk; failed screens use everyday words with the technical report behind "More details"; new "Add comments yourself" box (name optional + comment, running list, paste many at once); "Positive first" sort chip; version 1.0.29+30, 122 tests |
| 2026-11-12 | latest | Clean start again at the owner's request: all history squashed into one commit and force-pushed (nested Obsidian notes folder left out). Contains everything above, version 1.0.31+32, 122 tests |
| 2026-11-11 | `249e53c` | Clean start again (history squashed and force-pushed at the owner's request; rows below are squashed history). Added AGENTS.md, SETUP.md, notes/ and an Obsidian vault setup. Second review pass (F6, F20, F23 to F27): file storage with grouped saves and migration, type-scale snap, backup/restore, order edit, points on orders, undo for expenses and comments, id-based share link; 9 new tests (84 total); added share_plus and file_picker; version 1.0.2+3 |
| 2026-11-11 | squashed | Clean start again (history squashed and force-pushed at the owner's request; the rows below are squashed history). Fixed REVIEW.md F4 to F22 (all Should-fix and Polish items except the parts listed as open in section 5): undo for completed orders, product-in-use guard, report/tab performance, privacy clean-up of the web view, startup error screen, scroll-safe stock sheet, search by phone, contrast and colour fixes, form guards, link-import hardening, UTC times and a schema version; 11 new tests (75 total) |
| 2026-11-11 | squashed | Fixed REVIEW.md F1 to F3 (refund cap, proportional points reversal, tone filter negation) with 4 new tests (64 total); added `REVIEW.md` and `review/screens/` from the full inspection |
| 2026-11-11 | squashed | Owner asked for a clean start again: all history squashed into one commit and force-pushed. The rows below are the history that was squashed; their commit hashes no longer exist |
| 2026-11-11 | squashed | Set up Android SDK, JDK 17 and NDK; built a test release APK (55 MB, debug-signed) to the Desktop. Documented the Java loopback workaround. No app code changed |
| 2026-11-11 | squashed | Added `PROJECT_CONTEXT.md` and `CLAUDE.md` so every AI session starts with full context |
| 2026-11-11 | squashed | Tooltips on quantity/clear-search buttons; points sheet scrolls with keyboard; backup copy removed on erase/delete account; dropped unused `cupertino_icons` |
| 2026-11-11 | squashed | Clean start: history squashed into one commit by owner's request (old history and 58 MB APK removed from `main`). Contains the app, the three data-bug fixes with tests, and `.claude/` skills and hooks |
| before | gone | Replaced by the clean start. First held the original app + APK; second the three data-bug fixes |

Earlier work (now in the clean start): installed skills and hooks, installed Node
and Flutter, ran a repo audit, fixed audit items 1-3 with tests, tried and reverted
release-signing and a privacy page (owner: no deployment things yet).
