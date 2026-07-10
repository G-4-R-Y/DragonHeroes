// economy-core — the SOLE writer of real-money item and money state (canon §8).
//
// M0 stub. The real service (docs/tech/26) implements:
//   - append-only double-entry ledger (PostgreSQL, SERIALIZABLE + retry)
//   - item instances: GUID PK, single-owner constraint, state machine
//     owned → listed → escrowed → settled/consumed/destroyed
//   - idempotency keys on every mutating RPC
//   - PSP adapter (Asaas primary) for Pix escrow/split/payout
//   - nightly reconciliation: ledger sums to zero, no GUID owned twice
//   - kill switches for every wealth-transfer vector
//
// Game servers and Nakama NEVER write these tables — RPC only.
package main

import (
	"fmt"
	"os"
)

func main() {
	fmt.Println("dh economy-core stub — see docs/tech/26-backend-and-services.md")
	os.Exit(0)
}
