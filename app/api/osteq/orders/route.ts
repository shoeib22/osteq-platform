import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireOsteqCustomerAccess } from "@/lib/osteq/auth";
import { requireStaffAccess } from "@/lib/auth";
import { serializeDecimals } from "@/lib/osteq/serialize";

export async function GET(request: NextRequest) {
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

  const orders = await prisma.osteqOrder.findMany({
    where: isStaff ? {} : { customerId: customerId! },
    include: { items: true },
    orderBy: { createdAt: "desc" },
  });

  return NextResponse.json(serializeDecimals({ orders }));
}
