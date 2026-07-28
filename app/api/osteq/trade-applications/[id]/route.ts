import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireStaffAccess } from "@/lib/auth";
import { notifyTradeApplicationDecision } from "@/lib/osteq/notifications";

export async function PATCH(request: NextRequest, { params }: { params: { id: string } }) {
  let profileId: string;
  try {
    ({ id: profileId } = await requireStaffAccess());
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const application = await prisma.osteqTradeApplication.findUnique({ where: { id: params.id } });
  if (!application) {
    return NextResponse.json({ error: "Application not found." }, { status: 404 });
  }

  const body = await request.json();
  const decision = body.decision;
  if (decision !== "APPROVED" && decision !== "REJECTED") {
    return NextResponse.json({ error: "decision must be APPROVED or REJECTED." }, { status: 400 });
  }
  const rejectionReason =
    decision === "REJECTED" && typeof body.rejectionReason === "string" ? body.rejectionReason : null;

  // updateMany's WHERE status: "PENDING" is the race guard — only one concurrent transaction
  // can match a still-PENDING row, so a second racing request sees count === 0 instead of
  // silently overwriting the first request's decision.
  const reviewed = await prisma.$transaction(async (tx) => {
    const { count } = await tx.osteqTradeApplication.updateMany({
      where: { id: application.id, status: "PENDING" },
      data: { status: decision, reviewedByProfileId: profileId, reviewedAt: new Date(), rejectionReason },
    });
    if (count === 0) {
      return false;
    }
    await tx.osteqCustomerProfile.update({
      where: { id: application.customerId },
      data: { accountStatus: decision === "APPROVED" ? "TRADE_APPROVED" : "REJECTED" },
    });
    return true;
  });

  if (!reviewed) {
    return NextResponse.json({ error: "Application already reviewed." }, { status: 409 });
  }

  const updatedApplication = await prisma.osteqTradeApplication.findUniqueOrThrow({ where: { id: application.id } });
  notifyTradeApplicationDecision(updatedApplication, decision);

  return NextResponse.json({ ok: true });
}
