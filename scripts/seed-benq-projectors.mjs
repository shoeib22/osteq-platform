// One-off catalog import: seeds BenQ's home theater projector lineup into the "Projectors"
// category so the Flutter app's Projector Calculator can pick a real model and auto-fill its
// throw ratio, instead of the user having to type it in from a spec sheet by hand.
//
// Source data (name, throw ratio, aspect ratio, image URL) was pulled from each model's
// official benq.com spec page — see scripts/data/benq-projectors.json for the source URL
// per model. Osteq doesn't distribute BenQ; these entries exist for the calculator's model
// picker, not for sale, so they're seeded with no variants (the catalog UI already renders
// "Unavailable" for a product with no active variant).
//
// Usage: DATABASE_URL=... DIRECT_URL=... NEXT_PUBLIC_SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... node scripts/seed-benq-projectors.mjs
// Safe to re-run: matches products by slug and only re-uploads an image if the product doesn't have one yet.

import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { PrismaClient } from "@prisma/client";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const BUCKET = "product-images";
const CATEGORY = { name: "Projectors", slug: "projectors" };

function slugify(name) {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function extensionForContentType(contentType) {
  if (contentType?.includes("png")) return "png";
  if (contentType?.includes("webp")) return "webp";
  return "jpg";
}

// Raw Storage REST call instead of @supabase/supabase-js — this script also needs to run
// inside the deployed app container, whose production node_modules is Next's traced
// "standalone" output (only what the app's own bundled code imports) and doesn't carry
// @supabase/supabase-js as an installable package there, unlike this repo's dev node_modules.
async function uploadToStorage(supabaseUrl, serviceRoleKey, bucket, path, bytes, contentType) {
  const res = await fetch(`${supabaseUrl}/storage/v1/object/${bucket}/${path}`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${serviceRoleKey}`,
      apikey: serviceRoleKey,
      "Content-Type": contentType,
      "x-upsert": "true",
    },
    body: bytes,
  });
  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new Error(`Storage upload failed: HTTP ${res.status} ${text}`);
  }
}

async function main() {
  const requiredEnv = ["DATABASE_URL", "NEXT_PUBLIC_SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY"];
  const missing = requiredEnv.filter((k) => !process.env[k]);
  if (missing.length > 0) {
    console.error(`Missing required env vars: ${missing.join(", ")}`);
    process.exit(1);
  }

  const prisma = new PrismaClient();
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  const projectors = JSON.parse(readFileSync(path.join(__dirname, "data", "benq-projectors.json"), "utf-8"));

  const category = await prisma.osteqCategory.upsert({
    where: { slug: CATEGORY.slug },
    update: {},
    create: CATEGORY,
  });
  console.log(`Category "${category.name}" ready (${category.id}).`);

  let created = 0;
  let updated = 0;
  let imagesUploaded = 0;
  let imagesSkipped = 0;

  for (const item of projectors) {
    const slug = slugify(item.name);
    const specs = {
      throwRatioWide: item.throwRatioWide,
      throwRatioTele: item.throwRatioTele,
      aspectRatio: item.aspectRatio,
      resolution: item.resolution ?? null,
      sourceUrl: item.sourceUrl,
    };

    const existing = await prisma.osteqProduct.findUnique({ where: { slug } });
    const product = await prisma.osteqProduct.upsert({
      where: { slug },
      update: { specs, description: item.resolution ?? undefined },
      create: {
        categoryId: category.id,
        name: item.name,
        slug,
        description: item.resolution ?? null,
        specs,
        images: [],
      },
    });
    existing ? updated++ : created++;

    if (item.imageUrl && (!existing || existing.images.length === 0)) {
      try {
        const res = await fetch(item.imageUrl);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const contentType = res.headers.get("content-type") ?? "image/jpeg";
        const ext = extensionForContentType(contentType);
        const bytes = new Uint8Array(await res.arrayBuffer());
        const storagePath = `${product.id}/main.${ext}`;

        await uploadToStorage(supabaseUrl, serviceRoleKey, BUCKET, storagePath, bytes, contentType);

        await prisma.osteqProduct.update({
          where: { id: product.id },
          data: { images: [storagePath] },
        });
        imagesUploaded++;
        console.log(`  ✓ ${item.name} — image uploaded`);
      } catch (err) {
        console.warn(`  ! ${item.name} — image upload failed: ${err.message ?? err}`);
      }
    } else if (!item.imageUrl) {
      imagesSkipped++;
      console.log(`  · ${item.name} — no source image, left blank`);
    }
  }

  console.log(
    `\nDone. ${created} created, ${updated} updated, ${imagesUploaded} images uploaded, ${imagesSkipped} without a source image.`,
  );
  await prisma.$disconnect();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
