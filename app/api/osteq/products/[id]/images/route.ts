import { NextResponse, type NextRequest } from "next/server";
import { randomUUID } from "crypto";
import { prisma } from "@/lib/prisma";
import { requireStaffAccess } from "@/lib/auth";
import { createAdminClient } from "@/lib/supabase/admin";

const BUCKET = "product-images";
const ALLOWED_TYPES = new Set(["image/png", "image/jpeg", "image/webp"]);
const MAX_BYTES = 10 * 1024 * 1024;

export async function POST(request: NextRequest, { params }: { params: { id: string } }) {
  try {
    await requireStaffAccess();
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const product = await prisma.osteqProduct.findUnique({ where: { id: params.id } });
  if (!product) {
    return NextResponse.json({ error: "Product not found." }, { status: 404 });
  }

  const formData = await request.formData();
  const file = formData.get("file");
  if (!(file instanceof File)) {
    return NextResponse.json({ error: "A file upload is required." }, { status: 400 });
  }
  if (!ALLOWED_TYPES.has(file.type)) {
    return NextResponse.json({ error: "Only PNG, JPEG, or WebP images are allowed." }, { status: 400 });
  }
  if (file.size > MAX_BYTES) {
    return NextResponse.json({ error: "Image must be under 10MB." }, { status: 400 });
  }

  const extension = file.type === "image/png" ? "png" : file.type === "image/webp" ? "webp" : "jpg";
  const path = `${product.id}/${randomUUID()}.${extension}`;

  const admin = createAdminClient();
  const { error: uploadError } = await admin.storage
    .from(BUCKET)
    .upload(path, await file.arrayBuffer(), { contentType: file.type });
  if (uploadError) {
    return NextResponse.json({ error: `Upload failed: ${uploadError.message}` }, { status: 502 });
  }

  // Store only the relative storage path, never a full URL — the admin panel (running on
  // this same machine) and the Flutter app (reached through a separate, ephemeral tunnel
  // URL that changes every rebuild) each know their own correct Supabase base URL, but a
  // URL baked in server-side here would only ever be right for whichever one happened to
  // match at upload time.
  const updated = await prisma.osteqProduct.update({
    where: { id: product.id },
    data: { images: { push: path } },
  });

  return NextResponse.json({ product: updated });
}

export async function DELETE(request: NextRequest, { params }: { params: { id: string } }) {
  try {
    await requireStaffAccess();
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const product = await prisma.osteqProduct.findUnique({ where: { id: params.id } });
  if (!product) {
    return NextResponse.json({ error: "Product not found." }, { status: 404 });
  }

  const body = await request.json();
  const path = typeof body.path === "string" ? body.path : "";
  if (!path || !product.images.includes(path)) {
    return NextResponse.json({ error: "That image isn't on this product." }, { status: 400 });
  }

  // Best-effort: remove the underlying storage object too, but the DB update (the source of
  // truth for what the app displays) proceeds regardless — a leaked orphaned storage object
  // is a minor cleanup issue, whereas leaving a dead entry in `images` is a visible bug.
  const admin = createAdminClient();
  await admin.storage.from(BUCKET).remove([path]);

  const updated = await prisma.osteqProduct.update({
    where: { id: product.id },
    data: { images: product.images.filter((i) => i !== path) },
  });

  return NextResponse.json({ product: updated });
}
