# PROJECT_CONTEXT: read this first, update it with every change

This file is the shared memory for any AI (or person) who opens this repo.
It says what the app is, what state it is in, what the owner has decided, and
what changed. **Every change must also update this file** (see `CLAUDE.md`).
Last updated: 2026-11-13.

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
   **One exception, approved by the owner on 2026-11-20:** the sample share page (sample data only) was
   published on GitHub Pages from the `gh-pages` branch. Anything else public still needs the owner's yes.
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

- Analyzer clean. **122 tests pass** (last run 2026-11-20). A release APK builds
  (57 MB, 1.0.38+39 on 2026-11-20; needs the JAVA_TOOL_OPTIONS fix in the Session log). It has not been installed or tested on a phone by the AI yet.
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

**2026-11-20 (late), sample share page (a web version of the buyer page), PUBLISHED on GitHub Pages** (the source is not committed on main; version stays 1.0.37+38, no APK change)
- *PUBLISHED (owner chose GitHub Pages and approved):* live at **https://kyaikodev.github.io/A2Z2GO-Seller-App/#/product/A2G-FD-001** (also `A2G-HH-004` and `A2G-GR-001`; the other sample products open without comments). The files are on the `gh-pages` branch (one commit, 65 files, pushed without force); `main` is untouched. The owner turned Pages on in the repo settings (Source: deploy from a branch, `gh-pages`, root): `gh` is not signed in here, so that one click is the owner's. Checked live in the built-in browser at phone size: opens, no console errors, about 1.3 MB transferred and ready in about 1.2 s on this computer, another product link works, changing only the end of the address works, the strip, the comments and the "Sample preview" bar show. The files were scanned for personal details first: none (the phone-like digits are floating-point numbers, the email-like text is the public author list of the open-source packages in `assets/NOTICES`). Anyone with the link can open it; the repo is public.
- *The app's link and QR now point to the sample page for sample products (owner's request, source only, no new APK yet; 1.0.37+38 does not have it):* `share_sheet.dart`: `samplePageAddress`, `isSample(p)` (the SKU is one of `sampleProducts` AND the website link is still the one the sample comes with, so a seller's own product that reuses a sample SKU does not count), `shareLink` gives `<address>#/product/<sku>` for samples, `hasRealLink` is true for them, and a light-blue note under the QR says "Sample link ... made-up comments". Every other product behaves as before (its own website link, or the placeholder). Tests added to `test/share_test.dart` (3; every sample SKU round-trips through `skuFromLink`); 143 tests. To try it: install a new APK, Me tab > Load sample data, open a product > Share and preview, scan the QR with another phone.
- *How to update the live page:* (1) rebuild **in PowerShell** with `flutter build web -t lib/share_web.dart --release --base-href /A2Z2GO-Seller-App/` (Git Bash rewrites the address into `C:/Program Files/Git/...` and the build fails); (2) copy `build/web` to a temporary folder, add an empty `.nojekyll` file, `git init -b gh-pages`, commit, add the repo as `origin`; (3) push to `gh-pages`. A normal push of a new unrelated history is refused, so an update needs `--force` on `gh-pages` only: **ask the owner first** (rule 3). Pages takes a minute or two to refresh; reload with a new `?r=2` to skip the browser's copy. Do not commit `build/` to `main`.
- *Decisions with the owner (talked through first):* the **website stays untouched**; a **separate page of ours** holds the comments and links to the original product on the website; no database yet, so the first step is a **sample** page with built-in sample data. Later: a small service of our own stores real shares (or, if the boss agrees and the dev team builds it, a small comments table and tab on the website, which would make our page unnecessary). The comments are collected by the seller's phone and kept only there; another phone can only see them from a copy sent in a file or kept on a server. Migrating later is easy if the app sends a product through one place in the code. Owner's rule "no deployment yet" still holds: **nothing was published**; the owner must say yes, and choose the host (GitHub Pages is easiest, repo is public; Netlify, Cloudflare Pages or Firebase need an account the owner creates).
- *What was built:* `web/` (made with `flutter create --platforms=web .`; that command also bumped packages in `pubspec.lock` and added a default `test/widget_test.dart`, both undone; the one-line `web/**` skip in `analysis_options.yaml` was kept; title and description set in `web/index.html` and `web/manifest.json`); `lib/share_web.dart` (the web entry: in-memory store with the app's 20 sample products, `skuFromLink`, one-page routing with `onGenerateInitialRoutes`, a light-blue `SampleBar` "Sample preview: the comments are made up."); `addSampleComments` gives made-up comments marked "Sample" to three products only (A2G-FD-001 with TikTok, Facebook and YouTube posts, A2G-HH-004 on its existing Facebook post, A2G-GR-001), the original-post links go to a2z2go's real social pages; the app's own sample data is unchanged. `BuyerProductScreen(share: true)` (no "how buyers will see it" note) and `PreviewTaps` (`product_page.dart`): on the shared page every button that only looked the part (cart, wish list, share buttons, Store Location, Track Order, the breadcrumb "Home", Add To Cart) opens the product's website link (`sourceUrl`, else a2z2go.com); in the seller's preview they still say it is not connected. Tests: `test/share_page_test.dart` (4); 140 tests in all.
- *Link shape:* `<host>/#/product/<sku>`, for example `#/product/A2G-FD-001`; no product in the link shows the first sample.
- *How to build and look at it (nothing leaves the computer):* `flutter build web -t lib/share_web.dart --release` makes `build/web` (about 43 MB, not tracked by git); serve that folder with any static file server on 127.0.0.1 and open it at phone size. First checked in the built-in browser: the page, the strip, "See all" scrolling, the shuffled comment and the tab rotation all work; a brand-new tab showed no console errors; Add To Cart tried to open a2z2go.com (the browser pane blocks pop-ups from automated clicks, so the real open was not seen, a person's tap is allowed).
- *Lessons:* (1) Flutter web reads the end of the link (`#/product/x`) as the initial route and builds a stack `/`, `/product`, `/product/x`; without handling it the console showed "Null check operator used on a null value" in the release build; `onGenerateInitialRoutes` with one page fixed it. (2) A release web build is minified; `flutter run -d web-server --web-port=8091` (debug) gives readable errors. (3) `-O0` does not un-minify; the read-console tool keeps old messages, so check in a brand-new tab. (4) The screenshot tool scales the picture; a click needs the picture position divided by the scale. (5) A store test that never lets time pass leaves the store's save timer pending: use a plain `test`, not `testWidgets`.
- *Open:* check on a real iPhone (cannot be done from here); first-load time on a phone; the privacy check on showing commenters' names (real ones come later, the sample uses made-up names); who hosts the later small service.

**2026-11-20 (evening), buyer preview rebuilt as a 1:1 copy of the website's phone product page** (not committed; versions 1.0.33+34 to 1.0.38+39, APKs built for the owner's phone test)
- *Asked:* the owner said the header step "still lacks": look at the real a2z2go.com on a phone and make the buyer preview exactly 1:1, but keep our comments where the website has "Reviews".
- *How it was measured:* the live page (Shield Bath Soap 120g, out of stock with -50%, and Alaska Condensada, in stock) at 375 px wide, sizes, colors and spacing read from the page itself. Key values: page side space 15; title 20 px regular; "SKU:" label black + value #999; share buttons 40x40 (#1B4E9B, #00AEEF, #D93025) 7 apart; photo square 345; discount tag #F14705 white 14 px at the photo's top right; price 24 px weight 500 #FF3300, old price 14 px #999 struck through; stock line 15 px black; quantity box 100x37, "Add To Cart" 200x52 #FCB800 radius 2, heart 26 px #999; badges box #F4F4F4 padding 15; tabs are grey bars (#F4F4F4, 20 px, 44 tall) that open one at a time; breadcrumb band #F1F1F1 with "Home" #0099CC; header: small line 13 px, logo ~120x68, bag and user icons, search 42 tall with the filter inside and a yellow 100 px Search button; fixed bottom bar Menu / Search / Home / My Cart / Me.
- *Done:* new `lib/widgets/product_page.dart` (`SiteTopBar`, `BreadcrumbBar`, `ShareButtons`, `DiscountBadge`, `PriceBlock`, `AddToCartRow`, `FeatureBox`, `SiteAccordion`, `SiteBottomBar`, and the `Site` color/size constants); `buyer_product_screen.dart` rebuilt from them. Our social comments sit in the tab titled "What people are saying" (open by default when the product has posts), "More Information" holds brand, category, description and the source link, "More Seller" says "No Other Seller Selling this Product". "Home" in the breadcrumb and the bottom bar goes back. The cart, wish list, share buttons, search, bag, user, menu and "Store Location / Track Order" only look the part and say "This is a preview. It is not connected yet." The earlier `PreviewHeader` was removed.
- *New data:* `Product.oldPrice` (0 = none), `discountPercent`, saved in JSON (older saves load as 0); optional "Old price before discount" box in the product form (must be higher than the selling price); `applyProductEdit(oldPrice:)`. New `test/discount_test.dart`; `social_sections_test` now touches the product name instead of the old heading (the heading is a tab that opens and closes). 124 tests; the layout test (tiny phone, largest fonts) caught two overflows (the small header line, the bottom bar), both fixed.
- *Search bar removed (owner, same evening):* the website's search bar was taken out of the buyer preview header (it did nothing there). The Home screen's search bar (real: it opens Products with the text) stays. The comments tab is open by default only when the product has posts; the owner could not find the comments in the first screenshots because the test product had none; then built at the owner's yes as a blue underlined line under the price; the owner said it "looks ugly" and asked for a glimpse at the bottom instead. **Now:** a strip above the bottom bar (`CommentsPeek` in `product_page.dart`): the commenter's round initial, "12 comments" ("1 comment" when one) and the first real comment in quotes on one line, with a blue chevron. It shows only when the product has comments and the comments tab is not yet on screen; tapping it opens the "What people are saying" tab and scrolls to it (`SiteAccordionState.show`), and it steps aside once the tab is reached (a scroll listener in `buyer_product_screen.dart`). **Bug found by the test and fixed:** the page was a lazy `ListView`, so on a phone the comments tab was not built yet and the tap scrolled nothing; the page is now a `SingleChildScrollView` with a `Column` (everything built). Lesson: a scroll animation needs several frames in a test (pump 100, 100, 600). `test/comments_link_test.dart` (3 tests). 127 tests.
- *Owner's feedback after trying the 1.0.33+34 look (same day), all done in the source, no new APK yet:* (1) the glimpse strip "looks ugly" and its down arrow annoyed the owner: redesigned (`CommentsPeek` is now stateful): a round initial, a grey chat bubble with the commenter's name, the site ("Facebook") and one comment on one line, and a yellow "See all >" button with the count ("7 comments"); no down arrow. (2) It now **swaps the comment every 6 seconds in shuffled order** (`Timer.periodic`, fade and slide, a fresh shuffle once all have been shown, never repeating the last one; does not rotate with only one comment; the timer stops when the strip is hidden or the page closes; an optional `random` parameter on `BuyerProductScreen` makes the shuffle predictable in tests). (3) The comments section "felt not connected": `SocialTabs`, `ProofCard`, `CommentBubble` got a `flat` option used only on the buyer page (the seller's Social proof screens keep the old look): no box or shadow, the page's grey (#F4F4F4), a yellow tab indicator and count chip, rounder grey bubbles with 15 px text, a flat "See all N comments" button, and the page's blue (#0099CC) for "View original post". 4 tests in `comments_link_test.dart` (rotation and no-repeat checked). 128 tests.
- *Design audit of the comment strip and section (owner: "feels off, not connected, be professional"), done in the source after 1.0.34+35 (that APK still has the older look):* the ui-ux-pro-max skill's search script could not run (Python is not installed here), so its written checklist (`references/pro-rules.md`) was the standard, plus the website's measured tokens. Findings and fixes: (1) rounded 8 px chat bubbles and pill chips, but the site is square-ish (inputs 3 px, buttons 2 px) -> comments are plain list rows (square 2 px initial, name 15/500, text 15/400, thin #E5E5E5 lines), post box is a white row with a 1 px #D9D9D9 border and 2 px corners; (2) weights 600-800 and sizes 11-14, but the site uses 400/500 and 15 (small 13-14) -> max weight 500, body 15, small 13; (3) the strip was a second floating card above the menu bar -> `SiteBottomBar(above:)`: strip and bar share one white surface, one shadow (the site's `0 -1px 3px` + `0 -1px 2px`), strip has a thin bottom divider; (4) two-line 11 px "See all / 7 comments" button -> one line "See all (7)", 15/500, yellow #FCB800, 2 px corners, 44 px high, like "Add To Cart"; (5) contrast: #999 on white is 2.9:1 and #0099CC is 3.1:1 -> new `Site.muted` #666 (5.7:1) and `Site.linkText` #0077A3 (5:1) for small text (the site's own #999 for the SKU and closed tabs was kept for 1:1 fidelity); (6) auto-rotation had no pause and ignored reduced motion -> pauses while a finger is on the strip, does not rotate when the phone asks for reduced motion, screen readers get one button label ("See all N comments. <name> says: <text>"); (7) tab chips and per-site colors -> plain text tabs "TikTok (4)" on grey bars, yellow 3 px marker on the open one (an icon version squeezed two labels smaller than the third, caught in the after-check, icons removed); (8) the hint paragraph above the tabs was removed (the note below the list says the same). `CommentAvatar(square: true)` added. Tests: 130 (new: pause on touch, no rotation under reduced motion; tab labels in `social_sections_test` are now "TikTok (7)").
- *Buyer preview bottom bar removed (owner, after trying 1.0.35+36):* the website's five-button bar (Menu, Search, Home, My Cart, Me) is gone from the buyer preview; the owner wants it to focus on the product, since anything a buyer taps will go to the website. `SiteBottomBar` was deleted. Only the comments strip stays stuck to the bottom (it keeps the website bar's shadow and respects the phone's bottom edge); it is gone once the comments are reached, and absent when there are no comments. The way back is the breadcrumb "Home" and the phone's back gesture. **Bug caught by checking the picture:** with the bar gone the strip's yellow button stretched to the full screen height (a `Container` with `alignment` grows to fill the height it is offered; the old bar's box had been holding it down); fixed with a `Center(heightFactor: 1)`, and a test now requires the strip to be under 90 px high. 130 tests. No new APK yet (1.0.35+36 still has the bar).
- *Attention nudges (owner: "continuous nudge ... minor, fixed delays, not spam"), source only, no APK yet (1.0.36+37 does not have them):* the comments strip **hops up 6 px every 9 s** (a 0.5 s arc) and the Add To Cart button **wiggles 3 px each side every 13 s** (two swings, 0.45 s). All numbers live in `NudgeTiming` (`product_page.dart`). Rules (agreed with the owner in plain words): different rhythms (9 and 13) so they rarely meet, and a shared `NudgeLock` so they never move at the same moment (a nudge that finds the other one busy skips that turn); only the picture shifts (`Transform.translate`, no layout change); paused while a finger is on the element; **no movement when the phone asks for reduced motion** (kept on purpose although the owner said "no matter the situation": that setting protects people it makes dizzy); the strip's timer lives only while the strip is on screen. The first nudge comes one full interval after the page opens (9 s, 13 s). Tests in `test/nudge_test.dart` (6): lock, hop timing and size, wiggle timing and size (never more than 3 px), reduced motion, finger pause, two nudges never together. Test lessons: a big clock jump starts an animation but gives it no frames, so step time in 100 ms frames; and `open()` already uses 0.4 s of the first interval. 136 tests.
- *Known differences from the website:* share icons are letters ("f", "t", "G"), the bag/heart/menu icons are Material icons, not the site's icon font; the site's newsletter and footer, the red chat bubble and the star-rating form are not copied (the comments replace the reviews); in-stock text is black like the site's.
- *Next:* an APK to try it on the phone; ask the manager whether she wants the footer; consider reading the old price when importing a product link (not checked).

**2026-11-20 (later), buyer preview header** (not committed; version stays 1.0.32+33)
- *Asked:* the manager wants "literally the website in the app" (the owner refused a web view; the owner likes the product link import). Decision: make the **buyer preview** look like the website's **phone** product page, in steps. Checked the live phone page: site header (small line "Store Location | Track Order", logo + bag and user icons, search bar with the yellow button), grey "Home / name" trail, title, "SKU:", three share buttons, photo with an orange "-50%" badge, "Vendor : A2Z2GO", orange price with the old price struck through, stock line, grey box with the four badges, newsletter and footer. Also found: the "theme" email was signed by the manager but sent from a shared "Dev" mailbox; unclear who meant what, the owner will ask whether she wants the look or the paid MartFury Flutter template (made for Botble, not Magento).
- *Done (step 5, header):* `PreviewHeader` in `lib/widgets/site_header.dart` at the top of `buyer_product_screen.dart` (replaces the plain "Buyer preview" app bar): small text line, back arrow + red tag logo + bag and user icons, search bar with the yellow button. The text line, bag, user and search only show "This is a preview. It is not connected yet." The search bar code is shared with the Home header (`_SearchRow`). 122 tests.
- *Next (agreed order):* breadcrumb, share buttons, photo with a discount badge, the grey badges box (buyer side only), old price struck through (needs a new optional old-price field, filled by the seller or later by Magento; check if the link importer can read it).

**2026-11-20, Martfury look, step 1** (version 1.0.32+33; APK 1.0.32+33 built and uploaded after solving a Java loopback problem, see below; not committed, the owner said to hold the commit)
- *Asked:* the manager uses the a2z2go.com website in phone view and wants the app to look and feel the same ("Martfury" is the website's theme; she sent a Google search about the MartFury Flutter template, not a purchase). The website runs on Magento (confirmed: its code names Magento and Martfury, not Botble). Decision with the owner: **recreate the Martfury look in Flutter** (colors, flat shapes, search bar, bottom bar, tiles); do not buy or use the paid MartFury Flutter template (it is made for a different backend, Botble). The Magento connection waits for dev2 (down: a missing `Ced\AdvanceSearch` seller class).
- *Website look (checked on the live phone view):* white page, red `#E30500` logo, yellow Search button, orange-red prices, Work Sans, square corners, bottom bar Menu / Search / Home / My Cart / Me, banner slideshow, badges (min order, 7-day return, secure payment).
- *Done (step 1):* `lib/core/theme.dart`: corner sizes now 2/4/6/8 (were 8/12/16/24), white page, cards get a thin line, bottom-bar pill removed; `dashboard_screen.dart`: white page and a flat red header. Already matching before: red, yellow, Work Sans.
- *Done (step 2):* Home now starts with the website header: the red tag logo, a search bar and a yellow Search button (`lib/widgets/site_header.dart`); searching opens the Products tab with that text (`ProductsScreen.queryFrom`). The bottom bar now follows the website's order: **Menu, Products, Home, Orders, Me** (the website's "Search" is our Products, its "My Cart" is our Orders, because a seller has no cart). New `lib/screens/menu_screen.dart` (Menu tab: Insights, Expenses, Loyalty points). Insights is no longer a tab; `Tabs.insights` (99) opens it as a page. `Tabs` numbers changed (menu 0, products 1, home 2, orders 3, me 4). Tests updated: `app_flow_test` opens Insights through the Menu; the layout test passes `onSearch` so the header is checked at tiny size and largest fonts. 122 tests.
- *Done (step 3):* Home now has, under Quick actions, a "Your products" section with up to 6 tiles in two columns (`lib/widgets/site_blocks.dart`: `ProductTile`, `ProductGrid`): square photo, name (2 lines), orange-red price (`Brand.price` #D92B00, the site's orange darkened to read on white), "Out of stock" note; "See all" opens Products; a tile opens the product page. Rows grow with the text so large fonts do not overflow (the layout test covers it at tiny size and largest fonts). 122 tests.
- *Badges removed (owner):* the website's four badges (minimum order of ₱350, 7 days return, secure payment, 24/7 support) were first added to Home and then taken out the same day: they are for buyers and do not apply to the seller side. Rule: the seller screens do not show buyer promises; adjust again once the seller side of the website is known.
- *Owner's verdict after step 4:* "still does not feel like the website", but good enough for now; adjust later when the seller side of the website (dev2) is seen. The owner asked for a build to test on the phone.
- *APK build trouble, SOLVED (read this before building):* `flutter build apk --release` stopped after a few seconds with "java.io.IOException: Unable to establish loopback connection" (Gradle's client could not talk to its own daemon). It was NOT the company firewall (my first guess was wrong) and NOT the Java version. The stack trace showed Java's internal pipe (`PipeImpl`) first tries a Unix-domain socket file in the temp folder, and `connect` failed with "Invalid argument"; this computer's TEMP is a Windows short path (`C:\Users\DAVID~1.BEN\AppData\Local\Temp`; the user name has a dot). **Fix: build with the environment variable `JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=C:\Users\David.Benitez\javatmp`** (a plain folder; in PowerShell: `$env:JAVA_TOOL_OPTIONS="-Djdk.net.unixdomain.tmpdir=C:\Users\David.Benitez\javatmp"; flutter build apk --release`). It applies only to that command. Done during the search: a fresh Temurin JDK 21 (fingerprint checked) was unpacked to `AppData\Local\Programs\jdk21\x\jdk-21.0.13+9` and Flutter's `jdk-dir` now points to it (the old Temurin 17 is still in `Programs\jdk17`). Another trap: a failed build leaves the OLD `app-release.apk` in `build/app/outputs/flutter-apk/`; check its date before copying it anywhere (one old APK was copied by mistake on 2026-11-20, caught at once, deleted, never uploaded).
- *APK 1.0.38+39 built 2026-11-20 16:49 (57 MB)* with the `JAVA_TOOL_OPTIONS` fix (sample products share the sample page link and QR); file date checked before copying; copied to the Desktop as `A2Z2GO-Seller-v1.0.38+39.apk` and uploaded to the shared Drive folder ("upload complete"; storage 10.61 to 10.66 GB after a reload); the old 1.0.37+38 file was moved to the Bin; local server stopped. Not committed (owner said to hold the commit); not yet tried on a phone. Drive shows 71% full (the Bin counts; the owner decides about emptying it).
- *APK 1.0.37+38 built 2026-11-20 13:29 (57 MB)* with the `JAVA_TOOL_OPTIONS` fix (the attention nudges: comments bar hops every 9 s, Add To Cart wiggles every 13 s); file date checked before copying; copied to the Desktop as `A2Z2GO-Seller-v1.0.37+38.apk` and uploaded to the shared Drive folder ("upload complete"; storage 10.55 to 10.61 GB after a reload); the old 1.0.36+37 file was moved to the Bin; local server stopped. Not committed (owner said to hold the commit); not yet tried on a phone. Drive is still at 70% full (the Bin counts; see the note under 1.0.36+37).
- *APK 1.0.36+37 built 2026-11-20 13:16 (57 MB)* with the `JAVA_TOOL_OPTIONS` fix (the buyer preview without the five-button bottom bar; only the comments strip at the bottom); file date checked before copying; copied to the Desktop as `A2Z2GO-Seller-v1.0.36+37.apk` and uploaded to the shared Drive folder ("upload complete"; storage 10.49 to 10.55 GB after a reload); the old 1.0.35+36 file was moved to the Bin; local server stopped. Not committed (owner said to hold the commit); not yet tried on a phone. **Drive storage is at 70% (10.55 of 15 GB):** every APK moved to the Bin still counts until the Bin is emptied (about 57 MB each, 6 or more in the Bin now); the owner may want to empty the Bin (permanent delete, so only the owner decides).
- *APK 1.0.35+36 built 2026-11-20 11:52 (57 MB)* with the `JAVA_TOOL_OPTIONS` fix (it has the design-audit changes: strip and bar as one bar, plain-row comments, text tabs, pause and reduced-motion handling); file date checked before copying; copied to the Desktop as `A2Z2GO-Seller-v1.0.35+36.apk` and uploaded to the shared Drive folder ("upload complete"; storage 10.44 to 10.49 GB after a reload); the old 1.0.34+35 file was moved to the Bin; local server stopped. Not committed (owner said to hold the commit); not yet tried on a phone. The Desktop still holds the older APKs (1.0.32+33, 1.0.33+34, 1.0.34+35); they are the owner's files, not deleted.
- *APK 1.0.34+35 built 2026-11-20 11:29 (57 MB)* with the `JAVA_TOOL_OPTIONS` fix (the redesigned comment strip that swaps a shuffled comment every 6 seconds, and the flat comments section); file date checked before copying; copied to the Desktop as `A2Z2GO-Seller-v1.0.34+35.apk` and uploaded to the shared Drive folder (Drive said "upload complete"; storage grew 10.38 to 10.44 GB after a reload); the old 1.0.33+34 file was moved to the Bin; local server stopped. Not committed (owner said to hold the commit); not yet tried on a phone. Method that worked: new empty staging folder per build (no deleting), drop the file on the Drive page, wait in steps of at most 10 s without reloading, then reload once to confirm.
- *APK 1.0.33+34 built 2026-11-20 11:11 (57 MB)* with the `JAVA_TOOL_OPTIONS` fix; file date checked before copying; copied to the Desktop as `A2Z2GO-Seller-v1.0.33+34.apk` and uploaded to the shared Drive folder (storage grew by about 57 MB, which confirmed the upload finished); the old 1.0.32+33 file in Drive was moved to the Bin. Not committed (owner said to hold the commit); not yet tried on a phone. Lessons from this upload: the browser tool's wait is capped at 10 s (a 15 s wait was rejected, and reloading the Drive page right after cancelled the upload, so it had to be redone); and a safety check blocks `rm` on a variable path, so use a fresh staging folder instead of cleaning the old one.
- *APK 1.0.32+33 built 2026-11-20 09:12 (57 MB)*, copied to the Desktop as `A2Z2GO-Seller-v1.0.32+33.apk` and uploaded to the shared Google Drive folder; the old 1.0.31+32 file was moved to the Bin (upload first, then bin; local server stopped). Not committed (owner said to hold the commit). Not yet tried on a phone.
- *Left out on purpose:* the banner slideshow (no real pictures yet; they will come from Magento) and the old price + "-50%" badge (the Product model has no old/special price; add one when the Magento connection brings it, not before, to avoid a field nobody can fill).
- *Done (step 4):* the buyer product page (`buyer_product_screen.dart`) now follows the website's product page order: title, "SKU: … · brand", "Vendor : shop", the orange price (`Brand.price`), then the stock line (In stock / Only N left / Out of stock, in green / amber / red). The price chips and the separate "Seller" row were removed (the vendor line says the same). 122 tests.
- *Not changed:* the seller's own product detail page (`product_detail_screen.dart`, edit and stock buttons); it is a working screen, not a shop page.
- *Next steps:* the Products tab as a tile grid, the seller product page if the manager wants it closer to the site, then the Magento connection once dev2 is back.
- *How the screenshots were made:* a temporary widget test drew the screens to PNG (needs the Material icon font loaded from the Flutter SDK; tests do not load it by themselves); the test file was deleted. A Windows Firewall pop-up for `adb` appears when Flutter starts; Cancel is fine (managed by the company, tests do not need it).

**2026-11-19, manager emails and the dev2 test website** (documentation only, version stays 1.0.31+32)
- *Asked:* after the demo email, the manager wrote about a seller ("Kegg", Marikina) that does not show in the website's search by seller name or city, then asked "how can seller registration be made online to match the app?". The owner replied (polite, plain words) that the app is test mode with data only on the phone, that the website and its backend belong to another team, and asked what exactly she means and for complete instructions.
- *What we found:* the a2z2go.com seller registration page ("Start Selling", OTP and captcha) has no city field; the app has no seller registration with a city (only an optional store address for pickup). The two do not match, and the app has no online database. Nothing in the app was changed.
- *Outcome (from the owner, after a meeting):* the owner has no access to the website's backend. The manager told them to call a phone number to get a test login for the **dev2 a2z2go website** (a test copy, no rollout yet) so they can test against it. The owner will ask for it by Viber/phone. **Do not write the login, password or phone number in this repo (public).**
- *Screenshots:* 8 screenshots of the emails and website pages were uploaded to a "Screenshots" folder inside the shared A2Z2GO Drive folder (the owner chose that place; anyone with the folder link can open them).
- *Open:* get the dev2 address and a test account; find out what the website registration and search need (city field, how sellers appear in search); decide with the owner and manager whether the app should register sellers online (needs a backend). Test only on dev2.

**2026-11-19, emailing the demo and tidying Drive** (documentation only, version stays 1.0.31+32)
- *Asked:* how to email the video and PDF to the manager, and organise the Drive folder so the owner shares a link to the video, not the file.
- *Done:* the owner sends the PDF as an attachment (1 MB) and the 40-second video as a Drive link (the file's "view" link). A copy-paste subject and body were written for the owner. Nothing was sent by the AI. In Drive, three empty subfolders the AI made were moved to the Bin; no demo file was moved or deleted.
- *Lessons (Drive):* a subfolder created from the throwaway editor account does NOT inherit the A2Z2GO folder's "anyone with the link" sharing, so moving files into it would hide them from the link (Drive warns "Change who has access?"). Files inside A2Z2GO inherit editor link access. The owner should create subfolders and a view-only link from their own account. In the Drive list, selection can lag a screenshot behind; always check what is selected before pressing Delete (a shift-click once also selected the APK).
- *Open:* the owner should test the video link in a private window; set the link to Viewer if the boss should only watch.

**2026-11-19, app tour video and picture doc** (documentation only, version stays 1.0.31+32)
- *Asked:* the owner shared a 91-second phone screen recording of the app (in their Drive folder, no sound) and asked for screenshots, a picture doc, and an edited video with captions, for an impatient manager: simple words, catch attention, English. The repo is public.
- *What the video shows (watched frame by frame):* add a product by pasting an a2z2go.com link (autofill), add a Facebook post, the app reads 3 comments, "Add comments yourself", the product page, the buyer preview with the "What people are saying" tabs (Facebook 3, TikTok 25, YouTube 6), then a check against the real Facebook post, the real TikTok video and the real YouTube video: the comments match. This is the "real comments for buyers" feature the whole project built toward.
- *Done:* downloaded the video (70 MB) to the owner's Downloads\A2Z2GO-video folder; installed ffmpeg for the user only (downloaded from the maker's site, fingerprint checked; winget could not reach its server); made a 39-second SHORT video (title card, 4 numbered steps, proof clips sped up, end card; red cards and big white captions) and a 98-second FULL captioned version; uploaded both to the owner's Drive folder next to the original (the original was left untouched). Made 6 screenshots in `docs/tour/` and `APP_TOUR.md` (picture first, plain words). Linked from the README, `APP_WALKTHROUGH.md` and the notes index.
- *Privacy choices (public repo):* the phone's top bar was cropped off, the shop-owner name row was blurred, and no screenshots of the real Facebook, TikTok or YouTube pages (other people's names) went into the repo. The videos are NOT in the repo (size, and they show the owner's first name and real commenters' names); the Drive folder link is not written in the repo because that folder is editable by anyone with the link.
- *How the video was made (to redo it):* ffmpeg `trim` + `setpts` (speed) + `drawtext` per clip, joined with `concat`; caption text in small text files; 720x1600 output, no sound. A caption plan (start, end, speed, text) was kept in a small script.
- *PDF (redone after the owner's feedback):* `docs/A2Z2GO-Seller-App-Showcase.pdf` (2 A4 pages, made by printing an HTML page with Edge headless; also in the owner's Downloads\A2Z2GO-video folder and the Drive folder). The first version read like an advertisement ("for people in a hurry", "what does the app do?", "want more?"). The owner said the real task was to **show existing social media comments on the product page as proof**. The PDF and `APP_TOUR.md` now read like a work showcase for a manager: The task, What was built, Example product (with the real a2z2go.com link https://a2z2go.com/shield-bath-soap-120g.html), How the seller adds it, What the buyer sees, Result (a table: Facebook 3, TikTok 25, YouTube 6, all the same as the real posts, with the links to the three original posts), Limits. The links were checked: the a2z2go page answers and is titled "Shield Bath Soap 120g"; the TikTok short link goes to the same video; the Facebook and YouTube links answer. The old `A2Z2GO-App-Tour.pdf` was replaced by `A2Z2GO-Seller-App-Showcase.pdf` (new name so the two cannot be mixed up). Same privacy rules as the screenshots.
- *Lesson:* two caption plans must never share file names (the short video once got the full video's captions).
- *Open:* the owner may want a blurred copy of the videos (they show the first name and public commenters' names) before sharing wider.

**2026-11-13, app walkthrough for the owner's manager** (documentation only, version stays 1.0.31+32)
- *Asked:* a detailed step-by-step explanation of the whole app, from start to finish, to email to the owner's boss; make it an .md, commit and push.
- *Done:* new `APP_WALKTHROUGH.md` in the repo root: the app in one minute, install, 15 numbered steps (sign-in, Home, add product, product page and stock, find products, create and move orders, returns, expenses, loyalty, Insights, social proof, sharing and the buyer page, Me and sample data, backup/sign-out/erase), rules the app enforces, how it is built, what is not done, next steps, a 10-minute demo script and a glossary. Every screen name, button label, default (loyalty ₱100 = 1 point, 1 point = ₱1), status and limit was checked against the code before it was written. Linked from `README.md` and `notes/INDEX.md`; `CLAUDE.md` now says to keep it in step with feature changes.
- *Decision:* written for a non-technical reader, honest about limits (test-mode sign-in, data only on the phone, buyer cart is a placeholder, Android only, tested on one phone). No personal details, accounts or file paths in it.
- *Open:* no screenshots in it (none are stored in the repo); the owner may want pictures for the email.

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
- Connecting to the A2Z2GO website (likely Magento) belongs with the backend work below. A test copy
  (the "dev2" website) is promised by the manager; test only there, never on the live site. The seller
  registration page there has no city field, which is probably why sellers do not show in search by city.
- **Magento connection, what the public docs say (2026-11-20, owner tested the 1.0.32+33 look on a phone and had no
  preference for the next step, so this no-code research was chosen):** standard Magento has a REST API
  (`POST /rest/<store>/V1/products` etc.) and the user type decides access: admin and integration tokens can create
  products, customers and guests are limited to their own or public resources. **Never put an admin or integration token
  inside the app** (anyone can pull it out of the APK); a seller-scoped login or a small server in between is needed. The
  site's seller sign-up is the CedCommerce marketplace add-on (`csmarketplace` in the address, `Ced\AdvanceSearch` in the
  error page); I found no public documentation of a seller REST API for it, so the dev team must say whether one exists.
  Questions for the dev team: (1) does the Ced marketplace offer a seller login/token and endpoints to add products and
  register sellers, or must the app talk to a small server we build? (2) can a seller account be given only its own
  products? (3) where is the city stored and can the registration collect it? Ready-made apps for such stores exist (for
  example MageNative's "Advance Seller App"); not checked whether it fits this site.
- Pick the next feature or fix with the owner.
- When a backend exists: real `OtpSender`, replace local storage in `AppStore`.
- Before publishing (not now): release keystore via git-ignored `android/key.properties`,
  privacy policy hosted at a public URL, privacy/data page in app, store listing.

## 8. Change log (newest first; add an entry for every change)

| Date | Commit | What changed |
|------|--------|--------------|
| 2026-11-20 | (this commit) | **Sample share page (web), published on GitHub Pages** (`gh-pages` branch, sample data only): `web/` folder, `lib/share_web.dart` (web entry with the 20 sample products, made-up comments on three of them, a "Sample preview" bar), `BuyerProductScreen(share:)` and `PreviewTaps` (on the shared page every button opens the product's website link); the app's share link and QR for sample products now open that page (`share_sheet.dart`, a note under the QR); decisions: the website stays untouched, our own page holds the comments, one published exception to "no deployment yet" approved by the owner; 143 tests; version 1.0.38+39 |
| 2026-11-20 | 211d7fb | **Buyer page 1:1 with the website's phone product page** (header without search, breadcrumb, share buttons, photo with discount tag, orange price and struck old price, quantity and Add To Cart, badges box, grey tabs with our comments where the website has Reviews) plus the comments glimpse strip stuck to the bottom (rotating shuffled comment every 6 s, yellow "See all (N)" button, pause on touch, still under reduced motion); the five-button bottom bar was removed from the preview; design audit of the strip and the comments section (flat rows, text tabs, the page's greys and yellow, readable contrast); small attention nudges (strip hops every 9 s, Add To Cart wiggles every 13 s, never together, none under reduced motion); new optional old price on products; page changed to a scroll view so the comments can always be scrolled to; APK build fix (JAVA_TOOL_OPTIONS) written down; research notes on the Magento connection; 136 tests; version 1.0.37+38 |
| 2026-11-20 | b4e3c7b | **Martfury look, steps 1 to 4**: flatter corners, white page, thin card lines, flat red header; website-style header with yellow search on Home; bottom bar Menu / Products / Home / Orders / Me with a new Menu screen (Insights, Expenses, Loyalty points); a product tile grid on Home; buyer product page in the website's order (title, SKU, vendor, orange price, stock); notes on the dev2 site and the Magento decision; 122 tests; version 1.0.32+33 |
| 2026-11-19 | (this commit) | **Email and Drive notes** (documentation only): how the demo video (as a Drive link) and the showcase PDF are emailed, and the Drive sharing lessons; earlier "(this commit)" rows marked squashed; history squashed into one fresh commit; version 1.0.31+32 |
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
| 2026-11-19 | squashed | **App tour**: `APP_TOUR.md` with 6 screenshots in `docs/tour/` (made from the owner's screen recording); captioned short and full videos made with ffmpeg and saved to Downloads and the Drive folder (not in the repo); documentation only |
| 2026-11-13 | squashed | **App walkthrough** (`APP_WALKTHROUGH.md`): a plain-language step-by-step tour of the whole app for the owner's manager, linked from README and the notes index; documentation only |
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
