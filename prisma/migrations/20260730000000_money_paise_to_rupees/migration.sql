-- Convert every money column from integer paise to decimal rupees, preserving existing
-- data by dividing in place during the type change (USING clause), rather than
-- drop-and-recreate which would silently zero out every existing price.

ALTER TABLE "osteq_product_variants"
  ALTER COLUMN "retailPriceInPaise" TYPE DECIMAL(10, 2) USING ("retailPriceInPaise"::decimal / 100),
  ALTER COLUMN "tradePriceInPaise" TYPE DECIMAL(10, 2) USING ("tradePriceInPaise"::decimal / 100);
ALTER TABLE "osteq_product_variants" RENAME COLUMN "retailPriceInPaise" TO "retailPriceInRupees";
ALTER TABLE "osteq_product_variants" RENAME COLUMN "tradePriceInPaise" TO "tradePriceInRupees";

ALTER TABLE "osteq_orders"
  ALTER COLUMN "totalInPaise" TYPE DECIMAL(10, 2) USING ("totalInPaise"::decimal / 100);
ALTER TABLE "osteq_orders" RENAME COLUMN "totalInPaise" TO "totalInRupees";

ALTER TABLE "osteq_order_items"
  ALTER COLUMN "unitPriceInPaise" TYPE DECIMAL(10, 2) USING ("unitPriceInPaise"::decimal / 100);
ALTER TABLE "osteq_order_items" RENAME COLUMN "unitPriceInPaise" TO "unitPriceInRupees";

ALTER TABLE "osteq_quote_items"
  ALTER COLUMN "quotedUnitPriceInPaise" TYPE DECIMAL(10, 2) USING ("quotedUnitPriceInPaise"::decimal / 100);
ALTER TABLE "osteq_quote_items" RENAME COLUMN "quotedUnitPriceInPaise" TO "quotedUnitPriceInRupees";
