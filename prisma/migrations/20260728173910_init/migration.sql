-- CreateEnum
CREATE TYPE "StaffRole" AS ENUM ('ADMIN');

-- CreateEnum
CREATE TYPE "OsteqAccountStatus" AS ENUM ('PENDING', 'TRADE_APPROVED', 'REJECTED');

-- CreateEnum
CREATE TYPE "OsteqTradeApplicationStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');

-- CreateEnum
CREATE TYPE "OsteqOrderStatus" AS ENUM ('PROCESSING', 'SHIPPED', 'DELIVERED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "OsteqQuoteStatus" AS ENUM ('SUBMITTED', 'UNDER_REVIEW', 'QUOTED', 'REVISION_REQUESTED', 'ACCEPTED', 'REJECTED', 'CONVERTED_TO_ORDER');

-- CreateTable
CREATE TABLE "staff" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "fullName" TEXT,
    "role" "StaffRole" NOT NULL DEFAULT 'ADMIN',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "staff_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "osteq_customer_profiles" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "businessName" TEXT,
    "businessType" TEXT,
    "phone" TEXT,
    "accountStatus" "OsteqAccountStatus" NOT NULL DEFAULT 'PENDING',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "osteq_customer_profiles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "osteq_trade_applications" (
    "id" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,
    "businessName" TEXT NOT NULL,
    "businessType" TEXT NOT NULL,
    "taxId" TEXT,
    "phone" TEXT NOT NULL,
    "status" "OsteqTradeApplicationStatus" NOT NULL DEFAULT 'PENDING',
    "reviewedByProfileId" TEXT,
    "reviewedAt" TIMESTAMP(3),
    "rejectionReason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "osteq_trade_applications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "osteq_categories" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "parentCategoryId" TEXT,

    CONSTRAINT "osteq_categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "osteq_products" (
    "id" TEXT NOT NULL,
    "categoryId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "description" TEXT,
    "specs" JSONB,
    "images" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "osteq_products_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "osteq_product_variants" (
    "id" TEXT NOT NULL,
    "productId" TEXT NOT NULL,
    "sku" TEXT NOT NULL,
    "attributes" JSONB NOT NULL,
    "retailPriceInPaise" INTEGER NOT NULL,
    "tradePriceInPaise" INTEGER NOT NULL,
    "stockQuantity" INTEGER NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "osteq_product_variants_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "osteq_carts" (
    "id" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,

    CONSTRAINT "osteq_carts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "osteq_cart_items" (
    "id" TEXT NOT NULL,
    "cartId" TEXT NOT NULL,
    "variantId" TEXT NOT NULL,
    "quantity" INTEGER NOT NULL,

    CONSTRAINT "osteq_cart_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "osteq_orders" (
    "id" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,
    "status" "OsteqOrderStatus" NOT NULL DEFAULT 'PROCESSING',
    "shippingAddress" TEXT NOT NULL,
    "trackingNumber" TEXT,
    "totalInPaise" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "osteq_orders_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "osteq_order_items" (
    "id" TEXT NOT NULL,
    "orderId" TEXT NOT NULL,
    "variantId" TEXT NOT NULL,
    "quantity" INTEGER NOT NULL,
    "unitPriceInPaise" INTEGER NOT NULL,

    CONSTRAINT "osteq_order_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "osteq_quotes" (
    "id" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,
    "status" "OsteqQuoteStatus" NOT NULL DEFAULT 'SUBMITTED',
    "convertedOrderId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "osteq_quotes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "osteq_quote_items" (
    "id" TEXT NOT NULL,
    "quoteId" TEXT NOT NULL,
    "productVariantId" TEXT,
    "description" TEXT,
    "quantity" INTEGER NOT NULL,
    "quotedUnitPriceInPaise" INTEGER,
    "notes" TEXT,

    CONSTRAINT "osteq_quote_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "osteq_quote_messages" (
    "id" TEXT NOT NULL,
    "quoteId" TEXT NOT NULL,
    "authorProfileId" TEXT,
    "authorCustomerId" TEXT,
    "body" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "osteq_quote_messages_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "staff_email_key" ON "staff"("email");

-- CreateIndex
CREATE UNIQUE INDEX "osteq_customer_profiles_email_key" ON "osteq_customer_profiles"("email");

-- CreateIndex
CREATE INDEX "osteq_trade_applications_customerId_idx" ON "osteq_trade_applications"("customerId");

-- CreateIndex
CREATE INDEX "osteq_trade_applications_status_idx" ON "osteq_trade_applications"("status");

-- CreateIndex
CREATE UNIQUE INDEX "osteq_categories_slug_key" ON "osteq_categories"("slug");

-- CreateIndex
CREATE UNIQUE INDEX "osteq_products_slug_key" ON "osteq_products"("slug");

-- CreateIndex
CREATE INDEX "osteq_products_categoryId_idx" ON "osteq_products"("categoryId");

-- CreateIndex
CREATE UNIQUE INDEX "osteq_product_variants_sku_key" ON "osteq_product_variants"("sku");

-- CreateIndex
CREATE INDEX "osteq_product_variants_productId_idx" ON "osteq_product_variants"("productId");

-- CreateIndex
CREATE UNIQUE INDEX "osteq_carts_customerId_key" ON "osteq_carts"("customerId");

-- CreateIndex
CREATE UNIQUE INDEX "osteq_cart_items_cartId_variantId_key" ON "osteq_cart_items"("cartId", "variantId");

-- CreateIndex
CREATE INDEX "osteq_orders_customerId_idx" ON "osteq_orders"("customerId");

-- CreateIndex
CREATE INDEX "osteq_order_items_orderId_idx" ON "osteq_order_items"("orderId");

-- CreateIndex
CREATE UNIQUE INDEX "osteq_quotes_convertedOrderId_key" ON "osteq_quotes"("convertedOrderId");

-- CreateIndex
CREATE INDEX "osteq_quotes_customerId_idx" ON "osteq_quotes"("customerId");

-- CreateIndex
CREATE INDEX "osteq_quote_items_quoteId_idx" ON "osteq_quote_items"("quoteId");

-- CreateIndex
CREATE INDEX "osteq_quote_messages_quoteId_idx" ON "osteq_quote_messages"("quoteId");

-- AddForeignKey
ALTER TABLE "osteq_trade_applications" ADD CONSTRAINT "osteq_trade_applications_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "osteq_customer_profiles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "osteq_trade_applications" ADD CONSTRAINT "osteq_trade_applications_reviewedByProfileId_fkey" FOREIGN KEY ("reviewedByProfileId") REFERENCES "staff"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "osteq_categories" ADD CONSTRAINT "osteq_categories_parentCategoryId_fkey" FOREIGN KEY ("parentCategoryId") REFERENCES "osteq_categories"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "osteq_products" ADD CONSTRAINT "osteq_products_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES "osteq_categories"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "osteq_product_variants" ADD CONSTRAINT "osteq_product_variants_productId_fkey" FOREIGN KEY ("productId") REFERENCES "osteq_products"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "osteq_carts" ADD CONSTRAINT "osteq_carts_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "osteq_customer_profiles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "osteq_cart_items" ADD CONSTRAINT "osteq_cart_items_cartId_fkey" FOREIGN KEY ("cartId") REFERENCES "osteq_carts"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "osteq_cart_items" ADD CONSTRAINT "osteq_cart_items_variantId_fkey" FOREIGN KEY ("variantId") REFERENCES "osteq_product_variants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "osteq_orders" ADD CONSTRAINT "osteq_orders_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "osteq_customer_profiles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "osteq_order_items" ADD CONSTRAINT "osteq_order_items_orderId_fkey" FOREIGN KEY ("orderId") REFERENCES "osteq_orders"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "osteq_order_items" ADD CONSTRAINT "osteq_order_items_variantId_fkey" FOREIGN KEY ("variantId") REFERENCES "osteq_product_variants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "osteq_quotes" ADD CONSTRAINT "osteq_quotes_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "osteq_customer_profiles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "osteq_quotes" ADD CONSTRAINT "osteq_quotes_convertedOrderId_fkey" FOREIGN KEY ("convertedOrderId") REFERENCES "osteq_orders"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "osteq_quote_items" ADD CONSTRAINT "osteq_quote_items_quoteId_fkey" FOREIGN KEY ("quoteId") REFERENCES "osteq_quotes"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "osteq_quote_items" ADD CONSTRAINT "osteq_quote_items_productVariantId_fkey" FOREIGN KEY ("productVariantId") REFERENCES "osteq_product_variants"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "osteq_quote_messages" ADD CONSTRAINT "osteq_quote_messages_quoteId_fkey" FOREIGN KEY ("quoteId") REFERENCES "osteq_quotes"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "osteq_quote_messages" ADD CONSTRAINT "osteq_quote_messages_authorProfileId_fkey" FOREIGN KEY ("authorProfileId") REFERENCES "staff"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "osteq_quote_messages" ADD CONSTRAINT "osteq_quote_messages_authorCustomerId_fkey" FOREIGN KEY ("authorCustomerId") REFERENCES "osteq_customer_profiles"("id") ON DELETE SET NULL ON UPDATE CASCADE;
