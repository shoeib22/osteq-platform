import { prisma } from "@/lib/prisma";
import Link from "next/link";

export default async function OrdersPage({
  searchParams,
}: {
  searchParams: { status?: string };
}) {
  const status = searchParams.status;
  const orders = await prisma.osteqOrder.findMany({
    where: status ? { status: status as never } : undefined,
    include: { customer: true },
    orderBy: { createdAt: "desc" },
  });

  return (
    <div>
      <h1 className="mb-4 text-xl font-semibold">Orders</h1>
      <table className="w-full border-collapse text-sm">
        <thead>
          <tr className="border-b text-left">
            <th className="p-2">Customer</th>
            <th className="p-2">Total (₹)</th>
            <th className="p-2">Status</th>
            <th className="p-2">Created</th>
            <th className="p-2"></th>
          </tr>
        </thead>
        <tbody>
          {orders.map((order) => (
            <tr key={order.id} className="border-b">
              <td className="p-2">{order.customer.email}</td>
              <td className="p-2">₹{Number(order.totalInRupees).toFixed(2)}</td>
              <td className="p-2">{order.status}</td>
              <td className="p-2">{order.createdAt.toLocaleDateString()}</td>
              <td className="p-2">
                <Link href={`/admin/orders/${order.id}`} className="underline">
                  View
                </Link>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
