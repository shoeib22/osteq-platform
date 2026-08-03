import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireOsteqCustomerAccess } from "@/lib/osteq/auth";

export async function GET(request: NextRequest) {
  let customerId: string;
  try {
    ({ customerId } = await requireOsteqCustomerAccess(request));
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const profile = await prisma.osteqCustomerProfile.findUnique({
    where: { id: customerId },
    include: { tradeApplications: { orderBy: { createdAt: "desc" }, take: 1 } },
  });
  if (!profile) {
    return NextResponse.json({ error: "Profile not created yet." }, { status: 404 });
  }

  const { tradeApplications, ...profileFields } = profile;
  return NextResponse.json({
    profile: { ...profileFields, latestTradeApplicationStatus: tradeApplications[0]?.status ?? null },
  });
}

export async function POST(request: NextRequest) {
  let customerId: string;
  let email: string;
  try {
    ({ customerId, email } = await requireOsteqCustomerAccess(request));
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const body = await request.json();
  const businessName = typeof body.businessName === "string" ? body.businessName : null;
  const businessType = typeof body.businessType === "string" ? body.businessType : null;
  const phone = typeof body.phone === "string" ? body.phone : null;

  const profile = await prisma.osteqCustomerProfile.upsert({
    where: { id: customerId },
    create: { id: customerId, email, businessName, businessType, phone },
    update: { businessName, businessType, phone },
  });

  return NextResponse.json({ profile });
}
