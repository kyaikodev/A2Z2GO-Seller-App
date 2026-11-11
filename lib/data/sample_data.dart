/// Demo catalogue used by "Load sample data" (Me tab). Plain data only: the
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
    1850,
    12,
    lowStockAt: 3,
    description:
        'Oven-ready salmon fillets with a macadamia crust, served with creamy '
        'spinach sauce. Party tray good for 8-10 people. Order 2 days ahead.',
    sourceUrl: 'https://a2z2go.com/macadamia-crusted-salmon-with-spinach-cream-sauce-8-10pax.html',
    images: [
      'https://a2z2golive-media.s3.ap-southeast-1.amazonaws.com/catalog/product/cache/74c1057f7991b4edb2bc7bdaa94de933/m/a/macadamia_crusted_salmon_crusted_salmon_with_spinach_cream_sauce_2.png',
    ],
  ),
  SampleProduct(
    'A2G-FD-002',
    'Baked Salmon Teriyaki Party Tray (8-10pax)',
    'A2Z2GO FOOD',
    2450,
    1600,
    9,
    lowStockAt: 3,
    description: 'Teriyaki-glazed baked salmon with sesame and steamed greens.',
  ),
  SampleProduct(
    'A2G-FD-003',
    'Beef Caldereta Party Tray (8-10pax)',
    'A2Z2GO FOOD',
    1980,
    1250,
    14,
    lowStockAt: 3,
    description: 'Slow-cooked beef in tomato and liver sauce with potatoes.',
  ),
  SampleProduct(
    'A2G-FD-004',
    'Pancit Canton Party Tray (8-10pax)',
    'A2Z2GO FOOD',
    1150,
    700,
    20,
    lowStockAt: 4,
  ),
  SampleProduct(
    'A2G-FD-005',
    'Leche Flan Llanera (Large)',
    'A2Z2GO FOOD',
    380,
    210,
    25,
  ),
  // ---- Online Grocery
  SampleProduct(
    'A2G-GR-001',
    'Premium Jasmine Rice 5kg',
    'Online Grocery',
    365,
    310,
    40,
    lowStockAt: 8,
  ),
  SampleProduct(
    'A2G-GR-002',
    'Instant Pancit Canton Calamansi 60g (Pack of 6)',
    'Online Grocery',
    69,
    52,
    60,
    lowStockAt: 12,
  ),
  SampleProduct(
    'A2G-GR-003',
    'Cooking Oil 1L',
    'Online Grocery',
    118,
    98,
    48,
    lowStockAt: 10,
  ),
  SampleProduct(
    'A2G-GR-004',
    'Arabica Ground Coffee 250g',
    'Online Grocery',
    295,
    190,
    6,
  ),
  // ---- Household
  SampleProduct(
    'A2G-HH-001',
    'Dishwashing Liquid Lemon 500ml',
    'Household',
    89,
    58,
    35,
    lowStockAt: 8,
  ),
  SampleProduct(
    'A2G-HH-002',
    'Laundry Detergent Powder 1kg',
    'Household',
    135,
    95,
    6,
  ),
  SampleProduct(
    'A2G-HH-003',
    'Facial Tissue 3-Ply (Pack of 12)',
    'Household',
    160,
    115,
    18,
    lowStockAt: 6,
  ),
  // Real a2z2go listing + the brand's public Facebook post, with sample
  // comments (marked "Sample" for buyers) to show how proof looks.
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
    images: [
      'https://a2z2golive-media.s3.ap-southeast-1.amazonaws.com/catalog/product/cache/74c1057f7991b4edb2bc7bdaa94de933/1/7/1771568032pride_with_fabric_conditioner_sakura_blossom___2kg_x1.png',
    ],
    postUrl: 'https://www.facebook.com/PridePHL/posts/ang-blooming-na-bango-ng-sakura-blossom-nasa-pride-with-fabric-conditioner-na-ma/2856609677687109/',
    postCaption: 'Ang blooming na bango ng Sakura Blossom, nasa Pride with Fabric Conditioner na!',
  ),
  // ---- Health Care
  SampleProduct(
    'A2G-HC-001',
    'Vitamin C 500mg (100 tablets)',
    'Health Care',
    420,
    270,
    22,
    lowStockAt: 6,
  ),
  SampleProduct(
    'A2G-HC-002',
    'Digital Thermometer',
    'Health Care',
    350,
    210,
    7,
  ),
  // ---- Electronics
  SampleProduct(
    'A2G-EL-001',
    'USB-C Fast Charger 20W',
    'Electronics',
    599,
    330,
    15,
    lowStockAt: 4,
  ),
  SampleProduct(
    'A2G-EL-002',
    'Wireless Earbuds',
    'Electronics',
    1299,
    720,
    8,
    lowStockAt: 3,
  ),
  // ---- Christmas Basket
  SampleProduct(
    'A2G-XM-001',
    'Christmas Gift Basket - Classic',
    'Christmas Basket',
    1899,
    1200,
    10,
    lowStockAt: 3,
    description:
        'Ham, queso de bola, spaghetti kit, chocolates and fruit cake.',
  ),
  SampleProduct(
    'A2G-XM-002',
    'Christmas Hamper - Premium',
    'Christmas Basket',
    3999,
    2600,
    5,
    lowStockAt: 3,
  ),
  // ---- Hidden (delisted) example
  SampleProduct(
    'A2G-FD-006',
    'Roast Turkey 5kg (Seasonal)',
    'A2Z2GO FOOD',
    4500,
    3100,
    0,
    active: false,
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
  SampleExpense(9, 'Store rent (share)', 'Rent & utilities', 3500),
  SampleExpense(7, 'Packaging boxes and tape', 'Supplies', 620),
  SampleExpense(5, 'Facebook ads', 'Advertising', 1500),
  SampleExpense(3, 'Courier fees', 'Shipping & packaging', 850),
  SampleExpense(1, 'Food-safe cold bags', 'Supplies', 480),
];
