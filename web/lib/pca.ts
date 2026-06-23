// Client-side PCA -----------------------------------------------------------
//
// PCA is computed in the browser from the batting feature matrix (ml-pca does
// the SVD), so it stays in sync with whatever data the R pipeline ships and the
// R side never has to serialize principal components. Mirrors the feature set
// and centering/scaling of the old R/04_pca.R (prcomp(center, scale.)).

import { PCA } from "ml-pca";
import type { Batter } from "./data";

// Same eight features the R notebook used for the player-profile PCA.
export const PCA_FEATURES: (keyof Batter)[] = [
  "ba",
  "obp",
  "slg",
  "woba",
  "xwoba",
  "hr",
  "bb",
  "k",
];

export interface PcaScore {
  player: string;
  pos: string;
  pa: number;
  pc1: number;
  pc2: number;
  pc3: number;
}

export interface PcaLoading {
  feature: string;
  pc1: number;
  pc2: number;
  pc3: number;
}

export interface PcaResult {
  scores: PcaScore[];
  loadings: PcaLoading[];
  varExplained: [number, number, number]; // proportion for PC1..PC3
}

export function computePCA(batting: Batter[]): PcaResult {
  const rows = batting.filter((b) =>
    PCA_FEATURES.every((f) => typeof b[f] === "number" && !Number.isNaN(b[f]))
  );

  const matrix = rows.map((b) => PCA_FEATURES.map((f) => b[f] as number));

  // center + scale === prcomp(center = TRUE, scale. = TRUE)
  const pca = new PCA(matrix, { center: true, scale: true });

  const scoresMat = pca.predict(matrix).to2DArray();
  const variance = pca.getExplainedVariance(); // proportions, descending
  const loadingsMat = pca.getLoadings().to2DArray(); // [component][feature]

  const scores: PcaScore[] = rows.map((b, i) => ({
    player: b.player,
    pos: b.pos,
    pa: b.pa,
    pc1: scoresMat[i][0],
    pc2: scoresMat[i][1] ?? 0,
    pc3: scoresMat[i][2] ?? 0,
  }));

  const loadings: PcaLoading[] = PCA_FEATURES.map((f, j) => ({
    feature: String(f),
    pc1: loadingsMat[0]?.[j] ?? 0,
    pc2: loadingsMat[1]?.[j] ?? 0,
    pc3: loadingsMat[2]?.[j] ?? 0,
  }));

  return {
    scores,
    loadings,
    varExplained: [variance[0] ?? 0, variance[1] ?? 0, variance[2] ?? 0],
  };
}
