// The host's state beside a timing run (telemetry, never graded): a slow row read against what the
// CPU, memory + other processes did while it ran. Linux sysfs + procfs; an unreadable source = `-`.
//   node tools/scale-host.mjs <file> [interval ms]      (1000; runs until SIGTERM or SIGINT)
// Appends to <file>: `h key=value…` once (identity), then per interval `s <utc ms>` + `pkg_c` (the
// x86_pkg_temp zone, °C), `pkg_thr` + `core_thr` (thermal throttle events since the last line:
// the package counter once, the core counters once per core), `pkg_w` (RAPL energy, root only),
// `busy` (busy CPUs' worth), `mhz` (scaling_cur_freq weighted by each CPU's busy share: the
// active cores' clock), `psi_cpu` + `psi_mem` + `psi_io` (stall ms, "some"), `avail_mib`, `swap`
// (pages in + out), `run` (runnable tasks), `top` (the 3 busiest processes, % of one CPU); at exit
// `e <utc ms> self_cpu_ms=…` (this sampler's own cost). Timing tools add `m <utc ms> …` marks.
import { appendFileSync, readFileSync, readdirSync } from "node:fs";
import { cpus, release } from "node:os";

const [file, every = "1000"] = process.argv.slice(2);
const interval = Number(every);
if (!file || !(interval >= 100)) {
  process.stderr.write("usage: node tools/scale-host.mjs <file> [interval ms ≥ 100]\n");
  process.exit(2);
}

/** @param {string} path */
function read(path) {
  try {
    return readFileSync(path, "utf8").trim();
  } catch {
    return undefined;
  }
}
/** @param {string} path */
function num(path) {
  const v = read(path);
  return v === undefined || v === "" || Number.isNaN(Number(v)) ? undefined : Number(v);
}
/** @param {string} dir */
function list(dir) {
  try {
    return readdirSync(dir);
  } catch {
    return [];
  }
}

const cpu = "/sys/devices/system/cpu";
const ids = list(cpu)
  .filter((d) => /^cpu\d+$/.test(d))
  .map((d) => Number(d.slice(3)))
  .toSorted((a, b) => a - b);
// One core counter per physical core: its first thread's.
const firsts = ids.filter((i) => {
  const s = read(`${cpu}/cpu${i}/topology/thread_siblings_list`);
  return s === undefined || Number(s.split(/[,-]/)[0]) === i;
});
const zone = list("/sys/class/thermal").find(
  (z) => read(`/sys/class/thermal/${z}/type`) === "x86_pkg_temp",
);
const rapl = ["intel-rapl:0", "intel-rapl-mmio:0"].map((d) => `/sys/class/powercap/${d}`);
const energy = `${rapl[0]}/energy_uj`;
const pl1 = rapl.map((d) => num(`${d}/constraint_0_power_limit_uw`)).find((v) => v !== undefined);

appendFileSync(
  file,
  `h kernel=${release()} cpu=${JSON.stringify(cpus()[0]?.model ?? "-")} logical=${ids.length} cores=${firsts.length}` +
    ` governor=${read(`${cpu}/cpu0/cpufreq/scaling_governor`) ?? "-"}` +
    ` profile=${read("/sys/firmware/acpi/platform_profile") ?? "-"}` +
    ` pl1_w=${pl1 === undefined ? "-" : pl1 / 1e6}` +
    ` ac=${read("/sys/class/power_supply/AC/online") ?? "-"}` +
    ` pkg_sensor=${zone === undefined ? "-" : `/sys/class/thermal/${zone}`} interval_ms=${interval}\n`,
);

