import type { DSLDLabel, DSLDSearchHit } from "./dsldClient.ts";
import { matchNutrient } from "./nutrientsDict.ts";

export type Form =
  | "tablet"
  | "capsule"
  | "softgel"
  | "liquid"
  | "powder"
  | "gummy"
  | "lozenge"
  | "other";

export interface KeyIngredient {
  readonly nutrientKey: string;
  readonly amount: number;
  readonly unit: string;
}

export interface NormalizedProduct {
  readonly id: string;
  readonly brand: string;
  readonly name: string;
  readonly form: Form;
  readonly servingSize?: { readonly value: number; readonly unit: string };
  readonly keyIngredients: KeyIngredient[];
  readonly searchableText: string;
  readonly popularity: number;
  readonly servingsPerContainer?: number;
  readonly ingredientCount: number;
}

const BRAND_CASING_EXCEPTIONS: Record<string, string> = {
  "now foods": "NOW Foods",
  "now": "NOW",
  "gnc": "GNC",
  "ag1": "AG1",
  "bsn": "BSN",
  "evl": "EVL",
  "bpn": "BPN",
  "1st phorm": "1st Phorm",
  "bubs naturals": "BUBS Naturals",
  "nad+": "NAD+",
};

export function normalizeBrand(raw: string): string {
  const collapsed = raw.replace(/\s+/g, " ").trim();
  const lower = collapsed.toLowerCase();
  if (BRAND_CASING_EXCEPTIONS[lower]) return BRAND_CASING_EXCEPTIONS[lower];

  return collapsed
    .split(" ")
    .map((word) => {
      const lw = word.toLowerCase();
      if (BRAND_CASING_EXCEPTIONS[lw]) return BRAND_CASING_EXCEPTIONS[lw];
      // Preserve apostrophes: "nature's" → "Nature's"
      if (word.includes("'")) {
        const [head, ...rest] = word.split("'");
        return capitalize(head) + "'" + rest.join("'").toLowerCase();
      }
      return capitalize(word);
    })
    .join(" ");
}

function capitalize(word: string): string {
  if (!word) return word;
  return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase();
}

const PACK_SIZE_RE =
  /\b(?:pack of\s*\d+|\d+\s*(?:ct|count|tablets?|capsules?|softgels?|caplets?|gummies|servings?|pieces?|lozenges?|pk)\.?)\b/gi;

const TRAILING_SIZE_RE = /[,\-–—]?\s*\d+\s*(?:ct|count|tabs?|caps?)\.?\s*$/i;

export function normalizeProductName(raw: string, brand: string): string {
  let name = raw.replace(/\s+/g, " ").trim();

  // Strip brand prefix (exact + case-insensitive)
  const brandLower = brand.toLowerCase();
  if (name.toLowerCase().startsWith(brandLower)) {
    name = name.slice(brand.length).trim();
  }

  // Also strip any common "Brand's" variant
  const brandPossessive = brand + "'s";
  if (name.toLowerCase().startsWith(brandPossessive.toLowerCase())) {
    name = name.slice(brandPossessive.length).trim();
  }

  // Strip pack size markers anywhere
  name = name.replace(PACK_SIZE_RE, " ");
  // And trailing sizes
  name = name.replace(TRAILING_SIZE_RE, "");

  // Collapse leftover whitespace / punctuation
  name = name.replace(/\s+/g, " ").replace(/\s+([.,;:])/g, "$1").trim();
  name = name.replace(/^[\-–—,]+\s*/, "").replace(/\s*[\-–—,]+$/, "").trim();

  return name;
}

const FORM_KEYWORDS: Array<[Form, RegExp]> = [
  ["softgel", /\bsoft[-\s]?gels?\b/i],
  ["gummy", /\bgummies\b|\bgummy\b/i],
  ["capsule", /\bcaps?(ules?)?\b|\bveg[-\s]?caps?\b|\bvcaps?\b/i],
  ["tablet", /\btabs?(lets?)?\b|\bcaplets?\b/i],
  ["lozenge", /\blozenges?\b|\btroches?\b/i],
  ["liquid", /\bliquid\b|\bdrops?\b|\btincture\b|\bsyrup\b|\bspray\b/i],
  ["powder", /\bpowders?\b|\bscoops?\b/i],
];

