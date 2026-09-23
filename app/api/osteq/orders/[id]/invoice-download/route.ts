import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireOsteqCustomerAccess } from "@/lib/osteq/auth";
import { createAdminClient } from "@/lib/supabase/admin";

const BUCKET = "order-invoices";

export async function GET(request: NextRequest, { params }: { params: { id: string } }) {
  let customerId: string;
  try {
    ({ customerId } = await requireOsteqCustomerAccess(request));
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const order = await prisma.osteqOrder.findUnique({ where: { id: params.id } });
  if (!order || order.customerId !== customerId || !order.invoicePdfPath) {
    return NextResponse.json({ error: "Not found." }, { status: 404 });
  }

  const admin = createAdminClient();
  const { data, error } = await admin.storage.from(BUCKET).createSignedUrl(order.invoicePdfPath, 60);
  if (error || !data) {
    return NextResponse.json({ error: "Could not generate download link." }, { status: 502 });
  }

  return NextResponse.json({ url: data.signedUrl });
}
