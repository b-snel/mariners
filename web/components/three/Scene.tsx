"use client";

import { Canvas } from "@react-three/fiber";
import { OrbitControls } from "@react-three/drei";
import { EffectComposer, Bloom, Vignette } from "@react-three/postprocessing";
import { Suspense, type ReactNode } from "react";

interface SceneProps {
  children: ReactNode;
  /** Initial camera position. */
  camera?: [number, number, number];
  /** Slowly auto-orbit when the user isn't interacting (adds "life"). */
  autoRotate?: boolean;
}

// Shared WebGL stage: dark clear color, rim + key lighting, orbit controls, and
// the bloom pass that turns every emissive material into a glowing object. All
// charts drop their geometry in as children and inherit this look.
export default function Scene({
  children,
  camera = [6, 5, 9],
  autoRotate = true,
}: SceneProps) {
  return (
    <Canvas
      dpr={[1, 2]}
      camera={{ position: camera, fov: 48, near: 0.1, far: 100 }}
      gl={{ antialias: true, alpha: true }}
    >
      <color attach="background" args={["#04070d"]} />
      <fog attach="fog" args={["#04070d", 16, 38]} />

      <ambientLight intensity={0.45} />
      <pointLight position={[10, 12, 8]} intensity={120} color="#7fdfff" />
      <pointLight position={[-10, -6, -8]} intensity={60} color="#2dd4bf" />

      <Suspense fallback={null}>{children}</Suspense>

      <OrbitControls
        enablePan={false}
        enableDamping
        dampingFactor={0.08}
        minDistance={5}
        maxDistance={22}
        autoRotate={autoRotate}
        autoRotateSpeed={0.45}
      />

      <EffectComposer>
        <Bloom
          mipmapBlur
          intensity={0.9}
          luminanceThreshold={0.2}
          luminanceSmoothing={0.5}
        />
        <Vignette eskil={false} offset={0.25} darkness={0.75} />
      </EffectComposer>
    </Canvas>
  );
}
