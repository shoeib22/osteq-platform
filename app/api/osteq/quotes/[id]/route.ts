import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireOsteqCustomerAccess } from "@/lib/osteq/auth";
import { requireStaffAccess } from "@/lib/auth";
import { serializeDecimals } from "@/lib/osteq/serialize";

export async function GET(request: NextRequest, { params }: { params: { id: string } }) {
  let customerId: string | null = null;
  try {
    await requireStaffAccess();
  } catch {
    try {
      ({ customerId } = await requireOsteqCustomerAccess(request));
    } catch {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }
  }

  const quote = await prisma.osteqQuote.findUnique({
    where: { id: params.id },
    include: { items: true, messages: { orderBy: { createdAt: "asc" } } },
  });
  if (!quote || (customerId && quote.customerId !== customerId)) {
    return NextResponse.json({ error: "Quote not found." }, { status: 404 });
  }

  return NextResponse.json(serializeDecimals({ quote }));
}
