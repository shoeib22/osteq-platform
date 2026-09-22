import { prisma } from "@/lib/prisma";
import { notFound } from "next/navigation";
import Link from "next/link";
import { StatusForm } from "./StatusForm";
import { InvoicePdfForm } from "./InvoicePdfForm";

export default async function OrderDetailPage({ params }: { params: { id: string } }) {
  const order = await prisma.osteqOrder.findUnique({
    where: { id: params.id },
    include: { customer: true, items: { include: { variant: true } } },
  });
  if (!order) {
    notFound();
  }

  return (
    <div>
      <div className="mb-4 flex items-center justify-between">
        <h1 className="text-xl font-semibold">Order for {order.customer.email}</h1>
        <Link href={`/admin/orders/${order.id}/invoice`} className="text-sm underline">
          View / print invoice
        </Link>
      </div>
      <p className="mb-2 text-sm">Shipping to: {order.shippingAddress}</p>
      <p className="mb-4 text-sm">Total: ₹{Number(order.totalInRupees).toFixed(2)}</p>

      <h2 className="mb-2 font-medium">Items</h2>
      <ul className="mb-6 divide-y text-sm">
        {order.items.map((item) => (
          <li key={item.id} className="py-2">
            {item.variant.sku} — qty {item.quantity} — ₹{Number(item.unitPriceInRupees).toFixed(2)} each
          </li>
        ))}
      </ul>

      <h2 className="mb-2 font-medium">Status</h2>
      <StatusForm order={order} />
      <InvoicePdfForm orderId={order.id} hasInvoicePdf={order.invoicePdfPath != null} />
    </div>
  );
}
