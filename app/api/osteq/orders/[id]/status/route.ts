import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireStaffAccess } from "@/lib/auth";
import { notifyOrderStatusChange } from "@/lib/osteq/notifications";

const VALID_STATUSES = new Set(["PROCESSING", "SHIPPED", "DELIVERED", "CANCELLED"]);

export async function PATCH(request: NextRequest, { params }: { params: { id: string } }) {
  try {
    await requireStaffAccess();
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const existing = await prisma.osteqOrder.findUnique({ where: { id: params.id } });
  if (!existing) {
    return NextResponse.json({ error: "Order not found." }, { status: 404 });
  }

  const body = await request.json();
  const status = body.status;
  const trackingNumber = typeof body.trackingNumber === "string" ? body.trackingNumber : undefined;
  if (typeof status !== "string" || !VALID_STATUSES.has(status)) {
    return NextResponse.json({ error: "A valid status is required." }, { status: 400 });
  }

  const order = await prisma.osteqOrder.update({
    where: { id: params.id },
    data: { status: status as "PROCESSING" | "SHIPPED" | "DELIVERED" | "CANCELLED", trackingNumber },
  });

  notifyOrderStatusChange(order);

  return NextResponse.json({ order });
}
