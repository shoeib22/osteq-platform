"use server";

import { revalidatePath } from "next/cache";
import { adminApiFetch } from "@/lib/admin/api-fetch";

export async function createProduct(formData: FormData): Promise<{ error?: string } | null> {
  const categoryId = String(formData.get("categoryId") ?? "");
  const name = String(formData.get("name") ?? "");
  const slug = String(formData.get("slug") ?? "");
  const description = String(formData.get("description") ?? "");

  const { error } = await adminApiFetch("/api/osteq/products", {
    method: "POST",
    body: { categoryId, name, slug, description: description || undefined },
  });
  if (error) {
    return { error };
  }

  revalidatePath(`/admin/catalog/${categoryId}`);
  return null;
}
