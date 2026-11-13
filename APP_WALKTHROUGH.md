# A2Z2GO Seller: step-by-step walkthrough

**What this document is:** a plain-language tour of the whole app, from first launch to daily use, written so that
someone who has never seen it can follow along. It describes what exists today, what it does not do yet, and what
comes next.

**App version described:** 1.0.31 (build 32) · **Date:** 13 November 2026 · **Platform:** Android phone

---

## 1. The app in one minute

A2Z2GO Seller is a phone app for a small online seller. In one place the seller can:

- keep a **product catalogue** with photos, prices and stock;
- take and track **orders** from "new" to "delivered";
- handle **returns and refunds**;
- record **expenses**;
- reward repeat customers with **loyalty points**;
- see **sales and profit** at a glance;
- show **proof that the product is real**: public comments from Facebook, TikTok, Instagram and YouTube posts;
- **share a product** with buyers (link, QR code, chat apps) and preview exactly what the buyer will see.

Everything is stored **on the seller's phone**. There is no server yet (see section 6).

### At a glance

| | |
|---|---|
| Platform | Android (built with Flutter, so an iPhone version is possible later) |
| Where data lives | On the phone only, saved automatically |
| Sign-in | Mobile number + one-time code (the code is shown on screen for now) |
| Currency | Philippine peso (₱); phone numbers are Philippine mobiles |
| Automated checks | 122 automatic tests pass; the code analyser reports no problems |
| Main screens | Home · Orders · Products · Insights · Me |
| Tested on | The owner's Android phone. Not yet tested on iPhone or on many different Android phones |

---

## 2. Before you start

1. **Install the app.** Copy the app file (`A2Z2GO-Seller-v1.0.31+32.apk`) to an Android phone and open it. Android may
   ask to allow installing from your files or browser; allow it for this one install.
2. **Internet** is needed only for four things: autofilling a product from a web page, reading comments from social
   posts, loading product photos from a link, and sharing. Everything else works offline.
3. **Optional demo data:** a brand-new shop can load a ready-made sample shop (see step 14), which makes a good demo.

---

## 3. The walkthrough, step by step

### Step 1: Sign in

1. Open the app. The first screen says **"Welcome, seller"**.
2. Type a Philippine mobile number (for example `0917 123 4567`) and tap **Send code**. A new number creates a new
   account automatically.
3. The next screen, **"Enter your code"**, shows the code on screen because the app is in **test mode** (no text message is
   sent yet). Tap **Fill in** to enter it, then **Verify and continue**.
4. A new seller is asked **"What is your name?"** and then continues to the Home screen.
5. The app remembers you. You stay signed in until you choose **Sign out** (step 15).

### Step 2: The Home screen

The bottom bar has five tabs: **Home, Orders, Products, Insights, Me**.

Home shows, from top to bottom:

- a greeting (Good morning / afternoon / evening) with the seller's name;
- **Net sales today**, the one big number;
- an **Orders** card with a **View all** link;
- **Quick actions**: **Add product** and **New order**;
- **Sales · last 7 days**, a small chart;
- **Stock alerts**: products that are low or out of stock.

A brand-new shop sees **"Get your shop going"** instead: three steps (add your first product, put stock on the shelf,
record your first order).

### Step 3: Add a product

Products tab → **Add product** (or Quick actions on Home).

1. **Autofill from a link (optional shortcut).** Paste the address of a product page (for example from a2z2go.com) and
   tap **Autofill**. The app fills in the name, price, description and photos. Everything can still be edited.
2. **Photos.** Add up to 8 photos from the camera or gallery. The first one is the cover. Tap a photo to change it.
3. **Product details.** Fields marked with a red `*` are required:
   - **Product name \***
   - **Category \*** : tap to open a list of categories that already exist (plus a starting list such as Household,
     Personal Care, Health Care, Electronics). Type a new one and tap **Add** if it is not there.
   - **Brand** (optional): same kind of list, filled from brands already used.
   - **SKU \*** : a unique product code, suggested automatically (for example `SKU-0004`). Two products cannot share one.
