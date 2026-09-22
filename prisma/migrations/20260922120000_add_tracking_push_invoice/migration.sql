-- AlterEnum
ALTER TYPE "OsteqOrderStatus" RENAME VALUE 'SHIPPED' TO 'OUT_FOR_DELIVERY';

-- AlterTable
ALTER TABLE "osteq_orders" ADD COLUMN     "trackingUrl" TEXT,
ADD COLUMN     "invoicePdfPath" TEXT;

-- AlterTable
ALTER TABLE "osteq_customer_profiles" ADD COLUMN     "fcmToken" TEXT;
