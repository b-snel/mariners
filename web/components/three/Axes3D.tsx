"use client";

import { Line, Text } from "@react-three/drei";
import { HALF, type Scale } from "@/lib/scale";

interface Axes3DProps {
  x: Scale;
  y: Scale;
  z: Scale;
  xLabel: string;
  yLabel: string;
  zLabel: string;
  /** Format a tick value for display (per axis). */
  fmt?: (v: number) => string;
}

const AXIS = "#2b5878";
const TICK = "#6b8aa0";
const LABEL = "#9fd6ef";

// A back-corner 3D cage: three labelled axes meeting at (-H,-H,-H), a faint
// floor grid for depth, and tick labels mapped back from the data domain.
export default function Axes3D({
  x,
  y,
  z,
  xLabel,
  yLabel,
  zLabel,
  fmt = (v) => `${v}`,
}: Axes3DProps) {
  const o = -HALF; // origin corner

  return (
    <group>
      {/* Floor grid in the y = -HALF plane */}
      <gridHelper
        args={[HALF * 2, 10, "#16324a", "#0e2236"]}
        position={[0, -HALF, 0]}
      />

      {/* Three primary axis lines from the origin corner */}
      <Line points={[[o, o, o], [HALF, o, o]]} color={AXIS} lineWidth={1.5} />
      <Line points={[[o, o, o], [o, HALF, o]]} color={AXIS} lineWidth={1.5} />
      <Line points={[[o, o, o], [o, o, HALF]]} color={AXIS} lineWidth={1.5} />

      {/* X ticks (along bottom-back edge) */}
      {x.ticks.map((t) => (
        <group key={`x${t}`} position={[x(t), o, o]}>
          <Line points={[[0, 0, 0], [0, -0.18, 0]]} color={TICK} lineWidth={1} />
          <Text
            position={[0, -0.5, 0]}
            fontSize={0.26}
            color={TICK}
            anchorX="center"
            anchorY="top"
            rotation={[-Math.PI / 2, 0, 0]}
          >
            {fmt(t)}
          </Text>
        </group>
      ))}

      {/* Y ticks (up the left-back edge) */}
      {y.ticks.map((t) => (
        <group key={`y${t}`} position={[o, y(t), o]}>
          <Line points={[[0, 0, 0], [-0.18, 0, 0]]} color={TICK} lineWidth={1} />
          <Text
            position={[-0.36, 0, 0]}
            fontSize={0.26}
            color={TICK}
            anchorX="right"
            anchorY="middle"
          >
            {fmt(t)}
          </Text>
        </group>
      ))}

      {/* Z ticks (along bottom-left edge) */}
      {z.ticks.map((t) => (
        <group key={`z${t}`} position={[o, o, z(t)]}>
          <Line points={[[0, 0, 0], [-0.18, 0, 0]]} color={TICK} lineWidth={1} />
          <Text
            position={[-0.36, 0, 0]}
            fontSize={0.26}
            color={TICK}
            anchorX="right"
            anchorY="middle"
          >
            {fmt(t)}
          </Text>
        </group>
      ))}

      {/* Axis titles */}
      <Text
        position={[0, o - 1.1, o]}
        fontSize={0.34}
        color={LABEL}
        anchorX="center"
        anchorY="middle"
        rotation={[-Math.PI / 2, 0, 0]}
      >
        {xLabel}
      </Text>
      <Text
        position={[o - 1.5, 0, o]}
        fontSize={0.34}
        color={LABEL}
        anchorX="center"
        anchorY="middle"
        rotation={[0, 0, Math.PI / 2]}
      >
        {yLabel}
      </Text>
      <Text
        position={[o, o - 1.1, 0]}
        fontSize={0.34}
        color={LABEL}
        anchorX="center"
        anchorY="middle"
        rotation={[-Math.PI / 2, Math.PI / 2, 0]}
      >
        {zLabel}
      </Text>
    </group>
  );
}
