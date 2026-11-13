/// Demo catalogue used by "Load sample data" (Me tab). The products are real
/// listings from a2z2go.com (name, price, description, photo); the photos are
/// bundled in assets/sample so they show without internet. Stock and cost are
/// made up (cost is 70% of the price). Plain data only: the
/// store turns it into real products, orders and expenses, after which the
/// seller can edit or delete any of it like their own records.
library;

class SampleProduct {
  final String sku;
  final String name;
  final String category;
  final String description;
  final double price;
  final double cost;
  final int stock;
  final int lowStockAt;
  final bool active;
  final String brand;
  final String sourceUrl;
  final List<String> images;
  final String postUrl;
  final String postCaption;
  final List<List<String>> comments; // [author, text]
  const SampleProduct(
    this.sku,
    this.name,
    this.category,
    this.price,
    this.cost,
    this.stock, {
    this.description = '',
    this.lowStockAt = 5,
    this.active = true,
    this.brand = "",
    this.sourceUrl = "",
    this.images = const [],
    this.postUrl = "",
    this.postCaption = "",
    this.comments = const [],
  });
}

class SampleOrder {
  final int daysAgo;
  final int hour;
  final String customer; // '' = walk-in
  final String phone;
  final Map<String, int> lines; // sku -> qty
  final String status; // pending | packed | shipped | completed | cancelled
  final String payment;
  final double discount;
  final String note;
  const SampleOrder(
    this.daysAgo,
    this.hour,
    this.customer,
    this.phone,
    this.lines,
    this.status, {
    this.payment = 'GCash',
    this.discount = 0,
    this.note = '',
  });
}

class SampleExpense {
  final int daysAgo;
  final String title;
  final String category;
  final double amount;
  const SampleExpense(this.daysAgo, this.title, this.category, this.amount);
}

const sampleFirstSku = 'A2G-FD-001';

