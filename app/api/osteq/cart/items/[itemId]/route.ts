import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireOsteqCustomerAccess } from "@/lib/osteq/auth";

async function assertOwnedItem(customerId: string, itemId: string) {
  const item = await prisma.osteqCartItem.findUnique({ where: { id: itemId }, include: { cart: true } });
  if (!item || item.cart.customerId !== customerId) {
    return null;
  }
  return item;
}

export async function PATCH(request: NextRequest, { params }: { params: { itemId: string } }) {
  let customerId: string;
  try {
    ({ customerId } = await requireOsteqCustomerAccess(request));
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const item = await assertOwnedItem(customerId, params.itemId);
  if (!item) {
    return NextResponse.json({ error: "Cart item not found." }, { status: 404 });
  }

  const body = await request.json();
  const quantity = Number(body.quantity);
  if (!Number.isInteger(quantity) || quantity <= 0) {
    return NextResponse.json({ error: "A positive integer quantity is required." }, { status: 400 });
  }

  const updated = await prisma.osteqCartItem.update({ where: { id: item.id }, data: { quantity } });
  return NextResponse.json({ item: updated });
}

export async function DELETE(request: NextRequest, { params }: { params: { itemId: string } }) {
  let customerId: string;
  try {
    ({ customerId } = await requireOsteqCustomerAccess(request));
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const item = await assertOwnedItem(customerId, params.itemId);
  if (!item) {
    return NextResponse.json({ error: "Cart item not found." }, { status: 404 });
  }

  await prisma.osteqCartItem.delete({ where: { id: item.id } });
  return NextResponse.json({ ok: true });
}
