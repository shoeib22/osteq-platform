import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireStaffAccess } from "@/lib/auth";
import { serializeDecimals } from "@/lib/osteq/serialize";

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
  const retailPriceInRupees = Number.isFinite(Number(body.retailPriceInRupees))
    ? Number(body.retailPriceInRupees)
    : existing.retailPriceInRupees;
  const tradePriceInRupees = Number.isFinite(Number(body.tradePriceInRupees))
    ? Number(body.tradePriceInRupees)
    : existing.tradePriceInRupees;
  const stockQuantity = Number.isFinite(Number(body.stockQuantity))
    ? Number(body.stockQuantity)
    : existing.stockQuantity;
  const isActive = typeof body.isActive === "boolean" ? body.isActive : existing.isActive;

  const variant = await prisma.osteqProductVariant.update({
    where: { id: params.variantId },
    data: { sku, attributes, retailPriceInRupees, tradePriceInRupees, stockQuantity, isActive },
  });
  return NextResponse.json(serializeDecimals({ variant }));
}
