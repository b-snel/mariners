"use client";

import { motion } from "framer-motion";
import { useMemo } from "react";

export interface BarDatum {
  label: string;
  value: number;
  color: string;
  display?: string;
}

interface Props {
  data: BarDatum[];
  /** Value that bars diverge from (0 for ERA−xERA, .300 for BABIP). */
  baseline?: number;
  domain?: [number, number];
  format?: (v: number) => string;
  baselineLabel?: string;
}

// Diverging horizontal bars, sorted by value, that grow out from the baseline
// on mount. Deliberately 2D: a 3D bar chart distorts the very length
// comparison these charts exist to make.
export default function Bars2D({
  data,
  baseline = 0,
  domain,
  format = (v) => v.toFixed(2),
  baselineLabel,
}: Props) {
  const rows = useMemo(
    () => [...data].sort((a, b) => b.value - a.value),
    [data]
  );

  const [lo, hi] = useMemo<[number, number]>(() => {
    if (domain) return domain;
    const vals = data.map((d) => d.value).concat(baseline);
    const min = Math.min(...vals);
    const max = Math.max(...vals);
    const pad = (max - min || 1) * 0.08;
    return [min - pad, max + pad];
  }, [data, domain, baseline]);

  const W = 1000;
  const rowH = 34;
  const padL = 150;
  const padR = 70;
  const padT = 30;
  const plotW = W - padL - padR;
  const H = padT * 2 + rows.length * rowH;

  const xOf = (v: number) => padL + ((v - lo) / (hi - lo)) * plotW;
  const baseX = xOf(baseline);

  return (
    <svg
      viewBox={`0 0 ${W} ${H}`}
      width="100%"
      style={{ display: "block", padding: "8px 0 16px" }}
      role="img"
    >
      <defs>
        {rows.map((d, i) => (
          <filter id={`glow${i}`} key={i} x="-20%" y="-50%" width="140%" height="200%">
            <feGaussianBlur stdDeviation="3.5" result="b" />
            <feMerge>
              <feMergeNode in="b" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
        ))}
      </defs>

      {/* baseline */}
      <line
        x1={baseX}
        y1={padT - 8}
        x2={baseX}
        y2={H - padT + 8}
        stroke="#3a5a72"
        strokeDasharray="4 5"
        strokeWidth={1.5}
      />
      {baselineLabel && (
        <text
          x={baseX}
          y={14}
          textAnchor="middle"
          fill="#7d93a3"
          fontSize={13}
          fontFamily="var(--font-mono)"
        >
          {baselineLabel}
        </text>
      )}

      {rows.map((d, i) => {
        const y = padT + i * rowH;
        const vx = xOf(d.value);
        const x = Math.min(baseX, vx);
        const w = Math.max(Math.abs(vx - baseX), 0.5);
        const positive = d.value >= baseline;
        return (
          <g key={d.label}>
            <text
              x={padL - 12}
              y={y + rowH / 2}
              textAnchor="end"
              dominantBaseline="central"
              fill="#cfe0ea"
              fontSize={14}
              fontFamily="var(--font-display)"
            >
              {d.label}
            </text>
            {/* Static geometry; only scaleX is animated (anchored at the
                baseline via transform-box) so the bar grows out from "even".
                Animating SVG x/width through framer-motion mis-applies them as
                CSS transforms — scaleX avoids that entirely. */}
            <motion.rect
              x={x}
              y={y + 7}
              width={w}
              height={rowH - 14}
              rx={4}
              fill={d.color}
              filter={`url(#glow${i})`}
              style={{
                transformBox: "fill-box",
                transformOrigin: positive ? "left center" : "right center",
              }}
              initial={{ scaleX: 0, opacity: 0.4 }}
              animate={{ scaleX: 1, opacity: 1 }}
              transition={{
                duration: 0.9,
                delay: i * 0.04,
                ease: [0.16, 1, 0.3, 1],
              }}
            />
            <text
              x={vx + (d.value >= baseline ? 10 : -10)}
              y={y + rowH / 2}
              textAnchor={d.value >= baseline ? "start" : "end"}
              dominantBaseline="central"
              fill="#9fd6ef"
              fontSize={13}
              fontFamily="var(--font-mono)"
            >
              {d.display ?? format(d.value)}
            </text>
          </g>
        );
      })}
    </svg>
  );
}
