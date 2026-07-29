"use client";

import { useState } from "react";
import type { OsteqProduct } from "@prisma/client";
import { updateProduct } from "./actions";
import { SubmitButton } from "../../../SubmitButton";

export function ProductEditForm({ product }: { product: OsteqProduct }) {
  const [error, setError] = useState<string | undefined>();
  const [isPending, setIsPending] = useState(false);

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    setIsPending(true);
    try {
      const result = await updateProduct(formData);
      setError(result?.error);
    } finally {
      setIsPending(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-2 rounded border p-4">
      <input type="hidden" name="productId" value={product.id} />
      <label className="text-sm">
        Name
        <input
          name="name"
          defaultValue={product.name}
          required
          className="mt-1 w-full rounded border px-2 py-1 text-sm"
        />
      </label>
      <label className="text-sm">
        Description
        <textarea
          name="description"
          defaultValue={product.description ?? ""}
          className="mt-1 w-full rounded border px-2 py-1 text-sm"
        />
      </label>
      <label className="flex items-center gap-2 text-sm">
        <input type="checkbox" name="isActive" defaultChecked={product.isActive} />
        Active
      </label>
      <SubmitButton pending={isPending} className="w-fit rounded bg-black px-3 py-1 text-sm text-white disabled:opacity-50">
        Save
      </SubmitButton>
      {error && <span className="text-xs text-red-600">{error}</span>}
    </form>
  );
}
