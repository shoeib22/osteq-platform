import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireStaffAccess } from "@/lib/auth";
import { notifyQuoteReady } from "@/lib/osteq/notifications";

interface PricedLine {
  itemId: string;
  quotedUnitPriceInPaise: number;
}

// SUBMITTED and REVISION_REQUESTED both implicitly pass through UNDER_REVIEW on their way
// to QUOTED (see lib/osteq/quote-transitions.ts's map) — pricing is the one action that
// performs that two-hop transition in a single staff request, so it checks against this
// source set directly instead of chaining assertValidTransition() twice for an identical
// three-way branch.
const PRICEABLE_STATUSES = ["SUBMITTED", "UNDER_REVIEW", "REVISION_REQUESTED"] as const;

export async function PATCH(request: NextRequest, { params }: { params: { id: string } }) {
  try {
    await requireStaffAccess();
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const quote = await prisma.osteqQuote.findUnique({ where: { id: params.id }, include: { items: true } });
  if (!quote) {
    return NextResponse.json({ error: "Quote not found." }, { status: 404 });
  }
  if (!(PRICEABLE_STATUSES as readonly string[]).includes(quote.status)) {
    return NextResponse.json({ error: `Cannot price a quote in status ${quote.status}.` }, { status: 409 });
  }

  const body = await request.json();
  const lines: PricedLine[] = Array.isArray(body.lines) ? body.lines : [];
  if (lines.length === 0) {
    return NextResponse.json({ error: "At least one line item needs a price." }, { status: 400 });
  }
  const knownItemIds = new Set(quote.items.map((i) => i.id));
  for (const line of lines) {
    if (!knownItemIds.has(line.itemId) || !Number.isFinite(line.quotedUnitPriceInPaise)) {
      return NextResponse.json({ error: "Every line needs a valid itemId and quotedUnitPriceInPaise." }, { status: 400 });
    }
  }

  try {
    await prisma.$transaction(async (tx) => {
      // Flip status first, guarded by the still-priceable statuses — a losing concurrent
      // PATCH sees count 0 and throws before touching any item prices, so two racing
      // pricing requests can never partially overwrite each other.
      const guarded = await tx.osteqQuote.updateMany({
        where: { id: quote.id, status: { in: Array.from(PRICEABLE_STATUSES) } },
        data: { status: "QUOTED" },
      });
      if (guarded.count === 0) {
        throw new Error("Quote status changed, please retry.");
      }

      for (const line of lines) {
        await tx.osteqQuoteItem.update({
          where: { id: line.itemId },
          data: { quotedUnitPriceInPaise: line.quotedUnitPriceInPaise },
        });
      }
    });

    const updatedQuote = await prisma.osteqQuote.findUniqueOrThrow({ where: { id: quote.id } });
    notifyQuoteReady(updatedQuote);

    return NextResponse.json({ ok: true });
  } catch (err) {
    return NextResponse.json({ error: err instanceof Error ? err.message : "Pricing failed." }, { status: 409 });
  }
}
