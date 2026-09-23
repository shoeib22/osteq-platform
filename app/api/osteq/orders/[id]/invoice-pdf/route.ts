import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireStaffAccess } from "@/lib/auth";
import { createAdminClient } from "@/lib/supabase/admin";

const BUCKET = "order-invoices";
const MAX_BYTES = 20 * 1024 * 1024;

export async function POST(request: NextRequest, { params }: { params: { id: string } }) {
  try {
    await requireStaffAccess();
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const order = await prisma.osteqOrder.findUnique({ where: { id: params.id } });
  if (!order) {
    return NextResponse.json({ error: "Order not found." }, { status: 404 });
  }

  const formData = await request.formData();
  const file = formData.get("file");
  if (!(file instanceof File)) {
    return NextResponse.json({ error: "A file upload is required." }, { status: 400 });
  }
  if (file.type !== "application/pdf") {
    return NextResponse.json({ error: "Only PDF files are allowed." }, { status: 400 });
  }
  if (file.size > MAX_BYTES) {
    return NextResponse.json({ error: "Invoice PDF must be under 20MB." }, { status: 400 });
  }

  const path = `${order.id}/invoice.pdf`;

  const admin = createAdminClient();
  const { error: uploadError } = await admin.storage
    .from(BUCKET)
    .upload(path, await file.arrayBuffer(), { contentType: file.type, upsert: true });
  if (uploadError) {
    return NextResponse.json({ error: `Upload failed: ${uploadError.message}` }, { status: 502 });
  }

  const updated = await prisma.osteqOrder.update({
    where: { id: order.id },
    data: { invoicePdfPath: path },
  });

  return NextResponse.json({ order: updated });
}

export async function DELETE(request: NextRequest, { params }: { params: { id: string } }) {
  try {
    await requireStaffAccess();
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const order = await prisma.osteqOrder.findUnique({ where: { id: params.id } });
  if (!order || !order.invoicePdfPath) {
    return NextResponse.json({ error: "No invoice PDF on this order." }, { status: 400 });
  }

  const admin = createAdminClient();
  await admin.storage.from(BUCKET).remove([order.invoicePdfPath]);

  const updated = await prisma.osteqOrder.update({
    where: { id: order.id },
    data: { invoicePdfPath: null },
  });

  return NextResponse.json({ order: updated });
}
