# Mafia — Game Night

A mobile-friendly, multiplayer web app for in-person Mafia games. This replaces the old Firebase dependency with a server-authoritative game engine and Cloudflare D1 persistence. The original Swift project in the parent directory is preserved.

## Play

Host creates a lobby, shares its six-digit code, chooses one role per player, and deals roles. Each person uses their own phone. The game progresses through private role reveal, sequential night turns, morning discussion, first-to-two nominations, a vote between two nominees (neither nominee can vote), and an optional Judge verdict. Refreshing reconnects using the device's saved player key. Use the host's missing-player control only when a participant cannot continue.

Town wins when no Mafia remain; Mafia wins at parity. Vote ties are random. The first player to receive two distinct nominations goes on the block immediately and chooses a second nominee. Only the host can skip the block (during discussion, nominations, secondary selection, or voting); this clears the day’s choices and starts the next night without an elimination. If everyone nominates without anyone reaching two, the host can skip the block. Silencing is an in-person speaking restriction, not a voting restriction. Judge and Vis powers are once per game. Kazee eliminates themselves and their target during any day phase. Night groups coordinate in person in order: Mafia → Cops → Vis → Medic → Diddy. Empty groups and spent Vis powers are skipped. Medic acts only if Mafia or Vis attempted a kill. Recruited players join Mafia discussion and also take their original role’s turn. A group advances after all its members submit or confirm; civilians do not need to press a sleep button. A host force action advances only the current group. Kills, saves, investigations, silencing, and recruitment resolve at dawn, so players targeted for death still get their scheduled turn. Medic protection applies to night kills, including self-protection. Before the game the host sets the Godfather’s recruitment allowance (0–24, default 1), separate from the role deck. Each recruitment consumes one allowance instead of a night kill. Recruitment changes a living target’s team to Mafia while preserving their role, abilities, and spent one-shot powers. Recruited players win with Mafia, count toward Mafia parity, and know their teammates. Recruitment does not grant a new night-kill power. The allowance is spent when the action is submitted, including if the target dies that night. A rematch restores the configured allowance. Cop sees the target's alignment before that night's recruitment. Dead players spectate. Rematches keep the lobby and players.

A full-width morning report shows deaths, the number of successful saves, and living silenced players. All participants, including spectators, see it above the game controls throughout the day. Living players acknowledge the recap before nominations; the host’s existing override controls remain available. Protected identities, recruitment, and private Cop notes are not included.

Turn cues use a brief vibration pattern where the browser supports `navigator.vibrate`, plus a visible “Your group’s turn” banner. Tap the test control, keep the page open, and leave the phone unlocked. Browser/device settings can block vibration; this app cannot guarantee background or lock-screen alerts. Night readiness lists and participant IDs are private to avoid exposing roles.

## Development

Node 22.13+ required.

```sh
npm run install:ci
npm run build
node --import ./scripts/sites-env.mjs ./node_modules/wrangler/bin/wrangler.js d1 execute DB --local --config dist/server/wrangler.json --persist-to .wrangler/state --file drizzle/0000_black_annihilus.sql
npm run dev
```

Apply each migration once to a fresh local database. Hosted Sites deploys migrations automatically. Local and hosted databases are separate.

```sh
node --test tests/*.test.mjs
npx tsc --noEmit
```

The API uses unguessable per-player bearer tokens; client views omit other players' secret roles, night actions, individual ballots, and private investigation notes. State updates use a database revision check to prevent simultaneous submissions overwriting one another. Browser local storage holds only that device's reconnect key. Clearing browser storage loses the key. There is no account recovery. The host may skip missing players, but cannot inspect their roles.

Code lives in `app/page.tsx` (UI), `app/globals.css` (responsive styles), `app/api/game/route.ts` (API and persistence), and `lib/game.mjs` (pure rules engine). Tests cover the rules engine and `tests/api-smoke.mjs` exercises real multiplayer requests against a running local server. Set `BASE_URL` to change its target; it creates a dedicated test lobby.
