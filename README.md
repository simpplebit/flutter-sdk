# SimpleBit Flutter SDK

Accept payments in your Flutter app: create an invoice with a **public key**, open the hosted SimpleBit payment page, and get notified when it's paid.

The SDK never handles card data or rebuilds the payment UI — it opens the existing, PCI-compliant SimpleBit checkout page in an in-app WebView and detects completion by polling the invoice status.

## Install

This package is **not published to pub.dev** — install it directly from GitHub.

Add it as a git dependency in your app's `pubspec.yaml`:

```yaml
dependencies:
  simplebit_flutter:
    git:
      url: https://github.com/simpplebit/flutter-sdk.git
      ref: v0.1.0   # pin to a release tag (recommended) or use `main`
```

> If the package lives in a subdirectory of the repo rather than at its root, add `path:` — e.g. `path: flutter-sdk`.

Then:

```sh
flutter pub get
```

To upgrade later, bump `ref` to a newer tag and run `flutter pub upgrade simplebit_flutter`.

### Platform requirements

`webview_flutter` requires Android `minSdkVersion 19+` and iOS 12+. 

## Authentication

Use a **public** key (`sb_pub_…`), created from the dashboard (API Keys → key type *Public*). It is safe to ship in a mobile app: it can only create invoices and read a single invoice's status. Never embed a secret (`sb_live_…`) key.

## Usage

```dart
import 'package:simplebit_flutter/simplebit_flutter.dart';

final sb = SimpleBit(
  publishableKey: 'sb_pub_xxxxxxxxxxxxxxxxxxxx',
  apiBaseUrl: 'https://pay.simplebit.io/api',
  // checkoutBaseUrl defaults to the same origin without `/api`
);

Future<void> pay(BuildContext context) async {
  // 1. Create the invoice
  final invoice = await sb.createInvoice(
    items: [InvoiceItem(itemId: 'itm_123', quantity: 1)],
    customerEmail: 'buyer@example.com',
    customerPaysFee: false,
  );

  // 2. Open the hosted checkout (returns when paid / expired / dismissed)
  final result = await SimpleBitCheckout.present(
    context,
    client: sb,
    invoice: invoice,
  );

  // 3. React to the outcome
  if (result.isPaid) {
    // Fulfil the order. The authoritative confirmation is the `invoice.paid`
    // webhook delivered to your server — treat this client result as a UX hint.
  }
}
```

## How completion is detected

While the WebView is open, the SDK polls `GET /invoices/:id` with your public key every few seconds. When the invoice reaches a terminal status (`PAID`, `EXPIRED`, `CANCELLED`) it closes the sheet and returns a `PaymentResult`. The hosted page itself is shown unmodified.

> **Server-side truth:** the in-app result is for UX. Rely on the **`invoice.paid` webhook** (configured in the dashboard) for fulfilment, since a user can close the app before the poll completes.

## API

### `SimpleBit`

| Member | Description |
|--------|-------------|
| `createInvoice({items, municipalityTax, customerPaysFee, customTaxIds, customerEmail, customerName, customerPhone, expiresInHours})` | Creates an invoice, returns `CreatedInvoice`. |
| `getInvoiceStatus(id)` | Returns `InvoiceStatusResult` (`{ id, status, amount, currency }`). |
| `checkoutUrlFor(paymentLink)` | The hosted page URL, if you want to open it yourself. |
| `close()` | Releases the HTTP client. |

### `SimpleBitCheckout.present(context, {client, invoice, title, pollInterval})`

Pushes a full-screen checkout and resolves to a `PaymentResult` with an `outcome` of `paid`, `expired`, `cancelled`, or `dismissed`.

## Releasing (maintainers)

The SDK is consumed via git, so consumers pin to a **tag**. To cut a release:

1. Update `version:` in `pubspec.yaml` and add an entry to `CHANGELOG.md`.
2. Commit, then tag and push:
   ```sh
   git tag v0.1.0
   git push origin v0.1.0
   ```
3. Consumers reference it with `ref: v0.1.0`.

If you later publish to pub.dev, remove `publish_to: none` from `pubspec.yaml`, then `dart pub publish`.
