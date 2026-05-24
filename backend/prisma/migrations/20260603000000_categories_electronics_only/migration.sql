-- ─────────────────────────────────────────────────────────────────────
-- Taxonomy pivot: pare the canonical list to electronics-only.
--
-- Drop every category whose slug isn't in the new electronics manifest
-- AND isn't referenced by any product. Self-referential parents on
-- doomed rows are nulled first to avoid FK violations. The seed runs
-- next on boot and re-derives any parent links the new manifest needs.
--
-- The three currently-populated slugs (controllers, gaming-accessories,
-- chargers-and-cables) are part of the new manifest, so the live
-- products aren't disturbed.

WITH new_slugs AS (
  SELECT unnest(ARRAY[
    'laptops-and-computers','laptops','desktops','monitors','storage-drives','laptop-accessories',
    'mobile-phones','smartphones','phone-cases','screen-protectors','phone-holders',
    'audio','headphones','earbuds','bluetooth-speakers','soundbars','microphones',
    'wearables','smartwatches','fitness-bands','watch-straps',
    'cameras','dslr-mirrorless','action-cameras','camera-lenses','tripods','camera-accessories',
    'gaming','consoles','controllers','video-games','pc-gaming','gaming-accessories',
    'peripherals','keyboards','mice','webcams','drawing-tablets','usb-hubs',
    'tv-and-streaming','smart-tvs','streaming-devices','projectors','remote-controls',
    'smart-home','routers','smart-speakers','security-cameras','smart-lights','smart-plugs',
    'power-and-charging','power-banks','wall-chargers','chargers-and-cables','wireless-chargers','ups-and-surge',
    'tablets-and-ereaders','tablets','tablet-cases','ereaders','stylus-pens',
    'drones-and-rc','drones','rc-vehicles','drone-accessories'
  ]) AS slug
),
doomed AS (
  SELECT c.id
    FROM categories c
   WHERE c.slug NOT IN (SELECT slug FROM new_slugs)
     AND NOT EXISTS (SELECT 1 FROM products p WHERE p.category_id = c.id)
)
UPDATE categories SET parent_id = NULL
  WHERE parent_id IN (SELECT id FROM doomed) OR id IN (SELECT id FROM doomed);

DELETE FROM categories
  WHERE slug NOT IN (
    SELECT unnest(ARRAY[
      'laptops-and-computers','laptops','desktops','monitors','storage-drives','laptop-accessories',
      'mobile-phones','smartphones','phone-cases','screen-protectors','phone-holders',
      'audio','headphones','earbuds','bluetooth-speakers','soundbars','microphones',
      'wearables','smartwatches','fitness-bands','watch-straps',
      'cameras','dslr-mirrorless','action-cameras','camera-lenses','tripods','camera-accessories',
      'gaming','consoles','controllers','video-games','pc-gaming','gaming-accessories',
      'peripherals','keyboards','mice','webcams','drawing-tablets','usb-hubs',
      'tv-and-streaming','smart-tvs','streaming-devices','projectors','remote-controls',
      'smart-home','routers','smart-speakers','security-cameras','smart-lights','smart-plugs',
      'power-and-charging','power-banks','wall-chargers','chargers-and-cables','wireless-chargers','ups-and-surge',
      'tablets-and-ereaders','tablets','tablet-cases','ereaders','stylus-pens',
      'drones-and-rc','drones','rc-vehicles','drone-accessories'
    ])
  )
  AND NOT EXISTS (SELECT 1 FROM products p WHERE p.category_id = categories.id);
