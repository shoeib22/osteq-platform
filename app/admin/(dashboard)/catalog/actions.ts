"use server";

import { revalidatePath } from "next/cache";
import { adminApiFetch } from "@/lib/admin/api-fetch";

export async function saveCategory(formData: FormData): Promise<{ error?: string } | null> {
  const categoryId = String(formData.get("categoryId") ?? "");
  const name = String(formData.get("name") ?? "");
  const slug = String(formData.get("slug") ?? "");

  const path = categoryId ? `/api/osteq/categories/${categoryId}` : "/api/osteq/categories";
  const { error } = await adminApiFetch(path, {
    method: categoryId ? "PATCH" : "POST",
    body: { name, slug },
  });
  if (error) {
    return { error };
  }

  revalidatePath("/admin/catalog");
  return null;
}
