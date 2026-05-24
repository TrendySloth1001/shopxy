-- ─────────────────────────────────────────────────────────────────────
-- Categories: collapse legacy merchant-created rows onto the canonical
-- taxonomy that's seeded from `catalog.seed.ts`. Two passes:
--
--   1. Remap product.category_id from the four real legacy categories
--      (Controllers / Accessories / Cables / Electronic) onto the
--      closest canonical slug. Pure UPDATE — no rows lost.
--   2. Delete every category that's not referenced by any product and
--      not in the canonical seed list. Captures both the `I-*` test
--      noise and any half-formed merchant rows. Canonical rows are
--      identified by slug membership so a future manifest tweak
--      automatically protects new entries.

DO $$
DECLARE
  ctrl_id INT;
  acc_id INT;
  cab_id INT;
  elec_id INT;
BEGIN
  SELECT id INTO ctrl_id FROM categories WHERE slug = 'controllers';
  SELECT id INTO acc_id  FROM categories WHERE slug = 'gaming-accessories';
  SELECT id INTO cab_id  FROM categories WHERE slug = 'chargers-and-cables';
  SELECT id INTO elec_id FROM categories WHERE slug = 'electronics';

  -- Existing "Controllers" (legacy id=1) → canonical gaming controllers.
  IF ctrl_id IS NOT NULL THEN
    UPDATE products SET category_id = ctrl_id WHERE category_id IN (
      SELECT id FROM categories WHERE name = 'Controllers' AND id <> ctrl_id
    );
  END IF;

  -- "Accessories" was the catch-all merchant tag — most often phone /
  -- gaming peripherals in this dataset. Bucket to gaming-accessories;
  -- a follow-up admin pass can refine per product if needed.
  IF acc_id IS NOT NULL THEN
    UPDATE products SET category_id = acc_id WHERE category_id IN (
      SELECT id FROM categories WHERE name = 'Accessories' AND id <> acc_id
    );
  END IF;

  IF cab_id IS NOT NULL THEN
    UPDATE products SET category_id = cab_id WHERE category_id IN (
      SELECT id FROM categories WHERE name = 'Cables' AND id <> cab_id
    );
  END IF;

  IF elec_id IS NOT NULL THEN
    UPDATE products SET category_id = elec_id WHERE category_id IN (
      SELECT id FROM categories WHERE name = 'Electronic' AND id <> elec_id
    );
  END IF;
END $$;

-- Drop every category that (a) isn't in the canonical seed and (b)
-- isn't referenced by any product. The canonical set is recognised by
-- the curated slug list — anything else is fair game. Self-referential
-- parents on the doomed rows are nulled first to avoid FK violations.
WITH canonical_slugs AS (
  SELECT unnest(ARRAY[
    'mobiles-and-accessories','smartphones','wearables','cases-and-covers','chargers-and-cables','power-banks',
    'electronics','laptops','tablets','cameras','headphones','speakers',
    'fashion-men','mens-tshirts-shirts','mens-jeans-trousers','mens-footwear','mens-watches','mens-accessories',
    'fashion-women','womens-ethnic-wear','womens-tops-dresses','womens-footwear','womens-jewellery','womens-handbags',
    'beauty-and-personal-care','skincare','makeup','haircare','fragrances','mens-grooming',
    'home-and-kitchen','cookware','dinnerware','furniture','bedding','decor',
    'appliances','refrigerators','washing-machines','air-conditioners','microwaves','small-appliances',
    'grocery','fruits-and-vegetables','snacks','beverages','dairy-and-bakery','staples',
    'toys-and-baby','toys','baby-care','strollers-and-gear','diapers','feeding',
    'sports-and-fitness','gym-equipment','yoga','cycling','outdoor','sportswear',
    'books-and-stationery','fiction','non-fiction','textbooks','office-supplies','art-supplies',
    'pets','dog-food','cat-food','pet-toys','pet-accessories','pet-health',
    'automotive','car-accessories','bike-accessories','lubricants','auto-tools','tyres',
    'health-and-wellness','vitamins-and-supplements','ayurveda','medical-devices','first-aid','personal-hygiene',
    'gaming','consoles','video-games','gaming-accessories','pc-gaming','controllers',
    'office-and-industrial','office-furniture','printers-and-ink','industrial-tools','safety-gear','industrial-supplies'
  ]) AS slug
),
doomed AS (
  SELECT c.id FROM categories c
   WHERE c.slug NOT IN (SELECT slug FROM canonical_slugs)
     AND NOT EXISTS (SELECT 1 FROM products p WHERE p.category_id = c.id)
)
UPDATE categories SET parent_id = NULL
  WHERE parent_id IN (SELECT id FROM doomed) OR id IN (SELECT id FROM doomed);

DELETE FROM categories
  WHERE slug NOT IN (
    SELECT unnest(ARRAY[
      'mobiles-and-accessories','smartphones','wearables','cases-and-covers','chargers-and-cables','power-banks',
      'electronics','laptops','tablets','cameras','headphones','speakers',
      'fashion-men','mens-tshirts-shirts','mens-jeans-trousers','mens-footwear','mens-watches','mens-accessories',
      'fashion-women','womens-ethnic-wear','womens-tops-dresses','womens-footwear','womens-jewellery','womens-handbags',
      'beauty-and-personal-care','skincare','makeup','haircare','fragrances','mens-grooming',
      'home-and-kitchen','cookware','dinnerware','furniture','bedding','decor',
      'appliances','refrigerators','washing-machines','air-conditioners','microwaves','small-appliances',
      'grocery','fruits-and-vegetables','snacks','beverages','dairy-and-bakery','staples',
      'toys-and-baby','toys','baby-care','strollers-and-gear','diapers','feeding',
      'sports-and-fitness','gym-equipment','yoga','cycling','outdoor','sportswear',
      'books-and-stationery','fiction','non-fiction','textbooks','office-supplies','art-supplies',
      'pets','dog-food','cat-food','pet-toys','pet-accessories','pet-health',
      'automotive','car-accessories','bike-accessories','lubricants','auto-tools','tyres',
      'health-and-wellness','vitamins-and-supplements','ayurveda','medical-devices','first-aid','personal-hygiene',
      'gaming','consoles','video-games','gaming-accessories','pc-gaming','controllers',
      'office-and-industrial','office-furniture','printers-and-ink','industrial-tools','safety-gear','industrial-supplies'
    ])
  )
  AND NOT EXISTS (SELECT 1 FROM products p WHERE p.category_id = categories.id);
