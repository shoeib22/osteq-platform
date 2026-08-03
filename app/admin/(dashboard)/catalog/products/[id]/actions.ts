"use server";

import { revalidatePath } from "next/cache";
import { adminApiFetch } from "@/lib/admin/api-fetch";

export async function updateProduct(formData: FormData): Promise<{ error?: string } | null> {
  const productId = String(formData.get("productId") ?? "");
  const categoryId = String(formData.get("categoryId") ?? "");
  const name = String(formData.get("name") ?? "");
  const description = String(formData.get("description") ?? "");
  const isActive = formData.get("isActive") === "on";

  const { error } = await adminApiFetch(`/api/osteq/products/${productId}`, {
    method: "PATCH",
    body: { name, description, isActive },
  });
  if (error) {
    return { error };
  }

  revalidatePath(`/admin/catalog/products/${productId}`);
  if (categoryId) {
    revalidatePath(`/admin/catalog/${categoryId}`);
  }
  return null;
}

export async function createVariant(formData: FormData): Promise<{ error?: string } | null> {
  const productId = String(formData.get("productId") ?? "");
  const sku = String(formData.get("sku") ?? "");
  const attributeName = String(formData.get("attributeName") ?? "").trim();
  const attributeValue = String(formData.get("attributeValue") ?? "").trim();
  const retailPriceInRupees = Number(formData.get("retailPriceInRupees"));
  const tradePriceInRupees = Number(formData.get("tradePriceInRupees"));
  const stockQuantity = Number(formData.get("stockQuantity"));

  const { error } = await adminApiFetch(`/api/osteq/products/${productId}/variants`, {
    method: "POST",
    body: {
      sku,
      attributes: attributeName && attributeValue ? { [attributeName]: attributeValue } : {},
      retailPriceInRupees,
      tradePriceInRupees,
      stockQuantity,
    },
  });
  if (error) {
    return { error };
  }

  revalidatePath(`/admin/catalog/products/${productId}`);
  return null;
}

export async function updateVariant(formData: FormData): Promise<{ error?: string } | null> {
  const productId = String(formData.get("productId") ?? "");
  const variantId = String(formData.get("variantId") ?? "");
  const retailPriceInRupees = Number(formData.get("retailPriceInRupees"));
  const tradePriceInRupees = Number(formData.get("tradePriceInRupees"));
  const stockQuantity = Number(formData.get("stockQuantity"));
  const isActive = formData.get("isActive") === "on";

  const { error } = await adminApiFetch(`/api/osteq/products/${productId}/variants/${variantId}`, {
    method: "PATCH",
    body: { retailPriceInRupees, tradePriceInRupees, stockQuantity, isActive },
  });
  if (error) {
    return { error };
  }

  revalidatePath(`/admin/catalog/products/${productId}`);
  return null;
}
