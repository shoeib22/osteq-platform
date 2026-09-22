"use client";

import { useRef, useState } from "react";
import { useRouter } from "next/navigation";

// Same direct-browser-fetch pattern as ProductImages.tsx (catalog/products/[id]) — File
// uploads need a real FormData body, which the adminApiFetch/Server Action pattern used
// elsewhere in this admin panel only ever JSON-encodes.
export function InvoicePdfForm({ orderId, hasInvoicePdf }: { orderId: string; hasInvoicePdf: boolean }) {
  const router = useRouter();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | undefined>();

  async function handleFileChange(event: React.ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    if (!file) return;
    setBusy(true);
    setError(undefined);
    try {
      const formData = new FormData();
      formData.append("file", file);
      const res = await fetch(`/api/osteq/orders/${orderId}/invoice-pdf`, { method: "POST", body: formData });
      const json = await res.json().catch(() => ({}));
      if (!res.ok) {
        setError(typeof json.error === "string" ? json.error : "Upload failed.");
        return;
      }
      router.refresh();
    } catch {
      setError("Upload failed. Check your connection.");
    } finally {
      setBusy(false);
      if (fileInputRef.current) fileInputRef.current.value = "";
    }
  }

  async function handleRemove() {
    setBusy(true);
    setError(undefined);
    try {
      const res = await fetch(`/api/osteq/orders/${orderId}/invoice-pdf`, { method: "DELETE" });
      const json = await res.json().catch(() => ({}));
      if (!res.ok) {
        setError(typeof json.error === "string" ? json.error : "Remove failed.");
        return;
      }
      router.refresh();
    } catch {
      setError("Remove failed. Check your connection.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="mt-6">
      <h2 className="mb-2 font-medium">Invoice PDF</h2>
      <p className="mb-2 text-sm text-gray-600">
        {hasInvoicePdf ? "Invoice PDF uploaded." : "No invoice PDF uploaded yet."}
      </p>
      <input
        ref={fileInputRef}
        type="file"
        accept="application/pdf"
        onChange={handleFileChange}
        disabled={busy}
        className="text-sm"
      />
      {hasInvoicePdf && (
        <button
          type="button"
          onClick={handleRemove}
          disabled={busy}
          className="ml-2 rounded bg-red-600 px-2 py-1 text-xs text-white disabled:opacity-50"
        >
          Remove
        </button>
      )}
      {busy && <span className="ml-2 text-xs text-gray-500">Working…</span>}
      {error && <p className="mt-1 text-xs text-red-600">{error}</p>}
    </div>
  );
}
