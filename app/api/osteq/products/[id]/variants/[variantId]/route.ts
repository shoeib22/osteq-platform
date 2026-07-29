import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireStaffAccess } from "@/lib/auth";

export async function PATCH(
  request: NextRequest,
  { params }: { params: { id: string; variantId: string } },
) {
  try {
    await requireStaffAccess();
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const existing = await prisma.osteqProductVariant.findUnique({ where: { id: params.variantId } });
  if (!existing || existing.productId !== params.id) {
    return NextResponse.json({ error: "Variant not found." }, { status: 404 });
  }

  const body = await request.json();
  const sku = typeof body.sku === "string" && body.sku.trim() ? body.sku.trim() : existing.sku;
  const attributes = body.attributes !== undefined ? body.attributes : existing.attributes;
  const retailPriceInPaise = Number.isFinite(Number(body.retailPriceInPaise))
    ? Number(body.retailPriceInPaise)
    : existing.retailPriceInPaise;
  const tradePriceInPaise = Number.isFinite(Number(body.tradePriceInPaise))
    ? Number(body.tradePriceInPaise)
    : existing.tradePriceInPaise;
  const stockQuantity = Number.isFinite(Number(body.stockQuantity))
    ? Number(body.stockQuantity)
    : existing.stockQuantity;
  const isActive = typeof body.isActive === "boolean" ? body.isActive : existing.isActive;

  const variant = await prisma.osteqProductVariant.update({
    where: { id: params.variantId },
    data: { sku, attributes, retailPriceInPaise, tradePriceInPaise, stockQuantity, isActive },
  });
  return NextResponse.json({ variant });
}
