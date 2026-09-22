import type { OsteqOrder, OsteqQuote, OsteqTradeApplication } from "@prisma/client";
import { prisma } from "@/lib/prisma";
import { initializeApp, cert, getApps, type App } from "firebase-admin/app";
import { getMessaging } from "firebase-admin/messaging";

/**
 * Mirrors lib/notifications.ts's fire-and-forget Resend pattern exactly — the triggering
 * DB write is always the source of truth, so every branch here only logs on failure. No
 * queue/worker is introduced (this repo deploys to Vercel with no persistent process to
 * run one), matching this repo's existing convention.
 */
async function sendEmail(to: string, subject: string, text: string): Promise<void> {
  const resendApiKey = process.env.RESEND_API_KEY;
  if (!resendApiKey) {
    console.log(`[osteq notification] No RESEND_API_KEY configured. To: ${to} — ${subject}`);
    return;
  }
  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${resendApiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({ from: "Osteq <onboarding@resend.dev>", to, subject, text }),
    });
    if (!res.ok) {
      console.error(`Osteq notification failed: HTTP ${res.status}`);
    }
  } catch (err) {
    console.error("Osteq notification failed:", err);
  }
}

function firebaseApp(): App | null {
  if (getApps().length > 0) return getApps()[0];
  const json = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!json) return null;
  return initializeApp({ credential: cert(JSON.parse(json)) });
}

/**
 * Same fire-and-forget contract as sendEmail above — the triggering DB write is always
 * the source of truth, this only ever logs on failure.
 */
async function sendPush(
  fcmToken: string,
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<void> {
  const app = firebaseApp();
  if (!app) {
    console.log(`[osteq notification] No FIREBASE_SERVICE_ACCOUNT_JSON configured. Push skipped: ${title}`);
    return;
  }
  try {
    await getMessaging(app).send({ token: fcmToken, notification: { title, body }, data });
  } catch (err) {
    console.error("Osteq push notification failed:", err);
  }
}

export async function notifyTradeApplicationDecision(
  application: OsteqTradeApplication,
  decision: "APPROVED" | "REJECTED",
): Promise<void> {
  try {
    const customer = await prisma.osteqCustomerProfile.findUnique({ where: { id: application.customerId } });
    if (!customer) return;
    const subject = decision === "APPROVED" ? "Your Osteq trade account is approved" : "Your Osteq trade application";
    const text =
      decision === "APPROVED"
        ? "Your trade account has been approved. Trade pricing is now visible on every product."
        : `Your trade application was not approved.${application.rejectionReason ? ` Reason: ${application.rejectionReason}` : ""}`;
    await sendEmail(customer.email, subject, text);
  } catch (err) {
    console.error("Osteq notification failed (trade application decision):", err);
  }
}

export async function notifyQuoteReady(quote: OsteqQuote): Promise<void> {
  try {
    const customer = await prisma.osteqCustomerProfile.findUnique({ where: { id: quote.customerId } });
    if (!customer) return;
    await sendEmail(customer.email, "Your Osteq quote is ready", `Quote ${quote.id} has been priced and is ready for your review.`);
  } catch (err) {
    console.error("Osteq notification failed (quote ready):", err);
  }
}

export async function notifyOrderStatusChange(order: OsteqOrder): Promise<void> {
  try {
    const customer = await prisma.osteqCustomerProfile.findUnique({ where: { id: order.customerId } });
    if (!customer) return;
    await sendEmail(customer.email, "Your Osteq order status changed", `Order ${order.id} is now ${order.status}.`);

    if (order.status === "OUT_FOR_DELIVERY" && customer.fcmToken) {
      await sendPush(
        customer.fcmToken,
        "Your order is out for delivery",
        `Order ${order.id.slice(0, 8).toUpperCase()} is on its way.`,
        { orderId: order.id, trackingUrl: order.trackingUrl ?? "" },
      );
    }
  } catch (err) {
    console.error("Osteq notification failed (order status change):", err);
  }
}
