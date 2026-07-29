import { prisma } from "@/lib/prisma";
import { notFound } from "next/navigation";
import { PriceForm } from "./PriceForm";
import { MessageForm } from "./MessageForm";

const PRICEABLE_STATUSES = ["SUBMITTED", "UNDER_REVIEW", "REVISION_REQUESTED"];

export default async function QuoteDetailPage({ params }: { params: { id: string } }) {
  const quote = await prisma.osteqQuote.findUnique({
    where: { id: params.id },
    include: {
      customer: true,
      items: { include: { variant: true } },
      messages: { orderBy: { createdAt: "asc" } },
    },
  });
  if (!quote) {
    notFound();
  }

  return (
    <div>
      <h1 className="mb-4 text-xl font-semibold">Quote for {quote.customer.email}</h1>
      <p className="mb-4 text-sm">Status: {quote.status}</p>

      <h2 className="mb-2 font-medium">Line items</h2>
      {PRICEABLE_STATUSES.includes(quote.status) ? (
        <PriceForm quoteId={quote.id} items={quote.items} />
      ) : (
        <ul className="mb-6 divide-y text-sm">
          {quote.items.map((item) => (
            <li key={item.id} className="py-2">
              {item.variant?.sku ?? item.description} — qty {item.quantity} —{" "}
              {item.quotedUnitPriceInPaise != null
                ? `${item.quotedUnitPriceInPaise} paise`
                : "not priced"}
            </li>
          ))}
        </ul>
      )}

      <h2 className="mb-2 mt-6 font-medium">Messages</h2>
      <ul className="mb-4 divide-y text-sm">
        {quote.messages.map((message) => (
          <li key={message.id} className="py-2">
            <span className="font-medium">{message.authorProfileId ? "Staff" : "Customer"}:</span>{" "}
            {message.body}
          </li>
        ))}
      </ul>
      <MessageForm quoteId={quote.id} />
    </div>
  );
}
