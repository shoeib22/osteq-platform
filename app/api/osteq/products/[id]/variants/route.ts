import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireStaffAccess } from "@/lib/auth";
import { serializeDecimals } from "@/lib/osteq/serialize";

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
  const retailPriceInRupees = Number(body.retailPriceInRupees);
  const tradePriceInRupees = Number(body.tradePriceInRupees);
  const stockQuantity = Number.isFinite(Number(body.stockQuantity)) ? Number(body.stockQuantity) : 0;

  if (!sku || !Number.isFinite(retailPriceInRupees) || !Number.isFinite(tradePriceInRupees)) {
    return NextResponse.json(
      { error: "sku, retailPriceInRupees, and tradePriceInRupees are required." },
      { status: 400 },
    );
  }

  const variant = await prisma.osteqProductVariant.create({
    data: { productId: product.id, sku, attributes, retailPriceInRupees, tradePriceInRupees, stockQuantity },
  });
  return NextResponse.json(serializeDecimals({ variant }));
}
