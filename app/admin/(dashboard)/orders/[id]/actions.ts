"use server";

import { revalidatePath } from "next/cache";
import { adminApiFetch } from "@/lib/admin/api-fetch";

export async function updateOrderStatus(formData: FormData): Promise<{ error?: string } | null> {
  const orderId = String(formData.get("orderId") ?? "");
  const status = String(formData.get("status") ?? "");
  const trackingNumber = String(formData.get("trackingNumber") ?? "");
  const trackingUrl = String(formData.get("trackingUrl") ?? "");

  const { error } = await adminApiFetch(`/api/osteq/orders/${orderId}/status`, {
    method: "PATCH",
    body: {
      status,
      trackingNumber: trackingNumber.trim() === "" ? null : trackingNumber.trim(),
      trackingUrl: trackingUrl.trim() === "" ? null : trackingUrl.trim(),
    },
  });
  if (error) {
    return { error };
  }

  revalidatePath(`/admin/orders/${orderId}`);
  revalidatePath("/admin/orders");
  return null;
}
