import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireStaffAccess } from "@/lib/auth";
import { requireOsteqCustomerAccess } from "@/lib/osteq/auth";
import { resolveVariantPrice } from "@/lib/osteq/pricing";

export async function GET(request: NextRequest) {
  let accountStatus: "PENDING" | "TRADE_APPROVED" | "REJECTED" | null = null;
  try {
    const { customerId } = await requireOsteqCustomerAccess(request);
    const profile = await prisma.osteqCustomerProfile.findUnique({ where: { id: customerId } });
    accountStatus = profile?.accountStatus ?? null;
  } catch {
    // Catalog browsing is public — an invalid/missing token just means retail pricing.
  }

  const categoryId = new URL(request.url).searchParams.get("categoryId");
  const products = await prisma.osteqProduct.findMany({
    where: { isActive: true, ...(categoryId ? { categoryId } : {}) },
    include: { variants: { where: { isActive: true } }, category: true },
    orderBy: { name: "asc" },
  });

  return NextResponse.json({
    products: products.map((p) => ({
      id: p.id,
      name: p.name,
      slug: p.slug,
      description: p.description,
      specs: p.specs,
      images: p.images,
      category: { id: p.category.id, name: p.category.name, slug: p.category.slug },
      variants: p.variants.map((v) => ({
        id: v.id,
        sku: v.sku,
        attributes: v.attributes,
        stockQuantity: v.stockQuantity,
        ...resolveVariantPrice(v, accountStatus),
      })),
    })),
  });
}

export async function POST(request: NextRequest) {
  try {
    await requireStaffAccess();
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const body = await request.json();
  const categoryId = typeof body.categoryId === "string" ? body.categoryId : "";
  const name = typeof body.name === "string" ? body.name.trim() : "";
  const slug = typeof body.slug === "string" ? body.slug.trim() : "";
  const description = typeof body.description === "string" ? body.description : null;
  const specs = body.specs ?? null;
  const images = Array.isArray(body.images) ? body.images.filter((i: unknown) => typeof i === "string") : [];

  if (!categoryId || !name || !slug) {
    return NextResponse.json({ error: "categoryId, name, and slug are required." }, { status: 400 });
  }

  const product = await prisma.osteqProduct.create({
    data: { categoryId, name, slug, description, specs, images },
  });
  return NextResponse.json({ product });
}
