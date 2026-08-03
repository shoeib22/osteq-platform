-- AlterTable
ALTER TABLE "osteq_trade_applications" ADD COLUMN     "addressId" TEXT;

-- CreateTable
CREATE TABLE "osteq_addresses" (
    "id" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,
    "label" TEXT NOT NULL,
    "line1" TEXT NOT NULL,
    "line2" TEXT,
    "city" TEXT NOT NULL,
    "state" TEXT NOT NULL,
    "postalCode" TEXT NOT NULL,
    "country" TEXT NOT NULL DEFAULT 'India',
    "phone" TEXT,
    "isDefault" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "osteq_addresses_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "osteq_addresses_customerId_idx" ON "osteq_addresses"("customerId");

-- AddForeignKey
ALTER TABLE "osteq_addresses" ADD CONSTRAINT "osteq_addresses_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "osteq_customer_profiles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "osteq_trade_applications" ADD CONSTRAINT "osteq_trade_applications_addressId_fkey" FOREIGN KEY ("addressId") REFERENCES "osteq_addresses"("id") ON DELETE SET NULL ON UPDATE CASCADE;
