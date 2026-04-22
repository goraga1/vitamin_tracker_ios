import { mkdirSync, readFileSync, writeFileSync, existsSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import pLimit from "p-limit";

import { DSLDClient, type DSLDLabel, type DSLDSearchHit } from "./dsldClient.ts";
import { TOP_BRANDS } from "./topBrands.ts";
import { normalize, type NormalizedProduct } from "./normalizer.ts";
import { dedupe } from "./deduplicator.ts";
import { scorePopularity } from "./popularity.ts";
import { exportCatalog } from "./exporter.ts";

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUTPUT_ROOT = resolve(__dirname, "../output");
const RAW_ROOT = resolve(OUTPUT_ROOT, "raw");
const FINAL_OUTPUT = resolve(OUTPUT_ROOT, "catalog_v1.json");

const args = new Set(process.argv.slice(2));
const FULL_MODE = args.has("--full");
// Label enrichment pulls `keyIngredients` from /label/{id} but costs one
// request per product. DSLD rate-limits this aggressively (observed
// sustained 429s at >30 req/min). Default OFF — catalog ships with
// empty `keyIngredients`; full ingredients are fetched on-demand from
// the app when the user selects a product. Pass `--with-labels` to
// enrich anyway (slow, ~4-6 hours for 100 brands).
const WITH_LABELS = args.has("--with-labels");
const BRAND_CAP = FULL_MODE ? 200 : 50;
const BRANDS = FULL_MODE ? TOP_BRANDS : TOP_BRANDS.slice(0, 5);

// Concurrency: strictly serial. Observed empirically: DSLD rate-limits
// aggressively and starts returning sustained 429s at concurrency >= 2 after
// a few hundred requests, even with exponential backoff. Running serial with
// a small inter-request delay is slower but reliable. Individual failures
// are swallowed by `DSLDClient` — the crawl continues even if a handful of
// labels fail.
const limit = pLimit(1);
const INTER_REQUEST_DELAY_MS = Number(process.env.CRAWL_DELAY_MS ?? 150);

async function throttledLimit<T>(fn: () => Promise<T>): Promise<T> {
  return limit(async () => {
    const result = await fn();
    await new Promise((r) => setTimeout(r, INTER_REQUEST_DELAY_MS));
    return result;
  });
}

async function main() {
  mkdirSync(RAW_ROOT, { recursive: true });
  const client = new DSLDClient();

  console.log(
    `[crawler] mode=${FULL_MODE ? "FULL" : "SMOKE"} brands=${BRANDS.length} cap=${BRAND_CAP}/brand labels=${WITH_LABELS ? "ON (slow)" : "OFF (fast)"}`,
  );

  const byBrand = new Map<string, NormalizedProduct[]>();

  for (const brand of BRANDS) {
    const cachedPath = resolve(RAW_ROOT, `${slugify(brand)}.json`);
    if (existsSync(cachedPath)) {
      const cached = JSON.parse(readFileSync(cachedPath, "utf-8")) as {
        products: NormalizedProduct[];
      };
      byBrand.set(brand, cached.products);
      console.log(`[crawler] ${brand}: reusing ${cached.products.length} cached products`);
      continue;
    }

    console.log(`[crawler] ${brand}: fetching hits...`);
    const hits = await collectHits(client, brand, BRAND_CAP);
    console.log(`[crawler] ${brand}: ${hits.length} hits — fetching labels...`);

    const normalized: NormalizedProduct[] = [];
    if (WITH_LABELS) {
      await Promise.all(
        hits.map((hit) =>
          throttledLimit(async () => {
            const label = await client.getLabel(hit.dsldId);
            const product = normalize(hit, label);
            if (product) normalized.push(product);
          }),
        ),
      );
    } else {
      // Fast path: normalize from the search hit alone. Skips keyIngredients
      // (they'll be populated on-demand when the user taps a result) but
      // still produces a searchable brand + name + form-inferred entry.
      for (const hit of hits) {
        const product = normalize(hit, null);
        if (product) normalized.push(product);
      }
    }

    byBrand.set(brand, normalized);
    writeFileSync(
      cachedPath,
      JSON.stringify({ brand, products: normalized }, null, 2),
      "utf-8",
    );
    console.log(`[crawler] ${brand}: kept ${normalized.length} products\n`);
  }

  const merged = Array.from(byBrand.values()).flat();
  console.log(`[crawler] merged raw: ${merged.length} products`);

  const deduped = dedupe(merged);
  console.log(`[crawler] after dedup: ${deduped.length} products`);

  const scored = deduped.map((p) => ({ ...p, popularity: scorePopularity(p) }));
  scored.sort((a, b) => b.popularity - a.popularity);

  exportCatalog(scored, FINAL_OUTPUT, {
    version: "1.0.0",
    sourceRevision: "DSLD v9",
  });
  console.log(`[crawler] wrote ${FINAL_OUTPUT}`);

  // Quick summary for the operator
  const byBrandCount = new Map<string, number>();
  for (const p of scored) {
    byBrandCount.set(p.brand, (byBrandCount.get(p.brand) ?? 0) + 1);
  }
  const top10 = [...byBrandCount.entries()].sort((a, b) => b[1] - a[1]).slice(0, 10);
  console.log("[crawler] top brands by product count:");
  for (const [brand, count] of top10) console.log(`  ${count.toString().padStart(4)}  ${brand}`);
}

async function collectHits(
  client: DSLDClient,
  brand: string,
  cap: number,
): Promise<DSLDSearchHit[]> {
  const pageSize = 100;
  const all: DSLDSearchHit[] = [];
  let from = 0;
  let total = Infinity;

  while (all.length < cap && from < total) {
    try {
      const { hits, total: t } = await throttledLimit(() =>
        client.searchByBrand(brand, { size: pageSize, from }),
      );
      total = t;
      if (hits.length === 0) break;
      all.push(...hits);
      from += pageSize;
    } catch (err) {
      console.warn(`[crawler] page fetch failed for ${brand} at from=${from}:`, err);
      break;
    }
  }

  return all.slice(0, cap);
}

function slugify(s: string): string {
  return s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "");
}

main().catch((err) => {
  console.error("[crawler] fatal:", err);
  process.exit(1);
});
