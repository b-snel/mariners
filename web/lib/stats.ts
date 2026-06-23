// Minimal stats helpers shared by the charts.

// Standard normal CDF via the Abramowitz & Stegun 7.1.26 erf approximation.
// Matches R's pnorm() closely enough for the volcano's significance axis.
export function pnorm(x: number): number {
  const t = 1 / (1 + 0.2316419 * Math.abs(x));
  const d = 0.3989422804014327 * Math.exp((-x * x) / 2);
  const p =
    d *
    t *
    (0.31938153 +
      t *
        (-0.356563782 +
          t * (1.781477937 + t * (-1.821255978 + t * 1.330274429))));
  return x >= 0 ? 1 - p : p;
}

// Two-sided p-value and -log10(p) for an effect given its standard error.
export function negLog10P(effect: number, se: number): number {
  if (!Number.isFinite(se) || se <= 0) return 0;
  const z = effect / se;
  const p = 2 * pnorm(-Math.abs(z));
  return -Math.log10(Math.max(p, 1e-300));
}
