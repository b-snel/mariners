"use client";

import { useMemo } from "react";
import { Line, Text } from "@react-three/drei";
import * as THREE from "three";
import Scatter3D, { type Point3D } from "../three/Scatter3D";
import { computePCA } from "@/lib/pca";
import { extent } from "@/lib/scale";
import { posColor } from "@/lib/palette";
import type { Batter } from "@/lib/data";

export default function PcaChart({ batting }: { batting: Batter[] }) {
  const pca = useMemo(() => computePCA(batting), [batting]);

  const xDomain = useMemo(
    () => extent(pca.scores.map((s) => s.pc1)),
    [pca]
  );
  const yDomain = useMemo(
    () => extent(pca.scores.map((s) => s.pc2)),
    [pca]
  );
  const zDomain = useMemo(
    () => extent(pca.scores.map((s) => s.pc3)),
    [pca]
  );

  const points: Point3D[] = useMemo(
    () =>
      pca.scores.map((s) => ({
        id: s.player,
        xv: s.pc1,
        yv: s.pc2,
        zv: s.pc3,
        sizev: s.pa,
        color: posColor(s.pos),
        label: s.player,
        rows: [
          ["POS", s.pos],
          ["PA", String(s.pa)],
          ["PC1", s.pc1.toFixed(2)],
          ["PC2", s.pc2.toFixed(2)],
        ],
      })),
    [pca]
  );

  return (
    <Scatter3D
      points={points}
      x={{ label: `PC1 · ${(pca.varExplained[0] * 100).toFixed(0)}%`, domain: xDomain, fmt: (v) => v.toFixed(1) }}
      y={{ label: `PC2 · ${(pca.varExplained[1] * 100).toFixed(0)}%`, domain: yDomain, fmt: (v) => v.toFixed(1) }}
      z={{ label: `PC3 · ${(pca.varExplained[2] * 100).toFixed(0)}%`, domain: zDomain, fmt: (v) => v.toFixed(1) }}
      extras={({ sx, sy, sz }) => {
        // Feature-loading vectors from the origin, scaled to reach roughly the
        // edge of the point cloud so they read as the axes of variation.
        const maxLoad = Math.max(
          ...pca.loadings.flatMap((l) => [
            Math.abs(l.pc1),
            Math.abs(l.pc2),
            Math.abs(l.pc3),
          ])
        );
        const reach =
          0.7 *
          Math.min(
            Math.abs(sx(xDomain[1]) - sx(0)),
            Math.abs(sy(yDomain[1]) - sy(0)),
            Math.abs(sz(zDomain[1]) - sz(0))
          );
        const k = reach / (maxLoad || 1);
        const origin: [number, number, number] = [sx(0), sy(0), sz(0)];
        return (
          <group>
            {pca.loadings.map((l) => {
              const end: [number, number, number] = [
                sx(0) + l.pc1 * k,
                sy(0) + l.pc2 * k,
                sz(0) + l.pc3 * k,
              ];
              return (
                <group key={l.feature}>
                  <Line
                    points={[origin, end]}
                    color="#5b7790"
                    lineWidth={1.5}
                    transparent
                    opacity={0.55}
                  />
                  <Text
                    position={[
                      end[0] * 1.08,
                      end[1] * 1.08,
                      end[2] * 1.08,
                    ]}
                    fontSize={0.26}
                    color="#bcd6e6"
                    anchorX="center"
                    anchorY="middle"
                    outlineWidth={0.01}
                    outlineColor="#04070d"
                  >
                    {l.feature.toUpperCase()}
                  </Text>
                </group>
              );
            })}
            <mesh position={origin}>
              <sphereGeometry args={[0.06, 16, 16]} />
              <meshBasicMaterial color="#8fb6cc" />
            </mesh>
          </group>
        );
      }}
    />
  );
}
