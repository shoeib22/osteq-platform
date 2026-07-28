import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireStaffAccess } from "@/lib/auth";
import { requireOsteqCustomerAccess } from "@/lib/osteq/auth";
import { resolveVariantPrice } from "@/lib/osteq/pricing";

export async function GET(request: NextRequest, { params }: { params: { id: string } }) {
  let accountStatus: "PENDING" | "TRADE_APPROVED" | "REJECTED" | null = null;
  try {
    const { customerId } = await requireOsteqCustomerAccess(request);
    const profile = await prisma.osteqCustomerProfile.findUnique({ where: { id: customerId } });
    accountStatus = profile?.accountStatus ?? null;
  } catch {
    // Public browsing, same as the list route.
  }

  const product = await prisma.osteqProduct.findUnique({
    where: { id: params.id },
    include: { variants: { where: { isActive: true } }, category: true },
  });
  if (!product || !product.isActive) {
    return NextResponse.json({ error: "Product not found." }, { status: 404 });
  }

  return NextResponse.json({
    product: {
      id: product.id,
      name: product.name,
      slug: product.slug,
      description: product.description,
      specs: product.specs,
      images: product.images,
      category: { id: product.category.id, name: product.category.name, slug: product.category.slug },
      variants: product.variants.map((v) => ({
        id: v.id,
        sku: v.sku,
        attributes: v.attributes,
        stockQuantity: v.stockQuantity,
        ...resolveVariantPrice(v, accountStatus),
      })),
    },
  });
}

export async function PATCH(request: NextRequest, { params }: { params: { id: string } }) {
  try {
    await requireStaffAccess();
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const existing = await prisma.osteqProduct.findUnique({ where: { id: params.id } });
  if (!existing) {
    return NextResponse.json({ error: "Product not found." }, { status: 404 });
  }

  const body = await request.json();
  const name = typeof body.name === "string" ? body.name.trim() : existing.name;
  const description = typeof body.description === "string" ? body.description : existing.description;
  const specs = body.specs !== undefined ? body.specs : existing.specs;
  const images = Array.isArray(body.images)
    ? body.images.filter((i: unknown) => typeof i === "string")
    : existing.images;
  const isActive = typeof body.isActive === "boolean" ? body.isActive : existing.isActive;

  const product = await prisma.osteqProduct.update({
    where: { id: params.id },
    data: { name, description, specs, images, isActive },
  });
  return NextResponse.json({ product });
}
