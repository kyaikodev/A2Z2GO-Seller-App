import '../core/format.dart';

/// Times are saved in UTC (unambiguous when synced) and read back as local.
/// Older saves had local times without an offset; those read the same as before.
DateTime? _parseTime(String s) => DateTime.tryParse(s)?.toLocal();

// ---------------------------------------------------------------- Account

class SellerAccount {
  final String phone; // normalized +639XXXXXXXXX, doubles as the account id
  String ownerName;
  String storeName;
  String address;
  final DateTime createdAt;

  SellerAccount({
    required this.phone,
    required this.ownerName,
    required this.storeName,
    this.address = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'phone': phone,
    'ownerName': ownerName,
    'storeName': storeName,
    'address': address,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory SellerAccount.fromJson(Map<String, dynamic> j) => SellerAccount(
    phone: j['phone'] as String,
    ownerName: j['ownerName'] as String? ?? '',
    storeName: j['storeName'] as String? ?? '',
    address: j['address'] as String? ?? '',
    createdAt: _parseTime(j['createdAt'] as String? ?? ''),
  );
}

// ---------------------------------------------------------------- Product

/// The shortest description a product needs before it is shared with buyers.
const minDescriptionLength = 20;

/// Categories offered to a new shop, next to the ones it already uses.
const starterCategories = [
  'Online Grocery',
  'Household',
  'Personal Care',
  'Health Care',
  'Food & Drinks',
  'Baby & Kids',
  'Beauty',
  'Electronics',
  'Other',
];

class Product {
  final String id;
  String sku;
  String name;
  String category;
  String description;
  double price;
  double cost;
  int stock;
  int lowStockAt;

  /// Photos, cover first. Each entry is a file path on this phone or an
  /// http(s) address (photos taken from an imported product page).
  List<String> images;
  String brand;

  /// Where the product is listed elsewhere (e.g. its a2z2go.com page).
  String sourceUrl;

  /// Social posts (Facebook, Instagram, TikTok...) shown to buyers as proof.
  List<SocialPost> posts;
  bool active;
  final DateTime createdAt;

  Product({
    required this.id,
    required this.sku,
    required this.name,
    this.category = 'General',
    this.description = '',
    required this.price,
    this.cost = 0,
    this.stock = 0,
    this.lowStockAt = 5,
    List<String>? images,
    this.brand = '',
    this.sourceUrl = '',
    List<SocialPost>? posts,
    this.active = true,
    DateTime? createdAt,
  }) : images = images ?? [],
       posts = posts ?? [],
       createdAt = createdAt ?? DateTime.now();

  /// The cover photo.
  String? get imagePath => images.isEmpty ? null : images.first;

  int get commentCount => posts.fold(0, (s, p) => s + p.comments.length);

  /// What a product still needs before it can be shared with buyers. A
  /// product can be saved without these, but buyers should not see it half done.
  List<String> get missingForBuyers => [
    if (images.isEmpty) 'a photo',
    if (description.trim().length < minDescriptionLength)
      'a description (at least $minDescriptionLength letters)',
  ];

  bool get readyForBuyers => missingForBuyers.isEmpty;

  bool get isOut => stock <= 0;
  bool get isLow => stock > 0 && stock <= lowStockAt;
  double get margin => price <= 0 ? 0 : (price - cost) / price;

  Map<String, dynamic> toJson() => {
    'id': id,
    'sku': sku,
    'name': name,
    'category': category,
    'description': description,
    'price': price,
    'cost': cost,
    'stock': stock,
    'lowStockAt': lowStockAt,
    'images': images,
    'brand': brand,
    'sourceUrl': sourceUrl,
    'posts': posts.map((e) => e.toJson()).toList(),
    'active': active,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory Product.fromJson(Map<String, dynamic> j) {
    final images = <String>[
      for (final e in (j['images'] as List? ?? const [])) e as String,
    ];
    // Older saves had a single photo.
    final legacy = j['imagePath'] as String?;
    if (images.isEmpty && legacy != null) images.add(legacy);
    return Product(
      id: j['id'] as String,
      sku: j['sku'] as String? ?? '',
      name: j['name'] as String? ?? '',
      category: j['category'] as String? ?? 'General',
      description: j['description'] as String? ?? '',
      price: (j['price'] as num?)?.toDouble() ?? 0,
      cost: (j['cost'] as num?)?.toDouble() ?? 0,
      stock: (j['stock'] as num?)?.toInt() ?? 0,
      lowStockAt: (j['lowStockAt'] as num?)?.toInt() ?? 5,
      images: images,
      brand: j['brand'] as String? ?? '',
      sourceUrl: j['sourceUrl'] as String? ?? '',
      posts: [
        for (final e in (j['posts'] as List? ?? const []))
          SocialPost.fromJson(e as Map<String, dynamic>),
      ],
      active: j['active'] as bool? ?? true,
      createdAt: _parseTime(j['createdAt'] as String? ?? ''),
    );
  }
}

// ------------------------------------------------------------ Social proof

enum SocialPlatform {
  facebook,
  instagram,
  tiktok,
  youtube,
  shopee,
  lazada,
  link,
}

extension SocialPlatformX on SocialPlatform {
  String get label => switch (this) {
    SocialPlatform.facebook => 'Facebook',
    SocialPlatform.instagram => 'Instagram',
    SocialPlatform.tiktok => 'TikTok',
    SocialPlatform.youtube => 'YouTube',
    SocialPlatform.shopee => 'Shopee',
    SocialPlatform.lazada => 'Lazada',
    SocialPlatform.link => 'Link',
  };

  static SocialPlatform fromUrl(String url) {
    final host = (Uri.tryParse(url.trim())?.host ?? '').toLowerCase();
    bool has(String s) => host == s || host.endsWith('.$s');
    if (has('facebook.com') || has('fb.com') || has('fb.watch')) {
      return SocialPlatform.facebook;
    }
    if (has('instagram.com')) return SocialPlatform.instagram;
    if (has('tiktok.com')) return SocialPlatform.tiktok;
    if (has('youtube.com') || has('youtu.be')) return SocialPlatform.youtube;
    if (has('shopee.ph') || has('shopee.com')) return SocialPlatform.shopee;
    if (has('lazada.com.ph') || has('lazada.com')) return SocialPlatform.lazada;
    return SocialPlatform.link;
  }
}

/// A public comment copied by the seller from the original post. It always
/// travels with the post's link so buyers can check the source.
class SharedComment {
  final String id;
  String author;
  String text;

  /// True for the built-in demo shop, shown to buyers as a sample.
  bool demo;
  final DateTime addedAt;

  SharedComment({
    required this.id,
    required this.author,
    required this.text,
    this.demo = false,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'author': author,
    'text': text,
    'demo': demo,
    'addedAt': addedAt.toUtc().toIso8601String(),
  };

  factory SharedComment.fromJson(Map<String, dynamic> j) => SharedComment(
    id: j['id'] as String,
    author: j['author'] as String? ?? '',
    text: j['text'] as String? ?? '',
    demo: j['demo'] as bool? ?? false,
    addedAt: _parseTime(j['addedAt'] as String? ?? ''),
  );
}

class SocialPost {
  final String id;
  SocialPlatform platform;
  String url;
  String title; // caption or page title
  String? thumbUrl;
  final List<SharedComment> comments;
  final DateTime addedAt;

  SocialPost({
    required this.id,
    required this.platform,
    required this.url,
    this.title = '',
    this.thumbUrl,
    List<SharedComment>? comments,
    DateTime? addedAt,
  }) : comments = comments ?? [],
       addedAt = addedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'platform': platform.name,
    'url': url,
    'title': title,
    'thumbUrl': thumbUrl,
    'comments': comments.map((e) => e.toJson()).toList(),
    'addedAt': addedAt.toUtc().toIso8601String(),
  };

  factory SocialPost.fromJson(Map<String, dynamic> j) => SocialPost(
    id: j['id'] as String,
    platform: SocialPlatform.values.firstWhere(
      (e) => e.name == j['platform'],
      orElse: () => SocialPlatform.link,
    ),
    url: j['url'] as String? ?? '',
    title: j['title'] as String? ?? '',
    thumbUrl: j['thumbUrl'] as String?,
    comments: [
      for (final e in (j['comments'] as List? ?? const []))
        SharedComment.fromJson(e as Map<String, dynamic>),
    ],
    addedAt: _parseTime(j['addedAt'] as String? ?? ''),
  );
}

// ------------------------------------------------------------ Stock moves

enum MoveType { stockIn, stockOut, damaged, sale, restore, returned, adjust }

extension MoveTypeX on MoveType {
  String get label => switch (this) {
    MoveType.stockIn => 'Stock in',
    MoveType.stockOut => 'Stock out',
    MoveType.damaged => 'Damaged / lost',
    MoveType.sale => 'Sold (order)',
    MoveType.restore => 'Order cancelled',
    MoveType.returned => 'Customer return',
    MoveType.adjust => 'Count correction',
  };
}

class StockMove {
  final String id;
  final String productId;
  final String productName;
  final MoveType type;
  final int delta; // signed change to stock
  final double unitCost; // cost snapshot, used for damaged-stock losses
  final String note;
  final String? orderId;
  final DateTime at;

  StockMove({
    required this.id,
    required this.productId,
    required this.productName,
    required this.type,
    required this.delta,
    this.unitCost = 0,
    this.note = '',
    this.orderId,
    DateTime? at,
  }) : at = at ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'productId': productId,
    'productName': productName,
    'type': type.name,
    'delta': delta,
    'unitCost': unitCost,
    'note': note,
    'orderId': orderId,
    'at': at.toUtc().toIso8601String(),
  };

  factory StockMove.fromJson(Map<String, dynamic> j) => StockMove(
    id: j['id'] as String,
    productId: j['productId'] as String,
    productName: j['productName'] as String? ?? '',
    type: MoveType.values.firstWhere(
      (t) => t.name == j['type'],
      orElse: () => MoveType.adjust,
    ),
    delta: (j['delta'] as num?)?.toInt() ?? 0,
    unitCost: (j['unitCost'] as num?)?.toDouble() ?? 0,
    note: j['note'] as String? ?? '',
    orderId: j['orderId'] as String?,
    at: _parseTime(j['at'] as String? ?? ''),
  );
}

// ----------------------------------------------------------------- Orders

enum OrderStatus { pending, packed, shipped, completed, cancelled }

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
    OrderStatus.pending => 'Pending',
    OrderStatus.packed => 'Packed',
    OrderStatus.shipped => 'Shipped',
    OrderStatus.completed => 'Completed',
    OrderStatus.cancelled => 'Cancelled',
  };

