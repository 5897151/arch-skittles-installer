# Performance Policy

SKITTLES ships only performance behavior that has a clear purpose and bounded downside. `1.0.0-rc.1` does **not** yet have target-hardware benchmark results, so no FPS, latency, throughput, or power improvement is claimed. Real measurements are a stable-release gate.

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

The installer verifies CPU frequency policy support but does not create a permanent governor service. On the gaming profile, `/etc/gamemode.ini` requests `desiredgov=performance`; that applies only when GameMode is used. `skittles-doctor` reports the active scaling driver, governor, energy-performance preference where available, and Turbo availability.

This approach does not disable thermal controls or firmware power limits and does not overclock the i7-8700K.

## Measurement plan

Before `v1.0.0`, measure on the supported i7-8700K + RTX 3060 Ti system from the exact RC artifact. Record at minimum:

- idle package/system power and thermals after settling;
- sustained CPU workload throughput, frequency, temperature, and throttling state;
- sustained GPU workload stability and temperature;
- at least two representative games with repeatable built-in or scripted benchmarks, comparing normal launch and `gamemoderun` where practical;
- frame-time distribution (not only average FPS) when a stable capture method exists;
- zram behavior under controlled memory pressure;
- cold boot and resume observations to ensure performance policy did not trade away reliability.

Keep test resolution/settings, driver version, kernel, game build, ambient conditions where relevant, and run count in the results. Do not promote a tweak based on a single favorable run.


## Repeatable release measurement procedure

Use the exact downloaded RC and keep the machine configuration unchanged between comparison runs. Record the RC tag/source commit, Arch kernel, NVIDIA package version, game/benchmark build, resolution, graphics preset, display refresh mode, GameMode state, and approximate room conditions.

For each representative workload:

1. Reboot, log into Plasma Wayland, wait at least five minutes with no foreground workload, and record idle governor/EPP plus GPU idle state.
2. Run the workload **three times without GameMode** using the same route/menu/save/benchmark sequence. Discard a run only for a documented external interruption.
3. Reboot or return to the same settled state, then run the identical workload **three times with `gamemoderun`**.
4. Record average FPS, 1% low FPS when the benchmark/capture tool provides it, visible frametime anomalies, GPU utilization/temperature, CPU utilization/temperature when available, and whether clocks/policy return to the pre-game state after exit.
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

## Current measurements

**NOT TESTED on release hardware.** No numeric performance improvement is claimed for `1.0.0-rc.1` yet.
