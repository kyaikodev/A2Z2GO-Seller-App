# A2Z2GO Seller: full inspection (REVIEW.md)

Reviewer note: inspection only. No project code was changed. This run was done by the Sonnet 5.5 model
(not Fable 5.2). Screenshots are in `review/screens/`. Probe tests and the web build were run in a scratch
copy of the project, never in the project itself.

> Later work (comment readers for Facebook, TikTok, Instagram and YouTube, the social tabs, notes rules) is not
> part of this review. See the Session log in `PROJECT_CONTEXT.md`.

## 0. Status after the fix pass

| Finding | Status |
|---------|--------|
| F1 to F5 | Fixed (F1 to F3 earlier; F4 undo + restock option; F5 hide instead of delete) |
| F6 | Mostly: tabs built only when opened, reports cached, data now in one file per seller (atomic write, grouped saves, migrated from preferences). A real database is still a backend-time decision |
| F7 | Fixed: cookies cleared on sign-out and delete-account, debug buttons only in debug builds, message size capped |
| F8, F9, F10, F11 | Fixed |
| F12 | Mostly: header contrast, hint colour, 44 dp links, comment-remove button, chart screen-reader summary. The invisible OTP field is unchanged on purpose (it is the real input) |
| F13 | Fixed for charts and the Net profit tile (calm dark for sales, green/red for profit/loss). Prices and totals stay brand red; decide whether to change that |
| F14 | Partly: loyalty rules, product edits and expense edits now go through `AppStore`. Social-post and comment list edits still happen in screens |
| F15 | Fixed (version field, UTC times, old saves still load) |
| F16 | Fixed by hiding the tool unless the shop is empty (or debug build). Demo records are still untagged |
| F17 | Fixed (photos saved on the phone at product save, decode size capped, http to https). Not run on a real phone |
| F18, F19 | Fixed (return form has no unsaved-changes guard; it is short) |
| F20 | Mostly: unused `Sp` tokens removed and all inline font sizes snapped to a 9-step scale; not yet taken from theme text styles |
| F21, F22 | Fixed, except the Cupertino font note (unverified, left alone) |
| F23 to F27 | Done in a second pass: backup and restore (photos not included), edit order details, Undo for expenses and comments (not other deletes), points on orders, id-based share link |

## 1. Summary

**Overall health: good v1 with solid core logic, but money/points edges, a misleading comment picker and
several missing safety nets need fixing before real sellers rely on it.** 60 of 60 tests pass,
`flutter analyze` is clean, all dependencies are current, the web build compiles, and the Android release
build worked earlier. Code is tidy and consistent. The design looks clean and branded, but generic.

The 5 things that matter most:
1. **A return can refund any amount** (₱100,000 on a ₱360 order is accepted), driving sales and points far
   negative (F1).
2. **Loyalty points are reversed at today's rate**, so changing the rate makes balances negative (F2).
3. **The "positive comment" picker thinks "Not good at all" and "Hindi sulit, di legit" are positive**,
   and auto-ticks them for display to buyers (F3).
4. **Irreversible one-tap actions**: "Mark completed" on the order list has no confirm and no undo, and
   undoing it by deleting the order permanently loses the stock (F4).
5. **Scale**: every save rewrites the whole store and rebuilds all 5 tabs. At 10,000 orders the save alone
   took 156 ms on a PC (likely 0.5 to 1 s+ on a phone) (F6). Fine today, a wall at a few thousand orders.

Verified (probes P1 to P8, run on a scratch copy): tone classifier, number formatting, refund bounds, points
reversal, product delete with open order, completed-order delete, best-seller revenue, and 10k-order scale.
Not verified: behaviour on a real phone (keyboard, TalkBack, low-end performance), DST/time-zone effects,
web view on real Facebook/TikTok pages.

**Good, please do not "improve" these:** the AppStore stock/loyalty/return flows are internally consistent
(snapshots on order items, every stock change through `_move`), per-account data isolation, all-or-nothing
load with a backup copy, `r2()` money rounding, `FormActionBar` + keyboard-padded sheets, `EmptyState` and
`Skeleton`, reduced-motion handling, the layout test matrix (tiny phone and largest fonts), and the broad
logic tests. The brand tokens in `theme.dart` are a good foundation.

## 2. Findings table

