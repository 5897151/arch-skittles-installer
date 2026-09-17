# Performance Policy

SKITTLES ships only performance behavior that has a clear purpose and bounded downside. Formal benchmarking was explicitly deferred for `1.0.0`, so no FPS, latency, throughput, power, or other benchmark-based improvement is claimed.

| Optimization | Default | Why | Evidence | Risk / tradeoff |
| --- | --- | --- | --- | --- |
| CPU policy | Kernel/firmware adaptive policy | Preserve normal idle/boost behavior instead of pinning maximum-performance policy | Architectural choice; target benchmark pending | Performance may vary with firmware/kernel policy |
| GameMode | Gaming profile, on demand | Allows a game launched with `gamemoderun` to request `performance` governor temporarily | Upstream mechanism; target game benchmarks pending | Higher game-session power/heat; only useful when workload responds |
| zram | Half RAM capped at 4 GiB | Small RAM-backed swap buffer without persistent disk swap | Conservative generator-style sizing; target pressure test pending | Uses RAM/CPU for compression under pressure |
| NVIDIA | Arch `nvidia-open` + `nvidia-open-lts` defaults | Match supported current Arch kernel packaging, KMS/fbdev, suspend-notifier behavior | Package/runtime correctness validation; performance benchmark pending | Proprietary userspace/firmware remains; driver regressions possible |
| ext4 mounts | Normal ext4 relatime behavior | Avoid unmeasured `noatime` forcing | Kernel filesystem default philosophy | Some metadata writes remain |
| NTSync | Gaming profile via `ntsync-autoload` | Support Windows synchronization primitives where Proton/Wine stack uses them | Package availability/config correctness; game benchmark pending | Game-specific benefit; kernel/userspace compatibility evolves |
| I/O scheduler | Not overridden | Avoid universal assumptions across SATA/NVMe devices | No target measurement justifies a forced scheduler | Kernel/device default decides policy |
| LUKS discard | Off unless opted in | Privacy-first default; performance/maintenance choice remains explicit | Storage/privacy tradeoff, not an FPS tweak | Enabling reveals unused-block patterns |

## CPU/GameMode architecture

The installer verifies CPU frequency policy support but does not create a permanent governor service. On the gaming profile, `/etc/gamemode.ini` requests `desiredgov=performance`; that applies only when GameMode is used. `disable_splitlock=0` deliberately keeps the kernel split-lock mitigation enabled: disabling it is a security/reliability tradeoff, not a default performance optimization, and no i7-8700K evidence justifies that tradeoff. `skittles-doctor` reports the active scaling driver, governor, energy-performance preference where available, and Turbo availability.

This approach does not disable thermal controls or firmware power limits and does not overclock the i7-8700K.

## Measurement plan

If this optional matrix is executed later, measure on the supported i7-8700K + RTX 3060 Ti system from an exact published artifact. Every row remains **NOT TESTED** until it is run on that physical machine.

| Case | Controlled comparison | Required evidence / guardrail | Current result |
| --- | --- | --- | --- |
| 1. Baseline | Published pre-change behavior and normal desktop policy | Capture untouched baseline before interpreting later deltas | **NOT TESTED** |
| 2. zswap + zram | zswap active versus `zswap.enabled=0`, with the same zram configuration | Memory-pressure workload; zram/zswap counters, latency and CPU cost | **NOT TESTED** |
| 3. GameMode | identical launch with and without `gamemoderun` | Confirm governor restoration and that split-lock mitigation remains enabled; run `gamemoded -t` before game measurements | **NOT TESTED** |
| 4. Plasma VRR | Adaptive Sync off versus on, where the physical monitor supports it | Same display mode/FPS range; inspect stutter, tearing and frametime variance | **NOT TESTED** |
| 5. dm-crypt workqueues | default versus `no_read_workqueue` + `no_write_workqueue` | Storage-focused A/B only; monitor CPU, throughput, latency and regressions | **NOT TESTED** |
| 6. NVIDIA PAT | applicability check first; current `nvidia-open` 610+ removed the old PAT module option | Do not invent a replacement knob; record `N/A` rationale in notes unless a current supported mechanism exists | **NOT TESTED** |
| 7. ReBAR | firmware ReBAR off versus on, only if motherboard/GPU/driver expose both states | Record firmware setting and detected state; do not manipulate it automatically | **NOT TESTED** |
| 8. zram VM candidates | current defaults versus isolated candidates such as swappiness/page-cluster changes | One variable at a time under memory pressure; no blind ArchWiki bundle | **NOT TESTED** |
| 9. Gamescope | native compositor path versus an explicit per-game Gamescope test | Optional and game-specific; never wrap all games by default | **NOT TESTED** |
| 10. Clocksource sanity | packaged/default clocksource versus any available alternative only if diagnostics justify it | Latency/stability evidence required; do not force a clocksource by reputation | **NOT TESTED** |

