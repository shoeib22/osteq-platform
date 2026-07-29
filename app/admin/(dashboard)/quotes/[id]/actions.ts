"use server";

import { revalidatePath } from "next/cache";
import { adminApiFetch } from "@/lib/admin/api-fetch";

export async function priceQuote(formData: FormData): Promise<{ error?: string } | null> {
  const quoteId = String(formData.get("quoteId") ?? "");
  const itemIds = formData.getAll("itemId").map(String);
  const lines = itemIds
    .map((itemId) => {
      const price = formData.get(`price-${itemId}`);
      const priceStr = typeof price === "string" ? price.trim() : "";
      if (priceStr === "") {
        return null;
      }
      const quotedUnitPriceInPaise = Number(priceStr);
      return Number.isFinite(quotedUnitPriceInPaise) ? { itemId, quotedUnitPriceInPaise } : null;
    })
    .filter((line): line is { itemId: string; quotedUnitPriceInPaise: number } => line !== null);

  const { error } = await adminApiFetch(`/api/osteq/quotes/${quoteId}/price`, {
    method: "PATCH",
    body: { lines },
  });
  if (error) {
    return { error };
  }

  revalidatePath(`/admin/quotes/${quoteId}`);
  revalidatePath("/admin/quotes");
  return null;
}

export async function sendQuoteMessage(formData: FormData): Promise<{ error?: string } | null> {
  const quoteId = String(formData.get("quoteId") ?? "");
  const body = String(formData.get("body") ?? "");

  const { error } = await adminApiFetch(`/api/osteq/quotes/${quoteId}/messages`, {
    method: "POST",
    body: { body },
  });
  if (error) {
    return { error };
  }

  revalidatePath(`/admin/quotes/${quoteId}`);
  return null;
}