| ID | Sev | Area | Title | Files |
|----|-----|------|-------|-------|
| F1 | Must | Money | Return refund has no upper limit | `store.dart:364`, `return_form_screen.dart:124` |
| F2 | Must | Points | Points reversal uses the current earn rate | `store.dart:411` |
| F3 | Must | Content | "Positive" comment picker misreads negatives | `comment_tools.dart:150` |
| F4 | Should | Data/UX | Completing an order is one tap, no undo; deleting it loses stock | `orders_screen.dart:356`, `store.dart:301,328` |
| F5 | Should | Data | Deleting a product strands open orders | `store.dart:162` |
| F6 | Should | Scale | Whole-store save and all-tab rebuild on every change | `store.dart:93`, `shell.dart:59` |
| F7 | Should | Privacy | In-app browser keeps third-party login and exposes a debug copy button | `import_comments_screen.dart` |
| F8 | Should | Reliability | No global error handling; spinner can hang forever | `main.dart:28` |
| F9 | Should | UX | Stock in/out sheet is not scrollable | `product_detail_screen.dart:411` |
| F10 | Should | Reports | Best-seller revenue ignores refunds | `reports.dart:114,130` |
| F11 | Should | UX | Order search misses the phone format shown on screen | `orders_screen.dart:153` |
| F12 | Should | A11y | Contrast, tap-target and screen-reader gaps | several |
| F13 | Should | UX | Red means "good" and "bad" at once | `bar_chart.dart`, `analytics_screen.dart:96` |
| F14 | Should | Architecture | Screens edit models directly, bypassing AppStore | several |
| F15 | Should | Backend-readiness | No schema version; times saved without offset | `models.dart` |
| F16 | Should | Product | Demo-data tool visible to every seller, untagged | `my_store_screen.dart:111` |
| F17 | Should | Perf/UX | Remote photos are never saved; thumbnails decode full size | `common.dart:303` |
| F18 | Polish | Visual | Alignment, spacing, truncation, dialog and copy defects | several |
| F19 | Polish | Forms | No unsaved-changes guard, next-field or autofill | forms |
| F20 | Polish | Design system | Spacing tokens unused; 112 inline font sizes | `theme.dart` |
| F21 | Polish | Link import | Currency, charset, size and http handling | `link_import.dart` |
| F22 | Polish | Misc | `pesoShort` edge, chart label, DST (unverified), font warning | several |
| F23 | Proposal | Product | No backup or export of data that lives only on the phone | none |
| F24 | Proposal | Product | Edit orders, status timeline, payment status, shipping fields | orders |
| F25 | Proposal | UX | Undo for destructive actions | global |
| F26 | Proposal | Product | Redeemed points do not affect any order | loyalty |
| F27 | Proposal | Backend | Share link uses the SKU, which is not unique across sellers | `share_sheet.dart:12` |

## 3. Findings in detail

### Must fix

**F1. Return refund has no upper limit** (confirmed, probe P3)
- **Where:** `lib/data/store.dart:364` (`createReturn` only rejects `refund < 0`), `lib/screens/orders/return_form_screen.dart:124` (`moneyValidator`).
- **What is wrong:** The refund box is pre-filled from the items but can be edited to any number, and many returns can each refund the full order.
- **Proof:** Order total ₱360, return 1 item with refund ₱100,000, approve: net sales shows -₱99,640 and the customer's points go to -997. (Probe P3.)
- **Fix:** In `createReturn` (and re-check in `approveReturn`) reject when `refund > order.total - sum(refunds of this order's non-rejected returns)`. In the form, use the same limit in the validator and show "Up to ₱X can still be refunded".
- **Test:** `createReturn` with refund above the remaining amount fails; two returns whose refunds sum above the order total: the second fails.
- **Risk / effort:** S. Low risk; a seller who genuinely wants to over-refund (goodwill) would be blocked, so consider a clearly labelled "extra goodwill" field instead.
- **Depends on:** none.

**F2. Points reversal uses the current earn rate** (confirmed, probe P4)
- **Where:** `lib/data/store.dart:411` (`approveReturn`: `pts = (r.refund / loyalty.pesoPerPoint).floor()`).
- **What is wrong:** Points are earned at the rate in force when the order completed, but reversed at whatever the rate is when the return is approved. If loyalty is disabled at that moment, nothing is reversed at all.
- **Proof:** Order of ₱360 earns 3 points at ₱100/point. Seller changes the rule to ₱10/point. A ₱180 refund reverses 18 points: balance goes from 3 to -15. (Probe P4.)
- **Fix:** Store the earn rate on the earn transaction (or on the order), and reverse proportionally: `pointsEarnedForOrder * refund / order.total`, floored, never below the customer's balance for that order. Reverse even when loyalty is currently off.
- **Test:** Earn at rate A, change to rate B, return half: reversal equals half of the earned points.
- **Risk / effort:** M. Touches `LoyaltyTxn` (add `rate` or `orderTotal`), keep old saves loading (null means "use current rate").
- **Depends on:** F15 (if you add a schema version at the same time).

