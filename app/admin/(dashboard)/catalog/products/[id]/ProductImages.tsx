"use client";

import { useRef, useState } from "react";
import { useRouter } from "next/navigation";

interface ProductImageEntry {
  path: string;
  url: string;
}

// Uses a direct browser fetch (not the adminApiFetch/Server Action pattern used elsewhere in
// this admin panel) — that pattern exists specifically to forward the staff session cookie
// from a Server Action's Node context, which has no browser cookie jar. A Client Component
// fetching a same-origin route sends the browser's own cookies automatically, and File
// uploads need a real FormData body anyway, which adminApiFetch only ever JSON-encodes.
export function ProductImages({
  productId,
  images,
}: {
  productId: string;
  images: ProductImageEntry[];
}) {
  const router = useRouter();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState<string | undefined>();

  async function handleFileChange(event: React.ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    if (!file) return;
    setUploading(true);
    setError(undefined);
    try {
      const formData = new FormData();
      formData.append("file", file);
      const res = await fetch(`/api/osteq/products/${productId}/images`, {
        method: "POST",
        body: formData,
      });
      const json = await res.json().catch(() => ({}));
      if (!res.ok) {
        setError(typeof json.error === "string" ? json.error : "Upload failed.");
        return;
      }
      router.refresh();
    } catch {
      setError("Upload failed. Check your connection.");
    } finally {
      setUploading(false);
      if (fileInputRef.current) fileInputRef.current.value = "";
    }
  }

  async function handleDelete(path: string) {
    setError(undefined);
    try {
      const res = await fetch(`/api/osteq/products/${productId}/images`, {
        method: "DELETE",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ path }),
      });
      const json = await res.json().catch(() => ({}));
      if (!res.ok) {
        setError(typeof json.error === "string" ? json.error : "Delete failed.");
        return;
      }
      router.refresh();
    } catch {
      setError("Delete failed. Check your connection.");
    }
  }

  return (
    <div className="mt-4">
      <h3 className="mb-2 text-sm font-medium">Images</h3>
      {images.length > 0 && (
        <div className="mb-3 flex flex-wrap gap-3">
          {images.map(({ path, url }) => (
            <div key={path} className="relative">
              {/* eslint-disable-next-line @next/next/no-img-element -- admin-only tool, external Supabase Storage URLs not worth next/image's config overhead */}
              <img src={url} alt="" className="h-24 w-24 rounded border object-cover" />
              <button
                type="button"
                onClick={() => handleDelete(path)}
                className="absolute -right-2 -top-2 rounded-full bg-red-600 px-2 py-0.5 text-xs text-white"
              >
                ×
              </button>
            </div>
          ))}
        </div>
      )}
      <input
        ref={fileInputRef}
        type="file"
        accept="image/png,image/jpeg,image/webp"
        onChange={handleFileChange}
        disabled={uploading}
        className="text-sm"
      />
      {uploading && <span className="ml-2 text-xs text-gray-500">Uploading…</span>}
      {error && <p className="mt-1 text-xs text-red-600">{error}</p>}
    </div>
  );
}