4. **Price and stock.** **Selling price \***, **Your cost \***, **Opening stock \*** and **Low-stock alert at \*** (the
   number at which the app starts warning).
5. **Description.** Buyers read this. It is needed (at least 20 letters) before the product can be shared.
6. **Active** switch. A hidden product cannot be added to new orders.
7. Tap **Add product**. If a required field is empty, it turns **red with a message**, the screen **scrolls to the first
   missing field**, and the red clears as you type. Nothing is saved until the required fields are filled.

> **The "ready to share" rule.** A product can be saved without a photo or a description, but it cannot be shared with
> buyers until it has **at least one photo and a description of 20 letters or more**. Until then its page says "Not ready
> yet. Needs a photo and a description."

### Step 4: The product page and stock

Tap a product in the list. The page shows the photo, name, code and category, the price, the description (long text is
folded behind **Read more**), and four small facts: **In stock, Cost, Margin, Stock value**. If no cost was entered, it
says **Not set** rather than showing a made-up margin. A warning appears when stock is running low or sold out.

Four buttons change stock, and **every change is written to the stock history**, so the numbers always add up:

| Button | Use it for |
|---|---|
| **Stock in** | New stock arrived |
| **Stock out** | Stock removed for another reason |
| **Damaged** | Damaged or lost items (counted as a loss in Insights) |
| **Count** | A recount: type the real number and the app records the correction |

Orders reduce stock automatically; cancelling an order puts it back. The **Stock history** list at the bottom shows each
move with its date. The pencil icon edits the product; the three-dot menu deletes it (a product that is on an open order
cannot be deleted, but it can be hidden).

### Step 5: Find products

Products tab: search by **name or SKU**; tabs for **All, Low stock, Sold out, Hidden**; and a row of **category pills**
("Any category" plus each category in use).

### Step 6: Create an order

Orders tab → **Create an order** (or **New order** on Home).

1. **Customer.** Name and mobile are optional, so a walk-in buyer can stay nameless. Tap the name box to pick a **past
   customer**; picking one fills in their mobile number.
2. **Items.** Add products and quantities. The app will not let you sell more than the stock you have.
3. **Payment.** Choose **Cash, GCash, Maya, Bank transfer or COD** (cash on delivery); add a **discount** and a **note** if
   needed. If the customer has loyalty points, they can be used here.
4. The total updates as you go. Tap **Create order**. The app confirms **"Order created. Stock has been reserved."**

### Step 7: Move an order along

Orders tab: search, and tabs **All, To Ship, Shipping, Completed, Cancelled, Returns** (with counts for what needs
attention). Open an order and use the big button at the bottom:

**Pending → Mark as packed → Mark as shipped → Mark as completed**

Other options on the order page: **Cancel order** (stock goes back), **Record a return** (step 8), and delete (from the
menu, with a warning). When an order is completed and the customer's mobile number was entered, they **earn loyalty
points** (step 10).

### Step 8: Returns and refunds

From an order, tap **Record a return**. Choose the items and a reason (**Damaged item, Wrong item sent, Not as
described, Changed mind, Other**). The refund amount is limited to what can still be refunded on that order, and the screen
says how much is left. Open the return from the **Returns** tab to **approve or reject** it; an approved return can put
the items back into stock. Loyalty points earned on the refunded part are reduced to match.

### Step 9: Record expenses

Me tab → **Expenses**. Add what was spent: **What was it for? \***, **Amount \***, a **category** (Shipping & packaging,
Rent & utilities, Advertising, Salaries, Supplies, Fees & taxes, Other) and an optional note. Removing an expense offers
an **Undo**. Expenses feed straight into the profit numbers in Insights.

### Step 10: Loyalty points

Me tab → **Loyalty points**. The programme is **on by default** with simple rules that can be changed and saved:

