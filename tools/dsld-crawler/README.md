# DSLD Crawler

Builds `catalog_v1.json` — the bundled supplement catalog shipped inside the
Vitamin Tracker iOS app. The file is the first-stage search index: it gives
users instant, offline-first results for ~80% of the products they search for.

Data source: the NIH [Dietary Supplement Label Database](https://dsld.od.nih.gov/) (DSLD) v9 public API.

## Why this tool exists

DSLD has ~170k products — way too many to bundle as-is. This crawler pulls
products from a whitelist of ~100 top brands (see `src/topBrands.ts`),
normalizes and deduplicates them, and produces a single JSON file with
~3,000–5,000 entries that fits comfortably in the app bundle (1–5 MB).

Mapping rules live in three files:
- `topBrands.ts` — which brands to fetch
- `normalizer.ts` — how to clean brand/product names and infer dosage form
- `deduplicator.ts` — how to collapse SKUs that differ only by pack size

## Usage

```bash
cd tools/dsld-crawler
npm install

# Smoke test: only fetches the first 5 brands, max 50 products each.
# Good for verifying the pipeline works before the long run.
npm run crawl

# Full crawl (all ~100 brands, cap 200 products/brand, ~5-10 min).
# Ships an empty `keyIngredients` array per product — see below.
npm run build-catalog

# Full crawl WITH per-label ingredient enrichment. Much slower (~4-6 hours)
# and runs into DSLD rate limits frequently, so expect some lost products.
# Only run this if you explicitly need ingredient data baked into the
# bundled catalog (usually not needed — the app fetches labels on-demand
# when the user selects a search result).
npx tsx src/index.ts --full --with-labels
```

**On `keyIngredients`**: the default build skips `/label/{id}` fetches to
stay under DSLD's rate limits. The resulting catalog has empty
`keyIngredients: []` per product, which is fine for search (users query by
brand + name, not by ingredient dose). When the user selects a result, the
app hits `/label/{id}` for full ingredient data via `DSLDClient.shared.label`.

Output lands in `output/catalog_v1.json`. Per-brand intermediate results are
cached at `output/raw/<brand-slug>.json` so you can resume after an
interruption — delete those files to force re-fetch.

## Shipping a new catalog to the app

1. Run `npm run build-catalog`.
2. Inspect `output/catalog_v1.json` — sanity-check total count and spot-check a
   few popular products.
3. Copy the file into the iOS bundle:
   ```bash
   cp output/catalog_v1.json ../../Resources/catalog_v1.json
   ```
4. Commit both the crawler changes (if any) and the regenerated JSON in one
   PR so reviewers can tie the output to the input.
5. In the app, `BundledCatalogLoader` picks up the new file on the next cold
   launch — no additional wiring needed.

## When to rebuild

- **Quarterly** as a baseline refresh (DSLD updates continuously).
- **Ad-hoc** when users report a popular product missing from search.
- **Whenever you add a brand** to `topBrands.ts` — otherwise the change is
  inert.

## Expected runtime

At a concurrency of 3 requests (see `p-limit` in `src/index.ts`) the full
crawl takes roughly 30–60 min on a home internet connection. The crawler
emits progress lines per brand; an interrupted run can be resumed because
per-brand output is cached under `output/raw/`.

## Rate limiting & politeness

- `p-limit(3)` caps concurrent requests across the whole run.
- Each axios call has a 30s timeout and up to 3 retries with exponential
  backoff for 5xx / timeouts.
- A `User-Agent` header identifies the crawler so NIH ops can reach out if
  we ever become a problem.

If DSLD starts returning 429s, lower `pLimit` to 2 or 1. We have no signed
agreement with NIH — be a good citizen.

## Troubleshooting

- **"Could not locate nutrients.json"** — `nutrientsDict.ts` resolves the
  path relative to the crawler. If you moved the iOS `Resources/` folder,
  update the `candidates` array in that file.
- **Very low yield per brand** — DSLD search tokenization is permissive.
  Try searching manually on https://dsld.od.nih.gov/ first to confirm the
  brand spelling matches what they store.
- **Stale cache serving old data** — delete `output/raw/<brand>.json` for
  the affected brand and re-run.

## Schema of the output file

```jsonc
{
  "version": "1.0.0",
  "generatedAt": "2026-04-22T12:00:00Z",
  "totalProducts": 3247,
  "sourceRevision": "DSLD v9",
  "products": [
    {
      "id": "123456",
      "brand": "Nature Made",
      "name": "Vitamin D3 2000 IU",
      "form": "softgel",
      "servingSize": { "value": 1, "unit": "Softgel" },
      "keyIngredients": [
        { "nutrientKey": "vitamin_d", "amount": 50, "unit": "mcg" }
      ],
      "searchableText": "nature made vitamin d3 2000 iu softgel vitamin d 50 mcg",
      "popularity": 85
    }
  ]
}
```

`searchableText` is pre-lowercased and stripped of punctuation so the iOS
indexer can skip that step at launch.
