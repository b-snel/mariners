"use client";

import { useMemo } from "react";
import Scatter3D, { type Point3D } from "../three/Scatter3D";
import { extent } from "@/lib/scale";
import { negLog10P } from "@/lib/stats";
import { THEME } from "@/lib/palette";
import type { Batter } from "@/lib/data";

const OVER = THEME.magenta;
const UNDER = THEME.electric;
const NS = "#5d7185";

export default function VolcanoChart({ batting }: { batting: Batter[] }) {
  const points: Point3D[] = useMemo(() => {
    return batting
      .filter((b) => b.pa > 0 && Number.isFinite(b.woba))
      .map((b) => {
        const effect = b.diff;
        const se = Math.sqrt((b.xwoba * (1 - b.xwoba)) / b.pa);
        const y = negLog10P(effect, se);
        const color = effect > 0.02 ? OVER : effect < -0.02 ? UNDER : NS;
        const dir =
          effect > 0.02
            ? "Over-performing"
            : effect < -0.02
              ? "Under-performing"
              : "neutral";
        return {
          id: b.player,
          xv: effect,
          yv: y,
          zv: b.pa,
          sizev: b.woba,
          color,
          label: b.player,
          rows: [
            ["wOBA−xwOBA", (effect >= 0 ? "+" : "") + effect.toFixed(3)],
            ["wOBA", b.woba.toFixed(3)],
            ["PA", String(b.pa)],
            ["", dir],
          ],
          href: b.savant ?? undefined,
        } as Point3D;
      });
  }, [batting]);

  const xDomain = useMemo(() => extent(points.map((p) => p.xv)), [points]);
  const yDomain = useMemo(() => {
    const e = extent(points.map((p) => p.yv));
    return [0, e[1]] as [number, number]; // significance starts at 0
  }, [points]);
  const zDomain = useMemo(() => extent(points.map((p) => p.zv)), [points]);

  return (
    <Scatter3D
      points={points}
      x={{ label: "wOBA − xwOBA", domain: xDomain, fmt: (v) => v.toFixed(2) }}
      y={{ label: "−log10(p)", domain: yDomain, fmt: (v) => v.toFixed(1) }}
      z={{ label: "Plate appearances", domain: zDomain, fmt: (v) => `${Math.round(v)}` }}
    />
  );
}
