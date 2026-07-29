"use server";

import { revalidatePath } from "next/cache";
import { adminApiFetch } from "@/lib/admin/api-fetch";

export async function reviewTradeApplication(formData: FormData): Promise<{ error?: string } | null> {
  const applicationId = String(formData.get("applicationId") ?? "");
  const decision = String(formData.get("decision") ?? "");
  const rejectionReason = String(formData.get("rejectionReason") ?? "");

  const { error } = await adminApiFetch(`/api/osteq/trade-applications/${applicationId}`, {
    method: "PATCH",
    body: { decision, rejectionReason: rejectionReason || undefined },
  });
  if (error) {
    return { error };
  }

  revalidatePath("/admin/trade-applications");
  return null;
}
