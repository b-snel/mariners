"use client";

import { motion } from "framer-motion";
import type { ReactNode } from "react";

export interface LegendItem {
  label: string;
  color: string;
}

interface Props {
  index: string;
  title: string;
  sub?: ReactNode;
  children: ReactNode;
  legend?: LegendItem[];
  hint?: string;
  stats?: { k: string; v: string }[];
}

// Frosted, glowing panel that reveals as it scrolls into view. Wraps every
// chart with a consistent header / legend / stat footer.
export default function ChartCard({
  index,
  title,
  sub,
  children,
  legend,
  hint,
  stats,
}: Props) {
  return (
    <motion.section
      className="card section"
      initial={{ opacity: 0, y: 28 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: "-80px" }}
      transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
    >
      <div className="card-head">
        <div className="eyebrow">{index}</div>
        <h2 style={{ marginTop: 6 }}>{title}</h2>
        {sub && <div className="sub">{sub}</div>}
      </div>

      {children}

      {legend && (
        <div className="legend">
          {legend.map((l) => (
            <span className="item" key={l.label}>
              <span className="swatch" style={{ background: l.color, boxShadow: `0 0 8px ${l.color}` }} />
              {l.label}
            </span>
          ))}
          {hint && <span className="item" style={{ marginLeft: "auto" }}>{hint}</span>}
        </div>
      )}
      {!legend && hint && (
        <div className="legend">
          <span className="item" style={{ marginLeft: "auto" }}>{hint}</span>
        </div>
      )}

      {stats && (
        <div className="statbar">
          {stats.map((s) => (
            <div className="stat" key={s.k}>
              <div className="k">{s.k}</div>
              <div className="v">{s.v}</div>
            </div>
          ))}
        </div>
      )}
    </motion.section>
  );
}
