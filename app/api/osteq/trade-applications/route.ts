import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireOsteqCustomerAccess } from "@/lib/osteq/auth";
import { requireStaffAccess } from "@/lib/auth";

export async function POST(request: NextRequest) {
  let customerId: string;
  try {
    ({ customerId } = await requireOsteqCustomerAccess(request));
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const body = await request.json();
  const businessName = typeof body.businessName === "string" ? body.businessName.trim() : "";
  const businessType = typeof body.businessType === "string" ? body.businessType.trim() : "";
  const phone = typeof body.phone === "string" ? body.phone.trim() : "";
  const taxId = typeof body.taxId === "string" && body.taxId.trim() ? body.taxId.trim() : null;

  if (!businessName || !businessType || !phone) {
    return NextResponse.json(
      { error: "businessName, businessType, and phone are required." },
      { status: 400 },
    );
  }

  // Address is optional and can come two ways: reuse an existing saved address by id, or
  // create-and-save a new one inline in the same request — both end up as this customer's
  // own OsteqAddress row so it's reusable later (checkout, a future application), never a
  // one-off string like OsteqOrder.shippingAddress.
  let addressId: string | null = null;
  if (typeof body.addressId === "string" && body.addressId) {
    const existingAddress = await prisma.osteqAddress.findUnique({ where: { id: body.addressId } });
    if (!existingAddress || existingAddress.customerId !== customerId) {
      return NextResponse.json({ error: "Address not found." }, { status: 404 });
    }
    addressId = existingAddress.id;
  } else if (body.address && typeof body.address === "object") {
    const a = body.address as Record<string, unknown>;
    const label = typeof a.label === "string" ? a.label.trim() : "";
    const line1 = typeof a.line1 === "string" ? a.line1.trim() : "";
    const city = typeof a.city === "string" ? a.city.trim() : "";
    const state = typeof a.state === "string" ? a.state.trim() : "";
    const postalCode = typeof a.postalCode === "string" ? a.postalCode.trim() : "";
    if (!label || !line1 || !city || !state || !postalCode) {
      return NextResponse.json(
        { error: "address.label, line1, city, state, and postalCode are required when adding a new address." },
        { status: 400 },
      );
    }
    const line2 = typeof a.line2 === "string" && a.line2.trim() ? a.line2.trim() : null;
    const country = typeof a.country === "string" && a.country.trim() ? a.country.trim() : "India";
    const addressPhone = typeof a.phone === "string" && a.phone.trim() ? a.phone.trim() : null;
    const created = await prisma.osteqAddress.create({
      data: { customerId, label, line1, line2, city, state, postalCode, country, phone: addressPhone },
    });
    addressId = created.id;
  }

  const existingPending = await prisma.osteqTradeApplication.findFirst({
    where: { customerId, status: "PENDING" },
  });
  if (existingPending) {
    return NextResponse.json(
      { error: "You already have a pending trade application." },
      { status: 409 },
    );
  }

  const application = await prisma.osteqTradeApplication.create({
    data: { customerId, businessName, businessType, phone, taxId, addressId },
  });

  return NextResponse.json({ application });
}

export async function GET(request: NextRequest) {
  try {
    await requireStaffAccess();
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const statusFilter = new URL(request.url).searchParams.get("status");
  const applications = await prisma.osteqTradeApplication.findMany({
    where: statusFilter ? { status: statusFilter as "PENDING" | "APPROVED" | "REJECTED" } : undefined,
    orderBy: { createdAt: "asc" },
    include: { customer: true },
  });

  return NextResponse.json({ applications });
}
