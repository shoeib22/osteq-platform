import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireOsteqCustomerAccess } from "@/lib/osteq/auth";
import { assertValidTransition } from "@/lib/osteq/quote-transitions";
import { serializeDecimals } from "@/lib/osteq/serialize";

export async function POST(request: NextRequest, { params }: { params: { id: string } }) {
  let customerId: string;
  try {
    ({ customerId } = await requireOsteqCustomerAccess(request));
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const body = await request.json();
  const decision = body.decision;
  if (decision !== "ACCEPTED" && decision !== "REJECTED") {
    return NextResponse.json({ error: "decision must be ACCEPTED or REJECTED." }, { status: 400 });
  }

  const quote = await prisma.osteqQuote.findUnique({ where: { id: params.id }, include: { items: true } });
  if (!quote || quote.customerId !== customerId) {
    return NextResponse.json({ error: "Quote not found." }, { status: 404 });
  }

  try {
    assertValidTransition(quote.status, decision);
  } catch (err) {
    return NextResponse.json({ error: err instanceof Error ? err.message : "Invalid transition." }, { status: 409 });
  }

  if (decision === "REJECTED") {
    // The status: quote.status guard is the race check — if another request already moved
    // this quote off the status we just read, count is 0 and we report a conflict instead
    // of silently overwriting whatever that other request did.
    const result = await prisma.osteqQuote.updateMany({
      where: { id: quote.id, status: quote.status },
      data: { status: "REJECTED" },
    });
    if (result.count === 0) {
      return NextResponse.json({ error: "Quote status changed, please retry." }, { status: 409 });
    }
    return NextResponse.json({ ok: true });
  }

  const shippingAddress = typeof body.shippingAddress === "string" ? body.shippingAddress.trim() : "";
  if (!shippingAddress) {
    return NextResponse.json({ error: "shippingAddress is required to accept a quote." }, { status: 400 });
  }
  if (quote.items.some((i) => i.quotedUnitPriceInRupees === null)) {
    return NextResponse.json({ error: "Every line item must be priced before accepting." }, { status: 409 });
  }

  const totalInRupees = Math.round(
    quote.items.reduce((sum, i) => sum + Number(i.quotedUnitPriceInRupees) * i.quantity, 0) * 100,
  ) / 100;

  try {
    const order = await prisma.$transaction(async (tx) => {
      // Flip the status first, guarded by the source status we read — only one concurrent
      // ACCEPT can win this conditional update. The loser throws before ever creating an
      // order, so a race can never produce two orders from one quote.
      const guarded = await tx.osteqQuote.updateMany({
        where: { id: quote.id, status: quote.status },
        data: { status: "CONVERTED_TO_ORDER" },
      });
      if (guarded.count === 0) {
        throw new Error("Quote status changed, please retry.");
      }

      // Catalog-backed line items reserve real inventory, the same way checkout does — a
      // quote converting to an order must not silently bypass stock tracking just because
      // it came through the quote path instead of the cart. Custom/off-catalog lines
      // (productVariantId null) have no stock to decrement.
      for (const item of quote.items) {
        if (item.productVariantId === null) continue;
        const decremented = await tx.osteqProductVariant.updateMany({
          where: { id: item.productVariantId, stockQuantity: { gte: item.quantity } },
          data: { stockQuantity: { decrement: item.quantity } },
        });
        if (decremented.count === 0) {
          throw new Error(`Insufficient stock for one or more items in this quote.`);
        }
      }

      const created = await tx.osteqOrder.create({
        data: {
          customerId,
          shippingAddress,
          totalInRupees,
          items: {
            create: quote.items
              .filter((i) => i.productVariantId !== null)
              .map((i) => ({
                variantId: i.productVariantId!,
                quantity: i.quantity,
                unitPriceInRupees: i.quotedUnitPriceInRupees!,
              })),
          },
        },
        include: { items: true },
      });

      await tx.osteqQuote.update({
        where: { id: quote.id },
        data: { convertedOrderId: created.id },
      });

      return created;
    });

    return NextResponse.json(serializeDecimals({ order }));
  } catch (err) {
    return NextResponse.json({ error: err instanceof Error ? err.message : "Accept failed." }, { status: 409 });
  }
}
