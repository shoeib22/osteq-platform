"use server";

import { revalidatePath } from "next/cache";
import { adminApiFetch } from "@/lib/admin/api-fetch";

export async function updateOrderStatus(formData: FormData): Promise<{ error?: string } | null> {
  const orderId = String(formData.get("orderId") ?? "");
  const status = String(formData.get("status") ?? "");
  const trackingNumber = String(formData.get("trackingNumber") ?? "");

  const { error } = await adminApiFetch(`/api/osteq/orders/${orderId}/status`, {
    method: "PATCH",
    body: { status, trackingNumber: trackingNumber || undefined },
  });
  if (error) {
    return { error };
  }

  revalidatePath(`/admin/orders/${orderId}`);
  return null;
}
