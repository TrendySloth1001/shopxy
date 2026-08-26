export interface CategorySeed {
  slug: string;
  name: string;
  iconName: string;
  imageUrl: string;
  children?: Array<Omit<CategorySeed, 'children'>>;
}

const u = (id: string): string =>
  `https://images.unsplash.com/${id}?w=600&h=600&fit=crop&auto=format&q=70`;

export const CANONICAL_CATEGORIES: CategorySeed[] = [
  {
    slug: 'laptops-and-computers',
    name: 'Laptops & Computers',
    iconName: 'laptop_mac',
    imageUrl: u('photo-1496181133206-80ce9b88a853'),
    children: [
      { slug: 'laptops', name: 'Laptops', iconName: 'laptop_mac', imageUrl: u('photo-1517336714731-489689fd1ca8') },
      { slug: 'desktops', name: 'Desktops & All-in-Ones', iconName: 'desktop_windows', imageUrl: u('photo-1587202372775-e229f172b9d7') },
      { slug: 'monitors', name: 'Monitors', iconName: 'monitor', imageUrl: u('photo-1527443224154-c4a3942d3acf') },
      { slug: 'storage-drives', name: 'SSDs & Hard Drives', iconName: 'storage', imageUrl: u('photo-1531492746076-161ca9bcad58') },
      { slug: 'laptop-accessories', name: 'Laptop Accessories', iconName: 'cable', imageUrl: u('photo-1625948515291-69613efd103f') },
    ],
  },
  {
    slug: 'mobile-phones',
    name: 'Mobile Phones',
    iconName: 'smartphone',
    imageUrl: u('photo-1511707171634-5f897ff02aa9'),
    children: [
      { slug: 'smartphones', name: 'Smartphones', iconName: 'smartphone', imageUrl: u('photo-1592750475338-74b7b21085ab') },
      { slug: 'phone-cases', name: 'Cases & Covers', iconName: 'phonelink_ring', imageUrl: u('photo-1601784551446-20c9e07cdbdb') },
      { slug: 'screen-protectors', name: 'Screen Protectors', iconName: 'shield', imageUrl: u('photo-1565849904461-04a58ad377e0') },
      { slug: 'phone-holders', name: 'Phone Holders & Mounts', iconName: 'phone_iphone', imageUrl: u('photo-1574944985070-8f3ebc6b79d2') },
    ],
  },
  {
    slug: 'audio',
    name: 'Audio',
    iconName: 'headphones',
    imageUrl: u('photo-1505740420928-5e560c06d30e'),
    children: [
      { slug: 'headphones', name: 'Headphones', iconName: 'headphones', imageUrl: u('photo-1583394838336-acd977736f90') },
      { slug: 'earbuds', name: 'Earbuds & In-Ear', iconName: 'earbuds', imageUrl: u('photo-1606220588913-b3aacb4d2f46') },
      { slug: 'bluetooth-speakers', name: 'Bluetooth Speakers', iconName: 'speaker', imageUrl: u('photo-1545454675-3531b543be5d') },
      { slug: 'soundbars', name: 'Soundbars', iconName: 'speaker_group', imageUrl: u('photo-1558379850-2b9bb7e7f59f') },
      { slug: 'microphones', name: 'Microphones', iconName: 'mic', imageUrl: u('photo-1590602847861-f357a9332bbc') },
    ],
  },
  {
    slug: 'wearables',
    name: 'Wearables',
    iconName: 'watch',
    imageUrl: u('photo-1523275335684-37898b6baf30'),
    children: [
      { slug: 'smartwatches', name: 'Smartwatches', iconName: 'watch', imageUrl: u('photo-1546868871-7041f2a55e12') },
      { slug: 'fitness-bands', name: 'Fitness Bands', iconName: 'fitness_center', imageUrl: u('photo-1557935728-e6d1eaabe558') },
      { slug: 'watch-straps', name: 'Watch Straps', iconName: 'watch_later', imageUrl: u('photo-1524805444758-089113d48a6d') },
    ],
  },
  {
    slug: 'cameras',
    name: 'Cameras & Photography',
    iconName: 'photo_camera',
    imageUrl: u('photo-1502920917128-1aa500764cbd'),
    children: [
      { slug: 'dslr-mirrorless', name: 'DSLR & Mirrorless', iconName: 'photo_camera', imageUrl: u('photo-1519183071298-a2962feb14f4') },
      { slug: 'action-cameras', name: 'Action Cameras', iconName: 'videocam', imageUrl: u('photo-1606986628253-49a3933c6b27') },
      { slug: 'camera-lenses', name: 'Lenses', iconName: 'camera', imageUrl: u('photo-1495707902641-75cac588d2e9') },
      { slug: 'tripods', name: 'Tripods & Gimbals', iconName: 'videocam', imageUrl: u('photo-1610126443240-95d40f5b8167') },
      { slug: 'camera-accessories', name: 'Camera Accessories', iconName: 'sd_card', imageUrl: u('photo-1500634245200-e5245c7574ef') },
    ],
  },
  {
    slug: 'gaming',
    name: 'Gaming',
    iconName: 'sports_esports',
    imageUrl: u('photo-1542751371-adc38448a05e'),
    children: [
      { slug: 'consoles', name: 'Consoles', iconName: 'sports_esports', imageUrl: u('photo-1486572788966-cfd3df1f5b42') },
      { slug: 'controllers', name: 'Controllers', iconName: 'gamepad', imageUrl: u('photo-1580327344181-c1163234e5a0') },
      { slug: 'video-games', name: 'Video Games', iconName: 'videogame_asset', imageUrl: u('photo-1493711662062-fa541adb3fc8') },
      { slug: 'pc-gaming', name: 'PC Gaming', iconName: 'desktop_windows', imageUrl: u('photo-1591488320449-011701bb6704') },
      { slug: 'gaming-accessories', name: 'Gaming Accessories', iconName: 'gamepad', imageUrl: u('photo-1592840496694-26d035b52b48') },
    ],
  },
  {
    slug: 'peripherals',
    name: 'Peripherals',
    iconName: 'keyboard',
    imageUrl: u('photo-1587829741301-dc798b83add3'),
    children: [
      { slug: 'keyboards', name: 'Keyboards', iconName: 'keyboard', imageUrl: u('photo-1587829741301-dc798b83add3') },
      { slug: 'mice', name: 'Mice', iconName: 'mouse', imageUrl: u('photo-1527814050087-3793815479db') },
      { slug: 'webcams', name: 'Webcams', iconName: 'videocam', imageUrl: u('photo-1587825140708-dfaf72ae4b04') },
      { slug: 'drawing-tablets', name: 'Drawing Tablets', iconName: 'draw', imageUrl: u('photo-1561070791-2526d30994b8') },
      { slug: 'usb-hubs', name: 'USB Hubs & Docks', iconName: 'usb', imageUrl: u('photo-1625948515291-69613efd103f') },
    ],
  },
  {
    slug: 'tv-and-streaming',
    name: 'TV & Streaming',
    iconName: 'tv',
    imageUrl: u('photo-1593359677879-a4bb92f829d1'),
    children: [
      { slug: 'smart-tvs', name: 'Smart TVs', iconName: 'tv', imageUrl: u('photo-1593359677879-a4bb92f829d1') },
      { slug: 'streaming-devices', name: 'Streaming Devices', iconName: 'cast', imageUrl: u('photo-1574375927938-d5a98e8ffe85') },
      { slug: 'projectors', name: 'Projectors', iconName: 'videocam', imageUrl: u('photo-1626379953822-baec19c3accd') },
      { slug: 'remote-controls', name: 'Remote Controls', iconName: 'settings_remote', imageUrl: u('photo-1593784991095-a205069470b6') },
    ],
  },
  {
    slug: 'smart-home',
    name: 'Smart Home & Networking',
    iconName: 'router',
    imageUrl: u('photo-1558002038-1055907df827'),
    children: [
      { slug: 'routers', name: 'Routers & WiFi', iconName: 'router', imageUrl: u('photo-1606904825846-647eb07f5be2') },
      { slug: 'smart-speakers', name: 'Smart Speakers', iconName: 'speaker', imageUrl: u('photo-1543512214-318c7553f230') },
      { slug: 'security-cameras', name: 'Security Cameras', iconName: 'videocam', imageUrl: u('photo-1564403729032-1b59ce2c6c87') },
      { slug: 'smart-lights', name: 'Smart Lights', iconName: 'lightbulb', imageUrl: u('photo-1556228578-8d89b7ac8b56') },
      { slug: 'smart-plugs', name: 'Smart Plugs & Switches', iconName: 'power', imageUrl: u('photo-1620810437159-08e9c6e0f6dc') },
    ],
  },
  {
    slug: 'power-and-charging',
    name: 'Power & Charging',
    iconName: 'battery_charging_full',
    imageUrl: u('photo-1583863788434-e58a36330cf0'),
    children: [
      { slug: 'power-banks', name: 'Power Banks', iconName: 'battery_charging_full', imageUrl: u('photo-1609091839311-d5365f9ff1c5') },
      { slug: 'wall-chargers', name: 'Wall Chargers', iconName: 'power', imageUrl: u('photo-1583863788434-e58a36330cf0') },
      { slug: 'chargers-and-cables', name: 'Charging Cables', iconName: 'cable', imageUrl: u('photo-1601592996763-f05c992eedc4') },
      { slug: 'wireless-chargers', name: 'Wireless Chargers', iconName: 'battery_full', imageUrl: u('photo-1606152536277-5aa1fd33e150') },
      { slug: 'ups-and-surge', name: 'UPS & Surge Protectors', iconName: 'electric_bolt', imageUrl: u('photo-1605647540924-852290f6b0d5') },
    ],
  },
  {
    slug: 'tablets-and-ereaders',
    name: 'Tablets & E-Readers',
    iconName: 'tablet_mac',
    imageUrl: u('photo-1561154464-82e9adf32764'),
    children: [
      { slug: 'tablets', name: 'Tablets', iconName: 'tablet_mac', imageUrl: u('photo-1561154464-82e9adf32764') },
      { slug: 'tablet-cases', name: 'Tablet Cases', iconName: 'phonelink_ring', imageUrl: u('photo-1623126908029-58cb08a2b272') },
      { slug: 'ereaders', name: 'E-Readers', iconName: 'menu_book', imageUrl: u('photo-1592434134753-a70baf7979d5') },
      { slug: 'stylus-pens', name: 'Stylus Pens', iconName: 'edit', imageUrl: u('photo-1583485088034-697b5bc36b92') },
    ],
  },
  {
    slug: 'drones-and-rc',
    name: 'Drones & RC',
    iconName: 'flight',
    imageUrl: u('photo-1473968512647-3e447244af8f'),
    children: [
      { slug: 'drones', name: 'Drones', iconName: 'flight', imageUrl: u('photo-1473968512647-3e447244af8f') },
      { slug: 'rc-vehicles', name: 'RC Vehicles', iconName: 'directions_car', imageUrl: u('photo-1581235720704-06d3acfcb36f') },
      { slug: 'drone-accessories', name: 'Drone Accessories', iconName: 'sd_card', imageUrl: u('photo-1508614589041-895b88991e3e') },
    ],
  },
];

export function* flattenCanonical(): Iterable<{
  slug: string;
  name: string;
  iconName: string;
  imageUrl: string;
  parentSlug: string | null;
  sortOrder: number;
}> {
  let order = 0;
  for (const parent of CANONICAL_CATEGORIES) {
    yield {
      slug: parent.slug,
      name: parent.name,
      iconName: parent.iconName,
      imageUrl: parent.imageUrl,
      parentSlug: null,
      sortOrder: order++,
    };
    for (const child of parent.children ?? []) {
      yield {
        slug: child.slug,
        name: child.name,
        iconName: child.iconName,
        imageUrl: child.imageUrl,
        parentSlug: parent.slug,
        sortOrder: order++,
      };
    }
  }
}

export const CANONICAL_SLUGS: ReadonlySet<string> = new Set(
  Array.from(flattenCanonical()).map((n) => n.slug),
);
