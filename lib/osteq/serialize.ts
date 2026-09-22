function isDecimalLike(value: unknown): value is { toNumber(): number } {
  return (
    typeof value === "object" &&
    value !== null &&
    "toNumber" in value &&
    typeof (value as { toNumber: unknown }).toNumber === "function"
  );
}

/**
 * Recursively converts Prisma Decimal instances to plain numbers before a response goes
 * out. Prisma's Decimal.toJSON() returns a string (e.g. "1000.00"), so a Decimal field
 * passed straight into NextResponse.json() silently becomes a JSON string, not a number —
 * this keeps the wire contract a plain number everywhere (Flutter/Dart and any other
 * consumer just does `as num`, no need to know which fields might arrive as strings).
 */
export function serializeDecimals<T>(value: T): T {
  if (isDecimalLike(value)) {
    return value.toNumber() as unknown as T;
  }
  if (value instanceof Date) {
    return value;
  }
  if (Array.isArray(value)) {
    return value.map((v) => serializeDecimals(v)) as unknown as T;
  }
  if (value && typeof value === "object") {
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
      out[k] = serializeDecimals(v);
    }
    return out as T;
  }
  return value;
}

/**
 * The client only ever needs to know whether an invoice PDF exists, never the raw
 * storage path (access always goes through the signed-URL endpoint) — this mirrors the
 * "store the relative path, never a URL" convention by keeping the path itself entirely
 * server-side too.
 */
export function withInvoiceFlag<T extends { invoicePdfPath?: string | null }>(
  order: T,
): Omit<T, "invoicePdfPath"> & { hasInvoicePdf: boolean } {
  const { invoicePdfPath, ...rest } = order;
  return { ...rest, hasInvoicePdf: invoicePdfPath != null };
}
