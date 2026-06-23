"use client";

import { useMemo } from "react";
import Scatter3D, { type Point3D } from "../three/Scatter3D";
import { extent } from "@/lib/scale";
import { posColor } from "@/lib/palette";
import type { Batter } from "@/lib/data";

// Contact quality in 3D: hard-hit% × launch angle × production (wOBA), sized by
// plate appearances. Three real axes, so 3D earns its keep here.
export default function HardHitChart({ batting }: { batting: Batter[] }) {
  const points: Point3D[] = useMemo(
    () =>
      batting
        .filter(
          (b) =>
            typeof b.hard_hit_pct === "number" &&
            typeof b.avg_la === "number" &&
            Number.isFinite(b.woba)
        )
        .map((b) => ({
          id: b.player,
          xv: b.hard_hit_pct as number,
          yv: b.woba,
          zv: b.avg_la as number,
          sizev: b.pa,
          color: posColor(b.pos),
          label: b.player,
          rows: [
            ["Hard-hit%", `${(b.hard_hit_pct as number).toFixed(0)}`],
            ["Launch°", `${(b.avg_la as number).toFixed(1)}`],
            ["wOBA", b.woba.toFixed(3)],
            ["PA", String(b.pa)],
          ],
          href: b.savant ?? undefined,
        })),
    [batting]
  );

  const xDomain = useMemo(() => extent(points.map((p) => p.xv)), [points]);
  const yDomain = useMemo(() => extent(points.map((p) => p.yv)), [points]);
  const zDomain = useMemo(() => extent(points.map((p) => p.zv)), [points]);

  return (
    <Scatter3D
      points={points}
      x={{ label: "Hard-hit %", domain: xDomain, fmt: (v) => v.toFixed(0) }}
      y={{ label: "wOBA", domain: yDomain, fmt: (v) => v.toFixed(2) }}
      z={{ label: "Launch angle°", domain: zDomain, fmt: (v) => v.toFixed(0) }}
    />
  );
}
