"use client";

import { useFormStatus } from "react-dom";

export function SubmitButton({
  children,
  className,
}: {
  children: React.ReactNode;
  className?: string;
}) {
  const { pending } = useFormStatus();
  return (
    <button
      type="submit"
      disabled={pending}
      className={className ?? "rounded bg-black px-3 py-1 text-sm text-white disabled:opacity-50"}
    >
      {pending ? "Saving..." : children}
    </button>
  );
}
