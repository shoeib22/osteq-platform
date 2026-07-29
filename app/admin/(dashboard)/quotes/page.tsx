import { prisma } from "@/lib/prisma";
import Link from "next/link";

export default async function QuotesPage({
  searchParams,
}: {
  searchParams: { status?: string };
}) {
  const status = searchParams.status;
  const quotes = await prisma.osteqQuote.findMany({
    where: status ? { status: status as never } : undefined,
    include: { customer: true, items: true },
    orderBy: { createdAt: "asc" },
  });

  return (
    <div>
      <h1 className="mb-4 text-xl font-semibold">Quotes</h1>
      <table className="w-full border-collapse text-sm">
        <thead>
          <tr className="border-b text-left">
            <th className="p-2">Customer</th>
            <th className="p-2">Items</th>
            <th className="p-2">Status</th>
            <th className="p-2">Created</th>
            <th className="p-2"></th>
          </tr>
        </thead>
        <tbody>
          {quotes.map((quote) => (
            <tr key={quote.id} className="border-b">
              <td className="p-2">{quote.customer.email}</td>
              <td className="p-2">{quote.items.length}</td>
              <td className="p-2">{quote.status}</td>
              <td className="p-2">{quote.createdAt.toLocaleDateString()}</td>
              <td className="p-2">
                <Link href={`/admin/quotes/${quote.id}`} className="underline">
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
