import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireOsteqCustomerAccess } from "@/lib/osteq/auth";
import { requireStaffAccess } from "@/lib/auth";
import { serializeDecimals, withInvoiceFlag } from "@/lib/osteq/serialize";

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

  const order = await prisma.osteqOrder.findUnique({
    where: { id: params.id },
    include: {
      items: { include: { variant: { include: { product: true } } } },
      customer: true,
    },
  });
  if (!order || (customerId && order.customerId !== customerId)) {
    return NextResponse.json({ error: "Order not found." }, { status: 404 });
  }

  return NextResponse.json(serializeDecimals({ order: withInvoiceFlag(order) }));
}
