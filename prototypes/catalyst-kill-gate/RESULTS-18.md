# Measurement results — apple-bridge#18

What reading this house actually costs. Measured with `MeasureProbe` in this
spike, against the live home, on 2026-07-30.

Run them yourself (app must be running):

```bash
curl -s "http://127.0.0.1:23499/measure/structure"
curl -s "http://127.0.0.1:23499/measure/latency?n=30"
curl -s "http://127.0.0.1:23499/measure/whole-house"
curl -s "http://127.0.0.1:23499/measure/whole-house-concurrent?limit=32"
curl -s "http://127.0.0.1:23499/measure/unreachable"
curl -s "http://127.0.0.1:23499/measure/enable-notifications?n=60"
curl -s "http://127.0.0.1:23499/measure/watch"
curl -s "http://127.0.0.1:23499/measure/write-scene?confirm=yes&devices=5&keep=0"
```

## The house

| | |
|---|---|
| Rooms | 17 |
| Zones | 4 |
| Accessories | **226** |
| Unreachable accessories | **0** |
| Services | 552 |
| Characteristics, total | 2301 |
| Characteristics, readable | **2046** |
| Characteristics, snapshot-eligible (PoC filter) | **273** |
| Most eligible on one accessory | 14 |
| Action sets / user scenes | 17 / 13 |

The design doc's "four cameras reporting No Response" is **stale** — everything
is reachable today.

## 1. Startup

Process start → `homeManagerDidUpdateHomes` → `primaryHome` usable:
**1.07s, 1.38s, 1.51s, 1.81s** across four runs. Call it ~1–2s, every launch.
Nothing can be served before it.

## 2. Structure enumeration — 16ms

Walking homes, rooms, zones, accessories, services and characteristics with **no**
`readValue` calls: **0.016s**. Effectively free. Structure comes from the local
HomeKit database, not the network.

## 3. Per-characteristic read latency

30 serial reads on reachable accessories:

| | |
|---|---|
| Median | **64ms** |
| p95 | 158ms |
| Max | 217ms |
| Min | 27ms |
| Throughput, serial | 13.9/s |

## 4 & 6. Whole-house read — 273 eligible characteristics

| Mode | Wall clock | Reads/s | Median | Max | Speedup |
|---|---|---|---|---|---|
| Serial | 13.84s | 19.7 | 36ms | 368ms | 1× |
| Concurrent, limit 8 | 2.50s | 109 | 61ms | 209ms | 5.5× |
| Concurrent, limit 32 | **0.71s** | 386 | 75ms | 132ms | **19.5×** |

**HomeKit does not serialise behind its own queue.** Concurrency scales close to
linearly and per-call latency barely degrades — median 36→75ms while throughput
goes up 19.5×. Max latency actually *fell*.

Extrapolating to all **2046 readable** characteristics at limit 32: **~5.3s**.
That is the number that kills inlining values in a collection response.

## 5. Reachability and failure

- **0 accessories** report unreachable, so the hang-forever case could not be
  tested. Untested, not disproven.
- **`isReachable` is not a trustworthy pre-filter.** "Bathroom Thermostat" reports
  reachable and fails every read.
- Failures are **deterministic**: exactly 12 of 273 (4.4%) failed, the same ones,
  on every run.
- Every failure is `HMErrorDomain Code=74 "Read/Write operation failed."`
- Failures **fail fast** — 40–370ms, same order as successes. Nothing hangs. So a
  whole-house read is bounded even when parts of it are broken.

## 7. Change propagation — partial

**Characteristic value push works.** With notifications enabled (60/60 succeeded
in 160ms), an unsolicited update arrived with no polling:

```
+313.3s characteristic_value_changed | Hue dimmer switch/Battery Level = Optional(67)
```

`accessory(_:service:didUpdateValueFor:)` requires `enableNotification(true)` per
characteristic first, on those where `supportsEventNotification` is set. Setting a
delegate alone gives you nothing.

**`HMHomeDelegate` did NOT fire for self-originated writes.** Creating and
deleting a scene in-process produced **zero** `didAdd`/`didRemove` callbacks. A
process cannot confirm its own writes via delegate.

**Untested:** whether `HMHomeDelegate` fires for *external* structural changes —
a scene renamed in Home.app on another device. Needs a human to make the change
while the app watches, then `GET /measure/watch`.

## 8. Write cost — 5-accessory scene

| Phase | Time |
|---|---|
| Snapshot 5 accessories | 225ms |
| `addActionSet` | 494ms |
| 5 × `addAction` | 423ms total (median 76ms, max 122ms) |
| `removeActionSet` | 146ms |
| **Total** | **1.29s** over 12 round trips |

No failures. Scene created and deleted cleanly.

`addActionSet` is the expensive single call at ~0.5s; each `addAction` is ~76ms.
A 20-accessory scene extrapolates to roughly **2.1s**.

## Verdicts

**Can live values be inlined in a collection response? No — but per-accessory,
yes.**
- One accessory tops out at 14 eligible characteristics — batched concurrently
  that is one round trip, well under 200ms. Inline freely.
- All 2046 readable characteristics is ~5.3s even at concurrency 32. Never inline
  in a collection.
- So: collections return structure, values live behind a per-accessory (or
  explicitly batched) state resource.

**Is a push-based change stream feasible? Yes for state, unproven for structure.**
Characteristic notifications demonstrably arrive unsolicited. Structural external
change propagation is the open half.

**Does the store need a cache? Not for correctness — concurrency is the bigger
lever.** 19.5× from parallelism dwarfs anything caching would buy, and a cache on
live device state is a correctness liability. A very short TTL might help
collection endpoints; measure before adding.

**Partial failure is the normal case, not an edge case.** 4.4% of reads fail
deterministically, on accessories that claim to be reachable, with an unhelpful
error. A `failed[]` in the response is mandatory, and `isReachable` cannot be used
to pre-filter it away.

**Synchronous writes are fine — no need for 202 + operation resource.** 1.29s for
5 accessories, ~2.1s extrapolated for 20. That fits a synchronous HTTP request
carrying a partial-failure result.
