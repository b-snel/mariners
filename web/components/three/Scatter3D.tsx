"use client";

import { useMemo, useRef, useState, type ReactNode } from "react";
import { useFrame } from "@react-three/fiber";
import { Html, Line } from "@react-three/drei";
import * as THREE from "three";
import Scene from "./Scene";
import Axes3D from "./Axes3D";
import { HALF, linear, sizeScale } from "@/lib/scale";

export interface Axis3DConfig {
  label: string;
  domain: [number, number];
  fmt?: (v: number) => string;
}

export interface Point3D {
  id: string;
  xv: number;
  yv: number;
  zv: number;
  sizev: number;
  color: string;
  label: string;
  rows: [string, string][];
  href?: string | null;
}

interface Props {
  points: Point3D[];
  x: Axis3DConfig;
  y: Axis3DConfig;
  z: Axis3DConfig;
  autoRotate?: boolean;
  /** Extra 3D content drawn in scene space (e.g. PCA loading vectors). */
  extras?: (scales: {
    sx: ReturnType<typeof linear>;
    sy: ReturnType<typeof linear>;
    sz: ReturnType<typeof linear>;
  }) => ReactNode;
}

const easeOutCubic = (t: number) => 1 - Math.pow(1 - t, 3);

function DataPoint({
  point,
  pos,
  radius,
  index,
  hovered,
  setHovered,
}: {
  point: Point3D;
  pos: THREE.Vector3;
  radius: number;
  index: number;
  hovered: string | null;
  setHovered: (id: string | null) => void;
}) {
  const group = useRef<THREE.Group>(null);
  const start = useRef<number | null>(null);
  const isHover = hovered === point.id;
  const dimmed = hovered !== null && !isHover;

  useFrame(({ clock }) => {
    const g = group.current;
    if (!g) return;
    if (start.current === null) start.current = clock.elapsedTime;
    const delay = index * 0.045;
    const t = easeOutCubic(
      Math.min(1, Math.max(0, (clock.elapsedTime - start.current - delay) / 0.7))
    );
    // Rise from the floor into final position, scaling in.
    g.position.set(pos.x, THREE.MathUtils.lerp(-HALF, pos.y, t), pos.z);
    // Ease the hover "pop" toward its target instead of snapping.
    const target = isHover ? 1.45 : 1;
    const eased = THREE.MathUtils.lerp(g.userData.pop ?? 1, target, 0.18);
    g.userData.pop = eased;
    g.scale.setScalar(t * eased);
  });

  return (
    <group ref={group}>
      {/* depth stem to the floor for 3D position legibility */}
      <Line
        points={[[0, 0, 0], [0, -(pos.y + HALF), 0]]}
        color={point.color}
        lineWidth={1}
        transparent
        opacity={dimmed ? 0.06 : 0.22}
      />
      <mesh
        onPointerOver={(e) => {
          e.stopPropagation();
          setHovered(point.id);
          document.body.style.cursor = "pointer";
        }}
        onPointerOut={() => {
          setHovered(null);
          document.body.style.cursor = "auto";
        }}
        onClick={() => {
          if (point.href) window.open(point.href, "_blank", "noopener");
        }}
      >
        <sphereGeometry args={[radius, 32, 32]} />
        <meshStandardMaterial
          color={point.color}
          emissive={point.color}
          emissiveIntensity={isHover ? 2.6 : 1.5}
          roughness={0.25}
          metalness={0.1}
          transparent
          opacity={dimmed ? 0.35 : 1}
        />
      </mesh>

      {isHover && (
        <Html center distanceFactor={10} zIndexRange={[40, 0]}>
          <div className="hud">
            <div className="name">{point.label}</div>
            {point.rows.map(([k, v]) => (
              <div className="row" key={k}>
                <span>{k}</span>
                <b>{v}</b>
              </div>
            ))}
          </div>
        </Html>
      )}
    </group>
  );
}

function Cloud({ points, sx, sy, sz }: { points: Point3D[]; sx: ReturnType<typeof linear>; sy: ReturnType<typeof linear>; sz: ReturnType<typeof linear> }) {
  const [hovered, setHovered] = useState<string | null>(null);
  const rScale = useMemo(
    () => sizeScale(points.map((p) => p.sizev)),
    [points]
  );

  return (
    <group>
      {points.map((p, i) => (
        <DataPoint
          key={p.id}
          point={p}
          index={i}
          pos={new THREE.Vector3(sx(p.xv), sy(p.yv), sz(p.zv))}
          radius={rScale(p.sizev)}
          hovered={hovered}
          setHovered={setHovered}
        />
      ))}
    </group>
  );
}

export default function Scatter3D({
  points,
  x,
  y,
  z,
  autoRotate = true,
  extras,
}: Props) {
  const sx = useMemo(() => linear(x.domain), [x.domain]);
  const sy = useMemo(() => linear(y.domain), [y.domain]);
  const sz = useMemo(() => linear(z.domain), [z.domain]);

  return (
    <Scene autoRotate={autoRotate}>
      <Axes3D
        x={sx}
        y={sy}
        z={sz}
        xLabel={x.label}
        yLabel={y.label}
        zLabel={z.label}
        fmt={x.fmt}
      />
      <Cloud points={points} sx={sx} sy={sy} sz={sz} />
      {extras?.({ sx, sy, sz })}
    </Scene>
  );
}
