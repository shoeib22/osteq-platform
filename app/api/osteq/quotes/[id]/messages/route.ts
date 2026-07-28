import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireOsteqCustomerAccess } from "@/lib/osteq/auth";
import { requireStaffAccess } from "@/lib/auth";
import { assertValidTransition } from "@/lib/osteq/quote-transitions";

export async function POST(request: NextRequest, { params }: { params: { id: string } }) {
  let authorProfileId: string | null = null;
  let authorCustomerId: string | null = null;
  try {
    ({ id: authorProfileId } = await requireStaffAccess());
  } catch {
    try {
      ({ customerId: authorCustomerId } = await requireOsteqCustomerAccess(request));
    } catch {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }
  }

  const quote = await prisma.osteqQuote.findUnique({ where: { id: params.id } });
  if (!quote || (authorCustomerId && quote.customerId !== authorCustomerId)) {
    return NextResponse.json({ error: "Quote not found." }, { status: 404 });
  }

  const body = await request.json();
  const messageBody = typeof body.body === "string" ? body.body.trim() : "";
  if (!messageBody) {
    return NextResponse.json({ error: "body is required." }, { status: 400 });
  }

  const requestRevision = authorCustomerId !== null && body.requestRevision === true;
  if (requestRevision) {
    try {
      assertValidTransition(quote.status, "REVISION_REQUESTED");
    } catch (err) {
      return NextResponse.json({ error: err instanceof Error ? err.message : "Invalid transition." }, { status: 409 });
    }
  }

  if (!requestRevision) {
    const message = await prisma.osteqQuoteMessage.create({
      data: { quoteId: quote.id, authorProfileId, authorCustomerId, body: messageBody },
    });
    return NextResponse.json({ message });
  }

  try {
    const message = await prisma.$transaction(async (tx) => {
      const created = await tx.osteqQuoteMessage.create({
        data: { quoteId: quote.id, authorProfileId, authorCustomerId, body: messageBody },
      });
      // Same guard pattern as the respond route: only proceed with the status flip if the
      // quote is still in the status we read moments ago.
      const guarded = await tx.osteqQuote.updateMany({
        where: { id: quote.id, status: quote.status },
        data: { status: "REVISION_REQUESTED" },
      });
      if (guarded.count === 0) {
        throw new Error("Quote status changed, please retry.");
      }
      return created;
    });
    return NextResponse.json({ message });
  } catch (err) {
    return NextResponse.json({ error: err instanceof Error ? err.message : "Revision request failed." }, { status: 409 });
  }
}