/** Per-CPU [busy, total] jiffies from /proc/stat + its runnable count. */
function stat() {
  /** @type {Map<number, [number, number]>} */
  const per = new Map();
  let run;
  for (const line of (read("/proc/stat") ?? "").split("\n")) {
    const m = /^cpu(\d+) (.*)$/.exec(line);
    if (m) {
      const v = (m[2] ?? "").split(" ").map(Number);
      const total = v.slice(0, 8).reduce((a, b) => a + b, 0);
      per.set(Number(m[1]), [total - (v[3] ?? 0) - (v[4] ?? 0), total]);
    } else if (line.startsWith("procs_running ")) run = Number(line.split(" ")[1]);
  }
  return { per, run };
}
/** @param {string} kind cpu | memory | io → its "some" stall total, µs */
function psi(kind) {
  const m = /^some .* total=(\d+)/m.exec(read(`/proc/pressure/${kind}`) ?? "");
  return m ? Number(m[1]) : undefined;
}
function vm() {
  const t = read("/proc/vmstat") ?? "";
  const get = (/** @type {string} */ k) =>
    Number(new RegExp(`^${k} (\\d+)`, "m").exec(t)?.[1] ?? NaN);
  return get("pswpin") + get("pswpout");
}
const self = String(process.pid);
/** Every other process's CPU jiffies (utime + stime) + its name. */
function procs() {
  /** @type {Map<string, [string, number]>} */
  const out = new Map();
  for (const pid of list("/proc")) {
    if (!/^\d+$/.test(pid) || pid === self) continue;
    const s = read(`/proc/${pid}/stat`);
    if (!s) continue;
    const close = s.lastIndexOf(")");
    const f = s.slice(close + 2).split(" ");
    out.set(pid, [s.slice(s.indexOf("(") + 1, close), Number(f[11]) + Number(f[12])]);
  }
  return out;
}
function sample() {
  return {
    t: Date.now(),
    pkg: num(`${cpu}/cpu0/thermal_throttle/package_throttle_count`),
    core: firsts.reduce(
      (a, i) => a + (num(`${cpu}/cpu${i}/thermal_throttle/core_throttle_count`) ?? NaN),
      0,
    ),
    uj: num(energy),
    ...stat(),
    psi: ["cpu", "memory", "io"].map(psi),
    swap: vm(),
    procs: procs(),
  };
}

const hz = 100; // USER_HZ: /proc/stat + /proc/<pid>/stat count jiffies at 100 Hz on Linux.
/** @param {number | undefined} x @param {number} [digits] */
const fmt = (x, digits = 0) => (x === undefined || Number.isNaN(x) ? "-" : x.toFixed(digits));
/** @param {number | undefined} a @param {number | undefined} b */
const diff = (a, b) => (a === undefined || b === undefined ? undefined : a - b);
let last = sample();
const timer = setInterval(() => {
  const now = sample();
  const secs = (now.t - last.t) / 1000;
  let busy = 0;
  let weighted = 0;
  for (const [i, [b, t]] of now.per) {
    const [b0 = b, t0 = t] = last.per.get(i) ?? [];
    const share = t > t0 ? (b - b0) / (t - t0) : 0;
    busy += share;
    weighted += share * (num(`${cpu}/cpu${i}/cpufreq/scaling_cur_freq`) ?? NaN);
  }
  const top = [...now.procs]
    .map(([pid, [name, j]]) => [name, j - (last.procs.get(pid)?.[1] ?? j)])
    .filter(([, d]) => Number(d) > 0)
    .toSorted((a, b) => Number(b[1]) - Number(a[1]))
    .slice(0, 3)
    .map(
      ([name, d]) =>
        `${String(name).replace(/[\s,:]/g, "_")}:${Math.round((Number(d) / hz / secs) * 100)}`,
    );
  const [pc, pm, pi] = now.psi.map((v, k) => diff(v, last.psi[k]));
  const temp = zone === undefined ? undefined : num(`/sys/class/thermal/${zone}/temp`);
  const uj = diff(now.uj, last.uj);
  appendFileSync(
    file,
    `s ${now.t} pkg_c=${fmt(temp === undefined ? undefined : temp / 1000, 1)}` +
      ` pkg_thr=${fmt(diff(now.pkg, last.pkg))} core_thr=${fmt(diff(now.core, last.core))}` +
      ` pkg_w=${fmt(uj === undefined || uj < 0 ? undefined : uj / 1e6 / secs, 1)}` +
      ` busy=${fmt(busy, 2)} mhz=${fmt(busy > 0 ? weighted / busy / 1000 : undefined)}` +
      ` psi_cpu=${fmt(pc === undefined ? undefined : pc / 1000)}` +
      ` psi_mem=${fmt(pm === undefined ? undefined : pm / 1000)}` +
      ` psi_io=${fmt(pi === undefined ? undefined : pi / 1000)}` +
      ` avail_mib=${fmt(Number(/^MemAvailable:\s+(\d+)/m.exec(read("/proc/meminfo") ?? "")?.[1] ?? NaN) / 1024)}` +
      ` swap=${fmt(now.swap - last.swap)} run=${fmt(now.run)} top=${top.join(",") || "-"}\n`,
  );
  last = now;
}, interval);

for (const signal of /** @type {const} */ (["SIGTERM", "SIGINT"]))
  process.once(signal, () => {
    clearInterval(timer);
    const u = process.cpuUsage();
    appendFileSync(file, `e ${Date.now()} self_cpu_ms=${Math.round((u.user + u.system) / 1000)}\n`);
    process.exit(0);
  });
