import type { NormalizedProduct } from "./normalizer.ts";
import { TOP_15_BRANDS } from "./topBrands.ts";

const ROUND_DOSE_VALUES = new Set([
  50, 100, 200, 250, 400, 500, 600, 800, 1000, 1500, 2000, 3000, 5000, 10000,
]);

/**
 * Heuristic popularity score in [0, 100]. No external sales data — just signals
 * that correlate with mainstream products:
 *
 *   +30  brand in top-15 (mass market consumer recognition)
 *   +30  short product name (mainstream SKUs have concise names)
 *   +20  round-number dose (1000 IU, 500 mg, etc.)
 *   +20  single-nutrient product (easier to discover than blends)
 *
 * Scores are clamped at 100.
 */
export function scorePopularity(p: NormalizedProduct): number {
  let score = 0;

  if (TOP_15_BRANDS.has(p.brand)) score += 30;

  const nameLen = p.name.length;
  if (nameLen <= 20) score += 30;
  else if (nameLen <= 35) score += 20;
  else if (nameLen <= 50) score += 10;

  const firstDose = p.keyIngredients[0]?.amount;
  if (firstDose != null && ROUND_DOSE_VALUES.has(firstDose)) score += 20;

  if (p.ingredientCount <= 2) score += 20;
  else if (p.ingredientCount <= 5) score += 10;

  return Math.min(score, 100);
}
