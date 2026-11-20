# Phase 02 — benchmark protocol and results

**Status: the device run has not happened yet.** This file is the instrument; the
table below stays empty until someone runs it on a real Redmi 9.

Nothing in the app, the README or a store listing may quote a Redmi 9 speed until
the table is filled in with real numbers.

---

## 1. What is already measured (not the phone)

| Measurement | Value | Environment |
| --- | --- | --- |
| Conversion fidelity | correlation **1.000000**, max abs error **0.0034/255** | CI, `ai-edge-litert` vs PyTorch, 7 fixtures |
| Per-tile latency | **96 ms** and **212 ms** (two runs) | GitHub runner, 4 vCPU x86_64, LiteRT CPU |
| Model size | 4,910,280 bytes | produced artefact |
| Weight file | 4,885,111 bytes, SHA-256 pinned | upstream release |

These numbers say the model is small and the conversion is exact. They say
**nothing** about ARM Cortex-A53 performance, because per-tile cost is dominated
by memory bandwidth and NEON throughput, both of which are several times lower on
the phone.

### The arithmetic behind the default policy

For the balanced tier (working 512×384, tile 128, halo 16 → stride 96):

```
columns = ceil(512 / 96) = 6
rows    = ceil(384 / 96) = 4
tiles   = 24
```

Per-tile estimates for a Helio G35 / Cortex-A53 cluster derived in the audit:
**1.3 s – 2.8 s**, i.e. **31 s – 67 s** for the whole job. The 90-second
acceptance gate has ~1.3× headroom at the pessimistic end of that range.

---

## 2. Device run — procedure

### 2.1 Prepare

```bash
adb install -r app-debug.apk
adb logcat -c
adb shell dumpsys meminfo com.pixora.app | head -20
```

Fixtures (copy to the phone's gallery):

| # | Photo | Purpose |
| --- | --- | --- |
| 1 | 640×480, low quality scan of an old photo | **the acceptance gate** |
| 2 | 1000×750, soft/faded | mid-size behaviour, confirms the working-size reduction |
| 3 | 4032×3024 phone photo | must take the Fast enhancement path |
| 4 | portrait with EXIF rotation | orientation correctness |
| 5 | very low-light / noisy photo | quality judgement |

### 2.2 Record, per run

1. Watch the tile counter. Note the timestamp of tile 1 and the last tile:
   `elapsed / tiles` = real per-tile cost.
2. Note whether the ETA ever jumps backwards (it should only decrease).
3. `adb logcat -s PixoraEngine` — the engine logs one line per finished job:
   `restored <w>x<h> -> <ow>x<oh> in <ms> ms (<n> tiles)`.
4. `adb shell dumpsys meminfo com.pixora.app | grep TOTAL` before and after.

### 2.3 Gate checklist (must all hold)

- [ ] 640×480 completes in **≤ 90 s**
- [ ] a **second consecutive run** is within ~20 % of the first
- [ ] no ANR dialog, app stays responsive (progress animates, Cancel tappable)
- [ ] no OOM, no process restart in `adb logcat`
- [ ] progress is monotonically increasing and the ETA is plausible
- [ ] Cancel at ~50 % stops within one tile and leaves no output file
- [ ] output is exactly 4× the working size with the source aspect ratio
- [ ] portrait photo comes out upright

---

## 3. Results table (to be filled on the device)

Device: `Redmi 9 — <Helio G80 / Helio G35>`, RAM `____ GB`, Android `____`

| Fixture | Working size | Output | Tiles | Run 1 | Run 2 | Peak RSS | Pass? |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 640×480 | 512×384 | 2048×1536 | 24 | | | | |
| 1000×750 | 512×384 | 2048×1536 | 24 | | | | |
| 4032×3024 | classical | | 0 | | | | n/a |
| portrait | | | | | | | |
| noisy | | | | | | | |

**Verdict: ☐ PASS ☐ FAIL** — date, device, and who ran it:

---

## 4. If the gate fails

Apply these in order; each is a configurable knob, not a rewrite.

| # | Change | Effect | Cost |
| --- | --- | --- | --- |
| 1 | Lower the balanced tier's `maxOutputDimension` to **1536** | 384×288 working → **12 tiles** (half the work) | visibly smaller result |
| 2 | Drop `halo` 16 → 8 | stride 112 → 20 tiles (~17 % less work) | higher seam risk, needs visual check |
| 3 | Quantise to int8 (`w8a8`, ~1.25 MB) | 1.5–2× on CPU | quality must be re-verified, gate 0.995 applies |
| 4 | Cap input pixels at 400 000 | fewer tiles for large sources | smaller working image |
| 5 | Per-device measurement instead of a static tier | accurate ETA and caps | one extra engine call |

None of these change the model's identity, the licence, or the offline guarantee.

---

## 5. Why no GPU row

The GPU delegate is deliberately disabled. On a PowerVR GE8320 it is likely
slower than the CPU *and* is a known source of silently wrong output; on a
Mali-G52 it might help. Enabling it requires (a) a full-graph residency log,
(b) agreement with the CPU within the same 0.995 correlation gate, and (c) a
reliable speed-up across two runs — none of which can be established without the
device. The engine already reports `supportsGpuAcceleration: false` so the UI
never implies otherwise.