  OrderStatus? get next => switch (this) {
    OrderStatus.pending => OrderStatus.packed,
    OrderStatus.packed => OrderStatus.shipped,
    OrderStatus.shipped => OrderStatus.completed,
    _ => null,
  };

  bool get isOpen =>
      this == OrderStatus.pending ||
      this == OrderStatus.packed ||
      this == OrderStatus.shipped;
}

const paymentMethods = ['Cash', 'GCash', 'Maya', 'Bank transfer', 'COD'];

class OrderItem {
  final String productId;
  final String name; // snapshot so history survives product deletion
  final int qty;
  final double unitPrice;
  final double unitCost;

  OrderItem({
    required this.productId,
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.unitCost,
  });

  double get lineTotal => r2(unitPrice * qty);
  double get lineCost => r2(unitCost * qty);

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'name': name,
    'qty': qty,
    'unitPrice': unitPrice,
    'unitCost': unitCost,
  };

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
    productId: j['productId'] as String,
    name: j['name'] as String? ?? '',
    qty: (j['qty'] as num?)?.toInt() ?? 0,
    unitPrice: (j['unitPrice'] as num?)?.toDouble() ?? 0,
    unitCost: (j['unitCost'] as num?)?.toDouble() ?? 0,
  );
}

class Order {
  final String id;
  final int number; // human friendly #1001
  String customerName;
  String customerPhone; // normalized or empty
  final List<OrderItem> items;
  double discount; // includes the peso value of any points used
  int pointsUsed; // loyalty points the customer paid part of it with
  String payment;
  String note;
  OrderStatus status;
  DateTime createdAt;
  DateTime? completedAt;

