# Driver Wallet + Manual SuperQi Recharge (Admin)

Internal prepaid wallet for platform commission. Drivers pay company SuperQi, submit a receipt, and admins approve to credit `walletBalanceIqd`.

## After deploy

1. Deploy Firebase (if not already):
   ```bash
   firebase deploy --only firestore:rules,firestore:indexes,storage,functions
   ```
2. Open **Admin → Wallet → Settings**.
3. Set the real **Company SuperQi number** and account name (placeholder is empty until you do).
4. Set **WhatsApp for receipts** — the number drivers open to send SuperQi/payment receipt photos.
5. Tap **Initialize wallets for existing drivers** once so every driver doc has `walletBalanceIqd` / `walletStatus`.
6. Optionally set:
   - **Min balance for matching** (default `1`) — drivers below this cannot go online / receive offers
   - **Low-balance warning** (default `5000` IQD)
   - EN/AR recharge instructions shown in the driver app

## Daily ops

1. **Wallet → Recharges**: review pending requests (amount, reference, screenshot).
2. **Approve**: edit the credit amount if needed (defaults to what the driver submitted), then confirm. Credited amount is what the manager enters.
3. Tap **Wallet** on a request to open that driver’s balance + full ledger (and quick adjust).
4. **Reject** requires a reason; the driver is notified.
5. **Adjust**: manual credit/debit by driver UID with a required note, or open wallet/ledger from that tab.

## How commission works

- On trip completion (when `earningsApplied` becomes true), Cloud Functions debit `platformCommissionIqd` from the wallet and append a `commission` ledger row.
- Historical `outstandingPlatformCommissionIqd` settle flow remains for older debt.
- Matching / go-online / accept are blocked when `walletStatus == blocked` or balance &lt; min.

## Collections

| Path | Purpose |
|------|---------|
| `config/wallet` | SuperQi details + thresholds |
| `drivers/{uid}.walletBalanceIqd` | Prepaid balance (server-only updates) |
| `walletLedger` | Append-only audit log |
| `walletRechargeRequests` | Manual SuperQi (and other methods) requests |

Payment `method` is pluggable: `superQi` | `cash` | `bankTransfer` | `gateway` (future API).
