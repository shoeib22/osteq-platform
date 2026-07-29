"use client";

import { useState } from "react";
import type { OsteqOrder } from "@prisma/client";
import { updateOrderStatus } from "./actions";
import { SubmitButton } from "../../SubmitButton";

const STATUSES = ["PROCESSING", "SHIPPED", "DELIVERED", "CANCELLED"];

export function StatusForm({ order }: { order: OsteqOrder }) {
  const [error, setError] = useState<string | undefined>();
  const [isPending, setIsPending] = useState(false);

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    setIsPending(true);
    try {
      const result = await updateOrderStatus(formData);
      setError(result?.error);
    } finally {
      setIsPending(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-wrap items-center gap-2">
      <input type="hidden" name="orderId" value={order.id} />
      <select name="status" defaultValue={order.status} className="rounded border px-2 py-1 text-sm">
        {STATUSES.map((status) => (
          <option key={status} value={status}>
            {status}
          </option>
        ))}
      </select>
      <input
        name="trackingNumber"
        defaultValue={order.trackingNumber ?? ""}
        placeholder="Tracking number"
        className="rounded border px-2 py-1 text-sm"
      />
      <SubmitButton pending={isPending} className="rounded bg-black px-3 py-1 text-sm text-white disabled:opacity-50">
        Update
      </SubmitButton>
      {error && <span className="text-xs text-red-600">{error}</span>}
    </form>
  );
}
