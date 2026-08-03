"use client";

import { useState } from "react";
import { createVariant } from "./actions";
import { SubmitButton } from "../../../SubmitButton";

export function VariantForm({ productId }: { productId: string }) {
  const [error, setError] = useState<string | undefined>();
  const [isPending, setIsPending] = useState(false);

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    setIsPending(true);
    try {
      const result = await createVariant(formData);
      setError(result?.error);
    } finally {
      setIsPending(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-wrap items-center gap-2">
      <input type="hidden" name="productId" value={productId} />
      <input name="sku" placeholder="SKU" required className="rounded border px-2 py-1 text-sm" />
      <input
        name="attributeName"
        placeholder="Attribute name (e.g. length)"
        className="rounded border px-2 py-1 text-sm"
      />
      <input
        name="attributeValue"
        placeholder="Attribute value (e.g. 6ft)"
        className="rounded border px-2 py-1 text-sm"
      />
      <input
        name="retailPriceInRupees"
        type="number"
        step="0.01"
        placeholder="Retail (₹)"
        required
        className="w-32 rounded border px-2 py-1 text-sm"
      />
      <input
        name="tradePriceInRupees"
        type="number"
        step="0.01"
        placeholder="Trade (₹)"
        required
        className="w-32 rounded border px-2 py-1 text-sm"
      />
      <input
        name="stockQuantity"
        type="number"
        placeholder="Stock"
        defaultValue={0}
        className="w-24 rounded border px-2 py-1 text-sm"
      />
      <SubmitButton pending={isPending} className="rounded bg-black px-2 py-1 text-sm text-white disabled:opacity-50">
        Add
      </SubmitButton>
      {error && <span className="text-xs text-red-600">{error}</span>}
    </form>
  );
}
