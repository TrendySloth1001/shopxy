import 'dotenv/config';
import crypto from 'crypto';
import bcrypt from 'bcrypt';
import { Prisma } from '@prisma/client';
import prisma from '../src/infra/db/prisma.js';
import { trendingService } from '../src/modules/trending/trending.service.js';

const PC_SHOP_SLUG_PREFIX = 'pc-';
const DEFAULT_PASSWORD = 'shopxy123';

const uuid = () => crypto.randomBytes(8).toString('hex');
const pick = <T,>(arr: T[], i: number): T => arr[i % arr.length];

interface MerchantSeed {
  email: string;
  name: string;
  shopName: string;
  slug: string;
  tagline: string;
  logoSeed: string;
  bannerImage: string;
  spotlight: {
    dealLabel: string;
    subtitle: string;
    image: string;
    bg: string;
    accent: string;
  };
}

const MERCHANTS: MerchantSeed[] = [
  {
    email: 'nkumawat8956@gmail.com',
    name: 'Nikhil Kumawat',
    shopName: 'Nikhils Warehouse',
    slug: 'pc-nikhils-warehouse',
    tagline: 'Curated PC gear, cables and accessories',
    logoSeed: 'nikhils',
    bannerImage:
      'https://images.unsplash.com/photo-1518770660439-4636190af475?w=1200',
    spotlight: {
      dealLabel: 'Festive electronics — up to 40% off',
      subtitle: 'Curated cables, hubs, and gamepads',
      image:
        'https://images.unsplash.com/photo-1518770660439-4636190af475?w=1200',
      bg: '#EFE4D6',
      accent: '#B23A2E',
    },
  },
  {
    email: 'merchant-techbazaar@shopxy.test',
    name: 'Vivek Sharma',
    shopName: 'TechBazaar India',
    slug: 'pc-techbazaar-india',
    tagline: 'India\'s largest PC peripherals destination',
    logoSeed: 'techbazaar',
    bannerImage:
      'https://images.unsplash.com/photo-1587202372634-32705e3bf49c?w=1200',
    spotlight: {
      dealLabel: 'Gamer week — flat 25% off RGB peripherals',
      subtitle: 'Mechanical keyboards, gaming mice, mousepads',
      image:
        'https://images.unsplash.com/photo-1587202372634-32705e3bf49c?w=1200',
      bg: '#1E1E26',
      accent: '#F4F757',
    },
  },
  {
    email: 'merchant-coreforge@shopxy.test',
    name: 'Anil Patel',
    shopName: 'CoreForge Components',
    slug: 'pc-coreforge-components',
    tagline: 'CPUs, GPUs and motherboards — built to last',
    logoSeed: 'coreforge',
    bannerImage:
      'https://images.unsplash.com/photo-1591488320449-011701bb6704?w=1200',
    spotlight: {
      dealLabel: 'Ryzen + Radeon combos starting ₹29,999',
      subtitle: 'Pre-tested PC component bundles',
      image:
        'https://images.unsplash.com/photo-1591488320449-011701bb6704?w=1200',
      bg: '#191A2C',
      accent: '#E14B4B',
    },
  },
  {
    email: 'merchant-lumistore@shopxy.test',
    name: 'Priya Iyer',
    shopName: 'LumiStore',
    slug: 'pc-lumistore',
    tagline: 'Premium monitors, lighting and home-office gear',
    logoSeed: 'lumi',
    bannerImage:
      'https://images.unsplash.com/photo-1593640408182-31c70c8268f5?w=1200',
    spotlight: {
      dealLabel: 'Save up to ₹15,000 on QHD/4K monitors',
      subtitle: 'IPS, 144Hz, USB-C docks and stands',
      image:
        'https://images.unsplash.com/photo-1593640408182-31c70c8268f5?w=1200',
      bg: '#1A2A3A',
      accent: '#3DB2FF',
    },
  },
  {
    email: 'merchant-mobilemuse@shopxy.test',
    name: 'Rohit Mehra',
    shopName: 'MobileMuse',
    slug: 'pc-mobilemuse',
    tagline: 'Laptops, laptop bags, stands and travel-ready gear',
    logoSeed: 'mobilemuse',
    bannerImage:
      'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?w=1200',
    spotlight: {
      dealLabel: 'Laptops up to ₹35,000 off — limited stock',
      subtitle: 'Bags, stands, keyboard covers included',
      image:
        'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?w=1200',
      bg: '#2C2A4A',
      accent: '#F8B400',
    },
  },
  {
    email: 'merchant-soundwave@shopxy.test',
    name: 'Sneha Rao',
    shopName: 'Soundwave Audio',
    slug: 'pc-soundwave-audio',
    tagline: 'Headphones, speakers and studio-grade audio',
    logoSeed: 'soundwave',
    bannerImage:
      'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=1200',
    spotlight: {
      dealLabel: 'ANC headphones — flat ₹4,000 off',
      subtitle: 'In-ear, over-ear and bluetooth speakers',
      image:
        'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=1200',
      bg: '#0F1A2A',
      accent: '#FF6B6B',
    },
  },
  {
    email: 'merchant-powergrid@shopxy.test',
    name: 'Karan Bhatia',
    shopName: 'PowerGrid Accessories',
    slug: 'pc-powergrid-accessories',
    tagline: 'Cables, chargers, power banks and surge protectors',
    logoSeed: 'powergrid',
    bannerImage:
      'https://images.unsplash.com/photo-1606220588913-b3aacb4d2f37?w=1200',
    spotlight: {
      dealLabel: '100W GaN chargers and 1m+ cables — 30% off',
      subtitle: 'USB-C, MagSafe, HDMI 2.1 and DisplayPort',
      image:
        'https://images.unsplash.com/photo-1606220588913-b3aacb4d2f37?w=1200',
      bg: '#FFE8C2',
      accent: '#F25C05',
    },
  },
];

