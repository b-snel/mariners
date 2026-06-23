// Tiny scale helpers (a stand-in for d3-scale's linear scale) used to map data
// domains into the fixed scene cube. Kept dependency-free and pure.

export const HALF = 5; // scene spans [-HALF, HALF] on each axis

export interface Scale {
  (v: number): number;
  domain: [number, number];
  ticks: number[];
}

export function linear(
  domain: [number, number],
  range: [number, number] = [-HALF, HALF],
  tickCount = 5
): Scale {
  let [d0, d1] = domain;
  if (d0 === d1) {
    d0 -= 1;
    d1 += 1;
  }
  const [r0, r1] = range;
  const fn = ((v: number) =>
    r0 + ((v - d0) / (d1 - d0)) * (r1 - r0)) as Scale;
  fn.domain = [d0, d1];
  fn.ticks = niceTicks(d0, d1, tickCount);
  return fn;
}

export function extent(values: number[], pad = 0.06): [number, number] {
  let min = Infinity;
  let max = -Infinity;
  for (const v of values) {
    if (!Number.isFinite(v)) continue;
    if (v < min) min = v;
    if (v > max) max = v;
  }
  if (!Number.isFinite(min)) return [0, 1];
  const span = max - min || 1;
  return [min - span * pad, max + span * pad];
}

// "Nice" round tick values within [lo, hi].
function niceTicks(lo: number, hi: number, count: number): number[] {
  const span = hi - lo;
  if (span <= 0) return [lo];
  const step0 = span / count;
  const mag = Math.pow(10, Math.floor(Math.log10(step0)));
  const norm = step0 / mag;
  const step =
    (norm >= 5 ? 5 : norm >= 2 ? 2 : norm >= 1 ? 1 : 0.5) * mag;
  const start = Math.ceil(lo / step) * step;
  const out: number[] = [];
  for (let t = start; t <= hi + step * 1e-6; t += step) {
    out.push(Math.abs(t) < step * 1e-6 ? 0 : +t.toFixed(6));
  }
  return out;
}

// Map a value through a size domain to a sphere radius range.
export function sizeScale(
  values: number[],
  range: [number, number] = [0.12, 0.42]
): (v: number) => number {
  const [lo, hi] = extent(values, 0);
  return (v: number) => {
    if (!Number.isFinite(v)) return range[0];
    const t = hi === lo ? 0.5 : (v - lo) / (hi - lo);
    return range[0] + t * (range[1] - range[0]);
  };
}