  Order({
    required this.id,
    required this.number,
    this.customerName = '',
    this.customerPhone = '',
    required this.items,
    this.discount = 0,
    this.pointsUsed = 0,
    this.payment = 'Cash',
    this.note = '',
    this.status = OrderStatus.pending,
    DateTime? createdAt,
    this.completedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get subtotal => r2(items.fold(0.0, (s, i) => s + i.lineTotal));
  double get total => r2((subtotal - discount).clamp(0, double.infinity));
  double get cost => r2(items.fold(0.0, (s, i) => s + i.lineCost));
  int get itemCount => items.fold(0, (s, i) => s + i.qty);
  String get displayCustomer =>
      customerName.trim().isEmpty ? 'Walk-in customer' : customerName;

  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'items': items.map((e) => e.toJson()).toList(),
    'discount': discount,
    'pointsUsed': pointsUsed,
    'payment': payment,
    'note': note,
    'status': status.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'completedAt': completedAt?.toUtc().toIso8601String(),
  };

  factory Order.fromJson(Map<String, dynamic> j) => Order(
    id: j['id'] as String,
    number: (j['number'] as num?)?.toInt() ?? 0,
    customerName: j['customerName'] as String? ?? '',
    customerPhone: j['customerPhone'] as String? ?? '',
    items: ((j['items'] as List?) ?? [])
        .map((e) => OrderItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    discount: (j['discount'] as num?)?.toDouble() ?? 0,
    pointsUsed: (j['pointsUsed'] as num?)?.toInt() ?? 0,
    payment: j['payment'] as String? ?? 'Cash',
    note: j['note'] as String? ?? '',
    status: OrderStatus.values.firstWhere(
      (s) => s.name == j['status'],
      orElse: () => OrderStatus.pending,
    ),
    createdAt: _parseTime(j['createdAt'] as String? ?? ''),
    completedAt: _parseTime(j['completedAt'] as String? ?? ''),
  );
}

// ---------------------------------------------------------------- Returns

enum ReturnStatus { requested, approved, rejected }

extension ReturnStatusX on ReturnStatus {
  String get label => switch (this) {
    ReturnStatus.requested => 'Requested',
    ReturnStatus.approved => 'Refunded',
    ReturnStatus.rejected => 'Rejected',
  };
}

const returnReasons = [
  'Damaged item',
  'Wrong item sent',
  'Not as described',
  'Changed mind',
  'Other',
];

class ReturnItem {
  final String productId;
  final String name;
  final int qty;
  final double unitPrice;
  final double unitCost;

  ReturnItem({
    required this.productId,
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.unitCost,
  });

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'name': name,
    'qty': qty,
    'unitPrice': unitPrice,
    'unitCost': unitCost,
  };

  factory ReturnItem.fromJson(Map<String, dynamic> j) => ReturnItem(
    productId: j['productId'] as String,
    name: j['name'] as String? ?? '',
    qty: (j['qty'] as num?)?.toInt() ?? 0,
    unitPrice: (j['unitPrice'] as num?)?.toDouble() ?? 0,
    unitCost: (j['unitCost'] as num?)?.toDouble() ?? 0,
  );
}

class ReturnRequest {
  final String id;
  final String orderId;
  final int orderNumber;
  final String customerName;
  final String customerPhone;
  final List<ReturnItem> items;
  final String reason;
  final String note;
  double refund;
  bool restock; // put the items back into stock when approved
  ReturnStatus status;
  final DateTime createdAt;
  DateTime? resolvedAt;