const IMAGES = {
  laptop: [
    'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?w=800',
    'https://images.unsplash.com/photo-1517336714731-489689fd1ca8?w=800',
    'https://images.unsplash.com/photo-1541807084-5c52b6b3adef?w=800',
    'https://images.unsplash.com/photo-1531297484001-80022131f5a1?w=800',
    'https://images.unsplash.com/photo-1593642632559-0c6d3fc62b89?w=800',
    'https://images.unsplash.com/photo-1525547719571-a2d4ac8945e2?w=800',
  ],
  keyboard: [
    'https://images.unsplash.com/photo-1587829741301-dc798b83add3?w=800',
    'https://images.unsplash.com/photo-1618384887929-16ec33fab9ef?w=800',
    'https://images.unsplash.com/photo-1595044426077-d36d9236d54a?w=800',
    'https://images.unsplash.com/photo-1601445638532-3c6f6c3aa1d6?w=800',
    'https://images.unsplash.com/photo-1561112078-7d24e04c3407?w=800',
  ],
  mouse: [
    'https://images.unsplash.com/photo-1527864550417-7fd91fc51a46?w=800',
    'https://images.unsplash.com/photo-1615663245857-ac93bb7c39e7?w=800',
    'https://images.unsplash.com/photo-1563297007-0686b7003af7?w=800',
    'https://images.unsplash.com/photo-1605773527852-c546a8584ea3?w=800',
  ],
  monitor: [
    'https://images.unsplash.com/photo-1593640408182-31c70c8268f5?w=800',
    'https://images.unsplash.com/photo-1527443224154-c4a3942d3acf?w=800',
    'https://images.unsplash.com/photo-1547119957-637f8679db1e?w=800',
    'https://images.unsplash.com/photo-1517433670267-08bbd4be890f?w=800',
  ],
  headphone: [
    'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=800',
    'https://images.unsplash.com/photo-1583394838336-acd977736f90?w=800',
    'https://images.unsplash.com/photo-1487215078519-e21cc028cb29?w=800',
    'https://images.unsplash.com/photo-1546435770-a3e426bf472b?w=800',
  ],
  earbud: [
    'https://images.unsplash.com/photo-1606220588913-b3aacb4d2f37?w=800',
    'https://images.unsplash.com/photo-1590658268037-6bf12165a8df?w=800',
    'https://images.unsplash.com/photo-1572569511254-d8f925fe2cbb?w=800',
  ],
  speaker: [
    'https://images.unsplash.com/photo-1545454675-3531b543be5d?w=800',
    'https://images.unsplash.com/photo-1608043152269-423dbba4e7e1?w=800',
    'https://images.unsplash.com/photo-1558379850-c4f8b3e9d4a0?w=800',
  ],
  cable: [
    'https://images.unsplash.com/photo-1583394838336-acd977736f90?w=800',
    'https://images.unsplash.com/photo-1601524909162-ae8725290836?w=800',
    'https://images.unsplash.com/photo-1601524909164-3f51ad77c8c8?w=800',
    'https://images.unsplash.com/photo-1592434134753-a70baf7979d5?w=800',
  ],
  cpu: [
    'https://images.unsplash.com/photo-1591799264318-7e6ef8ddb7ea?w=800',
    'https://images.unsplash.com/photo-1518770660439-4636190af475?w=800',
    'https://images.unsplash.com/photo-1555680202-c86f0e12f086?w=800',
  ],
  gpu: [
    'https://images.unsplash.com/photo-1591488320449-011701bb6704?w=800',
    'https://images.unsplash.com/photo-1587202372634-32705e3bf49c?w=800',
    'https://images.unsplash.com/photo-1542751110-97427bbecf20?w=800',
  ],
  motherboard: [
    'https://images.unsplash.com/photo-1518770660439-4636190af475?w=800',
    'https://images.unsplash.com/photo-1555617981-dac3880eac6e?w=800',
  ],
  ram: [
    'https://images.unsplash.com/photo-1562976540-1502c2145186?w=800',
    'https://images.unsplash.com/photo-1591405351990-4726e331f141?w=800',
  ],
  ssd: [
    'https://images.unsplash.com/photo-1597872200969-2b65d56bd16b?w=800',
    'https://images.unsplash.com/photo-1531492746076-161ca9bcad58?w=800',
  ],
  cabinet: [
    'https://images.unsplash.com/photo-1587202372634-32705e3bf49c?w=800',
    'https://images.unsplash.com/photo-1591488320449-011701bb6704?w=800',
    'https://images.unsplash.com/photo-1542751110-97427bbecf20?w=800',
  ],
  airCooler: [
    'https://images.unsplash.com/photo-1587202372634-32705e3bf49c?w=800',
    'https://images.unsplash.com/photo-1555617981-dac3880eac6e?w=800',
  ],
  aio: [
    'https://images.unsplash.com/photo-1587202372634-32705e3bf49c?w=800',
    'https://images.unsplash.com/photo-1591488320449-011701bb6704?w=800',
  ],
  psu: [
    'https://images.unsplash.com/photo-1587202372634-32705e3bf49c?w=800',
    'https://images.unsplash.com/photo-1555617981-dac3880eac6e?w=800',
  ],
  laptopBag: [
    'https://images.unsplash.com/photo-1622560480605-d83c853bc5c3?w=800',
    'https://images.unsplash.com/photo-1547949003-9792a18a2601?w=800',
    'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=800',
  ],
  laptopStand: [
    'https://images.unsplash.com/photo-1525547719571-a2d4ac8945e2?w=800',
    'https://images.unsplash.com/photo-1593642632559-0c6d3fc62b89?w=800',
  ],
  keyboardCover: [
    'https://images.unsplash.com/photo-1595044426077-d36d9236d54a?w=800',
    'https://images.unsplash.com/photo-1517336714731-489689fd1ca8?w=800',
  ],
  mousepad: [
    'https://images.unsplash.com/photo-1561112078-7d24e04c3407?w=800',
    'https://images.unsplash.com/photo-1527864550417-7fd91fc51a46?w=800',
  ],
  cleaner: [
    'https://images.unsplash.com/photo-1583947582886-f40ec95dd752?w=800',
    'https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?w=800',
  ],
  webcam: [
    'https://images.unsplash.com/photo-1614624532983-4ce03382d63d?w=800',
    'https://images.unsplash.com/photo-1605647540924-852290f6b0d5?w=800',
  ],
  charger: [
    'https://images.unsplash.com/photo-1606220588913-b3aacb4d2f37?w=800',
    'https://images.unsplash.com/photo-1601524909162-ae8725290836?w=800',
  ],
  powerBank: [
    'https://images.unsplash.com/photo-1609091839311-d5365f9ff1c5?w=800',
    'https://images.unsplash.com/photo-1606220588913-b3aacb4d2f37?w=800',
  ],
  hub: [
    'https://images.unsplash.com/photo-1583394838336-acd977736f90?w=800',
    'https://images.unsplash.com/photo-1601524909164-3f51ad77c8c8?w=800',
  ],
  controller: [
    'https://images.unsplash.com/photo-1592840496694-26d035b52b48?w=800',
    'https://images.unsplash.com/photo-1605901309584-818e25960a8f?w=800',
    'https://images.unsplash.com/photo-1606144042614-b2417e99c4e3?w=800',
  ],
};

type Bucket = keyof typeof IMAGES;

interface ProductTemplate {
  name: string;
  mrp: number;
  selling: number;
  categorySlug: string;
  bucket: Bucket;
  highlights: string[];
  tags?: string[];
}

