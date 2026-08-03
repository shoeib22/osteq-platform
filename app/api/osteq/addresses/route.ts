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

  const addresses = await prisma.osteqAddress.findMany({
    where: { customerId },
    orderBy: [{ isDefault: "desc" }, { createdAt: "asc" }],
  });

  return NextResponse.json({ addresses });
}

export async function POST(request: NextRequest) {
  let customerId: string;
  try {
    ({ customerId } = await requireOsteqCustomerAccess(request));
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const body = await request.json();
  const label = typeof body.label === "string" ? body.label.trim() : "";
  const line1 = typeof body.line1 === "string" ? body.line1.trim() : "";
  const line2 = typeof body.line2 === "string" && body.line2.trim() ? body.line2.trim() : null;
  const city = typeof body.city === "string" ? body.city.trim() : "";
  const state = typeof body.state === "string" ? body.state.trim() : "";
  const postalCode = typeof body.postalCode === "string" ? body.postalCode.trim() : "";
  const country = typeof body.country === "string" && body.country.trim() ? body.country.trim() : "India";
  const phone = typeof body.phone === "string" && body.phone.trim() ? body.phone.trim() : null;
  const isDefault = body.isDefault === true;

  if (!label || !line1 || !city || !state || !postalCode) {
    return NextResponse.json(
      { error: "label, line1, city, state, and postalCode are required." },
      { status: 400 },
    );
  }

  const address = await prisma.$transaction(async (tx) => {
    if (isDefault) {
      await tx.osteqAddress.updateMany({ where: { customerId }, data: { isDefault: false } });
    }
    return tx.osteqAddress.create({
      data: { customerId, label, line1, line2, city, state, postalCode, country, phone, isDefault },
    });
  });

  return NextResponse.json({ address });
}