const sampleProducts = <SampleProduct>[
  // ---- A2Z2GO FOOD
  SampleProduct(
    'A2G-FD-001',
    'Macadamia Crusted Salmon with Spinach Cream Sauce (8-10pax)',
    'A2Z2GO FOOD',
    2840,
    1988,
    12,
    lowStockAt: 3,
    sourceUrl: 'https://a2z2go.com/macadamia-crusted-salmon-with-spinach-cream-sauce-8-10pax.html',
    images: ['asset:assets/sample/A2G-FD-001.jpg'],
  ),
  SampleProduct(
    'A2G-FD-002',
    '8 hour slow roasted beef belly with mashed potato (8-10pax)',
    'A2Z2GO FOOD',
    3510,
    2457,
    9,
    lowStockAt: 3,
    description: 'Preorder at least 3 days. No same day',
    sourceUrl: 'https://a2z2go.com/8-hour-slow-roasted-beef-belly-with-mashed-potato-8-10pax.html',
    images: ['asset:assets/sample/A2G-FD-002.jpg'],
  ),
  SampleProduct(
    'A2G-FD-003',
    'Bagnet Canton (8-10pax)',
    'A2Z2GO FOOD',
    810,
    567,
    14,
    lowStockAt: 3,
    sourceUrl: 'https://a2z2go.com/bagnet-canton-8-10pax.html',
    images: ['asset:assets/sample/A2G-FD-003.jpg'],
  ),
  SampleProduct(
    'A2G-FD-004',
    'Boneless Chicken Barbeque (8-10pax)',
    'A2Z2GO FOOD',
    1350,
    945,
    20,
    lowStockAt: 4,
    sourceUrl: 'https://a2z2go.com/boneless-chicken-barbeque-8-10pax.html',
    images: ['asset:assets/sample/A2G-FD-004.jpg'],
  ),
  SampleProduct(
    'A2G-FD-005',
    'Classic Ensaymada',
    'A2Z2GO FOOD',
    126,
    88.2,
    25,
    lowStockAt: 5,
    sourceUrl: 'https://a2z2go.com/classic-ensaymada.html',
    images: ['asset:assets/sample/A2G-FD-005.jpg'],
  ),
  // ---- Online Grocery
  SampleProduct(
    'A2G-GR-001',
    'Alaska Condensada 300ml x 1',
    'Online Grocery',
    57.5,
    40.25,
    40,
    lowStockAt: 8,
    sourceUrl: 'https://a2z2go.com/alaska-condensada-300ml-x-1.html',
    images: ['asset:assets/sample/A2G-GR-001.jpg'],
  ),
  SampleProduct(
    'A2G-GR-002',
    'Milo Choco Malt Drink 24g x12',
    'Online Grocery',
    125.2,
    87.64,
    60,
    lowStockAt: 10,
    sourceUrl: 'https://a2z2go.com/milo-choco-malt-drink-24g-x12.html',
    images: ['asset:assets/sample/A2G-GR-002.jpg'],
  ),
  SampleProduct(
    'A2G-GR-003',
    'Nestle All-Purpose Cream 250ml x 1',
    'Online Grocery',
    73.2,
    51.24,
    48,
    lowStockAt: 10,
    sourceUrl: 'https://a2z2go.com/nestle-all-purpose-cream-250ml-x-1.html',
    images: ['asset:assets/sample/A2G-GR-003.jpg'],
  ),
  SampleProduct(
    'A2G-GR-004',
    'Del Monte Fiesta Fruit Cocktail 836g x1',
    'Online Grocery',
    112.9,
    79.03,
    6,
    lowStockAt: 8,
    sourceUrl:
        'https://a2z2go.com/del-monte-fiesta-fruit-cocktail-836g-x1.html',
    images: ['asset:assets/sample/A2G-GR-004.jpg'],
  ),
  // ---- Household
  SampleProduct(
    'A2G-HH-001',
    'Natasha Cleaning Mamas Detergent Powder Brilliance 800g',
    'Household',
    82,
    57.4,
    35,
    lowStockAt: 8,
    sourceUrl: 'https://a2z2go.com/natasha-cleaning-mamas-detergent-powder-brilliance-800g.html',
    images: ['asset:assets/sample/A2G-HH-001.jpg'],
  ),
  SampleProduct(
    'A2G-HH-002',
    'Natasha Cleaning Mamas Fabric Conditioner Serene 1000mL',
    'Household',
    98,
    68.6,
    6,
    lowStockAt: 8,
    sourceUrl: 'https://a2z2go.com/natasha-cleaning-mamas-fabric-conditioner-serene-1000ml.html',
    images: ['asset:assets/sample/A2G-HH-002.jpg'],
  ),
  SampleProduct(
    'A2G-HH-003',
    'Garbage Bag Medium Black 22" x 24" x .001 x100',
    'Household',
    236,
    165.2,
    18,
    lowStockAt: 5,
    description: 'Garbage Bags Delivery from A2Z2GO.Garbage Bag Medium Black',
    sourceUrl:
        'https://a2z2go.com/garbage-bag-medium-black-22-x-24-x-001-x100.html',
    images: ['asset:assets/sample/A2G-HH-003.jpg'],
  ),
  SampleProduct(
    'A2G-HH-004',
    'Pride with Fabric Conditioner Sakura Blossom 2kg x1',
    'Household',
    215.30,
    165,
    40,
    lowStockAt: 8,
    brand: 'Pride',
    description: 'Laundry powder with fabric conditioner in a Sakura Blossom scent. 2kg pack.',
    sourceUrl: 'https://a2z2go.com/catalog/product/view/id/8691/s/pride-with-fabric-conditioner-sakura-blossom-2kg-x1/',
    images: ['asset:assets/sample/A2G-HH-004.jpg'],
    postUrl: 'https://www.facebook.com/PridePHL/posts/ang-blooming-na-bango-ng-sakura-blossom-nasa-pride-with-fabric-conditioner-na-ma/2856609677687109/',
    postCaption: 'Ang blooming na bango ng Sakura Blossom, nasa Pride with Fabric Conditioner na!',
  ),
  // ---- Health Care
  SampleProduct(
    'A2G-HC-001',
    'Ceelin Plus Syrup 120',
    'Health Care',
    167.7,
    117.39,
    22,
    lowStockAt: 5,
    sourceUrl: 'https://a2z2go.com/ceelin-plus-syrup-120.html',
    images: ['asset:assets/sample/A2G-HC-001.jpg'],
  ),
  SampleProduct(
    'A2G-HC-002',
    'Myra 400e',
    'Health Care',
    324,
    226.8,
    7,
    lowStockAt: 5,
    sourceUrl: 'https://a2z2go.com/myra-400e.html',
    images: ['asset:assets/sample/A2G-HC-002.jpg'],
  ),
  // ---- Electronics
  SampleProduct(
    'A2G-EL-001',
    'APC BVX1200LI-MS Easy Back UPS 1200VA/650Watts 230V AVR Universal Sockets',
    'Electronics',
    7150,
    5005,
    15,
    lowStockAt: 3,
    sourceUrl: 'https://a2z2go.com/apc-bvx1200li-ms-easy-back-ups-1200va-650watts-230v-avr-universal-sockets.html',
    images: ['asset:assets/sample/A2G-EL-001.jpg'],
  ),
  SampleProduct(
    'A2G-EL-002',
    'Acer Nitro ED270 Z Gaming Monitor – 27" FHD Curved VA, 280Hz, 1ms VRB, AMD FreeSync Technology',
    'Electronics',
    11441.64,
    8009.15,
    8,
    lowStockAt: 2,
    sourceUrl: 'https://a2z2go.com/acer-nitro-ed270-z-gaming-monitor-27-fhd-curved-va-280hz-1ms-vrb-amd-freesync-technology.html',
    images: ['asset:assets/sample/A2G-EL-002.jpg'],
  ),
  // ---- Christmas Basket
  SampleProduct(
    'A2G-XM-001',
    'Festive Feast',
    'Christmas Basket',
    445,
    311.5,
    10,
    lowStockAt: 3,
    sourceUrl: 'https://a2z2go.com/festive-feast.html',
    images: ['asset:assets/sample/A2G-XM-001.jpg'],
  ),
  SampleProduct(
    'A2G-XM-002',
    'Family Favorites',
    'Christmas Basket',
    565,
    395.5,
    5,
    lowStockAt: 3,
    sourceUrl: 'https://a2z2go.com/family-favorites.html',
    images: ['asset:assets/sample/A2G-XM-002.jpg'],
  ),
  // ---- Hidden (delisted) example
  SampleProduct(
    'A2G-FD-006',
    'Chicken Popper',
    'A2Z2GO FOOD',
    99,
    69.3,
    0,
    lowStockAt: 5,
    active: false,
    sourceUrl: 'https://a2z2go.com/chicken-popper.html',
    images: ['asset:assets/sample/A2G-FD-006.jpg'],
  ),
];

