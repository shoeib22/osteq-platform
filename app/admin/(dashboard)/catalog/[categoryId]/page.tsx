import { prisma } from "@/lib/prisma";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ProductForm } from "./ProductForm";

export default async function CategoryDetailPage({
  params,
}: {
  params: { categoryId: string };
}) {
  const category = await prisma.osteqCategory.findUnique({ where: { id: params.categoryId } });
  if (!category) {
    notFound();
  }

  const products = await prisma.osteqProduct.findMany({
    where: { categoryId: params.categoryId },
    orderBy: { name: "asc" },
  });

  return (
    <div>
      <h1 className="mb-4 text-xl font-semibold">{category.name}</h1>
      <ul className="mb-6 divide-y">
        {products.map((product) => (
          <li key={product.id} className="py-2">
            <Link href={`/admin/catalog/products/${product.id}`} className="underline">
              {product.name}
            </Link>
            {!product.isActive && <span className="ml-2 text-xs text-gray-500">(inactive)</span>}
          </li>
        ))}
      </ul>
      <h2 className="mb-2 font-medium">Add product</h2>
      <ProductForm categoryId={category.id} />
    </div>
  );
}