const TEMPLATES: ProductTemplate[] = [
  { name: 'ASUS ROG Strix G16 i7-13650HX Gaming Laptop', mrp: 134990, selling: 109990, categorySlug: 'laptops', bucket: 'laptop', highlights: ['16" 165Hz QHD+', 'RTX 4060 8GB', '16GB DDR5'], tags: ['Bestseller', 'Gaming'] },
  { name: 'Lenovo IdeaPad Slim 5 Ryzen 7 7730U', mrp: 78990, selling: 59990, categorySlug: 'laptops', bucket: 'laptop', highlights: ['14" WUXGA', '512GB SSD', 'Backlit keyboard'], tags: ['Bestseller'] },
  { name: 'HP Pavilion Plus 14 Intel Core i5-13500H', mrp: 89999, selling: 68990, categorySlug: 'laptops', bucket: 'laptop', highlights: ['2.8K OLED', '16GB LPDDR5', 'Iris Xe Graphics'] },
  { name: 'Apple MacBook Air 13 M3 8C/8C 8GB 256GB', mrp: 114900, selling: 99900, categorySlug: 'laptops', bucket: 'laptop', highlights: ['M3 chip', '18hr battery', 'Liquid Retina'], tags: ['Editor\'s pick'] },
  { name: 'Dell Inspiron 15 3530 i3-1305U Notebook', mrp: 54990, selling: 39990, categorySlug: 'laptops', bucket: 'laptop', highlights: ['15.6" FHD', '8GB DDR4', '512GB SSD'] },
  { name: 'Acer Predator Helios Neo 16 i9-14900HX', mrp: 189990, selling: 154990, categorySlug: 'laptops', bucket: 'laptop', highlights: ['RTX 4070 8GB', '240Hz WQXGA', 'Vapor chamber cooling'], tags: ['Gaming'] },
  { name: 'MSI Modern 14 C12M Intel i5-1235U', mrp: 64990, selling: 44990, categorySlug: 'laptops', bucket: 'laptop', highlights: ['1.4kg', '14" FHD IPS', 'Backlit'] },

  { name: 'LG UltraGear 27GP850 27" 1440p 180Hz IPS', mrp: 44999, selling: 33990, categorySlug: 'monitors', bucket: 'monitor', highlights: ['Nano IPS', '1ms GtG', 'G-SYNC Compatible'], tags: ['Gaming'] },
  { name: 'Samsung Odyssey G7 32" 240Hz Curved QHD', mrp: 79999, selling: 56990, categorySlug: 'monitors', bucket: 'monitor', highlights: ['1000R curve', 'HDR600', 'FreeSync Premium Pro'], tags: ['Bestseller'] },
  { name: 'Dell UltraSharp U2723QE 27" 4K USB-C Hub', mrp: 79000, selling: 63990, categorySlug: 'monitors', bucket: 'monitor', highlights: ['IPS Black', '90W PD', 'KVM switch'] },
  { name: 'BenQ EX240 24" 165Hz 1080p IPS', mrp: 24999, selling: 18990, categorySlug: 'monitors', bucket: 'monitor', highlights: ['HDRi', 'treVolo speakers', 'Low blue light'] },
  { name: 'Acer Nitro VG240Y 24" 100Hz FHD IPS', mrp: 18999, selling: 9990, categorySlug: 'monitors', bucket: 'monitor', highlights: ['ZeroFrame', 'AMD FreeSync', '1ms VRB'] },
  { name: 'LG 34WP65C 34" UltraWide Curved QHD', mrp: 54999, selling: 39990, categorySlug: 'monitors', bucket: 'monitor', highlights: ['1500R curve', 'sRGB 99%', 'USB-C 60W'] },

  { name: 'Samsung 990 Pro 2TB NVMe Gen4 SSD', mrp: 22999, selling: 16990, categorySlug: 'storage-drives', bucket: 'ssd', highlights: ['7450 MB/s read', '5-yr warranty', 'PS5 compatible'], tags: ['Bestseller'] },
  { name: 'WD Black SN850X 1TB NVMe Gen4 SSD', mrp: 12999, selling: 8490, categorySlug: 'storage-drives', bucket: 'ssd', highlights: ['7300 MB/s read', 'Game Mode 2.0'] },
  { name: 'Crucial MX500 1TB SATA SSD', mrp: 7499, selling: 5490, categorySlug: 'storage-drives', bucket: 'ssd', highlights: ['560 MB/s read', 'AES-256 encryption'] },
  { name: 'Seagate Barracuda 2TB 7200RPM HDD', mrp: 5990, selling: 4290, categorySlug: 'storage-drives', bucket: 'ssd', highlights: ['SATA 6Gb/s', '256MB cache'] },

  { name: 'Logitech MX Keys S Wireless Backlit Keyboard', mrp: 14995, selling: 11990, categorySlug: 'keyboards', bucket: 'keyboard', highlights: ['Perfect-stroke', 'Smart Actions', '10-day battery'], tags: ['Bestseller'] },
  { name: 'Keychron K2 V2 Hot-Swappable Mechanical', mrp: 11990, selling: 8990, categorySlug: 'keyboards', bucket: 'keyboard', highlights: ['75% layout', 'RGB backlight', 'Bluetooth 5.1'] },
  { name: 'Razer BlackWidow V4 Pro Green Switch', mrp: 24999, selling: 19990, categorySlug: 'keyboards', bucket: 'keyboard', highlights: ['Doubleshot ABS', 'Wrist rest', 'Chroma RGB'], tags: ['Gaming'] },
  { name: 'Corsair K70 RGB MK.2 Cherry MX Red', mrp: 17999, selling: 13490, categorySlug: 'keyboards', bucket: 'keyboard', highlights: ['8000Hz polling', 'Aluminum frame'] },
  { name: 'Redragon Kumara K552 TKL Mechanical', mrp: 4999, selling: 2299, categorySlug: 'keyboards', bucket: 'keyboard', highlights: ['Outemu Blue', 'Rainbow LED', 'Anti-ghost'] },

  { name: 'Logitech MX Master 3S Wireless Mouse', mrp: 11995, selling: 9490, categorySlug: 'mice', bucket: 'mouse', highlights: ['8K DPI', 'Quiet clicks', 'Multi-device'], tags: ['Bestseller'] },
  { name: 'Razer DeathAdder V3 Pro Wireless', mrp: 16999, selling: 13990, categorySlug: 'mice', bucket: 'mouse', highlights: ['63g ultralight', 'Focus Pro 30K', '90hr battery'], tags: ['Gaming'] },
  { name: 'Glorious Model O Wireless Pro 4K', mrp: 12999, selling: 10490, categorySlug: 'mice', bucket: 'mouse', highlights: ['62g', '4000Hz polling', 'BAMF 2.0 sensor'] },
  { name: 'Logitech G502 Hero High-Performance', mrp: 6995, selling: 4290, categorySlug: 'mice', bucket: 'mouse', highlights: ['25K DPI', '11 programmable', 'LightSync RGB'] },
  { name: 'HP M280 Wired USB Optical Mouse', mrp: 999, selling: 449, categorySlug: 'mice', bucket: 'mouse', highlights: ['1000 DPI', 'Ambidextrous', 'Plug-and-play'] },

  { name: 'Logitech G840 XL Cloth Gaming Mousepad', mrp: 4995, selling: 3290, categorySlug: 'mousepads', bucket: 'mousepad', highlights: ['400x900mm', 'Rubber base', 'Stitched edges'], tags: ['Gaming'] },
  { name: 'Razer Goliathus Extended Chroma RGB', mrp: 5990, selling: 4290, categorySlug: 'mousepads', bucket: 'mousepad', highlights: ['RGB underglow', '294x920mm', 'Micro-textured'] },
  { name: 'Corsair MM350 Pro Premium Spill-Proof', mrp: 3490, selling: 2390, categorySlug: 'mousepads', bucket: 'mousepad', highlights: ['Anti-fray edges', 'Splash-proof surface'] },
  { name: 'AmazonBasics XXL Mousepad 900x400', mrp: 1499, selling: 799, categorySlug: 'mousepads', bucket: 'mousepad', highlights: ['Non-slip rubber', 'Stitched border'] },

  { name: 'Sony WH-1000XM5 Wireless ANC Headphones', mrp: 34990, selling: 24990, categorySlug: 'headphones', bucket: 'headphone', highlights: ['Industry-leading ANC', '30hr battery', 'Multipoint'], tags: ['Bestseller'] },
  { name: 'Bose QuietComfort Ultra Headphones', mrp: 41900, selling: 33900, categorySlug: 'headphones', bucket: 'headphone', highlights: ['Immersive Audio', 'CustomTune'] },
  { name: 'Sennheiser HD 660S2 Open-back', mrp: 49990, selling: 39990, categorySlug: 'headphones', bucket: 'headphone', highlights: ['Audiophile grade', '300Ω drivers'] },
  { name: 'Boat Rockerz 450 Bluetooth On-ear', mrp: 3990, selling: 1499, categorySlug: 'headphones', bucket: 'headphone', highlights: ['40mm drivers', '15hr battery'] },
  { name: 'Apple AirPods Pro 2 (USB-C)', mrp: 24900, selling: 21490, categorySlug: 'earbuds', bucket: 'earbud', highlights: ['Adaptive Audio', 'H2 chip', 'Hearing Aid mode'], tags: ['Bestseller'] },
  { name: 'Samsung Galaxy Buds3 Pro', mrp: 24990, selling: 19990, categorySlug: 'earbuds', bucket: 'earbud', highlights: ['ANC', '24-bit Hi-Fi', 'IP57'] },
  { name: 'Sony WF-C700N True Wireless ANC', mrp: 8990, selling: 6990, categorySlug: 'earbuds', bucket: 'earbud', highlights: ['DSEE', '15hr w/ case', 'Multipoint'] },
  { name: 'Nothing Ear (a) TWS Earbuds', mrp: 7999, selling: 5499, categorySlug: 'earbuds', bucket: 'earbud', highlights: ['LDAC', 'Active Noise Cancellation'] },

  { name: 'JBL Flip 6 Portable Bluetooth Speaker', mrp: 11999, selling: 8490, categorySlug: 'bluetooth-speakers', bucket: 'speaker', highlights: ['IP67 dust/water', '12hr playtime', 'PartyBoost'] },
  { name: 'Sony SRS-XB100 Compact Wireless Speaker', mrp: 4990, selling: 3490, categorySlug: 'bluetooth-speakers', bucket: 'speaker', highlights: ['16hr battery', 'IP67'] },
  { name: 'Marshall Emberton II Portable Speaker', mrp: 17999, selling: 13990, categorySlug: 'bluetooth-speakers', bucket: 'speaker', highlights: ['30hr+ battery', 'IP67', 'True Stereophonic'] },

  { name: 'Anker PowerLine III USB-C to USB-C 1.8m', mrp: 1799, selling: 999, categorySlug: 'chargers-and-cables', bucket: 'cable', highlights: ['100W PD', 'Braided nylon', '12,000-bend tested'] },
  { name: 'Belkin HDMI 2.1 Ultra HD Cable 2m', mrp: 2999, selling: 1499, categorySlug: 'chargers-and-cables', bucket: 'cable', highlights: ['48Gbps', '8K@60Hz', 'eARC'] },
  { name: 'Mi Type-C to Type-C 5A 1m Cable', mrp: 599, selling: 249, categorySlug: 'chargers-and-cables', bucket: 'cable', highlights: ['100W PD', 'Aramid fiber'] },
  { name: 'Apple Thunderbolt 4 USB-C Pro Cable 1m', mrp: 11900, selling: 9990, categorySlug: 'chargers-and-cables', bucket: 'cable', highlights: ['40Gbps', '100W PD'] },
  { name: 'UGREEN DisplayPort 1.4 Cable 2m', mrp: 2299, selling: 1290, categorySlug: 'chargers-and-cables', bucket: 'cable', highlights: ['8K@60Hz', 'DSC 1.2', 'Gold plated'] },

  { name: 'Anker 100W GaN Prime 3-Port Charger', mrp: 7999, selling: 5490, categorySlug: 'wall-chargers', bucket: 'charger', highlights: ['GaNPrime', 'PD 3.0 + PPS'] },
  { name: 'Apple 35W Dual USB-C Power Adapter', mrp: 4900, selling: 3990, categorySlug: 'wall-chargers', bucket: 'charger', highlights: ['Two USB-C ports', 'Compact'] },
  { name: 'Mi 67W SonicCharge 3.0 Charger', mrp: 1799, selling: 999, categorySlug: 'wall-chargers', bucket: 'charger', highlights: ['67W output', 'QC4+', 'PD 3.0'] },

  { name: 'Anker 737 PowerCore 24000mAh 140W', mrp: 14999, selling: 11490, categorySlug: 'power-banks', bucket: 'powerBank', highlights: ['140W output', 'Smart display'] },
  { name: 'Mi 20000mAh Power Bank 3i 18W', mrp: 2499, selling: 1799, categorySlug: 'power-banks', bucket: 'powerBank', highlights: ['Triple output', '18W PD'] },

  { name: 'Anker 555 USB-C Hub 8-in-1 4K HDMI', mrp: 6999, selling: 4990, categorySlug: 'usb-hubs', bucket: 'hub', highlights: ['100W PD passthrough', '4K@60Hz HDMI', 'SD/microSD'] },
  { name: 'UGREEN Revodok Pro 109 9-in-1 Dock', mrp: 8990, selling: 6490, categorySlug: 'usb-hubs', bucket: 'hub', highlights: ['Dual HDMI', '1Gbps Ethernet'] },
  { name: 'CalDigit TS4 Thunderbolt 4 Dock', mrp: 41990, selling: 35990, categorySlug: 'usb-hubs', bucket: 'hub', highlights: ['18 ports', '98W charging'] },

  { name: 'Logitech C920 HD Pro Webcam 1080p', mrp: 6995, selling: 4990, categorySlug: 'webcams', bucket: 'webcam', highlights: ['1080p/30fps', 'Stereo mic'] },
  { name: 'Razer Kiyo Pro Ultra 4K HDR', mrp: 31999, selling: 24990, categorySlug: 'webcams', bucket: 'webcam', highlights: ['Sony STARVIS sensor', '4K@24fps'] },

  { name: 'Sony DualSense Edge PS5 Controller', mrp: 19999, selling: 17490, categorySlug: 'controllers', bucket: 'controller', highlights: ['Customisable mappings', 'Replaceable sticks'], tags: ['Gaming'] },
  { name: 'Xbox Wireless Controller Carbon Black', mrp: 5499, selling: 4290, categorySlug: 'controllers', bucket: 'controller', highlights: ['Bluetooth', 'Hybrid D-pad'] },
  { name: '8BitDo Ultimate 2.4G Controller Black', mrp: 6990, selling: 5490, categorySlug: 'controllers', bucket: 'controller', highlights: ['Hall-effect sticks', 'Charging dock'] },

  { name: 'Targus CityGear 15.6" Laptop Backpack', mrp: 6995, selling: 3990, categorySlug: 'laptop-bags', bucket: 'laptopBag', highlights: ['SafeFit padding', 'Trolley strap'] },
  { name: 'WiWU Alpha 15.4" Slim Laptop Sleeve', mrp: 2499, selling: 1499, categorySlug: 'laptop-bags', bucket: 'laptopBag', highlights: ['PU leather', 'Water resistant'] },
  { name: 'Lenovo Legion Gaming Backpack 17"', mrp: 4999, selling: 3290, categorySlug: 'laptop-bags', bucket: 'laptopBag', highlights: ['RFID pocket', 'Bottle holder'] },
  { name: 'Rain Design mStand Aluminium Laptop Stand', mrp: 7990, selling: 5990, categorySlug: 'laptop-stands', bucket: 'laptopStand', highlights: ['Sandblasted aluminium', '11-17" laptops'] },
  { name: 'BoYata Adjustable Laptop Stand', mrp: 3999, selling: 2490, categorySlug: 'laptop-stands', bucket: 'laptopStand', highlights: ['10-17.3"', '180° tilt'] },
  { name: 'Lapcare Foldable Portable Laptop Stand', mrp: 1499, selling: 799, categorySlug: 'laptop-stands', bucket: 'laptopStand', highlights: ['Aluminium', '8-level adjustable'] },
  { name: 'Saco TPU Keyboard Cover for MacBook Air 13', mrp: 999, selling: 399, categorySlug: 'keyboard-covers', bucket: 'keyboardCover', highlights: ['Ultra-thin', 'Spill resistant'] },
  { name: 'Tukzer Silicone Keyboard Skin for HP Pavilion 14', mrp: 799, selling: 299, categorySlug: 'keyboard-covers', bucket: 'keyboardCover', highlights: ['Dust-proof', 'Washable'] },

  { name: '3M Screen & Keyboard Cleaning Kit', mrp: 1490, selling: 899, categorySlug: 'cleaning-kits', bucket: 'cleaner', highlights: ['Anti-static cloth', '60ml solution'] },
  { name: 'OXO Good Grips Electronics Cleaning Brush', mrp: 990, selling: 590, categorySlug: 'cleaning-kits', bucket: 'cleaner', highlights: ['Soft bristle', 'Silicone tip'] },
  { name: 'Logitech Cleaning Putty for Keyboards', mrp: 599, selling: 349, categorySlug: 'cleaning-kits', bucket: 'cleaner', highlights: ['Reusable', 'Non-residue'] },

  { name: 'AMD Ryzen 7 7800X3D 8-Core 16-Thread', mrp: 44999, selling: 36490, categorySlug: 'cpus', bucket: 'cpu', highlights: ['3D V-Cache', '5.0 GHz boost', 'AM5'], tags: ['Bestseller'] },
  { name: 'Intel Core i7-14700K 20-Core LGA1700', mrp: 39999, selling: 32490, categorySlug: 'cpus', bucket: 'cpu', highlights: ['5.6 GHz boost', 'Intel UHD 770'] },
  { name: 'AMD Ryzen 5 7600 6-Core 12-Thread', mrp: 21999, selling: 17490, categorySlug: 'cpus', bucket: 'cpu', highlights: ['5.1 GHz boost', 'AM5', 'Wraith Stealth'] },
  { name: 'Intel Core i5-13600KF 14-Core LGA1700', mrp: 29999, selling: 23490, categorySlug: 'cpus', bucket: 'cpu', highlights: ['5.1 GHz turbo', 'Hybrid arch'] },
  { name: 'AMD Ryzen 9 7950X 16-Core 32-Thread', mrp: 69990, selling: 54990, categorySlug: 'cpus', bucket: 'cpu', highlights: ['5.7 GHz boost', '170W TDP'] },

  { name: 'ASUS TUF Gaming GeForce RTX 4070 Super 12GB', mrp: 78999, selling: 64990, categorySlug: 'graphics-cards', bucket: 'gpu', highlights: ['12GB GDDR6X', '2640 MHz boost', 'Axial-tech fans'], tags: ['Bestseller'] },
  { name: 'MSI Gaming X Trio RTX 4080 Super 16GB', mrp: 124999, selling: 104990, categorySlug: 'graphics-cards', bucket: 'gpu', highlights: ['Tri Frozr 3', '16GB GDDR6X'] },
  { name: 'Sapphire Pulse Radeon RX 7800 XT 16GB', mrp: 59999, selling: 47990, categorySlug: 'graphics-cards', bucket: 'gpu', highlights: ['Dual-X cooling', '16GB GDDR6'] },
  { name: 'Gigabyte RTX 4060 Eagle OC 8GB', mrp: 32999, selling: 26490, categorySlug: 'graphics-cards', bucket: 'gpu', highlights: ['Windforce 3X', 'OC mode 2475 MHz'] },
  { name: 'Zotac RTX 4090 AMP Extreme AIRO 24GB', mrp: 269999, selling: 224990, categorySlug: 'graphics-cards', bucket: 'gpu', highlights: ['IceStorm 3.0', '24GB GDDR6X'], tags: ['Flagship'] },

  { name: 'ASUS ROG Strix B650E-F Gaming WiFi', mrp: 34999, selling: 27490, categorySlug: 'motherboards', bucket: 'motherboard', highlights: ['AM5', 'PCIe 5.0', 'WiFi 6E'] },
  { name: 'MSI MAG B760 Tomahawk WiFi DDR5', mrp: 24999, selling: 19990, categorySlug: 'motherboards', bucket: 'motherboard', highlights: ['LGA1700', 'WiFi 6E', '2.5G LAN'] },
  { name: 'Gigabyte X670 Aorus Elite AX', mrp: 36990, selling: 28490, categorySlug: 'motherboards', bucket: 'motherboard', highlights: ['AM5', '16+2+2 phases', 'PCIe 5.0'] },

  { name: 'Corsair Vengeance DDR5 32GB (2x16) 6000 MT/s', mrp: 14999, selling: 10490, categorySlug: 'ram', bucket: 'ram', highlights: ['EXPO', 'CL30', 'Aluminium heatspreader'] },
  { name: 'G.Skill Trident Z5 RGB DDR5 32GB 6400 MT/s', mrp: 18999, selling: 14490, categorySlug: 'ram', bucket: 'ram', highlights: ['CL32', 'RGB lightbar'] },
  { name: 'Crucial Pro DDR4 32GB (2x16) 3200 MT/s', mrp: 9499, selling: 6490, categorySlug: 'ram', bucket: 'ram', highlights: ['Low-profile', 'XMP 2.0'] },

  { name: 'Corsair RM850x 850W 80+ Gold Fully Modular', mrp: 16999, selling: 12490, categorySlug: 'psus', bucket: 'psu', highlights: ['Cybenetics Gold', 'Zero RPM fan'] },
  { name: 'Seasonic Focus GX 750W 80+ Gold', mrp: 12999, selling: 9490, categorySlug: 'psus', bucket: 'psu', highlights: ['10-yr warranty', 'Hybrid fan'] },

  { name: 'NZXT H7 Flow ATX Mid-Tower Case', mrp: 14999, selling: 10990, categorySlug: 'cabinets', bucket: 'cabinet', highlights: ['Perforated front', 'USB-C front IO'] },
  { name: 'Lian Li O11 Dynamic EVO RGB', mrp: 21999, selling: 16490, categorySlug: 'cabinets', bucket: 'cabinet', highlights: ['Reversible chassis', 'Tempered glass'] },
  { name: 'Cooler Master MasterBox TD500 Mesh V2', mrp: 11999, selling: 8490, categorySlug: 'cabinets', bucket: 'cabinet', highlights: ['Crystalline front', 'ARGB fans included'] },
  { name: 'Phanteks Eclipse G500A DRGB', mrp: 13999, selling: 9990, categorySlug: 'cabinets', bucket: 'cabinet', highlights: ['Ultra-fine mesh', '3x 140mm fans'] },

  { name: 'Noctua NH-D15 Chromax.Black Dual-Tower', mrp: 11999, selling: 9490, categorySlug: 'cpu-coolers', bucket: 'airCooler', highlights: ['6 heat pipes', '2x NF-A15 fans'], tags: ['Editor\'s pick'] },
  { name: 'Cooler Master Hyper 212 Black Edition', mrp: 3499, selling: 2290, categorySlug: 'cpu-coolers', bucket: 'airCooler', highlights: ['4 direct-contact pipes', 'PWM fan'] },
  { name: 'be quiet! Dark Rock Pro 4 Air Cooler', mrp: 8999, selling: 6990, categorySlug: 'cpu-coolers', bucket: 'airCooler', highlights: ['Silent Wings fans', '250W TDP'] },

  { name: 'Corsair iCUE H150i Elite Capellix XT', mrp: 23999, selling: 17990, categorySlug: 'aio-coolers', bucket: 'aio', highlights: ['360mm rad', 'Magnetic Levitation fans', 'iCUE LCD'] },
  { name: 'NZXT Kraken Z73 RGB AIO 360mm', mrp: 29999, selling: 22990, categorySlug: 'aio-coolers', bucket: 'aio', highlights: ['LCD pump head', '7th gen Asetek'] },
  { name: 'Arctic Liquid Freezer III 240', mrp: 11999, selling: 8490, categorySlug: 'aio-coolers', bucket: 'aio', highlights: ['VRM fan', 'P12 PWM PST'] },
];

