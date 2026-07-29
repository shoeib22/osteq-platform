"use client";

import { useState } from "react";
import type { OsteqQuoteItem, OsteqProductVariant } from "@prisma/client";
import { priceQuote } from "./actions";
import { SubmitButton } from "../../SubmitButton";

type ItemWithVariant = OsteqQuoteItem & { variant: OsteqProductVariant | null };

export function PriceForm({ quoteId, items }: { quoteId: string; items: ItemWithVariant[] }) {
  const [error, setError] = useState<string | undefined>();
  const [isPending, setIsPending] = useState(false);

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    setIsPending(true);
    try {
      const result = await priceQuote(formData);
      setError(result?.error);
    } finally {
      setIsPending(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} className="mb-6 flex flex-col gap-2">
      <input type="hidden" name="quoteId" value={quoteId} />
      {items.map((item) => (
        <div key={item.id} className="flex items-center gap-2 text-sm">
          <input type="hidden" name="itemId" value={item.id} />
          <span className="w-64">
            {item.variant?.sku ?? item.description} — qty {item.quantity}
          </span>
          <input
            name={`price-${item.id}`}
            type="number"
            placeholder="Unit price (paise)"
            defaultValue={item.quotedUnitPriceInPaise ?? undefined}
            className="w-40 rounded border px-2 py-1"
          />
        </div>
      ))}
      <SubmitButton pending={isPending} className="w-fit rounded bg-black px-3 py-1 text-sm text-white disabled:opacity-50">
        Save prices &amp; mark quoted
      </SubmitButton>
      {error && <span className="text-xs text-red-600">{error}</span>}
    </form>
  );
}
