export interface PaymentResult {
  success: boolean;
  reference: string;
}

/**
 * No payment processor is selected yet (per the design spec — deferred to implementation
 * time). Checkout is built against this interface so wiring in Stripe/PayPal later only
 * means implementing PaymentProvider, not touching the order/stock transaction below.
 */
export interface PaymentProvider {
  charge(amountInPaise: number): Promise<PaymentResult>;
}

export const stubPaymentProvider: PaymentProvider = {
  async charge(amountInPaise: number): Promise<PaymentResult> {
    return { success: true, reference: `stub-${Date.now()}-${amountInPaise}` };
  },
};