function logoUrl(seed: string): string {
  return `https://api.dicebear.com/7.x/shapes/svg?seed=${seed}&backgroundColor=eef2ff`;
}

function asDecimal(n: number): Prisma.Decimal {
  return new Prisma.Decimal(n.toFixed(2));
}

function buildSpecs(highlights: string[]): Prisma.JsonValue {
  return [
    {
      title: 'Highlights',
      rows: highlights.map((h, i) => ({ label: `Feature ${i + 1}`, value: h })),
    },
  ];
}

function buildOffers(selling: number): Prisma.JsonValue {
  return [
    {
      kind: 'BANK',
      headline: `5% off with Axis Bank credit cards`,
      detail: `Up to ₹${Math.min(500, Math.round(selling * 0.05))} discount on EMI transactions`,
    },
    { kind: 'EXCHANGE', headline: 'Up to ₹2,000 off with exchange' },
  ];
}

const NEW_CATEGORIES: Array<{
  name: string;
  slug: string;
  parentSlug?: string;
  imageUrl: string;
}> = [
  { name: 'PC Components', slug: 'pc-components', imageUrl: IMAGES.cpu[0] },
  { name: 'CPUs', slug: 'cpus', parentSlug: 'pc-components', imageUrl: IMAGES.cpu[0] },
  { name: 'Graphics Cards', slug: 'graphics-cards', parentSlug: 'pc-components', imageUrl: IMAGES.gpu[0] },
  { name: 'Motherboards', slug: 'motherboards', parentSlug: 'pc-components', imageUrl: IMAGES.motherboard[0] },
  { name: 'RAM', slug: 'ram', parentSlug: 'pc-components', imageUrl: IMAGES.ram[0] },
  { name: 'PSUs', slug: 'psus', parentSlug: 'pc-components', imageUrl: IMAGES.psu[0] },
  { name: 'Cabinets', slug: 'cabinets', parentSlug: 'pc-components', imageUrl: IMAGES.cabinet[0] },
  { name: 'CPU Coolers', slug: 'cpu-coolers', parentSlug: 'pc-components', imageUrl: IMAGES.airCooler[0] },
  { name: 'AIO Coolers', slug: 'aio-coolers', parentSlug: 'pc-components', imageUrl: IMAGES.aio[0] },
  { name: 'Mousepads', slug: 'mousepads', parentSlug: 'peripherals', imageUrl: IMAGES.mousepad[0] },
  { name: 'Cleaning Kits', slug: 'cleaning-kits', parentSlug: 'peripherals', imageUrl: IMAGES.cleaner[0] },
  { name: 'Laptop Bags', slug: 'laptop-bags', parentSlug: 'laptop-accessories', imageUrl: IMAGES.laptopBag[0] },
  { name: 'Laptop Stands', slug: 'laptop-stands', parentSlug: 'laptop-accessories', imageUrl: IMAGES.laptopStand[0] },
  { name: 'Keyboard Covers', slug: 'keyboard-covers', parentSlug: 'laptop-accessories', imageUrl: IMAGES.keyboardCover[0] },
];

