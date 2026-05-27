import 'package:flutter/material.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

/// Static visual reference page that mirrors the Amazon mobile PDP
/// shown in the research screenshots — used to drive the gap analysis
/// between what merchants can author today and what we'd need to
/// render a full PDP. Lives under Profile → "Amazon PDP — demo" and is
/// intentionally not wired to any backend data; every value below is
/// fixture content so designers/PMs can see the target.
class AmazonPdpDemoPage extends StatefulWidget {
  const AmazonPdpDemoPage({super.key});

  @override
  State<AmazonPdpDemoPage> createState() => _AmazonPdpDemoPageState();
}

class _AmazonPdpDemoPageState extends State<AmazonPdpDemoPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  int _gallery = 0;
  int _variantIdx = 0;

  static const _variants = <_VariantSwatch>[
    _VariantSwatch(label: 'Red', price: 2399, mrp: 9999, inStock: true,
        accent: Color(0xFFD12C2C)),
    _VariantSwatch(label: 'Blue', price: 2399, mrp: 9999, inStock: true,
        accent: Color(0xFF1D4ED8)),
    _VariantSwatch(label: 'Black', price: 2399, mrp: 9999, inStock: true,
        accent: Color(0xFF14181D)),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: const _SearchBar(),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Container(
            color: AppColors.white,
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.black,
              unselectedLabelColor: AppColors.muted,
              indicatorColor: const Color(0xFFE05A2A),
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 14),
              tabs: const [
                Tab(text: 'Details'),
                Tab(text: 'Explore'),
                Tab(text: 'Reviews'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _DetailsTab(
            gallery: _gallery,
            onGallery: (i) => setState(() => _gallery = i),
            variants: _variants,
            variantIdx: _variantIdx,
            onVariant: (i) => setState(() => _variantIdx = i),
          ),
          const _ExploreTab(),
          const _ReviewsTab(),
        ],
      ),
      bottomNavigationBar: const _BottomCtas(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Top: search bar
// ─────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
        decoration: BoxDecoration(
          color: const Color(0xFFF1EFE8),
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          children: const [
            Icon(Icons.search_rounded, size: 18, color: AppColors.muted),
            SizedBox(width: AppSizes.sm),
            Expanded(
              child: Text(
                'Search or ask a question',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
            Icon(Icons.camera_alt_outlined, size: 18, color: AppColors.muted),
            SizedBox(width: AppSizes.md),
            Icon(Icons.mic_none_rounded, size: 18, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Tab 1 — Details (above-the-fold + product description gallery
//  + product details + product specifications + Q&A chips)
// ─────────────────────────────────────────────────────────────────

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({
    required this.gallery,
    required this.onGallery,
    required this.variants,
    required this.variantIdx,
    required this.onVariant,
  });

  final int gallery;
  final ValueChanged<int> onGallery;
  final List<_VariantSwatch> variants;
  final int variantIdx;
  final ValueChanged<int> onVariant;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSizes.huge),
      children: [
        const _BrandHeader(),
        const _Title(),
        const _BadgeRow(),
        _Gallery(index: gallery, onChanged: onGallery),
        _VariantPicker(
          variants: variants,
          selected: variantIdx,
          onSelect: onVariant,
        ),
        const _DescriptionGallery(),
        const SizedBox(height: AppSizes.lg),
        const _SectionTitle('Product details'),
        const _Accordion(
          title: 'Top highlights',
          rows: [
            ('Brand', 'Portronics'),
            ('Compatible Devices', 'Laptop, Smartphone, Tablet'),
            ('Connectivity Technology', 'Bluetooth'),
            ('Keyboard Description', 'Mechanical'),
            ('Recommended Uses For Product', 'Gaming'),
            ('Special Feature',
              'Built in Battery, Dual Wireless Technology, Linear Red '
              'Switches, Multi Device Pairing, Multicolor Back Light'),
          ],
        ),
        const _AboutBullets(items: [
          '[2-WAY CONNECT]: Hydra 10 is made for an experience '
              'without wires that wireless keyboard allows you to '
              'switch seamlessly between three devices over Bluetooth 5.3 '
              'and one over 2.4 GHz dongle.',
          '[RGB BACKLIGHT]: Customisable 16.8 million color modes — work '
              'late, game later. Brightness and effects toggle from the '
              'function row.',
          '[BATTERY]: 4000mAh cell rated for up to two weeks of typing '
              'with the lights off. USB-C charges full in ~90 min.',
        ]),
        const _ChipRow(items: [
          'Can it connect to multiple devices?',
          'Is it compatible with',
          'Does it have backlit keys?',
          'What type of switches does it',
        ]),
        const SizedBox(height: AppSizes.lg),
        const _SectionTitle('Product specifications'),
        const _SpecTabs(),
        const _SpecTable(rows: [
          ('Compatible Devices', 'Laptop, Smartphone, Tablet'),
          ('Connectivity Technology', 'Bluetooth'),
          ('Product Features',
            'Built in Battery, Dual Wireless Technology, Linear Red '
            'Switches, Multi Device Pairing, Multicolor Back Light'),
          ('Keyboard Backlighting Color Support', 'RGB'),
          ('Power Source', 'Battery Powered'),
          ('Switch Type', 'Linear'),
          ('Keyboard Layout', 'QWERTY'),
          ('Hand Orientation', 'Ambidextrous'),
          ('Button Quantity', '68'),
        ]),
        const SizedBox(height: AppSizes.huge),
      ],
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSizes.lg, AppSizes.md, AppSizes.lg, 0),
      child: Row(
        children: [
          Container(
            width: 22, height: 22,
            decoration: const BoxDecoration(
              color: Color(0xFFE05A2A),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text('P',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11)),
          ),
          const SizedBox(width: AppSizes.sm),
          const Text('Portronics',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14, color: AppColors.black)),
          const SizedBox(width: AppSizes.sm),
          const Text('Visit the store',
              style: TextStyle(
                  color: Color(0xFF1D4ED8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          Row(children: const [
            Text('4.2',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13, color: AppColors.black)),
            SizedBox(width: 4),
            Icon(Icons.star, color: Color(0xFFE05A2A), size: 14),
            SizedBox(width: 4),
            Text('(1,493)',
                style: TextStyle(
                    color: Color(0xFF1D4ED8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ]),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(AppSizes.lg, AppSizes.xs, AppSizes.lg, 0),
      child: Text(
        'Portronics Hydra 10 Mechanical Wireless Gaming Keyboard with '
        'Bluetooth 5.0 + 2.4 GHz, RGB Lights 16.8 Million Colors, '
        'Type C Charging, Compatible with PCs, Smartphones and Tablets (Red)',
        style: TextStyle(
          color: AppColors.black,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          height: 1.35,
        ),
      ),
    );
  }
}

class _BadgeRow extends StatelessWidget {
  const _BadgeRow();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSizes.lg, AppSizes.sm, AppSizes.lg, 0),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF14181D),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text(
              "Amazon's Choice",
              style: TextStyle(
                  color: Color(0xFFE05A2A),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2),
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          const Text(
            '200+ bought in past month',
            style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  static const _slides = [
    Color(0xFFEDE7DA),
    Color(0xFFE3E8F4),
    Color(0xFFFAE9CC),
    Color(0xFFE6F2EC),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.sm),
      child: SizedBox(
        height: 280,
        child: Stack(
          children: [
            PageView.builder(
              itemCount: _slides.length,
              onPageChanged: onChanged,
              itemBuilder: (_, i) => Container(
                color: _slides[i],
                alignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 220, height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF14181D),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_alt_outlined,
                      size: 100,
                      color: AppColors.muted,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: AppSizes.lg, top: AppSizes.lg,
              child: Container(
                width: 46, height: 46,
                decoration: const BoxDecoration(
                  color: Color(0xFFE05A2A),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text(
                  '76%\noff',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      height: 1.05),
                ),
              ),
            ),
            Positioned(
              right: AppSizes.lg, bottom: AppSizes.md,
              child: Row(children: const [
                _CircleIconButton(icon: Icons.favorite_border_rounded),
                SizedBox(width: AppSizes.sm),
                _CircleIconButton(icon: Icons.ios_share_outlined),
              ]),
            ),
            Positioned(
              left: 0, right: 0, bottom: AppSizes.md,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _slides.length; i++)
                    Container(
                      width: i == index ? 14 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i == index
                            ? AppColors.black
                            : AppColors.hairline,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36, height: 36,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: Color(0x14000000),
              blurRadius: 4,
              offset: Offset(0, 1)),
        ],
      ),
      child: Icon(icon, size: 16, color: AppColors.black),
    );
  }
}

class _VariantPicker extends StatelessWidget {
  const _VariantPicker({
    required this.variants,
    required this.selected,
    required this.onSelect,
  });
  final List<_VariantSwatch> variants;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final v = variants[selected];
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSizes.lg, AppSizes.lg, AppSizes.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Colour: ',
                  style: TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              Text(v.label,
                  style: const TextStyle(
                      color: AppColors.black,
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: variants.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: AppSizes.sm),
              itemBuilder: (_, i) {
                final isSel = i == selected;
                final vi = variants[i];
                return GestureDetector(
                  onTap: () => onSelect(i),
                  child: Container(
                    width: 110,
                    padding: const EdgeInsets.all(AppSizes.sm),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: isSel
                            ? const Color(0xFFE05A2A)
                            : AppColors.hairline,
                        width: isSel ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: vi.accent.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.keyboard_alt_outlined,
                              color: vi.accent,
                              size: 34,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(vi.label,
                            style: const TextStyle(
                                color: AppColors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                        Row(children: [
                          Text('₹${vi.price}',
                              style: const TextStyle(
                                  color: AppColors.black,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(width: 4),
                          Text('₹${vi.mrp}',
                              style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 10,
                                  decoration: TextDecoration.lineThrough)),
                        ]),
                        Text(
                          vi.inStock ? 'In stock' : 'Out of stock',
                          style: TextStyle(
                              color: vi.inStock
                                  ? AppColors.success
                                  : AppColors.error,
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DescriptionGallery extends StatelessWidget {
  const _DescriptionGallery();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSizes.lg, AppSizes.lg, AppSizes.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Product Description',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.black)),
          SizedBox(height: AppSizes.sm),
          _DescBlock(
            headline: 'HYDRA 10',
            sub: 'Wireless Mechanical Gaming Keyboard',
            bg: Color(0xFF14181D),
            fg: Colors.white,
          ),
          SizedBox(height: AppSizes.sm),
          _DescBlock(
            headline: 'SEAMLESS CONNECTIVITY',
            sub: '2.4GHz + Bluetooth 5.3 — stable wireless across devices',
            bg: Color(0xFF2A3140),
            fg: Colors.white,
          ),
          SizedBox(height: AppSizes.sm),
          _DescBlock(
            headline: 'PRECISION GAMING CONTROL',
            sub: 'Mechanical linear switches tuned for fast actuation',
            bg: Color(0xFF1F232C),
            fg: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _DescBlock extends StatelessWidget {
  const _DescBlock({
    required this.headline,
    required this.sub,
    required this.bg,
    required this.fg,
  });
  final String headline;
  final String sub;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(headline,
              style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  fontSize: 18)),
          const SizedBox(height: 4),
          Text(sub,
              style: TextStyle(
                  color: fg.withValues(alpha: 0.8), fontSize: 12)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSizes.lg, AppSizes.lg, AppSizes.lg, AppSizes.sm),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.hairline)),
        ),
        padding: const EdgeInsets.only(top: AppSizes.md),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppColors.black)),
      ),
    );
  }
}

class _Accordion extends StatefulWidget {
  const _Accordion({required this.title, required this.rows});
  final String title;
  final List<(String, String)> rows;
  @override
  State<_Accordion> createState() => _AccordionState();
}

class _AccordionState extends State<_Accordion> {
  bool _open = true;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14, color: AppColors.black)),
                  ),
                  Icon(
                    _open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            for (final r in widget.rows)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(r.$1,
                          style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                    Expanded(
                      child: Text(r.$2,
                          style: const TextStyle(
                              color: AppColors.black,
                              fontSize: 13,
                              height: 1.35)),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _AboutBullets extends StatelessWidget {
  const _AboutBullets({required this.items});
  final List<String> items;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSizes.lg, AppSizes.sm, AppSizes.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ',
                      style: TextStyle(
                          color: AppColors.black,
                          fontWeight: FontWeight.w800)),
                  Expanded(
                    child: Text(s,
                        style: const TextStyle(
                            color: AppColors.black,
                            fontSize: 12.5,
                            height: 1.4)),
                  ),
                ],
              ),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'See more',
              style: TextStyle(
                  color: Color(0xFF1D4ED8),
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.items});
  final List<String> items;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSizes.lg, 0, AppSizes.lg, 0),
      child: Wrap(
        spacing: AppSizes.sm,
        runSpacing: AppSizes.sm,
        children: [
          for (final s in items)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE3E8F4),
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              ),
              child: Text(s,
                  style: const TextStyle(
                      color: Color(0xFF1D4ED8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

class _SpecTabs extends StatefulWidget {
  const _SpecTabs();
  @override
  State<_SpecTabs> createState() => _SpecTabsState();
}

class _SpecTabsState extends State<_SpecTabs> {
  int _i = 0;
  static const _tabs = [
    'Features & Specs',
    'Item details',
    'Style',
    'Additional',
  ];
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
        scrollDirection: Axis.horizontal,
        itemCount: _tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSizes.sm),
        itemBuilder: (_, i) {
          final sel = i == _i;
          return GestureDetector(
            onTap: () => setState(() => _i = i),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: sel ? Colors.white : AppColors.heroPanel,
                border: Border.all(
                  color: sel ? const Color(0xFF1D4ED8) : AppColors.hairline,
                  width: sel ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              ),
              child: Text(_tabs[i],
                  style: TextStyle(
                      color:
                          sel ? const Color(0xFF1D4ED8) : AppColors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          );
        },
      ),
    );
  }
}

class _SpecTable extends StatelessWidget {
  const _SpecTable({required this.rows});
  final List<(String, String)> rows;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSizes.lg, AppSizes.md, AppSizes.lg, 0),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(rows[i].$1,
                      style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  child: Text(rows[i].$2,
                      style: const TextStyle(
                          color: AppColors.black,
                          fontSize: 13,
                          height: 1.35)),
                ),
              ],
            ),
            if (i != rows.length - 1)
              const Divider(
                  height: AppSizes.lg, color: AppColors.hairline),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Tab 2 — Explore (placeholder — frequently bought / sponsored)
// ─────────────────────────────────────────────────────────────────

class _ExploreTab extends StatelessWidget {
  const _ExploreTab();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.lg),
      children: const [
        _SectionTitle('Frequently bought together'),
        SizedBox(height: AppSizes.sm),
        Text(
          'Cross-sell carousel renders here. Mock surface — kept light '
          'so the gap analysis can focus on Details + Reviews.',
          style: TextStyle(color: AppColors.muted),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Tab 3 — Reviews (rating summary + histogram + sample review)
// ─────────────────────────────────────────────────────────────────

class _ReviewsTab extends StatelessWidget {
  const _ReviewsTab();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.lg),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('4.2',
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: AppColors.black,
                        height: 1)),
                Text('1,493 global ratings',
                    style: TextStyle(
                        color: AppColors.muted, fontSize: 12)),
              ],
            ),
            const SizedBox(width: AppSizes.xl),
            Expanded(
              child: Column(
                children: const [
                  _Hist(label: '5★', value: 0.62),
                  _Hist(label: '4★', value: 0.21),
                  _Hist(label: '3★', value: 0.08),
                  _Hist(label: '2★', value: 0.04),
                  _Hist(label: '1★', value: 0.05),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.lg),
        Container(
          padding: const EdgeInsets.all(AppSizes.md),
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: AppShapes.squircle(AppSizes.radiusMd),
            shadows: const [
              BoxShadow(
                  color: Color(0x10000000),
                  blurRadius: 6,
                  offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Row(children: [
                Icon(Icons.star, color: Color(0xFFE05A2A), size: 14),
                SizedBox(width: 2),
                Icon(Icons.star, color: Color(0xFFE05A2A), size: 14),
                SizedBox(width: 2),
                Icon(Icons.star, color: Color(0xFFE05A2A), size: 14),
                SizedBox(width: 2),
                Icon(Icons.star, color: Color(0xFFE05A2A), size: 14),
                SizedBox(width: 2),
                Icon(Icons.star, color: Color(0xFFE05A2A), size: 14),
                SizedBox(width: 8),
                Text('Crisp typing, lovely RGB',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.black)),
              ]),
              SizedBox(height: 6),
              Text(
                'Switches feel light and consistent. Battery life looks '
                'solid through the first week. Pairing across three '
                'devices is genuinely useful.',
                style: TextStyle(color: AppColors.black, fontSize: 13),
              ),
              SizedBox(height: 6),
              Text('Aman · Verified purchase',
                  style: TextStyle(color: AppColors.muted, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Hist extends StatelessWidget {
  const _Hist({required this.label, required this.value});
  final String label;
  final double value;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
              width: 26,
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: AppColors.heroPanel,
                valueColor: const AlwaysStoppedAnimation(
                    Color(0xFFE05A2A)),
              ),
            ),
          ),
          SizedBox(
              width: 36,
              child: Text(
                '${(value * 100).round()}%',
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Bottom bar — yellow Amazon-style CTA
// ─────────────────────────────────────────────────────────────────

class _BottomCtas extends StatelessWidget {
  const _BottomCtas();
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: SizedBox(
            height: 48,
            child: Material(
              color: const Color(0xFFFFCE36),
              shape: AppShapes.squircle(AppSizes.radiusFull),
              child: InkWell(
                customBorder: AppShapes.squircle(AppSizes.radiusFull),
                onTap: () {},
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Add to Cart',
                      style: TextStyle(
                          color: AppColors.black,
                          fontWeight: FontWeight.w800,
                          fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────────────────────────

class _VariantSwatch {
  const _VariantSwatch({
    required this.label,
    required this.price,
    required this.mrp,
    required this.inStock,
    required this.accent,
  });
  final String label;
  final int price;
  final int mrp;
  final bool inStock;
  final Color accent;
}