/// Newest orders first is not required; they are created oldest to newest.
const sampleOrders = <SampleOrder>[
  SampleOrder(9, 10, 'Ana Reyes', '0918 111 2222', {
    'A2G-FD-001': 1,
    'A2G-FD-005': 2,
  }, 'completed'),
  SampleOrder(
    9,
    15,
    '',
    '',
    {'A2G-GR-001': 1, 'A2G-HH-001': 2},
    'completed',
    payment: 'Cash',
  ),
  SampleOrder(8, 11, 'Marco dela Cruz', '0917 345 6789', {
    'A2G-EL-001': 2,
    'A2G-EL-002': 1,
  }, 'completed'),
  SampleOrder(
    7,
    9,
    'Liza Bautista',
    '0920 555 0101',
    {'A2G-FD-003': 1, 'A2G-FD-004': 1},
    'completed',
    payment: 'Maya',
  ),
  SampleOrder(
    6,
    14,
    'Jerome Santos',
    '0905 222 3344',
    {'A2G-XM-001': 2},
    'completed',
    discount: 150,
  ),
  SampleOrder(
    6,
    16,
    'Camille Tan',
    '0927 778 1212',
    {'A2G-HC-001': 2, 'A2G-HC-002': 1},
    'completed',
    payment: 'Bank transfer',
  ),
  SampleOrder(5, 10, 'Ana Reyes', '0918 111 2222', {
    'A2G-FD-002': 1,
  }, 'completed'),
  SampleOrder(
    4,
    13,
    'Rico Villanueva',
    '0916 909 4545',
    {'A2G-GR-004': 2, 'A2G-GR-002': 3},
    'completed',
    payment: 'COD',
  ),
  SampleOrder(
    3,
    9,
    'Joy Mendoza',
    '0998 616 7070',
    {'A2G-HH-002': 6},
    'completed',
    payment: 'Cash',
  ),
  SampleOrder(3, 17, 'Paolo Garcia', '0919 404 8080', {
    'A2G-XM-002': 1,
  }, 'completed'),
  SampleOrder(
    2,
    12,
    'Liza Bautista',
    '0920 555 0101',
    {'A2G-FD-001': 1, 'A2G-GR-003': 2},
    'cancelled',
    note: 'Customer changed delivery date',
  ),
  SampleOrder(1, 10, 'Marco dela Cruz', '0917 345 6789', {
    'A2G-FD-003': 1,
  }, 'shipped'),
  SampleOrder(
    1,
    15,
    'Camille Tan',
    '0927 778 1212',
    {'A2G-HH-003': 2, 'A2G-GR-001': 1},
    'shipped',
    payment: 'COD',
  ),
  SampleOrder(
    0,
    8,
    'Jerome Santos',
    '0905 222 3344',
    {'A2G-FD-001': 1, 'A2G-FD-005': 1},
    'completed',
    note: 'Pickup 6pm',
  ),
  SampleOrder(0, 9, 'Ana Reyes', '0918 111 2222', {'A2G-XM-001': 1}, 'packed'),
  SampleOrder(
    0,
    10,
    'Joy Mendoza',
    '0998 616 7070',
    {'A2G-FD-004': 1, 'A2G-FD-005': 1},
    'pending',
    payment: 'Cash',
  ),
  SampleOrder(0, 11, '', '', {'A2G-GR-002': 2}, 'pending', payment: 'Cash'),
];

const sampleExpenses = <SampleExpense>[
  SampleExpense(9, 'Store rent (share)', 'Rent & utilities', 880),
  SampleExpense(7, 'Packaging boxes and tape', 'Supplies', 160),
  SampleExpense(5, 'Facebook ads', 'Advertising', 380),
  SampleExpense(3, 'Courier fees', 'Shipping & packaging', 210),
  SampleExpense(1, 'Food-safe cold bags', 'Supplies', 120),
];