async function ensureCategories(): Promise<Map<string, number>> {
  const bySlug = new Map<string, number>();
  const existing = await prisma.category.findMany({
    select: { id: true, slug: true },
  });
  for (const c of existing) bySlug.set(c.slug, c.id);

  for (const c of NEW_CATEGORIES) {
    if (bySlug.has(c.slug)) continue;
    const parentId = c.parentSlug ? bySlug.get(c.parentSlug) ?? null : null;
    const created = await prisma.category.create({
      data: {
        name: c.name,
        slug: c.slug,
        parentId,
        imageUrl: c.imageUrl,
        isActive: true,
      },
    });
    bySlug.set(c.slug, created.id);
    console.log(`  + category ${c.slug} → #${created.id}`);
  }
  return bySlug;
}

async function ensureUser(m: MerchantSeed) {
  const existing = await prisma.user.findUnique({ where: { email: m.email } });
  if (existing) return existing;
  const passwordHash = await bcrypt.hash(DEFAULT_PASSWORD, 12);
  const created = await prisma.user.create({
    data: {
      email: m.email,
      name: m.name,
      passwordHash,
      role: 'OWNER',
      shopName: m.shopName,
      acceptedAt: new Date(),
    },
  });
  console.log(`  + user ${m.email} (pwd: ${DEFAULT_PASSWORD})`);
  return created;
}

