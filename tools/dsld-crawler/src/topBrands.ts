/**
 * Whitelist of supplement brands covering ~95% of product volume across
 * US mass market, premium/practitioner, sports nutrition, D2C viral,
 * longevity, and European categories.
 *
 * The crawler queries DSLD `search-filter?brand=<name>` for each entry here
 * and pulls every on-market product it finds. Brand strings must match what
 * DSLD stores — see `normalizer.ts` for the post-fetch normalization applied
 * to the raw strings.
 */
export const TOP_BRANDS: readonly string[] = [
  // Mass market US
  "Nature Made", "Nature's Bounty", "Nature's Way", "Nature's Plus",
  "Centrum", "One A Day", "Vitafusion", "Kirkland Signature",
  "GNC", "21st Century", "Sundown Naturals", "Puritan's Pride",
  "Spring Valley", "Equate", "up & up", "Natrol",

  // Mid-tier quality
  // Note: some brand names below use the shortest DSLD-indexed form.
  // DSLD's brand-products endpoint AND's all query tokens, so
  // "Bluebonnet Nutrition" returns 0 even though "Bluebonnet" returns ~1800.
  "NOW Foods", "Solgar", "Jarrow Formulas", "Life Extension",
  "Doctor's Best", "Swanson", "Bluebonnet", "Country Life",
  "Bronson", "Source Naturals", "Carlson", "California Gold Nutrition",
  "Physician's Choice", "Sports Research",

  // Premium / Practitioner
  "Thorne", "Pure Encapsulations", "Designs for Health", "Metagenics",
  "Klaire Labs", "Seeking Health", "Standard Process", "Quicksilver Scientific",
  "Biotics Research", "Xymogen", "Integrative Therapeutics", "Ortho Molecular Products",

  // Whole food / Organic
  "Garden of Life", "New Chapter", "MegaFood", "Rainbow Light",
  "Gaia Herbs", "Himalaya", "Ancient Nutrition", "Nordic Naturals",

  // D2C gummies / women / consumer
  "Olly", "Ritual", "Mary Ruth's", "Hum Nutrition",
  "Goli Nutrition", "SmartyPants", "Hiya Health",

  // Sports nutrition — mass market
  "Optimum Nutrition", "MyProtein", "Dymatize", "BSN",
  "MuscleTech", "Cellucor", "Ghost", "Alani Nu",
  "1st Phorm", "BPN", "Animal", "EVL", "Ryse", "Gorilla Mind",

  // Sports nutrition — premium
  "Transparent Labs", "Legion", "Jocko Fuel", "Momentous",
  "Onnit", "Vital Proteins", "BUBS Naturals",

  // Greens / meal replacement
  "AG1", "Bloom Nutrition", "Organifi", "Amazing Grass", "Ka'Chava",

  // Longevity / NAD+
  "Tru Niagen", "Elysium Health", "Timeline Nutrition",
  "Novos Labs", "Neurohacker Collective",

  // Probiotics / gut
  "Seed", "Culturelle", "Align", "Renew Life", "Just Thrive", "Pendulum",

  // Mushroom
  "Four Sigmatic", "Host Defense", "Real Mushrooms", "Om Mushrooms",

  // Specialty
  "BiOptimizers", "Natural Vitality", "Enzymedica", "Zahler",
  "Nutrafol", "Moon Juice",

  // Women's / prenatal
  "Needed", "Perelel", "Flo Vitamins",

  // European (international audience)
  "Vitabiotics", "Viridian", "Doppelherz", "Orthomol",
];

/**
 * Subset of brands that get a popularity boost — consumer-facing mass market
 * names that tend to dominate search intent.
 */
export const TOP_15_BRANDS: ReadonlySet<string> = new Set([
  "Nature Made", "Nature's Bounty", "Centrum", "One A Day", "NOW Foods",
  "Thorne", "Pure Encapsulations", "Garden of Life", "Olly", "Ritual",
  "Optimum Nutrition", "AG1", "Seed", "Nordic Naturals", "Life Extension",
]);