For every condition, capture average FPS, 1% low, 0.1% low, frametime percentiles and spikes where the tooling supports them; CPU/GPU utilization and clocks; memory plus swap/zram use; and storage latency for storage-related cases. Also capture thermals and throttling so a short boost is not mistaken for a sustainable gain.

Hold constant the game/scene/benchmark, resolution, graphics settings, Proton version, kernel, NVIDIA driver, background-service state, and thermal starting condition. Use at least three runs per condition, report every run, and compare median/mean together with variance where appropriate.

Every result set must identify the commit SHA, installer version, kernel, NVIDIA driver, relevant package versions, CPU/GPU/storage/display hardware, motherboard firmware/BIOS, test date, and exact experimental change. Do not promote a tweak whose effect is smaller than normal run-to-run variance or whose downside outweighs the measured gain.


## Repeatable release measurement procedure

Use an exact downloaded release artifact and keep the machine configuration unchanged between comparison runs. Record the tag/source commit, Arch kernel, NVIDIA package version, game/benchmark build, resolution, graphics preset, display refresh mode, GameMode state, and approximate room conditions.

For each representative workload:

1. Reboot, log into Plasma Wayland, wait at least five minutes with no foreground workload, and record idle governor/EPP plus GPU idle state.
2. Run the workload **three times without GameMode** using the same route/menu/save/benchmark sequence. Discard a run only for a documented external interruption.
3. Reboot or return to the same settled state, then run the identical workload **three times with `gamemoderun`**.
4. Record average FPS, 1% and 0.1% lows, frametime percentiles/spikes, GPU utilization/clock/temperature, CPU utilization/clock/temperature, memory and swap/zram use, and whether clocks/policy return to the pre-game state after exit.
5. Report all runs, not only the best run. Do not call a difference meaningful if it is within normal run-to-run variance.

Useful read-only state checks before, during, and after the workload include:

```bash
uname -r
pacman -Q nvidia-utils nvidia-open nvidia-open-lts gamemode 2>/dev/null || true
for p in /sys/devices/system/cpu/cpufreq/policy*; do
  printf '%s: ' "$p"
  cat "$p/scaling_driver" "$p/scaling_governor" 2>/dev/null | paste -sd ' ' -
  [ -r "$p/energy_performance_preference" ] && cat "$p/energy_performance_preference"
done
nvidia-smi --query-gpu=driver_version,temperature.gpu,utilization.gpu,power.draw --format=csv
gamemoded -t
```

If the chosen title has no repeatable built-in benchmark or controlled scene, do not publish numeric claims from it. Use it only as a stability/compatibility test and keep `Current measurements` unclaimed.

## Tweaks we deliberately do not apply

- `mitigations=off`: trades security for benchmark-dependent gains and is outside the project philosophy.
- constant CPU overclock or permanent maximum-performance governor: unnecessary heat/power for desktop idle and not justified by measurements.
- fixed maximum GPU clocks or forced power limits: increases heat/power and can reduce reliability; not an installer responsibility.
- random sysctl collections: defaults are not changed without a specific measured/defensive reason.
- giant TCP socket buffers: can waste memory and do not universally reduce latency.
- universally forced I/O schedulers: optimal policy depends on device/controller/workload.
- “gaming kernels” by reputation: both `linux` and `linux-lts` are chosen for straightforward support/recovery, not marketing claims.
- global overlay injection or forced FPS caps: these are per-game user decisions.
- SDDM replacement: Plasma Login Manager migration is a separate compatibility project, not a performance default.
- dm-crypt workqueue bypass, forced NVIDIA PAT, firmware ReBAR changes, zram VM tuning, clocksource overrides, and universal Gamescope wrapping: each remains isolated A/B work from the experiment matrix above.
- `linux-zen`: SKITTLES keeps `linux` + `linux-lts` for the supported and recovery paths.
- SMT disabling, global split-lock mitigation disabling, GPU clock offsets, power-limit manipulation, and automatic fan tuning: these trade away compatibility, security, thermals, or reliability without release-hardware evidence.

## Current measurements

**DEFERRED for v1.0.0.** No formal benchmark matrix was executed and no numeric performance improvement is claimed.

## Release measurement record template

Complete this section on the physical release machine; do not replace raw run data with a score.

```text
Release tag / SOURCE_COMMIT:
Arch ISO date:
Kernel:
NVIDIA packages / driver:
Game / workload build:
Resolution / preset / refresh mode:
Ambient/room notes:

Normal policy runs:
1.
2.
3.

GameMode runs:
1.
2.
3.

Observed average / 1% low / frametime notes:
CPU temperature / policy notes:
GPU temperature / power notes:
Policy restored after GameMode exit: PASS | FAIL
Long-run stability: PASS | FAIL
Conclusion (including variance/downsides):
```

If all measurements are completed and reviewed for a later release, set `performance_measurements` to `PASS` in `release-signoff.json` and record the SHA-256 of this completed file in `evidence.performance_sha256`. For v1.0.0 it remains `DEFERRED`, the SHA is `null`, and no numeric performance benefit is claimed.
