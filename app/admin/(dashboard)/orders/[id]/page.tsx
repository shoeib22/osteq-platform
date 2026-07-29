import { prisma } from "@/lib/prisma";
import { notFound } from "next/navigation";
import { StatusForm } from "./StatusForm";

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
      <h1 className="mb-4 text-xl font-semibold">Order for {order.customer.email}</h1>
      <p className="mb-2 text-sm">Shipping to: {order.shippingAddress}</p>
      <p className="mb-4 text-sm">Total: {order.totalInPaise} paise</p>

      <h2 className="mb-2 font-medium">Items</h2>
      <ul className="mb-6 divide-y text-sm">
        {order.items.map((item) => (
          <li key={item.id} className="py-2">
            {item.variant.sku} — qty {item.quantity} — {item.unitPriceInPaise} paise each
          </li>
        ))}
      </ul>

      <h2 className="mb-2 font-medium">Status</h2>
      <StatusForm order={order} />
    </div>
  );
}