async function wipePcShops() {
  const shops = await prisma.shop.findMany({
    where: { slug: { startsWith: PC_SHOP_SLUG_PREFIX } },
    select: { id: true, slug: true },
  });
  if (shops.length === 0) {
    console.log('  (no existing PC shops to wipe)');
    return;
  }
  const shopIds = shops.map((s) => s.id);
  const productIds = (
    await prisma.product.findMany({
      where: { shopId: { in: shopIds } },
      select: { id: true },
    })
  ).map((p) => p.id);

  if (productIds.length > 0) {
    await prisma.productEvent.deleteMany({ where: { productId: { in: productIds } } });
    await prisma.recentlyViewed.deleteMany({ where: { productId: { in: productIds } } });
    await prisma.trendingScore.deleteMany({ where: { productId: { in: productIds } } });
    await prisma.wishlistItem.deleteMany({ where: { productId: { in: productIds } } });
    await prisma.productImage.deleteMany({ where: { productId: { in: productIds } } });
    await prisma.productReview.deleteMany({ where: { productId: { in: productIds } } });
    await prisma.product.deleteMany({ where: { id: { in: productIds } } });
  }
  await prisma.banner.deleteMany({ where: { shopId: { in: shopIds } } });
  await prisma.shop.deleteMany({ where: { id: { in: shopIds } } });
  console.log(`  - wiped ${shops.length} PC shops (${productIds.length} products)`);
}

