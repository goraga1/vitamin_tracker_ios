import axios, { AxiosInstance, AxiosError } from "axios";

const BASE_URL = "https://api.ods.od.nih.gov/dsld/v9";
const USER_AGENT = "VitaminTracker-Crawler/1.0 (contact@vitamintracker.app)";

export interface DSLDSearchHit {
  readonly dsldId: string;
  readonly brandName: string;
  readonly fullName: string;
  readonly status?: string;
  readonly thumbnail?: string;
}

export interface DSLDLabel {
  readonly dsldId: string;
  readonly brandName: string;
  readonly fullName: string;
  readonly productName?: string;
  readonly status?: string;
  readonly physicalState?: { langualCodeDescription?: string; name?: string };
  readonly servingSizes?: Array<{
    unit?: string;
    quantity?: number;
    minQuantity?: number;
    maxQuantity?: number;
  }>;
  readonly ingredientRows?: Array<{
    name?: string;
    category?: string;
    quantity?: Array<{
      quantity?: number;
      unit?: string;
      dailyValueTargetGroup?: Array<{ percent?: number }>;
    }>;
    forms?: Array<{ name?: string }>;
    order?: number;
  }>;
  readonly netContents?: Array<{ unit?: string; quantity?: number }>;
  readonly servingsPerContainer?: number;
  readonly thumbnail?: string;
}

export interface SearchOptions {
  readonly size?: number;
  readonly from?: number;
}

export class DSLDClient {
  private readonly http: AxiosInstance;

  constructor() {
    this.http = axios.create({
      baseURL: BASE_URL,
      timeout: 30_000,
      headers: {
        "User-Agent": USER_AGENT,
        Accept: "application/json",
      },
    });
  }

  /**
   * Fetch a page of products for a given brand via DSLD's dedicated
   * `/brand-products` endpoint (more precise than `/search-filter?q=`,
   * which does fuzzy full-text matching and returns unrelated products).
   * Returns up to `size` hits starting at `from`.
   */
  async searchByBrand(
    brand: string,
    options: SearchOptions = {},
  ): Promise<{ hits: DSLDSearchHit[]; total: number }> {
    const size = options.size ?? 100;
    const from = options.from ?? 0;
    const params = { q: brand, size, from };

    try {
      return await this.withRetry(async () => {
        const res = await this.http.get("/brand-products", { params });
        return this.parseSearchResponse(res.data);
      }, `searchByBrand(${brand}, from=${from})`);
    } catch (err) {
      console.warn(
        `[DSLD] searchByBrand(${brand}) gave up: ${(err as Error).message}`,
      );
      return { hits: [], total: 0 };
    }
  }

  async getLabel(dsldId: string): Promise<DSLDLabel | null> {
    try {
      return await this.withRetry(async () => {
        const res = await this.http.get(`/label/${encodeURIComponent(dsldId)}`);
        return this.parseLabelResponse(dsldId, res.data);
      }, `getLabel(${dsldId})`);
    } catch (err) {
      // Swallow individual label failures — losing one product shouldn't
      // abort the whole crawl. Caller will skip this one and move on.
      console.warn(`[DSLD] getLabel(${dsldId}) gave up: ${(err as Error).message}`);
      return null;
    }
  }

  private parseSearchResponse(data: unknown): { hits: DSLDSearchHit[]; total: number } {
    // DSLD v9 `/brand-products` returns { total: {value, relation}, hits: [...] }
    // where each hit has shape { _id, _source: {...} }. Older `/search-filter`
    // response also decoded here as a fallback.
    const d = data as any;
    const totalVal = d?.total?.value ?? d?.total ?? d?.hits?.total?.value ?? 0;
    const total = Number(totalVal) || 0;
    const arr: unknown[] = d?.hits?.hits ?? d?.hits ?? [];
    const hits: DSLDSearchHit[] = [];
    for (const raw of arr) {
      const r = raw as any;
      const source = r?._source ?? r?.source ?? r;
      const dsldId = String(
        r?._id ?? source?.DSLD_ID ?? source?.dsldId ?? source?.id ?? "",
      );
      if (!dsldId) continue;
      hits.push({
        dsldId,
        brandName: String(source?.brandName ?? ""),
        fullName: String(source?.fullName ?? source?.productName ?? ""),
        status: source?.status,
        thumbnail: source?.thumbnail,
      });
    }
    return { hits, total };
  }

  private parseLabelResponse(dsldId: string, data: any): DSLDLabel {
    return {
      dsldId,
      brandName: String(data?.brandName ?? ""),
      fullName: String(data?.fullName ?? data?.productName ?? ""),
      productName: data?.productName,
      status: data?.status,
      physicalState: data?.physicalState,
      servingSizes: data?.servingSizes,
      ingredientRows: data?.ingredientRows,
      netContents: data?.netContents,
      servingsPerContainer: data?.servingsPerContainer,
      thumbnail: data?.thumbnail,
    };
  }

  private async withRetry<T>(
    fn: () => Promise<T>,
    label: string,
    attempt = 1,
  ): Promise<T> {
    try {
      return await fn();
    } catch (err) {
      const error = err as AxiosError;
      const status = error.response?.status;
      const retriable =
        !status ||
        status === 429 || // rate-limited — back off harder
        status >= 500 ||
        error.code === "ECONNABORTED" ||
        error.code === "ETIMEDOUT";
      const maxAttempts = status === 429 ? 6 : 4;
      if (retriable && attempt < maxAttempts) {
        // Exponential backoff: 1s → 2s → 4s → 8s → 16s → 32s (cap 60s)
        const delay = Math.min(1000 * 2 ** (attempt - 1), 60_000);
        console.warn(
          `[DSLD] ${label} failed (status=${status ?? "network"}). Retry ${attempt}/${maxAttempts - 1} in ${delay}ms`,
        );
        await new Promise((r) => setTimeout(r, delay));
        return this.withRetry(fn, label, attempt + 1);
      }
      if (status === 404) {
        // 404 on /label is expected for withdrawn products — treat as null
        return null as unknown as T;
      }
      throw err;
    }
  }
}
