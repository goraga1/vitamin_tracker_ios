import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));

export interface NutrientEntry {
  readonly key: string;
  readonly displayName: string;
  readonly aliases: readonly string[];
  readonly unit: string;
  readonly category?: string;
}

interface NutrientsFile {
  readonly version: number;
  readonly nutrients: Record<string, NutrientEntry>;
}

/**
 * Loads the app's bundled nutrient dictionary so the crawler can map DSLD
 * ingredient names (e.g. "Cholecalciferol") to the stable `nutrientKey`
 * identifiers (e.g. "vitamin_d") the app indexes against.
 */
function loadNutrientsFile(): NutrientsFile {
  const candidates = [
    resolve(__dirname, "../../../Resources/nutrients.json"),
    resolve(__dirname, "../../../../vitamin_tracker_ios/Resources/nutrients.json"),
  ];
  for (const path of candidates) {
    try {
      const raw = readFileSync(path, "utf-8");
      return JSON.parse(raw) as NutrientsFile;
    } catch {
      // try next
    }
  }
  throw new Error(
    `Could not locate nutrients.json. Looked in:\n  ${candidates.join("\n  ")}`,
  );
}

const file = loadNutrientsFile();
const entries = Object.values(file.nutrients);

/**
 * Index of normalized alias → nutrientKey for O(1) lookup during ingredient
 * mapping. Aliases are stored lower-cased and whitespace-collapsed.
 */
const aliasToKey = new Map<string, string>();
for (const entry of entries) {
  const allNames = [entry.displayName, ...entry.aliases];
  for (const name of allNames) {
    aliasToKey.set(normalizeAlias(name), entry.key);
  }
}

export function matchNutrient(rawName: string): NutrientEntry | undefined {
  const normalized = normalizeAlias(rawName);
  const exact = aliasToKey.get(normalized);
  if (exact) return file.nutrients[exact];

  // Substring heuristic: check if any alias is contained in the raw name.
  // Prefer longer aliases (more specific matches like "vitamin d3" beat "d").
  const tokens = normalized.split(" ");
  for (let len = tokens.length; len >= 1; len--) {
    for (let i = 0; i <= tokens.length - len; i++) {
      const slice = tokens.slice(i, i + len).join(" ");
      const key = aliasToKey.get(slice);
      if (key) return file.nutrients[key];
    }
  }
  return undefined;
}

function normalizeAlias(name: string): string {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

export const nutrientKeys = Object.keys(file.nutrients);
