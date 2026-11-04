# Resume and interview notes

Use the project to describe concrete implementation decisions. Select bullets that match the work you can explain and the role you are applying for.

## Project entry

**Mafia — Multiplayer Party Game**

React · TypeScript · JavaScript · Cloudflare Workers · D1/SQLite · Drizzle · Vite

[Live demo](https://mafia-game-night-jf.jfriar606317.chatgpt.site) · [Source](https://github.com/JFriar11/Mafia)

- Developed and deployed a mobile-friendly multiplayer web app with private roles, configurable recruitment, ordered night turns, nominations, and voting.
- Implemented a server-authoritative game state machine and optimistic concurrency using revision-checked SQLite updates to prevent simultaneous player requests from overwriting shared state.
- Separated player roles from team membership, enforced player-specific data visibility, and verified gameplay with 44 automated tests and multi-session API integration scenarios.

For a shorter resume, combine the first two bullets and keep the testing bullet.

## A concise verbal explanation

“Mafia is an in-person party game where everyone uses their own phone. The app acts as the referee. A React interface sends actions to a Cloudflare Worker, which validates them against a JavaScript rules engine and saves the lobby in D1. Each player receives a private view. Revision-checked database writes handle simultaneous choices, and HTTP polling keeps phones synchronized. The project started in SwiftUI and Firebase before moving to a web app.”

## Technical examples to discuss

| Topic | Example from this project |
| --- | --- |
| Concurrency | Two nominations arrive together. Only one request can update a given revision; the other retries against the latest state. |
| Data modeling | Recruitment changes a Medic’s team without replacing their role or resetting spent powers. |
| Authorization | A nominee cannot vote even if they manually call the API instead of using the interface. |
| Privacy | A Town player’s response omits Mafia membership, other roles, and Cop investigation notes. |
| State machines | A recruited Cop has two distinct night turns; current participants are tracked separately from role powers. |
| Fault handling | The host can move past a missing group member, and vibration failures have an on-screen fallback. |
| Product iteration | Rules evolved from ordinary nomination counts to first-to-two nominations and host-only skips. |
| Testing | Pure-engine tests cover edge cases; independent token sessions exercise the actual API and database. |

## Keep claims precise

The current verified evidence is 44 unit tests and integration scenarios, including a nine-player API test against the live deployment. The lobby supports configuring 4–24 players, but that is a product limit, not evidence of a 24-player load test or large-scale adoption.

Describe synchronization as HTTP polling, not WebSockets. TypeScript covers the interface and project checks; the rules engine is JavaScript, and the route currently disables TypeScript checking. Phone vibration support is best-effort, not universal. Avoid claiming production user counts, performance improvements, test coverage percentages, or security guarantees that have not been measured.

Before an interview, practice tracing one action through `web/app/page.tsx`, `web/app/api/game/route.ts`, `web/lib/game.mjs`, and the database revision check. Explain your own decisions and contributions clearly, including any development tools used when asked.