- **Spend ₱100 to earn 1 point**;
- **1 point is worth ₱1** when redeemed.

Points are earned when an order that has the customer's mobile number is completed. The **Customers** list shows each
customer's points; open one to **Redeem**, **Adjust**, or read the **History**. A seller can also add points by hand.

### Step 11: Insights (sales and profit)

Insights tab, with **7 days / 30 days** switches. It shows **Net sales** and **Net profit** up top, then:

- **Profit statement**, line by line: Gross sales, Discounts given, Refunds, **Net sales**, Cost of goods sold, Damaged /
  lost stock, Expenses, **Net profit**, and Average order;
- **Best sellers**;
- **Expenses by category**;
- **Inventory value**, at cost and at selling price.

All numbers are worked out from the seller's own records; nothing is estimated or made up.

### Step 12: Social proof (comments from real posts)

Product page → **Buyer page → Social proof**. This is how a seller shows buyers that other people talk about the product.

1. Tap the **+** button and paste a link to a public post (Facebook, Instagram, TikTok or YouTube). Only add public
   comments, and always keep the link to the original post.
2. On the post's card, tap **Add comments**. A **Get comments** screen opens, the app opens the post inside itself
   and **reads the comments automatically**.
3. A list appears: **"Choose what to keep"**. Positive comments are ticked for you. You can **Select positive**,
   **Select all**, **Clear**, **Show positive only**, or put **Positive first**. Tap **Add** to keep the ticked ones.
4. If a site cannot be read (for example Shopee or Lazada), or reading fails, the app says so in plain words and offers
   **Add comments yourself**: type a **Name** and a **Comment** (both required), tap **Add this comment**, repeat, then
   **Done**. A **Paste many at once** option accepts a long copied list.

What the automatic reader can do today:

| Site | Result |
|---|---|
| Facebook | Reads the comments that load on the post |
| TikTok | Reads the linked video's comments |
| Instagram | Reads the **newest** comments (up to about 25 without a login); they change every few seconds, so the list will not match the post a minute later |
| YouTube | Reads the main comments (not the replies under them) |
| Other sites | Not supported; use "Add comments yourself" |

### Step 13: Share a product with buyers

Product page → **Buyer page → Share and preview** (available once the product has a photo and a description).

- A **link** and a **QR code** for the product;
- one-tap buttons for **Messenger, Facebook, Viber, WhatsApp** and **More** (the phone's own share menu, with the cover
  photo attached), plus **Copy link**;
- **Preview as buyer**: shows exactly what a buyer will see.

The **buyer page** shows the product photos, price, name, the seller, the description, and a section
**"What people are saying"**: the social proof as **tabs** (Facebook, TikTok, Instagram…) that can be tapped or
**swiped**, each showing three comments, a link to the original post, and a **See all** button for the rest. If nothing
is touched for a few seconds, the next tab opens by itself.

> **Honest note:** if the product was imported from a web page, the link points to that real page. Otherwise it is a
> placeholder address that becomes a real page once the shop server exists. The **Add to cart** button on the buyer page
> is a placeholder for now.

### Step 14: The Me tab and demo data

The **Me** tab holds the seller's profile (editable with the pencil), **Loyalty points**, **Expenses**, **Backup**, and:

- **Load sample data** (shown only while the shop is empty, so it can never mix with real records). It fills the shop
  with about **20 real A2Z2GO products with photos, 17 orders from the last 10 days, a return and a few expenses**, so
  every screen has something to show. Everything can be edited or deleted.

### Step 15: Back up, sign out, erase

- **Backup → Back up my data** sends a copy of the records to the seller themselves (photos are not included).
  **Restore a backup** replaces the shop's records with a backup file, after a clear warning.
- **Sign out** keeps all the shop's data on the phone for the next sign-in.
- **Danger zone:** **Erase all shop data** and **Delete account**. Both ask for confirmation, say plainly that they
  cannot be undone, and are kept away from everyday buttons.

