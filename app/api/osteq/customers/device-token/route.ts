import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireOsteqCustomerAccess } from "@/lib/osteq/auth";

export async function POST(request: NextRequest) {
  let customerId: string;
  try {
    ({ customerId } = await requireOsteqCustomerAccess(request));
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const body = await request.json();
  const fcmToken = typeof body.fcmToken === "string" ? body.fcmToken : "";
  if (!fcmToken) {
    return NextResponse.json({ error: "fcmToken is required." }, { status: 400 });
  }

  await prisma.osteqCustomerProfile.update({
    where: { id: customerId },
    data: { fcmToken },
  });

  return NextResponse.json({ ok: true });
}