**F3. "Positive" comment picker misreads negatives** (confirmed, probe P1)
- **Where:** `lib/data/comment_tools.dart:150` (`classifyComment`), word lists at `:29` and `:86`; auto-ticking in `import_comments_screen.dart` (`_show`).
- **What is wrong:** It matches substrings and ignores negation. "Positive" comments are ticked automatically and then shown to buyers as "What people are saying".
- **Proof (probe P1):** "Not good at all" -> positive. "Hindi sulit, di legit" -> positive. "not recommended" -> positive. "Hindi ko recommend" -> positive. "Chocolate ang sarap" -> negative (contains "late"). "Breakfast was great" matches "fast" and "great".
- **Fix:** (1) Match whole words, not substrings. (2) If a negation word (`not`, `no`, `hindi`, `di`, `ayaw`, `never`, `walang`) appears within 3 words before a positive word, treat as negative. (3) Do not auto-tick anything; only suggest, or tick only when confidence is clear. (4) Keep the seller-review step.
- **Test:** The 8 phrases above with expected tones; "Fast delivery!" stays positive.
- **Risk / effort:** S to M. A simple rule-based fix will still be imperfect; the real fix is not auto-selecting (see Blind spots, item 2).
- **Depends on:** none.

### Should fix

**F4. Completing an order is one tap with no undo; deleting it loses the stock** (confirmed by code and probe P6)
- **Where:** `lib/screens/orders/orders_screen.dart:356` (big "Mark completed" button beside the Total, no confirmation), `lib/screens/orders/order_detail_screen.dart:78`, `lib/data/store.dart:301` (`advanceOrder`), `:328` (`deleteOrder`).
- **What is wrong:** An accidental tap records the sale, awards loyalty points and cannot be reversed. The only way out is Delete, which for a completed order does not put stock back.
- **Proof:** Stock 10, order of 4 completed, then deleted: stock stays 6. (Probe P6.)
- **Fix:** Add a confirm for the final step ("Mark completed?"), or a 5-second Undo in the snackbar that reverts status, points and completion date. Also offer "Put the items back in stock" when deleting a completed order.
- **Test:** Complete then undo: status, points, report numbers restored. Delete completed with "restore stock": stock back.
- **Risk / effort:** M. Needs a small "revert" path in the store.
- **Depends on:** F25.

**F5. Deleting a product strands open orders** (confirmed, probe P5)
- **Where:** `lib/data/store.dart:162` (`deleteProduct`), `:313` (`_restoreStock` skips missing products).
- **What is wrong:** Delete is allowed while orders or returns still reference the product. Later, cancelling the order says "The items go back into stock" but nothing happens, silently.
- **Proof:** Product with a pending order of 3 is deleted; the order is cancelled; no stock move exists anywhere. (Probe P5.)
- **Fix:** If any open order or pending return uses the product, block delete and offer "Hide product" instead (`active = false`), or confirm with a warning.
- **Test:** Delete blocked with an open order; allowed after the order is completed or cancelled.
- **Risk / effort:** S.
- **Depends on:** none.

**F6. Whole-store save and all-tab rebuild on every change** (confirmed, probe P8)
- **Where:** `lib/data/store.dart:93` (`_commit` encodes everything), `lib/screens/shell.dart:59` (`IndexedStack` keeps all 5 tabs built; each reads the store, so all rebuild on every change; Dashboard builds 2 reports, Insights 1).
- **What is wrong:** Cost per action grows with total history.
- **Proof (probe P8, desktop PC):** 10,000 orders, 1,000 products, 10,000 moves and 10,000 loyalty rows: payload 7.9 MB; synchronous part of one save 156 ms; one 30-day report 46 ms; 12-month report 29 ms; Snapshot 3 ms. A phone is typically 3 to 6 times slower, so roughly 0.5 s per save plus about 0.3 s of rebuild per tap, plus Android writing a 7.9 MB preferences file. At 1,000 orders it is about 0.8 MB and ~15 ms (fine).
- **Fix:** Short term: add the comment `shortcut: whole-store save, upgrade past ~2,000 orders` and cache `Report`/`Snapshot` per store version so hidden tabs do not recompute. Real fix: a database (SQLite/Drift) or the backend, saving only the changed rows (README already plans this inside AppStore).
- **Test:** A benchmark test with 5,000 orders that fails above a time budget.
- **Risk / effort:** L for the database; S for caching.
- **Depends on:** F14, F15.

