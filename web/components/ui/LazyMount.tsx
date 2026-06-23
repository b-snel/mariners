"use client";

import { useEffect, useRef, useState, type ReactNode } from "react";

// Mounts its children only once they scroll near the viewport. Keeps the number
// of live WebGL contexts (one per 3D chart) low until the user actually reaches
// each chart, and lets each scene play its entrance animation on first reveal.
export default function LazyMount({
  children,
  minHeight = 540,
  rootMargin = "200px",
}: {
  children: ReactNode;
  minHeight?: number;
  rootMargin?: string;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const [shown, setShown] = useState(false);

  useEffect(() => {
    if (shown || !ref.current) return;
    const el = ref.current;
    const io = new IntersectionObserver(
      (entries) => {
        if (entries.some((e) => e.isIntersecting)) {
          setShown(true);
          io.disconnect();
        }
      },
      { rootMargin }
    );
    io.observe(el);
    return () => io.disconnect();
  }, [shown, rootMargin]);

  return (
    <div ref={ref} style={{ minHeight }}>
      {shown ? children : null}
    </div>
  );
}
