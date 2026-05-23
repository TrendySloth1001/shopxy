-- Purchase requests: customer-app orders. A customer browses the
-- merchant catalog, submits a cart, and the merchant either confirms
-- (which materialises a SALE invoice) or rejects.
CREATE TABLE "purchase_requests" (
  "id"                SERIAL              PRIMARY KEY,
  "customer_user_id"  INTEGER             NOT NULL,
  "party_id"          INTEGER,
  "customer_name"     TEXT                NOT NULL,
  "customer_phone"    TEXT,
  "customer_email"    TEXT,
  "customer_address"  TEXT,
  "status"            TEXT                NOT NULL DEFAULT 'PENDING',
  "invoice_id"        INTEGER,
  "decided_by_id"     INTEGER,
  "decided_at"        TIMESTAMP(3),
  "decision_note"     TEXT,
  "note"              TEXT,
  "estimated_total"   DECIMAL(12,2)       NOT NULL DEFAULT 0,
  "created_at"        TIMESTAMP(3)        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at"        TIMESTAMP(3)        NOT NULL,

  CONSTRAINT "purchase_requests_customer_user_fk"
    FOREIGN KEY ("customer_user_id") REFERENCES "users"("id")     ON DELETE CASCADE,
  CONSTRAINT "purchase_requests_party_fk"
    FOREIGN KEY ("party_id")         REFERENCES "parties"("id")   ON DELETE SET NULL,
  CONSTRAINT "purchase_requests_invoice_fk"
    FOREIGN KEY ("invoice_id")       REFERENCES "invoices"("id")  ON DELETE SET NULL,
  CONSTRAINT "purchase_requests_decided_by_fk"
    FOREIGN KEY ("decided_by_id")    REFERENCES "users"("id")     ON DELETE SET NULL
);

CREATE UNIQUE INDEX "purchase_requests_invoice_id_key"
  ON "purchase_requests"("invoice_id");
CREATE INDEX "purchase_requests_customer_user_id_created_at_idx"
  ON "purchase_requests"("customer_user_id", "created_at");
CREATE INDEX "purchase_requests_status_created_at_idx"
  ON "purchase_requests"("status", "created_at");
CREATE INDEX "purchase_requests_party_id_idx"
  ON "purchase_requests"("party_id");

CREATE TABLE "purchase_request_items" (
  "id"            SERIAL          PRIMARY KEY,
  "request_id"    INTEGER         NOT NULL,
  "product_id"    INTEGER         NOT NULL,
  "product_name"  TEXT            NOT NULL,
  "product_sku"   TEXT            NOT NULL,
  "unit"          TEXT            NOT NULL DEFAULT 'PCS',
  "quantity"      DECIMAL(12,3)   NOT NULL,
  "unit_price"    DECIMAL(12,2)   NOT NULL,
  "total"         DECIMAL(12,2)   NOT NULL,

  CONSTRAINT "purchase_request_items_request_fk"
    FOREIGN KEY ("request_id") REFERENCES "purchase_requests"("id") ON DELETE CASCADE,
  CONSTRAINT "purchase_request_items_product_fk"
    FOREIGN KEY ("product_id") REFERENCES "products"("id")          ON DELETE RESTRICT
);

CREATE INDEX "purchase_request_items_request_id_idx"
  ON "purchase_request_items"("request_id");
CREATE INDEX "purchase_request_items_product_id_idx"
  ON "purchase_request_items"("product_id");
