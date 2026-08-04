# Driver Rewards & Incentives

Admin-managed reward campaigns that auto-credit the driver prepaid wallet (and support non-wallet rewards) without app updates.

## Admin

1. Open Admin → **Rewards**
2. Create a campaign (titles, conditions, reward type, limits)
3. Set status to **Active** (or use Activate in the menu)
4. Drivers progress automatically as they complete trips / stay online / meet metrics
5. Grants and audit logs appear in the Grants / Audit tabs

Assistants need the `rewards` permission (managers always have access).

## Conditions

| Type | Notes |
|------|--------|
| `completedTrips` | Scope: `campaign` (during campaign), `lifetime`, or `monthly` |
| `totalEarnings` | Driver earnings IQD (`campaign` or `lifetime`) |
| `onlineHours` | From `onlineSecondsTotal` / campaign progress |
| `rating` | Driver average rating |
| `acceptanceRate` | `statsOffersAccepted / statsOffersReceived` |
| `cancellationRate` | Driver cancels / (completed + cancels) |
| `custom` | Any numeric field on driver or progress (`customKey`) |

Logic: **AND** or **OR** across conditions.

## Reward types

| Type | Effect |
|------|--------|
| `wallet_credit` / `bonus` | Credits `walletBalanceIqd` via ledger type `reward` + push |
| `commission_discount` | Active reward on driver; reduces next commissions |
| `free_trips` | Skips commission for N completed trips |
| `custom` | Stored grant + active reward payload for future loyalty |

## Collections (CF write-only)

- `rewardCampaigns/{id}`
- `rewardProgress/{campaignId}_{driverId}`
- `rewardGrants/{id}`
- `rewardAuditLogs/{id}`
- `drivers/{id}/activeRewards/{grantId}`
- `walletLedger` entries with `type: reward`, `rewardCampaignId`, `rewardGrantId`

## Callables

- `saveRewardCampaign`
- `setRewardCampaignStatus`
- `deleteRewardCampaign` (soft-delete)
- `evaluateDriverRewards` (manual re-check for one driver)

## Runtime hooks

- Trip earnings applied → progress + evaluate all live campaigns
- Commission debit → apply free-trip / discount first
- Offer / accept / reject → acceptance-rate counters
- Driver online/offline → online hours accumulation

## Driver apps

- Flutter: home → trophies icon → active campaigns + personal grants; wallet history shows **Reward**
- iOS: wallet history labels `reward` as Reward / حافز
