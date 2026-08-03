"use client";

export function PrintButton() {
  return (
    <button
      type="button"
      onClick={() => window.print()}
      className="print:hidden rounded bg-black px-3 py-1 text-sm text-white"
    >
      Print invoice
    </button>
  );
}
