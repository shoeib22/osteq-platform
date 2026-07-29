"use client";

import { useState } from "react";
import { createProduct } from "./actions";
import { SubmitButton } from "../../SubmitButton";

export function ProductForm({ categoryId }: { categoryId: string }) {
  const [error, setError] = useState<string | undefined>();
  const [isPending, setIsPending] = useState(false);

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    setIsPending(true);
    try {
      const result = await createProduct(formData);
      setError(result?.error);
    } finally {
      setIsPending(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-wrap items-center gap-2">
      <input type="hidden" name="categoryId" value={categoryId} />
      <input name="name" placeholder="Name" required className="rounded border px-2 py-1 text-sm" />
      <input name="slug" placeholder="slug" required className="rounded border px-2 py-1 text-sm" />
      <input name="description" placeholder="Description" className="rounded border px-2 py-1 text-sm" />
      <SubmitButton pending={isPending} className="rounded bg-black px-2 py-1 text-sm text-white disabled:opacity-50">
        Add
      </SubmitButton>
      {error && <span className="text-xs text-red-600">{error}</span>}
    </form>
  );
}
