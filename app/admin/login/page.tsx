"use client";

import { useFormState } from "react-dom";
import { loginAction } from "./actions";

export default function AdminLoginPage() {
  const [state, formAction] = useFormState(loginAction, null);

  return (
    <div className="flex min-h-screen items-center justify-center">
      <form action={formAction} className="w-full max-w-sm space-y-4 p-6">
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
        {state?.error && <p className="text-sm text-red-600">{state.error}</p>}
        <button type="submit" className="w-full rounded bg-black px-3 py-2 text-white">
          Sign in
        </button>
      </form>
    </div>
  );
}
