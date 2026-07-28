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
    data: { customerId, businessName, businessType, phone, taxId },
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
