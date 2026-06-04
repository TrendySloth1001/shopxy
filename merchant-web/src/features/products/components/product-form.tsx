"use client";

import { useEffect, useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import {
  createProduct,
  listCategories,
  updateProduct,
  type ProductWritePayload,
} from "../api";
import type {
  Category,
  Product,
  ProductOffer,
  ProductVariant,
  SpecGroup,
  VariantAxis,
} from "../schema";
import { UNITS, unitLabel } from "../units";
import {
  CheckboxField,
  FormSection,
  NumberField,
  SelectField,
  TextArea,
  TextField,
} from "./form-controls";
import { ImageManager } from "./image-manager";
import { StringListEditor } from "./string-list-editor";
import { SpecsEditor } from "./specs-editor";
import { OffersEditor } from "./offers-editor";
import { ContentBlocksEditor, type Block } from "./content-blocks-editor";
import { VariantsEditor } from "./variants-editor";
import { CustomFieldsEditor } from "./custom-fields-editor";

/** Keep only content blocks that satisfy the backend's per-kind requirements. */
function cleanBlocks(blocks: Block[]): Block[] {
  const out: Block[] = [];
  for (const b of blocks) {
    if (b.kind === "HERO" && b.imageUrl && b.headline) out.push(b);
    else if (b.kind === "FEATURE" && b.imageUrl && b.title && b.body) out.push(b);
    else if (b.kind === "TEXT" && b.markdown) out.push(b);
    else if (b.kind === "GALLERY") {
      const images = ((b.images as Array<{ url: string; caption?: string }>) ?? [])
        .filter((x) => x?.url)
        .map((x) => ({ url: x.url, ...(x.caption ? { caption: x.caption } : {}) }));
      if (images.length > 0) out.push({ ...b, images });
    } else if (b.kind === "COMPARISON") {
      const columns = ((b.columns as Array<{ label: string; values: string[] }>) ?? [])
        .map((c) => ({ label: c.label, values: (c.values ?? []).filter(Boolean) }))
        .filter((c) => c.label && c.values.length > 0);
      const rows = ((b.rows as string[]) ?? []).filter(Boolean);
      if (columns.length >= 2 && rows.length > 0) out.push({ ...b, columns, rows });
    }
  }
  return out;
}

function num(s: string): number | undefined {
  const n = Number.parseFloat(s);
  return Number.isFinite(n) ? n : undefined;
}

export function ProductForm({ product }: { product?: Product }) {
  const router = useRouter();
  const isEdit = Boolean(product);

  const [name, setName] = useState(product?.name ?? "");
  const [sku, setSku] = useState(product?.sku ?? "");
  const [description, setDescription] = useState(product?.description ?? "");
  const [brand, setBrand] = useState(product?.brand ?? "");
  const [barcode, setBarcode] = useState(product?.barcode ?? "");
  const [hsnCode, setHsnCode] = useState(product?.hsnCode ?? "");
  const [mrp, setMrp] = useState(product ? String(product.mrp) : "");
  const [sellingPrice, setSellingPrice] = useState(
    product ? String(product.sellingPrice) : "",
  );
  const [purchasePrice, setPurchasePrice] = useState(
    product ? String(product.purchasePrice) : "",
  );
  const [taxPercent, setTaxPercent] = useState(
    product ? String(product.taxPercent) : "0",
  );
  const [stockQuantity, setStockQuantity] = useState("0");
  const [lowStockThreshold, setLowStockThreshold] = useState(
    product ? String(product.lowStockThreshold) : "0",
  );
  const [unit, setUnit] = useState(product?.unit ?? "PCS");
  const [categoryId, setCategoryId] = useState(
    product?.categoryId ? String(product.categoryId) : "",
  );
  const [isActive, setIsActive] = useState(product?.isActive ?? true);
  const [tags, setTags] = useState<string[]>(product?.tags ?? []);
  const [highlights, setHighlights] = useState<string[]>(product?.highlights ?? []);
  const [specs, setSpecs] = useState<SpecGroup[]>(product?.specs ?? []);
  const [offers, setOffers] = useState<ProductOffer[]>(product?.offers ?? []);
  const [contentBlocks, setContentBlocks] = useState<Block[]>(
    (product?.contentBlocks ?? []) as Block[],
  );
  const [variantAxes, setVariantAxes] = useState<VariantAxis[]>(
    product?.variantAxes ?? [],
  );
  const [variants, setVariants] = useState<ProductVariant[]>(
    product && product.variantAxes.length > 0 ? product.variants : [],
  );
  const [imageUrls, setImageUrls] = useState<string[]>(
    product ? product.images.map((i) => i.url) : [],
  );

  const [categories, setCategories] = useState<Category[]>([]);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    let active = true;
    void (async () => {
      try {
        const cats = await listCategories();
        if (active) setCategories(cats);
      } catch {
        /* select just won't populate */
      }
    })();
    return () => {
      active = false;
    };
  }, []);

  function validate(): boolean {
    const e: Record<string, string> = {};
    if (!name.trim()) e.name = "Name is required";
    if (!sku.trim()) e.sku = "SKU is required";
    if (num(mrp) === undefined || num(mrp)! <= 0) e.mrp = "Enter a valid MRP";
    if (num(sellingPrice) === undefined || num(sellingPrice)! <= 0)
      e.sellingPrice = "Enter a valid selling price";
    if (purchasePrice && num(purchasePrice) === undefined)
      e.purchasePrice = "Enter a valid price";
    setErrors(e);
    return Object.keys(e).length === 0;
  }

  function buildPayload(): ProductWritePayload {
    const cleanTags = tags.map((t) => t.trim()).filter(Boolean);
    const cleanHighlights = highlights.map((h) => h.trim()).filter(Boolean);
    const cleanSpecs = specs
      .map((g) => ({
        title: g.title.trim(),
        ...(g.tab?.trim() ? { tab: g.tab.trim() } : {}),
        rows: g.rows
          .filter((r) => r.label.trim() && r.value.trim())
          .map((r) => ({ label: r.label.trim(), value: r.value.trim() })),
      }))
      .filter((g) => g.title && g.rows.length > 0);
    const cleanOffers = offers
      .map((o) => ({
        kind: o.kind,
        headline: o.headline.trim(),
        ...(o.detail?.trim() ? { detail: o.detail.trim() } : {}),
        ...(o.code?.trim() ? { code: o.code.trim() } : {}),
      }))
      .filter((o) => o.headline);
    const catNum = categoryId ? Number(categoryId) : undefined;

    const base: ProductWritePayload = {
      name: name.trim(),
      sku: sku.trim(),
      mrp: num(mrp),
      sellingPrice: num(sellingPrice),
      purchasePrice: num(purchasePrice) ?? 0,
      taxPercent: num(taxPercent) ?? 0,
      lowStockThreshold: num(lowStockThreshold) ?? 0,
      unit,
      tags: cleanTags,
      highlights: cleanHighlights,
      specs: cleanSpecs,
      offers: cleanOffers,
      contentBlocks: cleanBlocks(contentBlocks),
    };

    // Only touch variant data when axes are defined — otherwise we'd wipe the
    // backend's implicit default variant.
    const namedAxes = variantAxes
      .map((a) => ({
        name: a.name.trim(),
        values: a.values.map((v) => v.trim()).filter(Boolean),
      }))
      .filter((a) => a.name && a.values.length > 0);
    if (namedAxes.length > 0) {
      base.variantAxes = namedAxes;
      base.variants = variants
        .filter((v) => v.sku.trim() && v.mrp > 0 && v.sellingPrice > 0)
        .map((v) => ({
          ...(v.id ? { id: v.id } : {}),
          sku: v.sku.trim(),
          ...(v.barcode ? { barcode: v.barcode } : {}),
          attributes: v.attributes,
          mrp: v.mrp,
          sellingPrice: v.sellingPrice,
          purchasePrice: v.purchasePrice,
          stockQuantity: v.stockQuantity,
          isActive: v.isActive,
          sortOrder: v.sortOrder,
        }));
    }

    if (isEdit) {
      // Send nullable string fields as value-or-null so they can be cleared.
      base.description = description.trim() || null;
      base.brand = brand.trim() || null;
      base.barcode = barcode.trim() || null;
      base.hsnCode = hsnCode.trim() || null;
      base.categoryId = catNum ?? null;
      base.isActive = isActive;
    } else {
      if (description.trim()) base.description = description.trim();
      if (brand.trim()) base.brand = brand.trim();
      if (barcode.trim()) base.barcode = barcode.trim();
      if (hsnCode.trim()) base.hsnCode = hsnCode.trim();
      if (catNum) base.categoryId = catNum;
      base.stockQuantity = num(stockQuantity) ?? 0;
      if (imageUrls.length > 0) base.imageUrls = imageUrls;
    }
    return base;
  }

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    if (!validate()) return;
    setSubmitting(true);
    try {
      const payload = buildPayload();
      const saved = isEdit
        ? await updateProduct(product!.id, payload)
        : await createProduct(payload);
      router.replace(`/dashboard/products/${saved.id}`);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not save the product.");
      setSubmitting(false);
    }
  }

  return (
    <form onSubmit={onSubmit} noValidate className="w-full px-lg py-xxl md:px-xxl">
      <div className="flex flex-wrap items-center justify-between gap-md">
        <h1 className="text-headline-md text-ink">
          {isEdit ? "Edit product" : "New product"}
        </h1>
        <div className="flex gap-sm">
          <button
            type="button"
            onClick={() => router.back()}
            className="h-10 rounded-button px-lg text-label-md text-muted hover:text-ink"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={submitting}
            className="inline-flex h-10 items-center rounded-button bg-brand px-lg text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:bg-disabled"
          >
            {submitting ? "Saving…" : isEdit ? "Save changes" : "Create product"}
          </button>
        </div>
      </div>

      {error ? (
        <p className="mt-md rounded-md border border-error bg-error-soft px-md py-sm text-body-sm text-error">
          {error}
        </p>
      ) : null}

      <div className="mt-xl max-w-content">
        {/* Core */}
        <div className="grid gap-lg sm:grid-cols-2">
          <div className="sm:col-span-2">
            <TextField label="Name" value={name} onChange={setName} error={errors.name} />
          </div>
          <TextField label="SKU" value={sku} onChange={setSku} error={errors.sku} />
          <TextField label="Brand" value={brand} onChange={setBrand} />
          <TextField label="Barcode" value={barcode} onChange={setBarcode} />
          <TextField label="HSN code" value={hsnCode} onChange={setHsnCode} />
          <div className="sm:col-span-2">
            <TextArea label="Description" value={description} onChange={setDescription} />
          </div>
        </div>

        {/* Pricing */}
        <div className="mt-lg grid gap-lg sm:grid-cols-3">
          <NumberField label="MRP" value={mrp} onChange={setMrp} error={errors.mrp} />
          <NumberField
            label="Selling price"
            value={sellingPrice}
            onChange={setSellingPrice}
            error={errors.sellingPrice}
          />
          <NumberField
            label="Purchase price"
            value={purchasePrice}
            onChange={setPurchasePrice}
            error={errors.purchasePrice}
          />
          <NumberField label="Tax %" value={taxPercent} onChange={setTaxPercent} />
          {!isEdit ? (
            <NumberField
              label="Opening stock"
              value={stockQuantity}
              onChange={setStockQuantity}
            />
          ) : null}
          <NumberField
            label="Low-stock threshold"
            value={lowStockThreshold}
            onChange={setLowStockThreshold}
          />
        </div>

        {/* Classification */}
        <div className="mt-lg grid gap-lg sm:grid-cols-2">
          <SelectField
            label="Unit"
            value={unit}
            onChange={setUnit}
            options={UNITS.map((u) => ({ value: u, label: unitLabel(u) }))}
          />
          <SelectField
            label="Category"
            value={categoryId}
            onChange={setCategoryId}
            options={[
              { value: "", label: "No category" },
              ...categories.map((c) => ({ value: String(c.id), label: c.name })),
            ]}
          />
        </div>

        {isEdit ? (
          <div className="mt-lg">
            <CheckboxField
              label="Active (visible in your catalogue)"
              checked={isActive}
              onChange={setIsActive}
            />
          </div>
        ) : null}

        {/* Images */}
        <div className="mt-xl">
          <FormSection title="Images" description="Add up to 10 photos." defaultOpen>
            <ImageManager
              productId={product?.id}
              initial={
                product
                  ? product.images.map((i) => ({ id: i.id, url: i.url }))
                  : []
              }
              onChange={isEdit ? undefined : setImageUrls}
            />
          </FormSection>

          <FormSection title="Tags" description="Keywords for search and badges.">
            <StringListEditor items={tags} onChange={setTags} placeholder="e.g. Bestseller" max={20} />
          </FormSection>

          <FormSection title="Highlights" description="Short selling points on the product page.">
            <StringListEditor
              items={highlights}
              onChange={setHighlights}
              placeholder="e.g. 12-month warranty"
              max={8}
            />
          </FormSection>

          <FormSection title="Specifications" description="Grouped spec sheet for the product page.">
            <SpecsEditor groups={specs} onChange={setSpecs} />
          </FormSection>

          <FormSection title="Offers" description="Bank / coupon / EMI / exchange offers.">
            <OffersEditor offers={offers} onChange={setOffers} />
          </FormSection>

          <FormSection title="A+ content" description="Rich content blocks on the product page (max 8).">
            <ContentBlocksEditor blocks={contentBlocks} onChange={setContentBlocks} />
          </FormSection>

          <FormSection title="Variants" description="Sell colour/size options under one product.">
            <VariantsEditor
              axes={variantAxes}
              variants={variants}
              onAxes={setVariantAxes}
              onVariants={setVariants}
            />
          </FormSection>

          {isEdit && product ? (
            <FormSection title="Custom fields" description="Your shop-defined fields for this product.">
              <CustomFieldsEditor productId={product.id} />
            </FormSection>
          ) : null}
        </div>
      </div>
    </form>
  );
}
