import { NextResponse, type NextRequest } from "next/server";
import { prisma } from "@/lib/prisma";
import { requireStaffAccess } from "@/lib/auth";

export async function GET() {
  const categories = await prisma.osteqCategory.findMany({ orderBy: { name: "asc" } });
  return NextResponse.json({ categories });
}

export async function POST(request: NextRequest) {
  try {
    await requireStaffAccess();
  } catch {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const body = await request.json();
  const name = typeof body.name === "string" ? body.name.trim() : "";
  const slug = typeof body.slug === "string" ? body.slug.trim() : "";
  const parentCategoryId = typeof body.parentCategoryId === "string" ? body.parentCategoryId : null;

  if (!name || !slug) {
    return NextResponse.json({ error: "name and slug are required." }, { status: 400 });
  }

  const category = await prisma.osteqCategory.create({ data: { name, slug, parentCategoryId } });
  return NextResponse.json({ category });
}
