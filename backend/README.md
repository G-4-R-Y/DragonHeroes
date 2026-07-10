# backend/ — meta-game services

| Service | Dir | Stack | Design doc |
|---|---|---|---|
| Nakama (accounts, guilds, chat, matchmaker, leaderboards, tournaments) | `nakama/` | Nakama OSS + runtime modules | [docs/tech/26](../docs/tech/26-backend-and-services.md) |
| Economy core — sole writer of real-money item/money state | `economy-core/` | Go + PostgreSQL | [docs/tech/26](../docs/tech/26-backend-and-services.md) §economy core |
| Liveops — content activation, flags, kill switches | `liveops/` | TBD (thin service) | [docs/tech/23](../docs/tech/23-content-pipeline.md) |

Hard rules (canon §8): studio never touches funds (PSP escrow/split); every item
transfer is one ACID transaction; kill switches exist before the marketplace opens.