export function inferForm(name: string, physicalState?: string): Form {
  const haystack = `${name} ${physicalState ?? ""}`;
  for (const [form, re] of FORM_KEYWORDS) {
    if (re.test(haystack)) return form;
  }
  return "other";
}

function pickServingSize(label: DSLDLabel): NormalizedProduct["servingSize"] {
  const first = label.servingSizes?.[0];
  if (!first) return undefined;
  const value = first.quantity ?? first.minQuantity ?? first.maxQuantity;
  if (value == null) return undefined;
  return { value, unit: first.unit ?? "serving" };
}

// Nutrition-facts rows we ignore when picking "key" ingredients — these are
// macros and non-nutrient categories that clutter search indexing.
const INGREDIENT_BLOCKLIST_CATEGORIES = new Set([
  "other",              // Calories, Sodium when not nutritionally indexed
  "fat",                // Total Fat, Cholesterol, Saturated Fat
  "carbohydrate",       // Total Carbs, Sugars, Dietary Fiber
  "protein",            // Protein as a macro (we handle protein separately if needed)
  "other ingredients",
  "non-nutritive ingredients",
  "inactive ingredients",
]);

export function extractKeyIngredients(label: DSLDLabel, limit = 5): KeyIngredient[] {
  const rows = label.ingredientRows ?? [];
  const sorted = [...rows].sort(
    (a, b) => (a.order ?? 99999) - (b.order ?? 99999),
  );

  const out: KeyIngredient[] = [];
  const seenKeys = new Set<string>();

  for (const row of sorted) {
    const category = (row.category ?? "").toLowerCase();
    if (INGREDIENT_BLOCKLIST_CATEGORIES.has(category)) continue;
    if (!row.name) continue;

    const match = matchNutrient(row.name);
    if (!match) continue;
    if (seenKeys.has(match.key)) continue;

    const q = row.quantity?.[0];
    if (!q || q.quantity == null) continue;

    out.push({
      nutrientKey: match.key,
      amount: q.quantity,
      unit: (q.unit ?? match.unit).toLowerCase(),
    });
    seenKeys.add(match.key);

    if (out.length >= limit) break;
  }

  return out;
}

export function buildSearchableText(
  brand: string,
  name: string,
  keyIngredients: KeyIngredient[],
): string {
  const ingredientTokens = keyIngredients
    .flatMap((ing) => [ing.nutrientKey.replace(/_/g, " "), `${ing.amount} ${ing.unit}`])
    .join(" ");
  return `${brand} ${name} ${ingredientTokens}`
    .toLowerCase()
    .replace(/[^a-z0-9\s.+%-]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

export function normalize(
  hit: DSLDSearchHit,
  label: DSLDLabel | null,
): NormalizedProduct | null {
  const fallbackLabel: DSLDLabel = label ?? {
    dsldId: hit.dsldId,
    brandName: hit.brandName,
    fullName: hit.fullName,
  };

  const brand = normalizeBrand(fallbackLabel.brandName || hit.brandName);
  if (!brand) return null;

  const rawName = fallbackLabel.fullName || fallbackLabel.productName || hit.fullName;
  const name = normalizeProductName(rawName, brand);
  if (!name) return null;

  const form = inferForm(
    name,
    fallbackLabel.physicalState?.name ??
      fallbackLabel.physicalState?.langualCodeDescription,
  );
  const servingSize = pickServingSize(fallbackLabel);
  const keyIngredients = extractKeyIngredients(fallbackLabel);
  const searchableText = buildSearchableText(brand, name, keyIngredients);

  return {
    id: fallbackLabel.dsldId,
    brand,
    name,
    form,
    servingSize,
    keyIngredients,
    searchableText,
    popularity: 0, // filled in after full scan, see scorePopularity
    servingsPerContainer: fallbackLabel.servingsPerContainer,
    ingredientCount: fallbackLabel.ingredientRows?.length ?? 0,
  };
}
