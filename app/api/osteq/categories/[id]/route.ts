import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireStaffAccess } from "@/lib/auth";

export async function PATCH(request: NextRequest, { params }: { params: { id: string } }) {
  try {
    await requireStaffAccess();
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const existing = await prisma.osteqCategory.findUnique({ where: { id: params.id } });
  if (!existing) {
    return NextResponse.json({ error: "Category not found." }, { status: 404 });
  }

  const body = await request.json();
  const name = typeof body.name === "string" && body.name.trim() ? body.name.trim() : existing.name;
  const slug = typeof body.slug === "string" && body.slug.trim() ? body.slug.trim() : existing.slug;
  const parentCategoryId =
    body.parentCategoryId === null
      ? null
      : typeof body.parentCategoryId === "string"
        ? body.parentCategoryId
        : existing.parentCategoryId;

  const category = await prisma.osteqCategory.update({
    where: { id: params.id },
    data: { name, slug, parentCategoryId },
  });
  return NextResponse.json({ category });
}
