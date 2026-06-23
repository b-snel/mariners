"use client";

import { useEffect, useMemo, useState } from "react";
import { loadDataset, type Dataset } from "@/lib/data";
import { POS_COLORS, THEME } from "@/lib/palette";
import ChartCard from "@/components/ui/ChartCard";
import LazyMount from "@/components/ui/LazyMount";
import PcaChart from "@/components/charts/PcaChart";
import VolcanoChart from "@/components/charts/VolcanoChart";
import HardHitChart from "@/components/charts/HardHitChart";
import TrendChart from "@/components/charts/TrendChart";
import Bars2D, { type BarDatum } from "@/components/charts/Bars2D";

const ORBIT_HINT = "drag to orbit · scroll to zoom · click a star for Savant";

export default function Page() {
  const [data, setData] = useState<Dataset | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadDataset().then(setData).catch((e) => setError(String(e)));
  }, []);

  if (error) {
    return (
      <div className="wrap" style={{ padding: "120px 0" }}>
        <p className="dim">Could not load data: {error}</p>
      </div>
    );
  }
  if (!data) {
    return (
      <div className="wrap" style={{ padding: "160px 0", textAlign: "center" }}>
        <div className="eyebrow">Booting telemetry…</div>
      </div>
    );
  }

  return <Dashboard data={data} />;
}

