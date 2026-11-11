import 'dart:convert';

import 'package:http/http.dart' as http;

/// What could be read from a public web page: used to autofill a product from
/// its listing, and to build a preview card for a social post.
class LinkInfo {
  final String url;
  final String? title;
  final String? description;
  final List<String> images;
  final double? price;
  final String? brand;
  final String? sku;

  const LinkInfo({
    required this.url,
    this.title,
    this.description,
    this.images = const [],
    this.price,
    this.brand,
    this.sku,
  });

  String? get image => images.isEmpty ? null : images.first;
  bool get isEmpty =>
      (title == null || title!.isEmpty) && images.isEmpty && price == null;
}

/// Why a link could not be read, in words a seller can act on.
class LinkImportException implements Exception {
  final String message;
  const LinkImportException(this.message);
  @override
  String toString() => message;
}

/// Downloads a public page and reads it. Only http(s) links are fetched.
Future<LinkInfo> fetchLinkInfo(String rawUrl, {http.Client? client}) async {
  final url = rawUrl.trim();
  final uri = Uri.tryParse(url);
  if (uri == null ||
      !(uri.scheme == 'http' || uri.scheme == 'https') ||
      uri.host.isEmpty) {
    throw const LinkImportException('Paste a full link starting with https://');
  }
  final c = client ?? http.Client();
  try {
    final res = await c
        .get(
          uri,
          headers: const {
            'User-Agent': 'Mozilla/5.0 (compatible; A2Z2GOSeller/1.0)',
            'Accept': 'text/html,application/xhtml+xml',
            'Accept-Language': 'en-PH,en;q=0.8',
          },
        )
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw LinkImportException(
        'The page answered with an error (${res.statusCode}).',
      );
    }
    final info = parseLinkInfo(url, res.body);
    if (info.isEmpty) {
      throw const LinkImportException(
        'That page does not share product details we can read. Fill them in by hand.',
      );
    }
    return info;
  } on LinkImportException {
    rethrow;
  } catch (_) {
    throw const LinkImportException(
      'Could not open that link. Check your internet and the link, then try again.',
    );
  } finally {
    if (client == null) c.close();
  }
}

/// Pure parsing, so it can be tested without a network.
LinkInfo parseLinkInfo(String url, String html) {
  final base = Uri.tryParse(url);

  String? abs(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    final u = Uri.tryParse(s.trim());
    if (u == null) return null;
    final r = base == null ? u : base.resolveUri(u);
    return (r.scheme == 'http' || r.scheme == 'https') ? r.toString() : null;
  }

  // ---- JSON-LD (what shops publish for search engines): best source.
  Map<String, dynamic>? product;
  final ld = RegExp(
    r'<script[^>]+type=["\x27]application/ld\+json["\x27][^>]*>(.*?)</script>',
    caseSensitive: false,
    dotAll: true,
  );
  for (final m in ld.allMatches(html)) {
    try {
      final found = _findProduct(jsonDecode(m.group(1)!.trim()));
      if (found != null) {
        product = found;
        break;
      }
    } catch (_) {}
  }

  final meta = _metaTags(html);
  String? clean(Object? v) {
    if (v == null) return null;
    final s = _decode(v.toString()).replaceAll(RegExp(r'\s+'), ' ').trim();
    return s.isEmpty ? null : s;
  }

  final images = <String>[];
  void addImage(Object? v) {
    if (v is String) {
      final a = abs(v);
      // Shops often list the same photo twice at different cached sizes.
      String file(String x) {
        final s = Uri.parse(x).pathSegments;
        return s.isEmpty ? x : s.last;
      }

      if (a != null && !images.any((x) => file(x) == file(a))) images.add(a);
    } else if (v is List) {
      v.forEach(addImage);
    } else if (v is Map) {
      addImage(v['url'] ?? v['contentUrl']);
    }
  }

  double? price;
  String? brand;
  String? sku;
  String? title;
  String? description;

  if (product != null) {
    title = clean(product['name']);
    description = clean(product['description']);
    addImage(product['image']);
    final b = product['brand'];
    brand = clean(b is Map ? b['name'] : b);
    sku = clean(product['sku']);
    final offers = product['offers'];
    final offer = offers is List && offers.isNotEmpty ? offers.first : offers;
    if (offer is Map) {
      price = _num(offer['price'] ?? offer['lowPrice']);
    }
  }

  title ??= clean(meta['og:title'] ?? meta['twitter:title']) ?? _title(html);
  description ??= clean(
    meta['og:description'] ??
        meta['twitter:description'] ??
        meta['description'],
  );
  addImage(meta['og:image'] ?? meta['twitter:image']);
  price ??= _num(meta['product:price:amount'] ?? meta['og:price:amount']);
  brand ??= clean(meta['product:brand']);

  return LinkInfo(
    url: url,
    title: title,
    description: description,
    images: images,
    price: price,
    brand: brand,
    sku: sku,
  );
}

Map<String, dynamic>? _findProduct(Object? node) {
  if (node is List) {
    for (final e in node) {
      final f = _findProduct(e);
      if (f != null) return f;
    }
  } else if (node is Map) {
    final t = node['@type'];
    final isProduct = t == 'Product' || (t is List && t.contains('Product'));
    if (isProduct) return node.cast<String, dynamic>();
    final graph = node['@graph'];
    if (graph != null) return _findProduct(graph);
  }
  return null;
}

double? _num(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', '').trim());
}

String? _title(String html) {
  final m = RegExp(
    r'<title[^>]*>(.*?)</title>',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(html);
  final t = m == null ? null : _decode(m.group(1)!).trim();
  return (t == null || t.isEmpty) ? null : t;
}

Map<String, String> _metaTags(String html) {
  final out = <String, String>{};
  for (final m in RegExp(
    r'<meta\s[^>]*>',
    caseSensitive: false,
  ).allMatches(html)) {
    final tag = m.group(0)!;
    String? attr(String name) {
      final r = RegExp(
        '$name\\s*=\\s*(?:"([^"]*)"|\'([^\']*)\')',
        caseSensitive: false,
      ).firstMatch(tag);
      return r == null ? null : (r.group(1) ?? r.group(2));
    }

    final key = attr('property') ?? attr('name');
    final content = attr('content');
    if (key != null && content != null) {
      out.putIfAbsent(key.toLowerCase(), () => _decode(content));
    }
  }
  return out;
}

String _decode(String s) {
  return s
      .replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
        final code = int.tryParse(m.group(1)!);
        return code == null ? m.group(0)! : String.fromCharCode(code);
      })
      .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
        final code = int.tryParse(m.group(1)!, radix: 16);
        return code == null ? m.group(0)! : String.fromCharCode(code);
      })
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ');
}
