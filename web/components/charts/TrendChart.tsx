"use client";

import { motion } from "framer-motion";
import { useMemo, useState } from "react";
import type { WarPoint } from "@/lib/data";
import { THEME } from "@/lib/palette";

const LINE_COLORS = [
  THEME.cyan,
  THEME.magenta,
  THEME.green,
  THEME.amber,
  THEME.electric,
  "#a78bfa",
  "#fb923c",
  "#f472b6",
];

interface Series {
  player: string;
  color: string;
  pts: { t: number; war: number }[];
  final: number;
}

// Cumulative-WAR race: one luminous line per player, drawn on with an animated
// stroke. Hover (line or legend chip) highlights and dims the rest; click a line
// to pin that highlight; click a legend chip to toggle a player on/off.
export default function TrendChart({
  history,
  topN = 8,
}: {
  history: WarPoint[];
  topN?: number;
}) {
  const [hidden, setHidden] = useState<Set<string>>(new Set());
  const [hovered, setHovered] = useState<string | null>(null);
  const [pinned, setPinned] = useState<string | null>(null);

  const { series, xDomain, yDomain } = useMemo(() => {
    const byPlayer = new Map<string, { t: number; war: number }[]>();
    for (const p of history) {
      const t = Date.parse(p.date);
      if (Number.isNaN(t)) continue;
      const arr = byPlayer.get(p.player) ?? [];
      arr.push({ t, war: p.war });
      byPlayer.set(p.player, arr);
    }
    let all: Series[] = [...byPlayer.entries()].map(([player, pts]) => {
      pts.sort((a, b) => a.t - b.t);
      return { player, pts, final: pts[pts.length - 1]?.war ?? 0, color: "" };
    });
    all.sort((a, b) => b.final - a.final);
    all = all.slice(0, topN).map((s, i) => ({
      ...s,
      color: LINE_COLORS[i % LINE_COLORS.length],
    }));

    const ts = history.map((p) => Date.parse(p.date)).filter((t) => !Number.isNaN(t));
    const wars = all.flatMap((s) => s.pts.map((p) => p.war));
    const yMin = Math.min(0, ...wars);
    const yMax = Math.max(...wars, 1);
    return {
      series: all,
      xDomain: [Math.min(...ts), Math.max(...ts)] as [number, number],
      yDomain: [yMin, yMax + (yMax - yMin) * 0.08] as [number, number],
    };
  }, [history, topN]);

  const highlight = pinned ?? hovered;

  const W = 1000;
  const H = 460;
  const padL = 54;
  const padR = 132;
  const padT = 18;
  const padB = 40;
  const plotW = W - padL - padR;
  const plotH = H - padT - padB;

  const xOf = (t: number) =>
    padL + ((t - xDomain[0]) / (xDomain[1] - xDomain[0] || 1)) * plotW;
  const yOf = (w: number) =>
    padT + (1 - (w - yDomain[0]) / (yDomain[1] - yDomain[0] || 1)) * plotH;

  const yTicks = useMemo(() => {
    const [lo, hi] = yDomain;
    const step = niceStep((hi - lo) / 5);
    const out: number[] = [];
    for (let t = Math.ceil(lo / step) * step; t <= hi; t += step) out.push(+t.toFixed(2));
    return out;
  }, [yDomain]);

  const toggle = (player: string) =>
    setHidden((prev) => {
      const next = new Set(prev);
      if (next.has(player)) next.delete(player);
      else next.add(player);
      return next;
    });

  const clickLine = (player: string) =>
    setPinned((prev) => (prev === player ? null : player));

  return (
    <div>
      <svg viewBox={`0 0 ${W} ${H}`} width="100%" style={{ display: "block", padding: "8px 0 4px" }} role="img">
        <defs>
          <filter id="lineGlow" x="-10%" y="-30%" width="120%" height="160%">
            <feGaussianBlur stdDeviation="3" result="b" />
            <feMerge>
              <feMergeNode in="b" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
        </defs>

        {/* y gridlines + ticks */}
        {yTicks.map((t) => (
          <g key={t}>
            <line x1={padL} y1={yOf(t)} x2={W - padR} y2={yOf(t)} stroke="#16324a" strokeWidth={1} />
            <text x={padL - 10} y={yOf(t)} textAnchor="end" dominantBaseline="central" fill="#5d7185" fontSize={12} fontFamily="var(--font-mono)">
              {t}
            </text>
          </g>
        ))}
        <text x={padL} y={H - 10} fill="#7d93a3" fontSize={12} fontFamily="var(--font-mono)">
          season →
        </text>
        <text x={padL - 44} y={padT + 4} fill="#9fd6ef" fontSize={12} fontFamily="var(--font-mono)">
          WAR
        </text>

        {series.map((s, i) => {
          const isHidden = hidden.has(s.player);
          const isHigh = highlight === s.player;
          const dim = highlight !== null && !isHigh;
          const targetOpacity = isHidden ? 0 : dim ? 0.16 : 1;
          const d = s.pts.map((p, j) => `${j === 0 ? "M" : "L"} ${xOf(p.t).toFixed(1)} ${yOf(p.war).toFixed(1)}`).join(" ");
          const last = s.pts[s.pts.length - 1];
          return (
            <g key={s.player} style={{ cursor: isHidden ? "default" : "pointer" }}>
              {/* wide invisible hit area for hover/click */}
              {!isHidden && (
                <path
                  d={d}
                  fill="none"
                  stroke="transparent"
                  strokeWidth={16}
                  onMouseEnter={() => setHovered(s.player)}
                  onMouseLeave={() => setHovered(null)}
                  onClick={() => clickLine(s.player)}
                />
              )}
              <motion.path
                d={d}
                fill="none"
                stroke={s.color}
                strokeLinecap="round"
                strokeLinejoin="round"
                filter="url(#lineGlow)"
                style={{ pointerEvents: "none" }}
                initial={{ pathLength: 0, opacity: 0 }}
                animate={{ pathLength: 1, opacity: targetOpacity, strokeWidth: isHigh ? 4 : 2.4 }}
                transition={{
                  pathLength: { duration: 1.6, delay: 0.15 + i * 0.12, ease: "easeInOut" },
                  opacity: { duration: 0.35 },
                  strokeWidth: { duration: 0.2 },
                }}
              />
              {!isHidden && (
                <>
                  <motion.circle
                    cx={xOf(last.t)}
                    cy={yOf(last.war)}
                    r={isHigh ? 5 : 3.6}
                    fill={s.color}
                    filter="url(#lineGlow)"
                    style={{ pointerEvents: "none" }}
                    initial={{ opacity: 0, scale: 0 }}
                    animate={{ opacity: targetOpacity, scale: 1 }}
                    transition={{ delay: 0.15 + i * 0.12 + 1.6, duration: 0.3 }}
                  />
                  <motion.text
                    x={xOf(last.t) + 10}
                    y={yOf(last.war)}
                    dominantBaseline="central"
                    fill={s.color}
                    fontSize={12.5}
                    fontFamily="var(--font-mono)"
                    fontWeight={isHigh ? 600 : 400}
                    style={{ pointerEvents: "none" }}
                    initial={{ opacity: 0 }}
                    animate={{ opacity: dim ? 0.2 : 1 }}
                    transition={{ delay: 0.15 + i * 0.12 + 1.7, duration: 0.4 }}
                  >
                    {shortName(s.player)} {s.final.toFixed(1)}
                  </motion.text>
                </>
              )}
            </g>
          );
        })}
      </svg>

      {/* Interactive legend: click to toggle, hover to highlight. */}
      <div className="trend-legend">
        {series.map((s) => {
          const isHidden = hidden.has(s.player);
          return (
            <button
              key={s.player}
              type="button"
              className={`chip${isHidden ? " off" : ""}`}
              onClick={() => toggle(s.player)}
              onMouseEnter={() => !isHidden && setHovered(s.player)}
              onMouseLeave={() => setHovered(null)}
            >
              <span className="swatch" style={{ background: isHidden ? "transparent" : s.color, borderColor: s.color, boxShadow: isHidden ? "none" : `0 0 8px ${s.color}` }} />
              {shortName(s.player)}
              <span className="war">{s.final.toFixed(1)}</span>
            </button>
          );
        })}
        {pinned && (
          <button type="button" className="chip clear" onClick={() => setPinned(null)}>
            ✕ clear focus
          </button>
        )}
      </div>
    </div>
  );
}

function niceStep(raw: number): number {
  const mag = Math.pow(10, Math.floor(Math.log10(raw || 1)));
  const n = raw / mag;
  return (n >= 5 ? 5 : n >= 2 ? 2 : n >= 1 ? 1 : 0.5) * mag;
}

function shortName(name: string): string {
  const parts = name.split(" ");
  if (parts.length < 2) return name;
  return `${parts[0][0]}. ${parts.slice(1).join(" ")}`;
}
