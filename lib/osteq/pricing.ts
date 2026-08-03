type AccountStatus = "PENDING" | "TRADE_APPROVED" | "REJECTED" | null | undefined;

// Prisma's Decimal fields come back as a decimal.js instance, not a plain number — this
// converts either shape to a plain JS number for arithmetic/JSON, since a single
// exact-numeric(10,2)-to-number conversion per value is precision-safe (the accumulated
// float-error risk that InRupees storage avoids applies to repeated arithmetic, not a
// one-time read of an exact decimal).
type DecimalLike = number | { toNumber(): number };
function toNumber(value: DecimalLike): number {
  return typeof value === "number" ? value : value.toNumber();
}

/**
 * The single place that decides retail vs. trade price for a given customer — every
 * endpoint that prices a variant (catalog read, cart, checkout, quotes) calls this instead
 * of inlining the accountStatus check, so there is exactly one rule to change if pricing
 * logic ever grows beyond a flat two-tier split.
 */
export function resolveVariantPrice(
  variant: { retailPriceInRupees: DecimalLike; tradePriceInRupees: DecimalLike },
  accountStatus: AccountStatus,
): { priceInRupees: number; tier: "retail" | "trade" } {
  if (accountStatus === "TRADE_APPROVED") {
    return { priceInRupees: toNumber(variant.tradePriceInRupees), tier: "trade" };
  }
  return { priceInRupees: toNumber(variant.retailPriceInRupees), tier: "retail" };
}
