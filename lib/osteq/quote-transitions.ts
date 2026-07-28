type QuoteStatus =
  | "SUBMITTED"
  | "UNDER_REVIEW"
  | "QUOTED"
  | "REVISION_REQUESTED"
  | "ACCEPTED"
  | "REJECTED"
  | "CONVERTED_TO_ORDER";

/**
 * The one place that knows which quote status transitions are legal — every route that
 * moves a quote's status calls assertValidTransition() instead of writing its own if-chain,
 * so the state machine can't drift out of sync between the "staff prices it" and "customer
 * responds" routes.
 */
export const QUOTE_TRANSITIONS: Record<QuoteStatus, QuoteStatus[]> = {
  SUBMITTED: ["UNDER_REVIEW"],
  UNDER_REVIEW: ["QUOTED"],
  QUOTED: ["ACCEPTED", "REJECTED", "REVISION_REQUESTED"],
  REVISION_REQUESTED: ["UNDER_REVIEW"],
  ACCEPTED: ["CONVERTED_TO_ORDER"],
  REJECTED: [],
  CONVERTED_TO_ORDER: [],
};

export function assertValidTransition(from: QuoteStatus, to: QuoteStatus): void {
  if (!QUOTE_TRANSITIONS[from].includes(to)) {
    throw new Error(`Cannot move quote from ${from} to ${to}.`);
  }
}