---

## 4. Rules the app enforces for you

- A product code (**SKU**) can only be used once.
- Required fields must be filled before saving, and they are marked in red when missing.
- You cannot sell, or take out, more than the stock on hand; every stock change is recorded, so history always adds up.
- A refund can never be more than what is left to refund.
- Hidden products cannot be added to new orders; a product on an open order cannot be deleted.
- Sample data can only be loaded into an empty shop.
- Destructive actions (delete, erase, restore) always ask first.
- A corrupted save is set aside and the app starts clean instead of showing half-loaded data.

---

## 5. How it is built (short, non-technical)

- **One code base** (Flutter) for the whole app. This is why an iPhone version is possible later.
- **All shop data is one organised record on the phone**, saved automatically after every change. Moving to a real
  database later only changes one part of the app.
- **The comment readers** open the public post in a small built-in browser inside the app and read what a person would
  see. Each site (Facebook, TikTok, Instagram, YouTube) loads comments differently, so each has its own reading steps.
- **Quality checks:** 122 automatic tests (money, stock, orders, returns, forms, screens on small phones with large
  text, the comment readers' logic) and a code analyser, both clean. A written project log records every change.

---

## 6. What is not done yet

| Not done | Why / what it needs |
|---|---|
| **Real text-message sign-in** | Needs an SMS service; the code is shown on screen for now |
| **A server and shared database** | Everything is on one phone today; a server is needed for several devices and for buyers |
| **A real buyer shop and cart** | The buyer page is a preview; "Add to cart" is a placeholder |
| **Buyers adding comments** | Needs a server, a way to identify buyers, moderation and spam limits |
| **Website link to a2z2go.com products** | The website probably runs on its own store software; connecting belongs with the server work |
| **iPhone version** | Needs a Mac and an Apple developer account; the readers need testing there |
| **Store release** | Release signing, privacy policy page and store listing are deliberately left until the app is finished |
| **Photos in backups** | Backups carry the records only |

---

## 7. Suggested next steps

1. A short trial with a real seller on real orders, to find what feels slow or unclear.
2. Decide how buyers should see products (a web page, the chat link, or both) and how buyer comments should work
   (shown at once, or approved by the seller first).
3. Choose the server and SMS provider, then connect sign-in and the shared database.
4. Release preparation: signing, privacy policy, store listing; then an iPhone version.

---

## 8. A 10-minute demo script

1. Open the app, sign in with a mobile number, use the code shown on screen. *(Step 1)*
2. Me → **Load sample data**. Go back to **Home** and point out net sales, the chart and stock alerts. *(Steps 2, 14)*
3. Products → open one product. Show the stock buttons and the history. *(Step 4)*
4. **Add product**: leave the required fields empty and tap **Add product** to show the red fields and the scroll. Pick a
   category from the list. *(Step 3)*
5. Orders → **Create an order** with a past customer; mark it packed, shipped, completed. *(Steps 6, 7)*
6. Open a completed order → **Record a return** and approve it. *(Step 8)*
7. **Insights**: show the profit statement and best sellers. *(Step 11)*
8. A product with social proof → **Share and preview** → **Preview as buyer**; swipe between the social tabs. *(Steps 12, 13)*
9. Me → **Loyalty points** and **Expenses** quickly, then **Backup**. *(Steps 9, 10, 15)*

---

## 9. Words used in this document

| Word | Meaning |
|---|---|
| **SKU** | The seller's own unique code for a product |
| **COD** | Cash on delivery |
| **OTP / one-time code** | The short code used to sign in instead of a password |
| **Stock history** | The list of every increase or decrease of a product's stock |
| **Net sales** | Sales after discounts and refunds |
| **Margin** | The share of the selling price that is profit (price minus cost, divided by price) |
| **Social proof** | Public posts and comments about a product, shown to buyers with a link to the original |
| **Test mode** | The sign-in code is shown on screen instead of being sent by text message |