**F7. In-app browser keeps third-party login and exposes a debug copy button** (confirmed by code; behaviour on device unverified)
- **Where:** `lib/screens/products/import_comments_screen.dart:102` (JavaScript unrestricted), `:104` (channel `A2ZGrab` open to every page), `:220` and `:445` ("Copy debug info"), no cookie clearing anywhere in `lib/`.
- **What is wrong:** (a) The seller can log into Facebook/TikTok inside the app's web view; those cookies persist and are never cleared on sign-out or account delete, so a second seller on the same phone inherits the first one's session. (b) "Copy debug info" copies the first 1,500 characters of the visible page text (can include the logged-in user's name and notifications) to the clipboard, with the wording "Paste it to your helper" (a developer tool in a seller screen). (c) Any page, even a frame on the loaded page, can call the JavaScript channel and inject fake comments.
- **Proof:** `grep` finds no `WebViewCookieManager`, `clearCookies` or `kDebugMode` anywhere in `lib/`.
- **Fix:** Clear web view cookies/storage on sign-out, delete-account and when leaving the import screen; hide the debug buttons unless `kDebugMode`; ignore channel messages after the first valid one and cap their size.
- **Test:** Unit-test the message parser with oversized and repeated messages; manual check that cookies are gone after sign-out.
- **Risk / effort:** S.
- **Depends on:** none.

**F8. No global error handling; spinner can hang forever** (confirmed by code)
- **Where:** `lib/main.dart:28` (`FutureBuilder` never checks `snap.hasError`); no `FlutterError.onError`, `runZonedGuarded` or `PlatformDispatcher.onError` anywhere (0 matches).
- **What is wrong:** If `SharedPreferences.getInstance()` fails (full storage, corrupted file), the app shows the loading spinner forever with no message. Any uncaught error leaves no trace.
- **Proof:** Reading `main.dart`: the builder shows `_Splash` whenever `!snap.hasData`, including on error.
- **Fix:** Handle `snap.hasError` with a "Something went wrong. Try again" screen; add a top-level error hook that logs locally (and later reports to a crash service).
- **Test:** Widget test with an auth future that throws shows the error screen.
- **Risk / effort:** S.
- **Depends on:** none.

**F9. Stock in/out sheet is not scrollable** (likely; not reproduced on a device)
- **Where:** `lib/screens/products/product_detail_screen.dart:411` (`showStockSheet`: a plain `Column` inside bottom-inset padding).
- **What is wrong:** With the keyboard open on a short phone, a title, a 3-line hint ("Damaged / lost"), two fields and a button can exceed the free height and overflow. The same pattern was fixed in the points sheet; this one was missed.
- **Proof:** Sibling sheets (`expenses_screen.dart:145`, `my_store_screen.dart:275`) wrap the column in `SingleChildScrollView`; this one does not.
- **Fix:** Wrap the `Column` in `SingleChildScrollView`.
- **Test:** Widget test at 320x568 with `viewInsets.bottom = 260` finds no overflow.
- **Risk / effort:** S.
- **Depends on:** none.

**F10. Best-seller revenue ignores refunds** (confirmed, probe P7)
- **Where:** `lib/data/reports.dart:114` (revenue added) and `:130` (returns only subtract quantity).
- **What is wrong:** Totals and the best-seller list disagree after a refund.
- **Proof:** 4 sold at ₱100, 2 refunded: net sales ₱200, best seller shows "2 sold, ₱400". (Probe P7.)
- **Fix:** Subtract the refund share from the product's revenue in the same loop.
- **Test:** The probe case as a regression test.
- **Risk / effort:** S.
- **Depends on:** none.

**F11. Order search misses the phone format shown on screen** (confirmed, probe P2)
- **Where:** `lib/screens/orders/orders_screen.dart:153` (`o.customerPhone.contains(q)` against `+639…`); the Returns tab ignores the search box entirely (`_returnsList`).
- **What is wrong:** The app shows "0917 123 4567" but stores "+639171234567".
- **Proof:** `'+639171234567'.contains('09171234567')` is `false`. (Probe P2.)
- **Fix:** Compare digits only, and normalise the typed query with `normalizePhone` when it looks like a number. Apply the search to returns too.
- **Test:** Search "0917 123" finds the order.
- **Risk / effort:** S.
- **Depends on:** none.

**F12. Contrast, tap-target and screen-reader gaps** (confirmed by calculation and code)
- **Where and proof:**
  - `dashboard_screen.dart:123,134`: `Colors.white70` text on brand red `#E30500` is about 2.8:1 (needs 4.5:1). Affects "Sales today" and the greeting.
  - `theme.dart:214`: hint colour `#8E919B` on white is about 3.2:1.
  - `dashboard_screen.dart:339` ("View all", "See all", "Insights" links): about 20 dp tall; no padding (needs 48 dp).
  - `proof_screen.dart:224`: delete-comment "x" is about 26 dp, with no confirmation or undo.
  - `bar_chart.dart`: drawn on a canvas with no `Semantics`, so a screen reader sees nothing.
  - `auth_screens.dart:245`: the invisible code field is still in the accessibility tree next to the visible boxes.
- **Fix:** Use `Colors.white` at full opacity or a lighter red tint with larger text; darken hint colour to `#6B6F7A` or better; wrap links in `InkWell` with min 48 dp height; add `Semantics(label: 'Sales per day: Thu ₱4,800 ...')` to the chart; `ExcludeSemantics` on the invisible field.
- **Test:** `tester.getSemantics` on the chart; a contrast test over `Brand` colour pairs.
- **Risk / effort:** S to M.
- **Depends on:** none.

**F13. Red means "good" and "bad" at once** (confirmed visually, `review/screens/09-insights-360.jpg`)
- **Where:** `lib/widgets/bar_chart.dart` (positive bars `Brand.primary #E30500`, negative bars `Brand.bad #C62828`), `lib/screens/analytics/analytics_screen.dart:96` (positive Net profit uses brand red, negative uses the nearly identical error red), prices and totals also in brand red.
- **What is wrong:** Brand red is used for normal good numbers and also for losses and errors, so a loss day is almost indistinguishable by colour from a good day, and "Out of stock" red chips sit next to red prices. Meaning relies on bar direction alone.
- **Proof:** Screenshot: Sales bars are all red; the Profit chart shows green bars and tiny red bars below the line; the Net profit tile icon is red while Net sales is green.
- **Fix:** Reserve red for problems. Use a neutral dark colour or the brand's secondary for money amounts and positive bars; keep green/red only for profit/loss. Add value labels for negative bars.
- **Test:** Visual check; a golden test of the chart with a negative value.
- **Risk / effort:** M. Needs an owner decision on brand use (see Blind spots, item 1).
- **Depends on:** none.

**F14. Screens edit models directly, bypassing AppStore** (confirmed by code)
- **Where:** `loyalty_screen.dart:51,52,118` (`l.pesoPerPoint = ...`), `product_form_screen.dart:337` (`editing..sku = ...`), `expenses_screen.dart:233`, `proof_screen.dart:146,226,385` (list edits), and `AppStore.updateProduct/updateExpense/saveLoyaltyConfig` are just "please save".
- **What is wrong:** The README says swapping to a backend "is contained to AppStore". In practice screens mutate objects in place and then call a save, so a backend would need changes in many screens, and validation can be skipped (the F-style bug fixed earlier for SKU came from this).
- **Fix:** Give each edit a store method that takes values and validates (`updateProductFields(id, ...)`, `setLoyaltyRules(...)`, `removeComment(...)`), and make model fields read-only outside the store over time.
- **Test:** Store-level tests for each method (invalid input returns `Result.fail` and changes nothing).
- **Risk / effort:** M to L, do gradually.
- **Depends on:** none; helps F6, F15.

**F15. No schema version; times saved without offset** (confirmed by code)
- **Where:** `lib/data/store.dart:93` (payload has no `version`), `lib/data/models.dart` (`toIso8601String()` on local `DateTime`s, no offset), `Product.fromJson` handles one legacy field ad hoc.
- **What is wrong:** The next model change has no safe migration hook. Local-time strings are ambiguous when synced to a server or when the phone changes time zone.
- **Fix:** Add `"version": 1` to the saved JSON and a `_migrate(json)` step; save times as UTC (`toUtc().toIso8601String()`) and read with `.toLocal()`.
- **Test:** Load a version-less fixture and a version 1 fixture; round-trip a time across zones.
- **Risk / effort:** M. Must keep old saves loading.
- **Depends on:** none.

**F16. Demo-data tool visible to every seller, untagged** (confirmed visually, `review/screens/04-me-360.jpg`)
- **Where:** `lib/screens/store/my_store_screen.dart:111`, `lib/data/store.dart:646`.
- **What is wrong:** A real seller sees "Load sample data" above Sign out. One confirm adds about 20 products, 17 orders, a return and expenses to the real shop, distorting analytics. Only comments carry a `demo` flag; products, orders and expenses do not, so the only cleanup is "Erase all shop data", which also erases the real records.
- **Fix:** Show it only in debug builds or only on an empty shop, and tag demo records so a "Remove sample data" action can delete just those.
- **Test:** Load then remove sample data leaves real records untouched.
- **Risk / effort:** S to M.
- **Depends on:** none.

**F17. Remote photos are never saved; thumbnails decode full size** (confirmed by code)
- **Where:** `lib/widgets/common.dart:303` (`Image.network`) and `:313` (`Image.file`), `product_form_screen.dart:251` (autofill adds remote URLs and keeps them as URLs).
- **What is wrong:** (a) Imported product photos stay as web addresses: offline or if the source page changes, they vanish. (b) Neither image widget sets `cacheWidth`, so a 56 dp thumbnail decodes a 1280 px photo (about 5 MB of memory each). (c) `abs()` in link import accepts `http://` images; Android blocks cleartext traffic by default so they show a placeholder.
- **Fix:** On save, download remote photos into the app's folder (reuse `_persist`); pass `cacheWidth: (size * devicePixelRatio).round()`; upgrade `http://` image URLs to `https://`.
- **Test:** Unit-test the URL upgrade; a widget test that `ResizeImage` is used.
- **Risk / effort:** M.
- **Depends on:** none.

### Polish

**F18. Visual and copy defects** (confirmed in screenshots)
- Quick-action icons misalign when a label wraps: "Add product" sits about 13 px higher than the others (`dashboard_screen.dart:432`; `03-dashboard-empty-360.jpg`). Same cause on product detail at 320 px: "Stock value" wraps and its number rises (`13-product-detail-320.jpg`, `product_detail_screen.dart:301`). Fix: `crossAxisAlignment: start` and fixed label height.
- Me tab: the "Inventory value" card touches the "Load sample data" tile (no gap) (`my_store_screen.dart:100-111`; `04-me-360.jpg`).
- Order cards truncate the date to "Nov 11, 2026 · 11:00 ..." so AM/PM is lost (`orders_screen.dart:281`; `07-orders-360.jpg`); the search hint "Search order #, customer or ..." and the helper "Add it so this customer earns loyalty..." are cut (`11-new-order-360.jpg`). Fix: shorter text (drop the year), allow two lines.
- Dialogs: Cancel and the confirm button are both red text, so there is no primary/secondary hierarchy (`common.dart:44`).
- Naming: tab says "Products", screen says "My Products"; tab "Insights"; "Me" with title "Me".
- Edit forms show "1250.0" and "99.0" (`product_form_screen.dart:72`, `expenses_screen.dart:126`). Use the same formatter as autofill.
- Product detail puts the daily actions (Stock in/out/Damaged/Count) below a long "Buyer page" block (`12-product-detail-360.jpg`). Fix: move the four buttons above it.
- Sign-in copy says "We will text you a code" while the app is in test mode (`auth_screens.dart:110`).
- **Test:** Golden/screenshot tests for these screens at 320 and 360 px.
- **Risk / effort:** S each.

**F19. Forms: no unsaved-changes guard, next-field or autofill** (confirmed by grep)
- 0 uses of `PopScope` outside the shell; `textInputAction` only 2 uses (sign-in), `autofillHints` 3. Back on the long Add Product form discards everything silently; Enter does not move to the next field.
- **Fix:** `PopScope` with a "Discard changes?" dialog on forms with edits; `textInputAction.next` + focus nodes; hints for name/phone.
- **Test:** Widget test: edit then back shows the dialog.
- **Risk / effort:** S to M.

**F20. Design tokens are defined but bypassed** (confirmed by count)
- `Sp` spacing tokens: 0 uses outside `theme.dart`. 112 inline `fontSize:` literals in screens/widgets using 19 different sizes (10.5 to 40). 9 inline `Color(0x…)` literals. Only 5 uses of `Theme.of(context).textTheme`.
- **Fix:** Use text styles from the theme (and add `statLabel`, `caption`); delete `Sp` or adopt it; define a type scale of about 8 sizes. This also makes a font-scale or rebrand a one-file change.
- **Risk / effort:** M, mechanical. Do it together with F13/F18.

**F21. Link import details** (confirmed by code)
- `link_import.dart:60`: `res.body` has no size cap (a huge page loads into memory) and `package:http` decodes as Latin-1 when the header has no charset, garbling UTF-8 names and the "₱" sign on such sites. `link_import.dart:153`: the price is taken from JSON-LD without checking `priceCurrency`, so a USD 29.99 price would be filled in as ₱29.99.
- **Fix:** Stream with a 2 MB limit and decode UTF-8 (`allowMalformed`); only autofill the price when currency is PHP or absent, else show the value with a warning.
- **Test:** `parseLinkInfo` fixture with `priceCurrency: USD`.
- **Risk / effort:** S.

**F22. Small items**
- `format.dart:27`: `pesoShort(999999)` returns "₱1000K" (also 999,500 to 999,999); should roll to "₱1.0M" (confirmed, probe P2).
- Chart tooltip on the 30-day range shows only the day number ("5: ₱1,000"), with no month (`reports.dart:42`).
- `reports.dart:15` (`Period.days`) subtracts `Duration(days: n-1)` from local midnight; in a time zone with daylight-saving the start can land at 23:00 or 01:00 and shift a day bucket. Unverified (this machine cannot change zone); the Philippines has no DST, so low impact.
- After removing `cupertino_icons`, the web build prints "Expected to find fonts for (MaterialIcons, packages/cupertino_icons/CupertinoIcons)". Likely harmless (the app only imports the iOS page-transition class), but confirm on a device that nothing renders a Cupertino icon (unverified).
- Dashboard "Sales today" is net of refunds approved today, so it can read lower or negative on a day with an old-order refund; label it "Net sales today" or show refunds separately.

### Proposals (not bugs)

**F23. No backup or export.** All business records live only in the phone's app storage ("Your shop data stays on this phone"). Uninstall, clearing data or a lost phone is a total loss, and Android's automatic backup is on by default but invisible and limited. Cheap: export a JSON/CSV file to share (no backend needed) plus an import. Highest-value missing feature.

**F24. Orders are not editable and have no timeline.** A typo in the customer's phone sends loyalty points to the wrong person and can only be fixed by deleting and recreating. Cheap: edit customer name, phone and note on non-completed orders (change phone before completion only). Also missing: status history with times, payment status (COD unpaid), shipping fee, delivery address, tracking number, tap-to-call/message. Needs no backend.

**F25. Undo for destructive actions.** Deleting products, orders, returns and comments confirms but cannot be undone (and the comment "x" does not even confirm). A snackbar Undo (keep the object for 5 seconds) covers all of them. Cheap.

**F26. Redeeming points does nothing to an order.** `pesoPerPointValue` is only displayed; "Redeem" lowers the balance but nothing links to a discount on an order. Add "Use points" in the new-order form that sets the discount and writes the redeem transaction together.

**F27. Share link uses the SKU.** `share_sheet.dart:12` builds `https://a2z2go.com/p/<sku>`; two sellers can both have SKU-0001, and the domain is a placeholder that does not serve the page yet (the sheet says "Preview only"). When the backend exists, use a shop id plus product id.

Other proposals (cheap to medium, no backend): barcode scan for product lookup and stock-in, receipts as PDF/image, low-stock push reminders, a customers screen (all buyers, order history, notes), product variants, order filters by date/payment, onboarding checklist (exists on Home), pull-to-refresh not needed. Needs a backend: real OTP/SMS, multi-device sync, buyer storefront and cart, online payments.

### Deferred by owner (not reviewed as findings)
- Release signing (still the debug key), store listing, public privacy policy and an in-app privacy page.
- Real SMS sign-in (the code is shown on screen in test mode, so sign-in is not protection yet).
- Any CI for publishing.

## 4. UI/UX assessment

**Verdict:** A clean, consistent, brand-aware Material 3 app. First impression is competent but template-like: big red header, soft cards, heavy (700 to 800 weight) headings, generic Material icons and placeholder icons in place of product photos. It does not look amateur; it looks like a good starter kit. It will read as "professional" once it gains (1) a restrained colour system where red is rare, (2) data-first screens (stock and money at a glance) instead of marketing-style blocks, (3) real imagery, and (4) fixes for the small alignment and truncation defects below.

**Top 5 changes for perceived quality, in order:**
1. Fix colour meaning (F13): red only for problems and primary actions; use a calm neutral or the secondary yellow/navy for money and charts.
2. Fix the visible alignment, spacing and truncation defects (F18) and make text styles come from the theme (F20).
3. Make the daily-use screens operational-first: product detail actions first (F18), order cards with the phone number and tap-to-call, a status timeline on order detail (F24).
4. Safety nets: undo and confirm on irreversible actions, unsaved-changes guards (F4, F19, F25).
5. Accessibility basics (F12): contrast on the red header, 48 dp targets, a text summary for charts.

**Design-system proposal (build on `theme.dart`):**
- *Colour roles:* `primary` (brand red, buttons and the active tab only), `onSurface` (near-black, all money), `muted` (secondary text, at least 4.5:1), `positive` (green), `negative` (use a different red from brand, or add an icon), `info` (blue, links), `accent` yellow (highlights, test-mode notes). Money amounts are navy/black, never brand red.
- *Type scale (8 sizes, from theme):* display 40 (hero number only), headline 24, title 18, subtitle 16, body 14, label 12.5 (min), caption 12 (min). Remove 10.5, 11, 11.5, 13.5, 19, 26, 32 sizes.
- *Spacing scale:* use the existing `Sp` 4/8/12/16/24/32; screens padding 16, card padding 16, gaps 12.
- *Radii:* 12 for cards and inputs (`Rd.md`), 24 for sheets, 20 for chips; remove 8/10/14 variants.
- *Shared components to add or extract:* `StatTile` with fixed label height; `QuickAction`; `AmountText`; `ConfirmDialog` with primary/secondary buttons; `UndoSnackbar`; `AppSheet` (scrollable, keyboard-padded) used by every bottom sheet; `Pill`/chip with named parameters; `SectionHeader`.

**Screen-by-screen (most impactful first):**
- *Dashboard* (`05-dashboard-360.jpg`): header fine; make "Sales today" contrast pass (F12); quick actions aligned (F18); show refunds separately (F22); chart bars neutral (F13).
- *Insights* (`09-insights-360.jpg`): Net profit tile and bars colour (F13); label chart days with month on 30-day range (F22); add a text summary under each chart (F12).
- *Product detail* (`12-product-detail-360.jpg`): move Stock in/out/Damaged/Count above "Buyer page"; collapse Buyer page into one row; show margin and stock value on one line.
- *Orders* (`07-orders-360.jpg`): shorter date, status chip below name on narrow widths, confirm or undo on "Mark completed", phone shown and searchable.
- *Order form* (`11-new-order-360.jpg`): helper text on two lines; show line total live; add "Use points" (F26).
- *Me* (`04-me-360.jpg`): spacing fix; move Load sample data out of the main list (F16); group Erase/Delete under a "Danger zone" header.
- *Sign-in* (`01-sign-in-360.jpg`, `02-otp-360.jpg`): good; the test-mode box is clear. Fix the "We will text you" copy while in test mode.
- *Not visually reviewed (need a device):* camera/gallery sheets, web view import, buyer preview with real photos, share QR sheet, loyalty and expenses screens (read in code only).

## 5. Suggested fix order

1. **Batch A, money/points integrity** (store only, safest, highest value): F1, F2, F5, F10. Re-test: logic tests, the existing "returns" and "loyalty" groups, report numbers.
2. **Batch B, misleading content and search**: F3, F11. Re-test: `product_proof_test`, `import_comments_test`, order search.
3. **Batch C, safety nets**: F4 (with F25 undo), F8, F9, F19. Re-test: `app_flow_test`, `screens_layout_test`, add keyboard-inset layout test.
4. **Batch D, privacy hygiene**: F7, F16. Re-test: manual cookie check after sign-out; sample data add/remove.
5. **Batch E, visual polish**: F13, F18, F12, F20, F22. Re-test: layout tests plus new goldens at 320/360/600 px.
6. **Batch F, scale and backend-readiness** (do when data volume or the backend arrives): F6, F14, F15, F17, F21, then proposals F23 to F27 as the owner chooses (F23 backup first).

## 6. Blind spots and questions for the owner

1. **Brand:** are red/yellow/navy and Work Sans fixed? F13 needs a decision on how much red to keep.
2. **Social-proof feature, risk to decide on:** the app copies other people's public comments (names and text) from Facebook/TikTok/YouTube by scripting a web view, then shows only the "positive" ones to buyers. Automated collection can breach those sites' terms (and risk the seller's account); republishing people's names/comments raises data-privacy questions; and showing only selected positive comments as "what people are saying" can be seen as misleading advertising in some jurisdictions. I have not given legal advice. Suggest: link to the original posts (embed) instead of copying text, show all or a representative sample, or get consent. This may change which fixes are worth doing (F3, F7).
3. **Who uses the app:** one seller per phone, or shared devices? (affects F7, F16, sign-in).
4. **Expected volume:** how many orders per month? (F6 urgency; my assumption was a few hundred to a few thousand.)
5. **Data loss tolerance:** is it acceptable that uninstalling the app deletes the business? (F23.)
6. **Over-refunds and goodwill:** should a seller ever refund more than the item price? (F1.)
7. **Assumptions I made:** Philippines only (peso, +63 numbers, English UI); Android only; the owner will add a backend later; the "buyer page" is a future feature.

## 7. Not read / not verified

- **Read fully:** every file in `lib/` except `sample_data.dart` (skimmed the first 40 lines; it is plain data) and `comment_tools.dart` (read lines 1 to 330 of 490; the rest is the Facebook text parser covered by `real_page_test.dart` and `product_proof_test.dart`).
- **Skimmed, not read line by line:** all test files (read the list of test names and the sizes, plus the bits quoted above), `grab_script.dart` (read fully, but its behaviour on live sites was not run).
- **Not run on a device:** camera/gallery, web view import, keyboard behaviour (F9), TalkBack, performance on a real phone, Android Auto Backup, DST/time zones (F22).
- **Screens not visually reviewed:** import-comments, share sheet, buyer preview with photos, loyalty, expenses, return forms, sheets (read in code only).
- **Toolchain results (this run):** `flutter analyze`: no issues. `flutter test`: 60 passed. `flutter pub outdated`: all direct and dev dependencies up to date. Web release build: succeeded (with the Cupertino font warning, F22). Probe tests P1 to P8 passed as measurements (they print results and are not part of the project).
