import { prisma } from "@/lib/prisma";
import { notFound } from "next/navigation";
import { ProductEditForm } from "./ProductEditForm";
import { VariantForm } from "./VariantForm";
import { VariantEditForm } from "./VariantEditForm";

export default async function ProductDetailPage({ params }: { params: { id: string } }) {
  const product = await prisma.osteqProduct.findUnique({
    where: { id: params.id },
    include: { variants: { orderBy: { sku: "asc" } } },
  });
  if (!product) {
    notFound();
  }

  return (
    <div>
      <h1 className="mb-4 text-xl font-semibold">{product.name}</h1>
      <ProductEditForm product={product} />

      <h2 className="mb-2 mt-6 font-medium">Variants</h2>
      <table className="mb-4 w-full border-collapse text-sm">
        <thead>
          <tr className="border-b text-left">
            <th className="p-2">SKU</th>
            <th className="p-2">Attributes</th>
            <th className="p-2">Retail (paise)</th>
            <th className="p-2">Trade (paise)</th>
            <th className="p-2">Stock</th>
            <th className="p-2">Active</th>
            <th className="p-2"></th>
          </tr>
        </thead>
        <tbody>
          {product.variants.map((variant) => (
            <VariantEditForm key={variant.id} productId={product.id} variant={variant} />
          ))}
        </tbody>
      </table>

      <h2 className="mb-2 font-medium">Add variant</h2>
      <VariantForm productId={product.id} />
    </div>
  );
}
