type AccountStatus = "PENDING" | "TRADE_APPROVED" | "REJECTED" | null | undefined;

/**
 * The single place that decides retail vs. trade price for a given customer — every
 * endpoint that prices a variant (catalog read, cart, checkout, quotes) calls this instead
 * of inlining the accountStatus check, so there is exactly one rule to change if pricing
 * logic ever grows beyond a flat two-tier split.
 */
export function resolveVariantPrice(
  variant: { retailPriceInPaise: number; tradePriceInPaise: number },
  accountStatus: AccountStatus,
): { priceInPaise: number; tier: "retail" | "trade" } {
  if (accountStatus === "TRADE_APPROVED") {
    return { priceInPaise: variant.tradePriceInPaise, tier: "trade" };
  }
  return { priceInPaise: variant.retailPriceInPaise, tier: "retail" };
}
