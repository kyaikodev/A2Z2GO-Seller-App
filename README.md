# A2Z2GO Seller

Seller-side app (Android, Flutter). No backend yet: everything is saved on the phone.

## Run it

```
flutter pub get
flutter devices
flutter run -d <your-android-device-id>
```

## What works

- Sign in with mobile number + OTP, sign out, new-seller setup (name + store)
- Products with photo (camera/gallery), SKU, category, price, cost, low-stock alert
- Inventory: stock in / out / damaged / recount, with full history
- Orders: create, Pending > Packed > Shipped > Completed, cancel, delete (stock handled correctly)
- Returns and refunds (approve / reject, optional restock)
- Expenses
- Loyalty points: earn rules, redeem, adjust, per-customer history
- Dashboard and Analytics: sales, profit statement, best sellers, charts. All computed from your records.

A new seller starts with no data. Everything can be edited or deleted, and
"My Store > Erase all store data" wipes it.

## OTP

There is no SMS service yet, so the code is shown on the OTP screen (marked as test mode).
When a backend exists, write an `OtpSender` (lib/data/auth.dart) that calls it and pass it to
`AuthController`. Nothing else changes.

## Moving to a real database later

All reads/writes go through `AppStore` (lib/data/store.dart). Records are plain JSON with
unique string IDs, so swapping the local storage for an API is contained to that one file.

## Colors / theme

lib/core/theme.dart (`Brand`). Change them there and the whole app follows.

## Tests

```
flutter test
```