async function ensureShop(userId: number, m: MerchantSeed) {
  return prisma.shop.upsert({
    where: { ownerUserId: userId },
    create: {
      ownerUserId: userId,
      name: m.shopName,
      slug: m.slug,
      tagline: m.tagline,
      logoUrl: logoUrl(m.logoSeed),
      bannerUrl: m.bannerImage,
      isPublished: true,
      rating: new Prisma.Decimal('4.3'),
      ratingCount: 120 + Math.floor(Math.random() * 500),
    },
    update: {
      name: m.shopName,
      slug: m.slug,
      tagline: m.tagline,
      logoUrl: logoUrl(m.logoSeed),
      bannerUrl: m.bannerImage,
      isPublished: true,
    },
  });
}

async function seedProductsForShop(opts: {
  shopId: number;
  slugPrefix: string;
  templates: ProductTemplate[];
  catBySlug: Map<string, number>;
}): Promise<number[]> {
  const { shopId, slugPrefix, templates, catBySlug } = opts;
  const createdIds: number[] = [];
  for (let i = 0; i < templates.length; i++) {
    const t = templates[i];
    const categoryId = catBySlug.get(t.categorySlug) ?? null;
    const sku = `${slugPrefix}-${i.toString().padStart(3, '0')}-${uuid().slice(0, 4)}`;
    const bucket = IMAGES[t.bucket];
    const imageCount = 1 + (i % 3);
    const images = Array.from({ length: imageCount }, (_, k) => ({
      url: pick(bucket, i + k),
      sortOrder: k,
    }));
    const product = await prisma.product.create({
      data: {
        name: t.name,
        sku,
        mrp: asDecimal(t.mrp),
        sellingPrice: asDecimal(t.selling),
        purchasePrice: asDecimal(Math.round(t.selling * 0.78)),
        taxPercent: asDecimal(18),
        stockQuantity: asDecimal(15 + (i % 30)),
        unit: 'PCS',
        categoryId,
        shopId,
        isActive: true,
        isPublished: true,
        ratingAvg: new Prisma.Decimal((3.8 + (i % 12) * 0.1).toFixed(2)),
        ratingCount: 12 + (i % 200),
        tags: t.tags ?? [],
        highlights: t.highlights,
        specs: buildSpecs(t.highlights) as Prisma.InputJsonValue,
        offers: buildOffers(t.selling) as Prisma.InputJsonValue,
        images: { create: images },
      },
      select: { id: true },
    });
    createdIds.push(product.id);
  }
  return createdIds;
}

