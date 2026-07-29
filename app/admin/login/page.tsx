"use client";

import { useState, useTransition } from "react";
import { loginAction } from "./actions";

export default function AdminLoginPage() {
  const [error, setError] = useState<string | undefined>();
  const [isPending, startTransition] = useTransition();

  function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    startTransition(async () => {
      const result = await loginAction(formData);
      setError(result?.error);
    });
  }

  return (
    <div className="flex min-h-screen items-center justify-center">
      <form onSubmit={handleSubmit} className="w-full max-w-sm space-y-4 p-6">
        <h1 className="text-xl font-semibold">Osteq Admin</h1>
        <input
          name="email"
          type="email"
          placeholder="Email"
          required
          className="w-full rounded border px-3 py-2"
        />
        <input
          name="password"
          type="password"
          placeholder="Password"
          required
          className="w-full rounded border px-3 py-2"
        />
        {error && <p className="text-sm text-red-600">{error}</p>}
        <button type="submit" disabled={isPending} className="w-full rounded bg-black px-3 py-2 text-white disabled:opacity-50">
          {isPending ? "Signing in..." : "Sign in"}
        </button>
      </form>
    </div>
  );
}
