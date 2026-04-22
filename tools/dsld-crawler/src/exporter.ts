import { writeFileSync, mkdirSync } from "node:fs";
import { dirname } from "node:path";
import type { NormalizedProduct } from "./normalizer.ts";

export interface CatalogFile {
  readonly version: string;
  readonly generatedAt: string;
  readonly totalProducts: number;
  readonly sourceRevision: string;
  readonly products: readonly CatalogProduct[];
}

export interface CatalogProduct {
  readonly id: string;
  readonly brand: string;
  readonly name: string;
  readonly form: string;
  readonly servingSize?: { readonly value: number; readonly unit: string };
  readonly keyIngredients: ReadonlyArray<{
    readonly nutrientKey: string;
    readonly amount: number;
    readonly unit: string;
  }>;
  readonly searchableText: string;
  readonly popularity: number;
}

export function exportCatalog(
  products: NormalizedProduct[],
  outputPath: string,
  opts: { version: string; sourceRevision: string },
): void {
  mkdirSync(dirname(outputPath), { recursive: true });

  const serialized: CatalogProduct[] = products.map((p) => {
    const out: CatalogProduct = {
      id: p.id,
      brand: p.brand,
      name: p.name,
      form: p.form,
      servingSize: p.servingSize,
      keyIngredients: p.keyIngredients,
      searchableText: p.searchableText,
      popularity: p.popularity,
    };
    return out;
  });

  const file: CatalogFile = {
    version: opts.version,
    generatedAt: new Date().toISOString(),
    totalProducts: serialized.length,
    sourceRevision: opts.sourceRevision,
    products: serialized,
  };

  // Write pretty JSON so git diffs are readable; iOS side parses both fine.
  writeFileSync(outputPath, JSON.stringify(file, null, 2), "utf-8");
}