async function seedHeroBanners() {
  await prisma.banner.deleteMany({ where: { placement: 'HERO', shopId: null } });
  const slides = [
    { imageUrl: IMAGES.gpu[0], linkUrl: '/search?q=gpu' },
    { imageUrl: IMAGES.monitor[0], linkUrl: '/shop/pc-lumistore' },
    { imageUrl: IMAGES.headphone[0], linkUrl: '/shop/pc-soundwave-audio' },
    { imageUrl: IMAGES.laptop[0], linkUrl: '/shop/pc-mobilemuse' },
  ];
  for (let i = 0; i < slides.length; i++) {
    await prisma.banner.create({
      data: {
        placement: 'HERO',
        imageUrl: slides[i].imageUrl,
        linkUrl: slides[i].linkUrl,
        sortOrder: i,
        isActive: true,
        startAt: new Date(Date.now() - 3_600_000),
        endAt: new Date(Date.now() + 30 * 86_400_000),
      },
    });
  }
  console.log(`  + ${slides.length} hero banners`);
}

async function seedShopBanners(shopIds: Map<string, number>) {
  const cards: Array<{ placement: 'AD_STRIP' | 'PROMO' | 'CURATED_RAIL'; imageUrl: string; slug: string }> = [
    { placement: 'AD_STRIP', imageUrl: IMAGES.keyboard[0], slug: 'pc-techbazaar-india' },
    { placement: 'AD_STRIP', imageUrl: IMAGES.charger[0], slug: 'pc-powergrid-accessories' },
    { placement: 'PROMO', imageUrl: IMAGES.cable[0], slug: 'pc-nikhils-warehouse' },
    { placement: 'CURATED_RAIL', imageUrl: IMAGES.monitor[0], slug: 'pc-lumistore' },
  ];
  const shopList = [...new Set(cards.map((c) => shopIds.get(c.slug)).filter((x): x is number => x != null))];
  if (shopList.length > 0) {
    await prisma.banner.deleteMany({
      where: { placement: { in: ['AD_STRIP', 'PROMO', 'CURATED_RAIL'] }, shopId: { in: shopList } },
    });
  }
  let count = 0;
  for (let i = 0; i < cards.length; i++) {
    const c = cards[i];
    const shopId = shopIds.get(c.slug);
    if (shopId == null) continue;
    await prisma.banner.create({
      data: {
        placement: c.placement,
        shopId,
        imageUrl: c.imageUrl,
        linkUrl: `/shop/${c.slug}`,
        sortOrder: i,
        isActive: true,
        startAt: new Date(Date.now() - 3_600_000),
        endAt: new Date(Date.now() + 30 * 86_400_000),
      },
    });
    count++;
  }
  console.log(`  + ${count} shop banners`);
}

async function seedEvents(allProductIds: number[], userId: number) {
  const types: Array<'IMPRESSION' | 'TAP' | 'VIEW' | 'WISHLIST_ADD' | 'PURCHASE'> = [
    'IMPRESSION', 'IMPRESSION', 'IMPRESSION', 'IMPRESSION', 'IMPRESSION',
    'IMPRESSION', 'TAP', 'TAP', 'VIEW', 'WISHLIST_ADD',
  ];
  const now = Date.now();
  const rows: Prisma.ProductEventCreateManyInput[] = [];
  for (const productId of allProductIds) {
    const eventCount = 6 + Math.floor(Math.random() * 12);
    for (let i = 0; i < eventCount; i++) {
      rows.push({
        clientUuid: `${uuid()}-${productId}-${i}`,
        eventType: pick(types, i),
        productId,
        userId: Math.random() < 0.3 ? userId : null,
        occurredAt: new Date(now - Math.floor(Math.random() * 22 * 3_600_000)),
      });
    }
  }
  const chunkSize = 1000;
  for (let i = 0; i < rows.length; i += chunkSize) {
    await prisma.productEvent.createMany({
      data: rows.slice(i, i + chunkSize),
      skipDuplicates: true,
    });
  }
  console.log(`  + ${rows.length} product events across ${allProductIds.length} products`);
}

async function seedRecentlyViewed(productIds: number[], userId: number) {
  for (const id of productIds.slice(0, 6)) {
    await prisma.recentlyViewed.upsert({
      where: { userId_productId: { userId, productId: id } },
      create: { userId, productId: id, lastViewedAt: new Date() },
      update: { lastViewedAt: new Date() },
    });
  }
  console.log(`  + recently-viewed seeded for user #${userId}`);
}

async function main() {
  console.log('— Seeding PC catalog —');
  console.log('1. Wiping existing PC shops…');
  await wipePcShops();

  console.log('2. Ensuring categories…');
  const catBySlug = await ensureCategories();

  console.log('3. Creating users + shops…');
  const shopBySlug = new Map<string, number>();
  const userByEmail = new Map<string, number>();
  for (const m of MERCHANTS) {
    const user = await ensureUser(m);
    userByEmail.set(m.email, user.id);
    const shop = await ensureShop(user.id, m);
    shopBySlug.set(m.slug, shop.id);
    console.log(`  ✓ ${m.shopName} → shop #${shop.id}`);
  }

  console.log('5. Creating products…');
  const productsByShop = new Map<number, number[]>();
  let totalProducts = 0;
  for (let m = 0; m < MERCHANTS.length; m++) {
    const merchant = MERCHANTS[m];
    const shopId = shopBySlug.get(merchant.slug)!;
    const rotated = [...TEMPLATES.slice(m * 7), ...TEMPLATES.slice(0, m * 7)];
    const take = Math.min(45, rotated.length);
    const slice = rotated.slice(0, take);
    const slugPrefix = merchant.slug.replace(/^pc-/, '').slice(0, 12);
    const ids = await seedProductsForShop({
      shopId,
      slugPrefix,
      templates: slice,
      catBySlug,
    });
    productsByShop.set(shopId, ids);
    totalProducts += ids.length;
    console.log(`  ✓ ${merchant.shopName}: ${ids.length} products`);
  }
  console.log(`  + ${totalProducts} products across ${MERCHANTS.length} shops`);

  console.log('6. Creating image banners…');
  await seedHeroBanners();
  await seedShopBanners(shopBySlug);

  const allProductIds = Array.from(productsByShop.values()).flat();
  const devUserId = userByEmail.get('nkumawat8956@gmail.com')!;

  console.log('9. Seeding product events…');
  await seedEvents(allProductIds, devUserId);

  console.log('10. Seeding recently-viewed…');
  await seedRecentlyViewed(allProductIds, devUserId);

  console.log('11. Recomputing trending snapshot…');
  const tr = await trendingService.recomputeWindow();
  console.log(`  ✓ trending snapshot for ${tr.products} products`);

  console.log('12. Building for-you recommendations for dev user…');
  const rec = await trendingService.recomputeForUser(devUserId);
  console.log(`  ✓ ${rec.count} recommended products cached`);

  console.log('— Done —');
  await prisma.$disconnect();
}

main().catch(async (e) => {
  console.error(e);
  await prisma.$disconnect();
  process.exit(1);
});
