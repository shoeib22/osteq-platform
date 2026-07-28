import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireOsteqCustomerAccess } from "@/lib/osteq/auth";
import { resolveVariantPrice } from "@/lib/osteq/pricing";

async function getOrCreateCart(customerId: string) {
  return prisma.osteqCart.upsert({
    where: { customerId },
    create: { customerId },
    update: {},
    include: { items: { include: { variant: true } } },
  });
}

export async function GET(request: NextRequest) {
  let customerId: string;
  try {
    ({ customerId } = await requireOsteqCustomerAccess(request));
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const profile = await prisma.osteqCustomerProfile.findUnique({ where: { id: customerId } });
  if (!profile) {
    return NextResponse.json(
      { error: "Create your profile first via POST /api/osteq/customers/me." },
      { status: 400 },
    );
  }
  const cart = await getOrCreateCart(customerId);

  return NextResponse.json({
    items: cart.items.map((item) => ({
      id: item.id,
      variantId: item.variantId,
      sku: item.variant.sku,
      quantity: item.quantity,
      ...resolveVariantPrice(item.variant, profile.accountStatus),
    })),
  });
}

export async function POST(request: NextRequest) {
  let customerId: string;
  try {
    ({ customerId } = await requireOsteqCustomerAccess(request));
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const profile = await prisma.osteqCustomerProfile.findUnique({ where: { id: customerId } });
  if (!profile) {
    return NextResponse.json(
      { error: "Create your profile first via POST /api/osteq/customers/me." },
      { status: 400 },
    );
  }

  const body = await request.json();
  const variantId = typeof body.variantId === "string" ? body.variantId : "";
  const quantity = Number(body.quantity);
  if (!variantId || !Number.isInteger(quantity) || quantity <= 0) {
    return NextResponse.json({ error: "variantId and a positive integer quantity are required." }, { status: 400 });
  }

  const variant = await prisma.osteqProductVariant.findUnique({ where: { id: variantId } });
  if (!variant || !variant.isActive) {
    return NextResponse.json({ error: "Variant not found." }, { status: 404 });
  }

  const cart = await getOrCreateCart(customerId);

  // A single atomic upsert on the (cartId, variantId) unique constraint closes the race two
  // concurrent POSTs for the same variant would otherwise hit: both could miss an in-memory
  // duplicate check and both attempt `create`, with the loser throwing on the unique
  // constraint instead of just incrementing quantity.
  const item = await prisma.osteqCartItem.upsert({
    where: { cartId_variantId: { cartId: cart.id, variantId } },
    create: { cartId: cart.id, variantId, quantity },
    update: { quantity: { increment: quantity } },
  });

  return NextResponse.json({ item });
}
