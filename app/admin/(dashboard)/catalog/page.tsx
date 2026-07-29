import { prisma } from "@/lib/prisma";
import Link from "next/link";
import { CategoryForm } from "./CategoryForm";

export default async function CatalogPage() {
  const categories = await prisma.osteqCategory.findMany({ orderBy: { name: "asc" } });

  return (
    <div>
      <h1 className="mb-4 text-xl font-semibold">Catalog</h1>
      <ul className="mb-6 divide-y">
        {categories.map((category) => (
          <li key={category.id} className="flex items-center justify-between py-2">
            <Link href={`/admin/catalog/${category.id}`} className="underline">
              {category.name}
            </Link>
            <CategoryForm mode="edit" category={category} />
          </li>
        ))}
      </ul>
      <h2 className="mb-2 font-medium">Add category</h2>
      <CategoryForm mode="create" />
    </div>
  );
}
