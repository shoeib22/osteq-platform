import { prisma } from "@/lib/prisma";
import { notFound } from "next/navigation";
import Link from "next/link";
import { PrintButton } from "./PrintButton";
import { createAdminClient } from "@/lib/supabase/admin";

const BUCKET = "order-invoices";

export default async function OrderInvoicePage({ params }: { params: { id: string } }) {
  const order = await prisma.osteqOrder.findUnique({
    where: { id: params.id },
    include: { customer: true, items: { include: { variant: { include: { product: true } } } } },
  });
  if (!order) {
    notFound();
  }

  let uploadedInvoiceUrl: string | null = null;
  if (order.invoicePdfPath) {
    const admin = createAdminClient();
    const { data } = await admin.storage.from(BUCKET).createSignedUrl(order.invoicePdfPath, 300);
    uploadedInvoiceUrl = data?.signedUrl ?? null;
  }

  return (
    <div className="mx-auto max-w-2xl">
      <div className="mb-4 flex items-center justify-between print:hidden">
        <Link href={`/admin/orders/${order.id}`} className="text-sm underline">
          Back to order
        </Link>
        {!uploadedInvoiceUrl && <PrintButton />}
      </div>

      {uploadedInvoiceUrl ? (
        <div className="rounded border p-8 text-center">
          <p className="mb-4 text-sm text-gray-600">A staff-uploaded invoice PDF is on file for this order.</p>
          <a href={uploadedInvoiceUrl} className="underline" target="_blank" rel="noreferrer">
            View uploaded invoice PDF
          </a>
        </div>
      ) : (
        <div className="rounded border p-8 print:border-0 print:p-0">
          <h1 className="text-2xl font-bold">Osteq</h1>
          <p className="text-sm text-gray-600">AV & home-theater equipment for trade installers</p>

          <div className="mt-6 flex items-start justify-between text-sm">
            <div>
              <p className="font-medium">Invoice #{order.id.slice(0, 8).toUpperCase()}</p>
              <p>Date: {order.createdAt.toLocaleDateString()}</p>
              <p>Status: {order.status}</p>
            </div>
            <div className="text-right">
              <p>Billed to: {order.customer.email}</p>
              <p>Ship to: {order.shippingAddress}</p>
              {order.trackingNumber && <p>Tracking: {order.trackingNumber}</p>}
            </div>
          </div>

          <table className="mt-8 w-full border-collapse text-sm">
            <thead>
              <tr className="border-b text-left">
                <th className="p-2">Item</th>
                <th className="p-2">Qty</th>
                <th className="p-2">Unit ₹</th>
                <th className="p-2">Total ₹</th>
              </tr>
            </thead>
            <tbody>
              {order.items.map((item) => (
                <tr key={item.id} className="border-b">
                  <td className="p-2">
                    {item.variant.product.name} ({item.variant.sku})
                  </td>
                  <td className="p-2">{item.quantity}</td>
                  <td className="p-2">{Number(item.unitPriceInRupees).toFixed(2)}</td>
                  <td className="p-2">{(Number(item.unitPriceInRupees) * item.quantity).toFixed(2)}</td>
                </tr>
              ))}
            </tbody>
          </table>

          <p className="mt-4 text-right text-lg font-bold">
            Grand total: ₹{Number(order.totalInRupees).toFixed(2)}
          </p>

          <p className="mt-8 text-xs text-gray-500">
            This is a system-generated invoice for the above order.
          </p>
        </div>
      )}
    </div>
  );
}