  ReturnRequest({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    this.customerName = '',
    this.customerPhone = '',
    required this.items,
    required this.reason,
    this.note = '',
    required this.refund,
    this.restock = true,
    this.status = ReturnStatus.requested,
    DateTime? createdAt,
    this.resolvedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int get qty => items.fold(0, (s, i) => s + i.qty);
  double get cost => r2(items.fold(0.0, (s, i) => s + i.unitCost * i.qty));

  Map<String, dynamic> toJson() => {
    'id': id,
    'orderId': orderId,
    'orderNumber': orderNumber,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'items': items.map((e) => e.toJson()).toList(),
    'reason': reason,
    'note': note,
    'refund': refund,
    'restock': restock,
    'status': status.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'resolvedAt': resolvedAt?.toUtc().toIso8601String(),
  };

  factory ReturnRequest.fromJson(Map<String, dynamic> j) => ReturnRequest(
    id: j['id'] as String,
    orderId: j['orderId'] as String? ?? '',
    orderNumber: (j['orderNumber'] as num?)?.toInt() ?? 0,
    customerName: j['customerName'] as String? ?? '',
    customerPhone: j['customerPhone'] as String? ?? '',
    items: ((j['items'] as List?) ?? [])
        .map((e) => ReturnItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    reason: j['reason'] as String? ?? '',
    note: j['note'] as String? ?? '',
    refund: (j['refund'] as num?)?.toDouble() ?? 0,
    restock: j['restock'] as bool? ?? true,
    status: ReturnStatus.values.firstWhere(
      (s) => s.name == j['status'],
      orElse: () => ReturnStatus.requested,
    ),
    createdAt: _parseTime(j['createdAt'] as String? ?? ''),
    resolvedAt: _parseTime(j['resolvedAt'] as String? ?? ''),
  );
}

// --------------------------------------------------------------- Expenses

const expenseCategories = [
  'Shipping & packaging',
  'Rent & utilities',
  'Advertising',
  'Salaries',
  'Supplies',
  'Fees & taxes',
  'Other',
];

class Expense {
  final String id;
  String title;
  String category;
  double amount;
  String note;
  DateTime date;

  Expense({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    this.note = '',
    DateTime? date,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'amount': amount,
    'note': note,
    'date': date.toUtc().toIso8601String(),
  };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    category: j['category'] as String? ?? 'Other',
    amount: (j['amount'] as num?)?.toDouble() ?? 0,
    note: j['note'] as String? ?? '',
    date: _parseTime(j['date'] as String? ?? ''),
  );
}

// ---------------------------------------------------------------- Loyalty

class LoyaltyConfig {
  bool enabled;
  double pesoPerPoint; // spend this much to earn 1 point
  double pesoPerPointValue; // what 1 point is worth when redeemed

  LoyaltyConfig({
    this.enabled = true,
    this.pesoPerPoint = 100,
    this.pesoPerPointValue = 1,
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'pesoPerPoint': pesoPerPoint,
    'pesoPerPointValue': pesoPerPointValue,
  };

  factory LoyaltyConfig.fromJson(Map<String, dynamic> j) => LoyaltyConfig(
    enabled: j['enabled'] as bool? ?? true,
    pesoPerPoint: (j['pesoPerPoint'] as num?)?.toDouble() ?? 100,
    pesoPerPointValue: (j['pesoPerPointValue'] as num?)?.toDouble() ?? 1,
  );
}

enum LoyaltyType { earn, redeem, adjust, reversal }

extension LoyaltyTypeX on LoyaltyType {
  String get label => switch (this) {
    LoyaltyType.earn => 'Earned',
    LoyaltyType.redeem => 'Redeemed',
    LoyaltyType.adjust => 'Adjustment',
    LoyaltyType.reversal => 'Reversed (return)',
  };
}

class LoyaltyTxn {
  final String id;
  final String phone;
  final String name;
  final int points; // signed
  final LoyaltyType type;
  final String? orderId;
  final String?
  returnId; // set on refund reversals, so one return can be undone alone
  final String note;
  final DateTime at;

  LoyaltyTxn({
    required this.id,
    required this.phone,
    required this.name,
    required this.points,
    required this.type,
    this.orderId,
    this.returnId,
    this.note = '',
    DateTime? at,
  }) : at = at ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'phone': phone,
    'name': name,
    'points': points,
    'type': type.name,
    'orderId': orderId,
    'returnId': returnId,
    'note': note,
    'at': at.toUtc().toIso8601String(),
  };

  factory LoyaltyTxn.fromJson(Map<String, dynamic> j) => LoyaltyTxn(
    id: j['id'] as String,
    phone: j['phone'] as String? ?? '',
    name: j['name'] as String? ?? '',
    points: (j['points'] as num?)?.toInt() ?? 0,
    type: LoyaltyType.values.firstWhere(
      (t) => t.name == j['type'],
      orElse: () => LoyaltyType.adjust,
    ),
    orderId: j['orderId'] as String?,
    returnId: j['returnId'] as String?,
    note: j['note'] as String? ?? '',
    at: _parseTime(j['at'] as String? ?? ''),
  );
}

class LoyaltyCustomer {
  final String phone;
  String name;
  int balance;
  int earned;
  int redeemed;
  DateTime? lastActivity;

  LoyaltyCustomer({
    required this.phone,
    required this.name,
    this.balance = 0,
    this.earned = 0,
    this.redeemed = 0,
    this.lastActivity,
  });
}
