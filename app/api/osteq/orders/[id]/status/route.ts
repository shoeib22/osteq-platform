import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireStaffAccess } from "@/lib/auth";
import { notifyOrderStatusChange } from "@/lib/osteq/notifications";

const VALID_STATUSES = new Set(["PROCESSING", "OUT_FOR_DELIVERY", "DELIVERED", "CANCELLED"]);

function parseTrackingUrl(value: unknown): string | null | undefined {
  if (value === null || value === "") return null;
  if (typeof value !== "string") return undefined;
  try {
    new URL(value);
    return value;
  } catch {
    return undefined;
  }
}

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
  let status = body.status;
  const trackingNumber =
    body.trackingNumber === null || body.trackingNumber === ""
      ? null
      : typeof body.trackingNumber === "string"
        ? body.trackingNumber
        : undefined;

  const trackingUrlProvided = body.trackingUrl !== undefined;
  const trackingUrl = trackingUrlProvided ? parseTrackingUrl(body.trackingUrl) : undefined;
  if (trackingUrlProvided && trackingUrl === undefined) {
    return NextResponse.json({ error: "trackingUrl must be a valid URL." }, { status: 400 });
  }

  // Pasting a tracking link is what actually marks an order out for delivery — auto-flip
  // the status whenever a link is being set for the first time, regardless of what status
  // the admin form submitted, unless the order is already DELIVERED/CANCELLED.
  if (
    trackingUrl != null &&
    existing.trackingUrl == null &&
    existing.status !== "DELIVERED" &&
    existing.status !== "CANCELLED"
  ) {
    status = "OUT_FOR_DELIVERY";
  }

  if (typeof status !== "string" || !VALID_STATUSES.has(status)) {
    return NextResponse.json({ error: "A valid status is required." }, { status: 400 });
  }

  const order = await prisma.osteqOrder.update({
    where: { id: params.id },
    data: {
      status: status as "PROCESSING" | "OUT_FOR_DELIVERY" | "DELIVERED" | "CANCELLED",
      trackingNumber,
      ...(trackingUrlProvided ? { trackingUrl } : {}),
    },
  });

  notifyOrderStatusChange(order);

  return NextResponse.json({ order });
}
