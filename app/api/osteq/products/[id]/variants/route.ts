import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireStaffAccess } from "@/lib/auth";

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

  const body = await request.json();
  const sku = typeof body.sku === "string" ? body.sku.trim() : "";
  const attributes = body.attributes ?? {};
  const retailPriceInPaise = Number(body.retailPriceInPaise);
  const tradePriceInPaise = Number(body.tradePriceInPaise);
  const stockQuantity = Number.isFinite(Number(body.stockQuantity)) ? Number(body.stockQuantity) : 0;

  if (!sku || !Number.isFinite(retailPriceInPaise) || !Number.isFinite(tradePriceInPaise)) {
    return NextResponse.json(
      { error: "sku, retailPriceInPaise, and tradePriceInPaise are required." },
      { status: 400 },
    );
  }

  const variant = await prisma.osteqProductVariant.create({
    data: { productId: product.id, sku, attributes, retailPriceInPaise, tradePriceInPaise, stockQuantity },
  });
  return NextResponse.json({ variant });
}
