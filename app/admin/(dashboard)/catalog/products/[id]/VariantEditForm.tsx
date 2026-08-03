"use client";

import { useState } from "react";
import type { OsteqProductVariant } from "@prisma/client";
import { updateVariant } from "./actions";
import { SubmitButton } from "../../../SubmitButton";

export function VariantEditForm({
  productId,
  variant,
}: {
  productId: string;
  variant: OsteqProductVariant;
}) {
  const [error, setError] = useState<string | undefined>();
  const [isPending, setIsPending] = useState(false);
  const formId = `variant-form-${variant.id}`;

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    setIsPending(true);
    try {
      const result = await updateVariant(formData);
      setError(result?.error);
    } finally {
      setIsPending(false);
    }
  }

  return (
    <tr className="border-b">
      <td className="p-2">{variant.sku}</td>
      <td className="p-2">{JSON.stringify(variant.attributes)}</td>
      <td className="p-2">
        <input
          name="retailPriceInRupees"
          type="number"
          step="0.01"
          defaultValue={Number(variant.retailPriceInRupees)}
          form={formId}
          className="w-24 rounded border px-2 py-1 text-sm"
        />
      </td>
      <td className="p-2">
        <input
          name="tradePriceInRupees"
          type="number"
          step="0.01"
          defaultValue={Number(variant.tradePriceInRupees)}
          form={formId}
          className="w-24 rounded border px-2 py-1 text-sm"
        />
      </td>
      <td className="p-2">
        <input
          name="stockQuantity"
          type="number"
          defaultValue={variant.stockQuantity}
          form={formId}
          className="w-20 rounded border px-2 py-1 text-sm"
        />
      </td>
      <td className="p-2">
        <input type="checkbox" name="isActive" defaultChecked={variant.isActive} form={formId} />
      </td>
      <td className="p-2">
        <form id={formId} onSubmit={handleSubmit}>
          <input type="hidden" name="productId" value={productId} />
          <input type="hidden" name="variantId" value={variant.id} />
          <SubmitButton pending={isPending} className="rounded bg-black px-2 py-1 text-xs text-white disabled:opacity-50">
            Save
          </SubmitButton>
        </form>
        {error && <span className="ml-2 text-xs text-red-600">{error}</span>}
      </td>
    </tr>
  );
}
