import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireOsteqCustomerAccess } from "@/lib/osteq/auth";
import { requireStaffAccess } from "@/lib/auth";
import { serializeDecimals } from "@/lib/osteq/serialize";

interface IncomingQuoteItem {
  productVariantId?: string;
  description?: string;
  quantity: number;
  notes?: string;
}

export async function POST(request: NextRequest) {
  let customerId: string;
  try {
    ({ customerId } = await requireOsteqCustomerAccess(request));
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const body = await request.json();
  const items: IncomingQuoteItem[] = Array.isArray(body.items) ? body.items : [];
  if (items.length === 0) {
    return NextResponse.json({ error: "At least one item is required." }, { status: 400 });
  }
  for (const item of items) {
    if (!Number.isInteger(item.quantity) || item.quantity <= 0) {
      return NextResponse.json({ error: "Every item needs a positive integer quantity." }, { status: 400 });
    }
    if (!item.productVariantId && !item.description) {
      return NextResponse.json(
        { error: "Every item needs either a productVariantId or a description." },
        { status: 400 },
      );
    }
  }

  const quote = await prisma.osteqQuote.create({
    data: {
      customerId,
      items: {
        create: items.map((item) => ({
          productVariantId: item.productVariantId ?? null,
          description: item.description ?? null,
          quantity: item.quantity,
          notes: item.notes ?? null,
        })),
      },
    },
    include: { items: true },
  });

  return NextResponse.json(serializeDecimals({ quote }));
}

export async function GET(request: NextRequest) {
  const url = new URL(request.url);
  const statusFilter = url.searchParams.get("status");

  let customerId: string | null = null;
  let isStaff = false;
  try {
    await requireStaffAccess();
    isStaff = true;
  } catch {
    try {
      ({ customerId } = await requireOsteqCustomerAccess(request));
    } catch {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }
  }

  const quotes = await prisma.osteqQuote.findMany({
    where: {
      ...(isStaff ? {} : { customerId: customerId! }),
      ...(statusFilter ? { status: statusFilter as never } : {}),
    },
    include: { items: true },
    orderBy: { createdAt: "asc" },
  });

  return NextResponse.json(serializeDecimals({ quotes }));
}
