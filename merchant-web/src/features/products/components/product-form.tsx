"use client";

import { useEffect, useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
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
  const t = useTranslations("products");
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
  const [categoriesError, setCategoriesError] = useState(false);
  const [categoriesNonce, setCategoriesNonce] = useState(0);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    let active = true;
    void (async () => {
      try {
        const cats = await listCategories();
        if (active) {
          setCategories(cats);
          setCategoriesError(false);
        }
      } catch {
        if (active) setCategoriesError(true);
      }
    })();
    return () => {
      active = false;
    };
  }, [categoriesNonce]);

  function validate(): boolean {
    const e: Record<string, string> = {};
    if (!name.trim()) e.name = t("form.errors.nameRequired");
    if (!sku.trim()) e.sku = t("form.errors.skuRequired");
    if (num(mrp) === undefined || num(mrp)! <= 0) e.mrp = t("form.errors.invalidMrp");
    if (num(sellingPrice) === undefined || num(sellingPrice)! <= 0)
      e.sellingPrice = t("form.errors.invalidSellingPrice");
    if (purchasePrice && (num(purchasePrice) === undefined || num(purchasePrice)! < 0))
      e.purchasePrice = t("form.errors.invalidPrice");
    const tax = num(taxPercent);
    if (taxPercent && (tax === undefined || tax < 0 || tax > 100))
      e.taxPercent = t("form.errors.invalidTaxPercent");
    if (!isEdit && stockQuantity && (num(stockQuantity) === undefined || num(stockQuantity)! < 0))
      e.stockQuantity = t("form.errors.negativeStock");
    if (lowStockThreshold && (num(lowStockThreshold) === undefined || num(lowStockThreshold)! < 0))
      e.lowStockThreshold = t("form.errors.negativeThreshold");
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
      setError(e instanceof Error ? e.message : t("form.saveError"));
      setSubmitting(false);
    }
  }

  return (
    <form onSubmit={onSubmit} noValidate className="w-full px-lg py-xxl md:px-xxl">
      <div className="flex flex-wrap items-center justify-between gap-md">
        <h1 className="text-headline-md text-ink">
          {isEdit ? t("form.editTitle") : t("form.newTitle")}
        </h1>
        <div className="flex gap-sm">
          <button
            type="button"
            onClick={() => router.back()}
            className="h-10 rounded-button px-lg text-label-md text-muted hover:text-ink"
          >
            {t("form.cancel")}
          </button>
          <button
            type="submit"
            disabled={submitting}
            className="inline-flex h-10 items-center rounded-button bg-brand px-lg text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:bg-disabled"
          >
            {submitting ? t("form.saving") : isEdit ? t("form.saveChanges") : t("form.createProduct")}
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
            <TextField label={t("form.nameLabel")} value={name} onChange={setName} error={errors.name} />
          </div>
          <TextField label={t("form.skuLabel")} value={sku} onChange={setSku} error={errors.sku} />
          <TextField label={t("form.brandLabel")} value={brand} onChange={setBrand} />
          <TextField label={t("form.barcodeLabel")} value={barcode} onChange={setBarcode} />
          <TextField label={t("form.hsnLabel")} value={hsnCode} onChange={setHsnCode} />
          <div className="sm:col-span-2">
            <TextArea label={t("form.descriptionLabel")} value={description} onChange={setDescription} />
          </div>
        </div>

        {/* Pricing */}
        <div className="mt-lg grid gap-lg sm:grid-cols-3">
          <NumberField label={t("form.mrpLabel")} value={mrp} onChange={setMrp} error={errors.mrp} min={0} step={0.01} />
          <NumberField
            label={t("form.sellingPriceLabel")}
            value={sellingPrice}
            onChange={setSellingPrice}
            error={errors.sellingPrice}
            min={0}
            step={0.01}
          />
          <NumberField
            label={t("form.purchasePriceLabel")}
            value={purchasePrice}
            onChange={setPurchasePrice}
            error={errors.purchasePrice}
            min={0}
            step={0.01}
          />
          <NumberField
            label={t("form.taxPercentLabel")}
            value={taxPercent}
            onChange={setTaxPercent}
            error={errors.taxPercent}
            min={0}
            max={100}
            step={0.01}
          />
          {!isEdit ? (
            <NumberField
              label={t("form.openingStockLabel")}
              value={stockQuantity}
              onChange={setStockQuantity}
              error={errors.stockQuantity}
              min={0}
              step={1}
            />
          ) : null}
          <NumberField
            label={t("form.lowStockThresholdLabel")}
            value={lowStockThreshold}
            onChange={setLowStockThreshold}
            error={errors.lowStockThreshold}
            min={0}
            step={1}
          />
        </div>

        {/* Classification */}
        <div className="mt-lg grid gap-lg sm:grid-cols-2">
          <SelectField
            label={t("form.unitLabel")}
            value={unit}
            onChange={setUnit}
            options={UNITS.map((u) => ({ value: u, label: unitLabel(u) }))}
          />
          <div className="flex flex-col gap-xs">
            <SelectField
              label={t("form.categoryLabel")}
              value={categoryId}
              onChange={setCategoryId}
              options={[
                { value: "", label: t("form.noCategory") },
                ...categories.map((c) => ({ value: String(c.id), label: c.name })),
              ]}
            />
            {categoriesError ? (
              <p className="text-body-sm text-error">
                {t("form.categoriesLoadError")}{" "}
                <button
                  type="button"
                  onClick={() => setCategoriesNonce((n) => n + 1)}
                  className="underline underline-offset-2 hover:text-ink"
                >
                  {t("form.retry")}
                </button>
              </p>
            ) : null}
          </div>
        </div>

        {isEdit ? (
          <div className="mt-lg">
            <CheckboxField
              label={t("form.activeLabel")}
              checked={isActive}
              onChange={setIsActive}
            />
          </div>
        ) : null}

        {/* Images */}
        <div className="mt-xl">
          <FormSection title={t("form.sections.images.title")} description={t("form.sections.images.description")} defaultOpen>
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

          <FormSection title={t("form.sections.tags.title")} description={t("form.sections.tags.description")}>
            <StringListEditor items={tags} onChange={setTags} placeholder={t("form.sections.tags.placeholder")} max={20} />
          </FormSection>

          <FormSection title={t("form.sections.highlights.title")} description={t("form.sections.highlights.description")}>
            <StringListEditor
              items={highlights}
              onChange={setHighlights}
              placeholder={t("form.sections.highlights.placeholder")}
              max={8}
            />
          </FormSection>

          <FormSection title={t("form.sections.specifications.title")} description={t("form.sections.specifications.description")}>
            <SpecsEditor groups={specs} onChange={setSpecs} />
          </FormSection>

          <FormSection title={t("form.sections.offers.title")} description={t("form.sections.offers.description")}>
            <OffersEditor offers={offers} onChange={setOffers} />
          </FormSection>

          <FormSection title={t("form.sections.aplusContent.title")} description={t("form.sections.aplusContent.description")}>
            <ContentBlocksEditor blocks={contentBlocks} onChange={setContentBlocks} />
          </FormSection>

          <FormSection title={t("form.sections.variants.title")} description={t("form.sections.variants.description")}>
            <VariantsEditor
              axes={variantAxes}
              variants={variants}
              onAxes={setVariantAxes}
              onVariants={setVariants}
            />
          </FormSection>

          {isEdit && product ? (
            <FormSection title={t("form.sections.customFields.title")} description={t("form.sections.customFields.description")}>
              <CustomFieldsEditor productId={product.id} />
            </FormSection>
          ) : null}
        </div>
      </div>
    </form>
  );
}
