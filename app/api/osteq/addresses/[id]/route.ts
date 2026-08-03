import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireOsteqCustomerAccess } from "@/lib/osteq/auth";

async function assertOwnedAddress(customerId: string, addressId: string) {
  const address = await prisma.osteqAddress.findUnique({ where: { id: addressId } });
  if (!address || address.customerId !== customerId) {
    return null;
  }
  return address;
}

export async function PATCH(request: NextRequest, { params }: { params: { id: string } }) {
  let customerId: string;
  try {
    ({ customerId } = await requireOsteqCustomerAccess(request));
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const existing = await assertOwnedAddress(customerId, params.id);
  if (!existing) {
    return NextResponse.json({ error: "Address not found." }, { status: 404 });
  }

  const body = await request.json();
  const label = typeof body.label === "string" && body.label.trim() ? body.label.trim() : existing.label;
  const line1 = typeof body.line1 === "string" && body.line1.trim() ? body.line1.trim() : existing.line1;
  const line2 =
    body.line2 === null ? null : typeof body.line2 === "string" ? body.line2.trim() || null : existing.line2;
  const city = typeof body.city === "string" && body.city.trim() ? body.city.trim() : existing.city;
  const state = typeof body.state === "string" && body.state.trim() ? body.state.trim() : existing.state;
  const postalCode =
    typeof body.postalCode === "string" && body.postalCode.trim() ? body.postalCode.trim() : existing.postalCode;
  const country =
    typeof body.country === "string" && body.country.trim() ? body.country.trim() : existing.country;
  const phone =
    body.phone === null ? null : typeof body.phone === "string" ? body.phone.trim() || null : existing.phone;
  const isDefault = typeof body.isDefault === "boolean" ? body.isDefault : existing.isDefault;

  const address = await prisma.$transaction(async (tx) => {
    if (isDefault && !existing.isDefault) {
      await tx.osteqAddress.updateMany({ where: { customerId }, data: { isDefault: false } });
    }
    return tx.osteqAddress.update({
      where: { id: existing.id },
      data: { label, line1, line2, city, state, postalCode, country, phone, isDefault },
    });
  });

  return NextResponse.json({ address });
}

export async function DELETE(request: NextRequest, { params }: { params: { id: string } }) {
  let customerId: string;
  try {
    ({ customerId } = await requireOsteqCustomerAccess(request));
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const existing = await assertOwnedAddress(customerId, params.id);
  if (!existing) {
    return NextResponse.json({ error: "Address not found." }, { status: 404 });
  }

  await prisma.osteqAddress.delete({ where: { id: existing.id } });
  return NextResponse.json({ ok: true });
}
