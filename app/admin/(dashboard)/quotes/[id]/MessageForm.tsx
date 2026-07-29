"use client";

import { useState } from "react";
import { sendQuoteMessage } from "./actions";
import { SubmitButton } from "../../SubmitButton";

export function MessageForm({ quoteId }: { quoteId: string }) {
  const [error, setError] = useState<string | undefined>();
  const [isPending, setIsPending] = useState(false);

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    setIsPending(true);
    try {
      const result = await sendQuoteMessage(formData);
      setError(result?.error);
    } finally {
      setIsPending(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} className="flex items-center gap-2">
      <input type="hidden" name="quoteId" value={quoteId} />
      <input name="body" placeholder="Message" required className="flex-1 rounded border px-2 py-1 text-sm" />
      <SubmitButton pending={isPending} className="rounded bg-black px-3 py-1 text-sm text-white disabled:opacity-50">
        Send
      </SubmitButton>
      {error && <span className="text-xs text-red-600">{error}</span>}
    </form>
  );
}