function Dashboard({ data }: { data: Dataset }) {
  const { batting, pitching, warHistory, meta } = data;

  const positionsPresent = useMemo(() => {
    const set = new Set(batting.map((b) => b.pos));
    return [...set].filter((p) => p in POS_COLORS);
  }, [batting]);

  const posLegend = positionsPresent.map((p) => ({
    label: p,
    color: POS_COLORS[p],
  }));

  // Headline stats.
  const topHitter = useMemo(
    () => [...batting].sort((a, b) => (b.war ?? 0) - (a.war ?? 0))[0],
    [batting]
  );
  const topOver = useMemo(
    () => [...batting].sort((a, b) => b.diff - a.diff)[0],
    [batting]
  );

  // ERA − xERA: negative = outperforming peripherals (good → teal).
  const luckBars: BarDatum[] = useMemo(
    () =>
      pitching.map((p) => ({
        label: p.player,
        value: p.era_minus_xera,
        color: p.era_minus_xera <= 0 ? THEME.teal : THEME.red,
        display: (p.era_minus_xera >= 0 ? "+" : "") + p.era_minus_xera.toFixed(2),
      })),
    [pitching]
  );

  const babipBars: BarDatum[] = useMemo(
    () =>
      batting
        .filter((b) => typeof b.babip === "number")
        .map((b) => {
          const v = b.babip as number;
          return {
            label: b.player,
            value: v,
            color: v > 0.33 ? THEME.magenta : v < 0.27 ? THEME.electric : "#5d7185",
            display: v.toFixed(3),
          };
        }),
    [batting]
  );

  const generated = useMemo(() => {
    try {
      return new Date(meta.generatedAt).toLocaleString(undefined, {
        dateStyle: "medium",
        timeStyle: "short",
      });
    } catch {
      return meta.generatedAt;
    }
  }, [meta.generatedAt]);

  return (
    <>
      {/* ---- Hero ---- */}
      <header className="hero wrap">
        <span className="badge">
          <span className={`dot ${meta.dataSource === "live" ? "live" : "synthetic"}`} />
          {meta.dataSource === "live" ? "LIVE FANGRAPHS DATA" : "DEMO DATA"} · {meta.season}
        </span>
        <h1 style={{ marginTop: 26 }}>
          Seattle Mariners
          <br />
          in three dimensions
        </h1>
        <p>
          The 2026 roster as a moving constellation — principal components,
          expected-stats over/under-performance, and value accruing game by
          game. Refreshed the morning after every game.
        </p>
      </header>

      <div className="wrap">
        {/* ---- PCA (hero chart) ---- */}
        <ChartCard
          index="01 / Player-profile space"
          title="PCA of batting profiles"
          sub="Each star is a hitter placed by the three principal components of their batting line. Nearby stars have similar profiles; the labelled rods are the feature loadings — the directions of variation. Sized by plate appearances."
          legend={posLegend}
          hint={ORBIT_HINT}
          stats={[
            { k: "Hitters", v: String(batting.length) },
            { k: "WAR leader", v: topHitter ? `${topHitter.player.split(" ").slice(-1)} ${(topHitter.war ?? 0).toFixed(1)}` : "—" },
            { k: "Features", v: "8" },
          ]}
        >
          <LazyMount>
            <div className="canvas-host">
              <PcaChart batting={batting} />
            </div>
          </LazyMount>
        </ChartCard>

        {/* ---- Volcano ---- */}
        <ChartCard
          index="02 / Luck & regression"
          title="wOBA vs xwOBA volcano"
          sub="Horizontal = how far actual wOBA sits above (right) or below (left) expected wOBA. Vertical = how confident the sample size makes that gap. Depth = plate appearances. Over-performers (magenta) tend to regress down; under-performers (blue) have upside."
          legend={[
            { label: "Over-performing", color: THEME.magenta },
            { label: "Under-performing", color: THEME.electric },
            { label: "Within noise", color: "#5d7185" },
          ]}
          hint={ORBIT_HINT}
          stats={[
            { k: "Biggest over-perf.", v: topOver ? `${topOver.player.split(" ").slice(-1)} +${topOver.diff.toFixed(3)}` : "—" },
          ]}
        >
          <LazyMount>
            <div className="canvas-host">
              <VolcanoChart batting={batting} />
            </div>
          </LazyMount>
        </ChartCard>

        {/* ---- Hard-hit 3D ---- */}
        <ChartCard
          index="03 / Contact quality"
          title="Hard-hit × launch angle × production"
          sub="Does hitting it hard and at a good angle translate to results? Hard-hit % runs left-to-right, launch angle into the screen, and wOBA up the vertical — the upper region is elite contact that pays off."
          legend={posLegend}
          hint={ORBIT_HINT}
        >
          <LazyMount>
            <div className="canvas-host">
              <HardHitChart batting={batting} />
            </div>
          </LazyMount>
        </ChartCard>

        {/* ---- WAR trends (2D) ---- */}
        <ChartCard
          index="04 / Value over the season"
          title="Cumulative WAR race"
          sub={
            meta.warSource === "live"
              ? "Season-to-date WAR for the top hitters, reconstructed from FanGraphs date-range leaderboards and drawn on as the season unfolds."
              : "Illustrative cumulative-WAR paths (live history was unavailable)."
          }
        >
          <TrendChart history={warHistory} />
        </ChartCard>

        {/* ---- ERA − xERA ---- */}
        <ChartCard
          index="05 / Pitching luck"
          title="ERA − xERA"
          sub="Negative bars (teal) mean a pitcher is outperforming their peripherals — expect some regression upward. Positive bars (red) mean the ERA is worse than the underlying skill suggests."
        >
          <Bars2D
            data={luckBars}
            baseline={0}
            format={(v) => v.toFixed(2)}
            baselineLabel="even"
          />
        </ChartCard>

        {/* ---- BABIP ---- */}
        <ChartCard
          index="06 / Batted-ball luck"
          title="BABIP vs league average"
          sub="Batting average on balls in play. Bars to the right of the .300 line (magenta) are running hot; to the left (blue) running cold. Extremes tend to regress toward the line."
        >
          <Bars2D
            data={babipBars}
            baseline={0.3}
            format={(v) => v.toFixed(3)}
            baselineLabel=".300 — MLB avg"
          />
        </ChartCard>
      </div>

      <footer>
        <div className="wrap">
          Data: FanGraphs via baseballr · source {meta.dataSource} · WAR history{" "}
          {meta.warSource} · generated {generated}. Rendered with React Three
          Fiber. Not affiliated with MLB or the Seattle Mariners.
        </div>
      </footer>
    </>
  );
}
