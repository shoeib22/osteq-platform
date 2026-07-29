"use client";

export function SubmitButton({
  pending,
  children,
  className,
}: {
  pending: boolean;
  children: React.ReactNode;
  className?: string;
}) {
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
