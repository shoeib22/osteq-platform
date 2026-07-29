"use client";

import { useState } from "react";
import { reviewTradeApplication } from "./actions";
import { SubmitButton } from "../SubmitButton";

export function TradeApplicationActions({ applicationId }: { applicationId: string }) {
  const [error, setError] = useState<string | undefined>();
  const [isPending, setIsPending] = useState(false);
  const [showReject, setShowReject] = useState(false);

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    setIsPending(true);
    try {
      const result = await reviewTradeApplication(formData);
      setError(result?.error);
    } finally {
      setIsPending(false);
    }
  }

  return (
    <div className="flex flex-col gap-2">
      <div className="flex gap-2">
        <form onSubmit={handleSubmit}>
          <input type="hidden" name="applicationId" value={applicationId} />
          <input type="hidden" name="decision" value="APPROVED" />
          <SubmitButton pending={isPending} className="rounded bg-green-600 px-2 py-1 text-sm text-white disabled:opacity-50">
            Approve
          </SubmitButton>
        </form>
        <button
          type="button"
          onClick={() => setShowReject((v) => !v)}
          className="rounded bg-red-600 px-2 py-1 text-sm text-white"
        >
          Reject
        </button>
      </div>
      {showReject && (
        <form onSubmit={handleSubmit} className="flex gap-2">
          <input type="hidden" name="applicationId" value={applicationId} />
          <input type="hidden" name="decision" value="REJECTED" />
          <input name="rejectionReason" placeholder="Reason" className="rounded border px-2 py-1 text-sm" />
          <SubmitButton pending={isPending} className="rounded bg-red-600 px-2 py-1 text-sm text-white disabled:opacity-50">
            Confirm reject
          </SubmitButton>
        </form>
      )}
      {error && <p className="text-xs text-red-600">{error}</p>}
    </div>
  );
}
