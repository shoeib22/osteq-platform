import { prisma } from "@/lib/prisma";
import { TradeApplicationActions } from "./TradeApplicationActions";

export default async function TradeApplicationsPage({
  searchParams,
}: {
  searchParams: { status?: string };
}) {
  const status = searchParams.status;
  const applications = await prisma.osteqTradeApplication.findMany({
    where: status ? { status: status as never } : undefined,
    include: { customer: true },
    orderBy: { createdAt: "asc" },
  });

  return (
    <div>
      <h1 className="mb-4 text-xl font-semibold">Trade Applications</h1>
      <table className="w-full border-collapse text-sm">
        <thead>
          <tr className="border-b text-left">
            <th className="p-2">Business</th>
            <th className="p-2">Type</th>
            <th className="p-2">Phone</th>
            <th className="p-2">Customer</th>
            <th className="p-2">Status</th>
            <th className="p-2">Actions</th>
          </tr>
        </thead>
        <tbody>
          {applications.map((application) => (
            <tr key={application.id} className="border-b">
              <td className="p-2">{application.businessName}</td>
              <td className="p-2">{application.businessType}</td>
              <td className="p-2">{application.phone}</td>
              <td className="p-2">{application.customer.email}</td>
              <td className="p-2">{application.status}</td>
              <td className="p-2">
                {application.status === "PENDING" && (
                  <TradeApplicationActions applicationId={application.id} />
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
