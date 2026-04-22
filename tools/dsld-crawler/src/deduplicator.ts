import type { NormalizedProduct } from "./normalizer.ts";

/**
 * Products are frequently sold in multiple SKUs that differ only by pack size
 * (60 tablets vs 120 vs 250). For search purposes we want one row per unique
 * supplement formulation. The dedup key is:
 *
 *   brand + normalizedName + form + servingSize + sorted keyIngredients
 *
 * When multiple SKUs collide we keep the one with the largest
 * `servingsPerContainer` (proxy for "the popular size"), falling back to the
 * lower DSLD id on ties for determinism.
 */
export function dedupe(products: NormalizedProduct[]): NormalizedProduct[] {
  const groups = new Map<string, NormalizedProduct[]>();

  for (const p of products) {
    const key = dedupKey(p);
    const existing = groups.get(key);
    if (existing) existing.push(p);
    else groups.set(key, [p]);
  }

  const result: NormalizedProduct[] = [];
  for (const list of groups.values()) {
    list.sort((a, b) => {
      const byCount = (b.servingsPerContainer ?? 0) - (a.servingsPerContainer ?? 0);
      if (byCount !== 0) return byCount;
      return a.id.localeCompare(b.id);
    });
    result.push(list[0]);
  }

  return result;
}

function dedupKey(p: NormalizedProduct): string {
  const ingredients = [...p.keyIngredients]
    .map((i) => `${i.nutrientKey}:${i.amount}${i.unit}`)
    .sort()
    .join("|");
  const serving = p.servingSize
    ? `${p.servingSize.value}${p.servingSize.unit.toLowerCase()}`
    : "-";
  return [
    p.brand.toLowerCase(),
    canonicalName(p.name),
    p.form,
    serving,
    ingredients,
  ].join("");
}

function canonicalName(name: string): string {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}
