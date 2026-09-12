# 33 — Community contributions and funding alternatives

Status: proposals under evaluation, no live payouts/subscription/settlement
changes. Canon §12.47, roadmap R22, [verbatim request](../harness/requests/2026-09-12-recovery.md).
Existing [economy](../design/15-economy-and-marketplace.md), [legal launch gates](30-legal-payments-compliance.md)
and MIT-code/proprietary-asset license split remain in effect.

## Ricardo's proposed pools

Allocate 10% of a period's **distributable profit** to community contributors,
and another 10% to cash-prize events. Do not confuse this with a 10% transaction
fee, 10% of gross sales, or the earlier proposal of 20% of marketplace fee
revenue going to prizes. Preserve that older proposal as history; select one
funding basis in the eventual contract and never apply both accidentally.

Illustrative accounting model, pending accountant/legal review:
`P = max(0, recognized platform revenue - agreed operating costs - taxes - reserves)`;
contributor pool `0.10 P`, event pool `0.10 P`, company remainder `0.80 P`.
Player sale proceeds and custodial balances are not platform revenue/profit.
Define allowable costs, reserves, accounting period, refund corrections, minimum
payout and audit rights before promising a percentage. A loss period cannot
create an unfunded prize promise; advertise only already-funded event awards.

Contributor score proposal: sum accepted, active contributions using published
category base weights × reviewed completeness/quality × actual maintained scope.
Dungeons, creature kits, items, art, tools, localization and maintenance need
separate calibrated weights. Splitting one contribution into ten IDs must not
increase its weight. Versions, coauthors and derivative work share a declared
credit allocation. Popularity votes nominate content; they do not measure work
or certify ownership. Reject self-voting/Sybil incentives and payout-by-raw-count.

Period payout: `pool × contributor_score / total_eligible_score`. Publish the
snapshot, weights, eligible contributors and rounding/remainder method. Adding
accepted work can raise a contributor's proportional share; it also dilutes
others, so do not promise every weekly submission increases income. Historical
contributions retain credit; depreciation/retirement/maintenance weighting is
a contract decision with advance notice, not an automatic weekly reset.
Require contribution rights/consent, dispute handling and appropriate tax/KYC
review before accepting cash-payout obligations.

## Compare revenue models before changing the ledger

| Model | Product/economic tradeoff | Unresolved gate |
|---|---|---|
| Current marketplace transaction fee | Revenue follows settled trading activity; no subscription needed to play | PSP split/escrow, disputes, seller onboarding and actual unit economics |
| Optional subscription | More predictable per-account revenue; can fund service/convenience | no paid power, no paid access/boost to random rewards; churn/support cost |
| Subscription funded from settled sales | Reduces out-of-pocket cost for active sellers | explicit opt-in, authorized billing, settlement availability; never promise sales cover fees |
| Direct player-to-player Pix | Reduces platform participation in settlement | atomic item/payment delivery, false receipts, fraud/disputes and fee collection become difficult |

Recommendation for the implementation plan: retain the existing PSP-mediated
ledger boundary while modelling these alternatives with recorded volume/cost
assumptions. Direct Pix is not an anti-fraud shortcut: the BCB documents payment
limits, fraud controls and recovery mechanisms; a screenshot or submitted receipt
cannot release an item. Use verified provider events and idempotent settlement.
References: [BCB Pix overview](https://bcb.gov.br/estabilidadefinanceira/pix-sobre),
[BCB Pix security](https://bcb.gov.br/estabilidadefinanceira/pix-seguranca).

No payment integration is switched on by this spec. Cash tournaments remain
free-entry and funded in advance; marketplace remains web-only; no paid RNG.
Contributor agreements, Brazilian payment/tax treatment and event rules need
qualified review under the existing legal launch gates before operation.
