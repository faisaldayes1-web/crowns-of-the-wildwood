# Online play plan

Owner: Online & Platforms group. Branch `group/online-platforms-osscle`. Every change is logged in
`docs/changelog/online-platforms.md` with its revert line.

Goal: Crowns of the Wildwood plays online on Steam, 5 v 5 with bots filling empty slots, next to
the couch split-screen (2-4 players, shipped) and PS5 / DualSense support (shipped).

## 1. Approach in two layers

1. **ENet first (direct IP).** Godot's built-in `ENetMultiplayerPeer` over UDP. Works on a LAN and
   over the internet with a forwarded port. It needs no store account, so it can be built and
   tested headlessly in CI today, and everything above the transport (who simulates what, what is
   sent, how players are slotted) is the same code that Steam will use.
2. **Steam networking and lobbies (GodotSteam).** Swap the transport for
   `SteamMultiplayerPeer` (GodotSteam's Steam Networking Sockets peer). Steam gives NAT traversal
   and relays (no port forwarding), lobbies, friend invites ("Join game" from the Steam overlay) and
   rich presence. Because Godot's high-level multiplayer API sits on a `MultiplayerPeer`, the game
   code does not change: only `scripts/net.gd` picks which peer to create.

## 2. Authority model: host-authoritative

- One player **hosts**. The host's game runs the whole simulation exactly as offline play does:
  every unit's movement and collisions, combat and damage, abilities, projectiles, doors, the
  monarchs, captures, the clock, scores and all bots.
- **Clients send inputs, not results.** Each physics frame a client sends its stick, aim direction,
  held buttons (attack, block) and a counter per tap button (grab, Q, E, dodge). The host drives
  that player's unit from those inputs, so a modified client cannot teleport, heal or score.
- **The host sends snapshots.** 20 times a second the host sends every unit's position, facing,
  hearts, energy, class, life state, level and score line, plus the match state (score, clock,
  fortify timer, monarch positions and states, door health). Clients smooth between snapshots.
- A client that drops out hands its unit back to a bot; the match goes on.
- Later (milestone N3): client-side prediction for the client's own unit (move locally at once,
  correct to the host's position on each snapshot) so it feels instant on 80-150 ms links.

## 3. What is replicated

| Thing | Step one (now) | Later |
| --- | --- | --- |
| Unit position, facing, walk animation | yes, 20 Hz snapshot | prediction for own unit (N3) |
| Hearts, energy, class, dead / respawn timer, level, K/D | yes, snapshot | |
| Score, clock, fortify phase, game over | yes, snapshot | |
| Monarch state and position | yes, snapshot | |
| Castle door health and broken state, vault open | yes, snapshot | |
| Attacks, projectiles, ability effects, hit sparks, sounds | no (host only) | reliable event RPCs (N2) |
| Kill feed, chat, toasts, announcements | no | reliable event RPCs (N2) |
| Class variants, rank perks, hero look and banner | no (base look) | sent once at join and on change (N2) |
| Turrets, traps, barricades, blessings, potions | no | spawn / despawn events (N2) |

Bandwidth estimate: 10 units x ~60 bytes x 20 Hz = 12 KB/s down per client, inputs ~2 KB/s up.

## 4. Slots and teams

- Host is player 1 on the side they pick on the title screen (lineup slot 0).
- Joiners take bot slots: the first joiner goes to the other side (versus by default), then sides
  alternate. Each team has 5 slots, so up to 9 people with bots filling the rest.
- Couch split-screen stays local only for now; online and couch together is milestone N4.

## 5. Matchmaking

- **ENet:** host presses HOST on the title screen (port 24560 UDP); the friend types the host's
  IP and presses JOIN. Joining mid-match drops you into a bot's slot.
- **Steam:** HOST creates a Steam lobby (friends-only or public). Friends join through the overlay
  or the in-game lobby list. The lobby carries the map, bot difficulty and slot list; the host
  starts the match when ready. Quick match (public lobby search by region and map) comes last.

## 6. Milestones

| # | Milestone | Done when |
| --- | --- | --- |
| N1 | **ENet host / join step one** | HOST / JOIN on the title menu; two instances connect by IP, both players spawn and see each other move, bots keep playing on the host; headless smoke test `tools/net_smoke.sh` passes |
| N2 | Full match over ENet | attacks, projectiles, abilities, effects, kill feed, chat, class looks all show on clients; a whole match plays to the end screen online |
| N3 | Feel | client prediction for the own unit, interpolation buffer, lag and packet-loss testing (`tools/net_smoke.sh` with simulated latency) |
| N4 | Lobby and slots | pre-match lobby screen: who is in, which side, ready flags, kick; couch players joining online matches |
| N5 | Steam | GodotSteam build, `SteamMultiplayerPeer`, lobbies, invites, rich presence, Steam app ID in `steam_appid.txt` |
| N6 | Steam release work | depots and builds uploaded via `tools/export.sh` output, achievements, Steam Deck check |

## 7. Builds

`tools/export.sh` exports the Windows and Linux desktop builds headlessly with the project's
export presets and zips each one with the version and commit in the name. The web (HTML5) export
is owned by the Current build showcase thread and is not touched by this script.

## 8. Testing

`tools/net_smoke.sh` starts a headless host and a headless client on one machine. The host waits
for the client, starts a match, and both sides walk their player for a few seconds. It passes only
when the client connected, got its slot, saw its own unit move (input went to the host and came
back in snapshots), saw the host's player move, saw bots move, and the host saw the client's unit
move. It must pass before every push from this group.
