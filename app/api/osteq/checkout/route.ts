import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireOsteqCustomerAccess } from "@/lib/osteq/auth";
import { resolveVariantPrice } from "@/lib/osteq/pricing";
import { stubPaymentProvider } from "@/lib/osteq/payment";
import { serializeDecimals } from "@/lib/osteq/serialize";

export async function POST(request: NextRequest) {
  let customerId: string;
  try {
    ({ customerId } = await requireOsteqCustomerAccess(request));
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON body." }, { status: 400 });
  }
  if (typeof body !== "object" || body === null) {
    return NextResponse.json({ error: "A JSON object body is required." }, { status: 400 });
  }
  const shippingAddress =
    "shippingAddress" in body && typeof body.shippingAddress === "string" ? body.shippingAddress.trim() : "";
  if (!shippingAddress) {
    return NextResponse.json({ error: "shippingAddress is required." }, { status: 400 });
  }

  const profile = await prisma.osteqCustomerProfile.findUnique({ where: { id: customerId } });
  const cart = await prisma.osteqCart.findUnique({
    where: { customerId },
    include: { items: { include: { variant: true } } },
  });
  if (!cart || cart.items.length === 0) {
    return NextResponse.json({ error: "Cart is empty." }, { status: 400 });
  }

  try {
    const order = await prisma.$transaction(async (tx) => {
      let totalInRupees = 0;
      const orderItemsData: { variantId: string; quantity: number; unitPriceInRupees: number }[] = [];

      for (const item of cart.items) {
        // The WHERE clause's stockQuantity >= quantity is the race guard — Postgres evaluates
        // it and applies the decrement as one atomic statement, so a concurrent checkout for
        // the same variant can never observe stock as sufficient after this one already
        // consumed it (unlike a separate findUnique-then-update, which has a window between
        // the read and the write for another transaction to decrement first).
        const result = await tx.osteqProductVariant.updateMany({
          where: { id: item.variantId, stockQuantity: { gte: item.quantity } },
          data: { stockQuantity: { decrement: item.quantity } },
        });
        if (result.count === 0) {
          throw new Error(`Insufficient stock for SKU ${item.variant.sku}.`);
        }

        const updated = await tx.osteqProductVariant.findUniqueOrThrow({ where: { id: item.variantId } });
        const { priceInRupees } = resolveVariantPrice(updated, profile?.accountStatus ?? null);
        totalInRupees += priceInRupees * item.quantity;
        orderItemsData.push({ variantId: item.variantId, quantity: item.quantity, unitPriceInRupees: priceInRupees });
      }
      // Round once after summing, rather than after each line, so per-line rounding error
      // can't compound across many items — floats are exact enough for a single INR total
      // at this magnitude, this just pins it to the DB column's 2-decimal-place contract.
      totalInRupees = Math.round(totalInRupees * 100) / 100;

      const payment = await stubPaymentProvider.charge(totalInRupees);
      if (!payment.success) {
        throw new Error("Payment failed.");
      }

      const created = await tx.osteqOrder.create({
        data: {
          customerId,
          shippingAddress,
          totalInRupees,
          items: { create: orderItemsData },
        },
        include: { items: true },
      });

      await tx.osteqCartItem.deleteMany({ where: { cartId: cart.id } });

      return created;
    });

    return NextResponse.json(serializeDecimals({ order }));
  } catch (err) {
    return NextResponse.json({ error: err instanceof Error ? err.message : "Checkout failed." }, { status: 409 });
  }
}
