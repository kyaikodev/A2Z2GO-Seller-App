import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/link_import.dart';
import '../../data/models.dart';
import '../../data/store.dart' show Result;
import '../../widgets/common.dart';
import '../../widgets/pick_field.dart';
import '../../widgets/scope.dart';
import 'proof_screen.dart' show SocialProofSection;

/// Add a product, or edit one when [productId] is given.
class ProductFormScreen extends StatefulWidget {
  final String? productId;
  const ProductFormScreen({super.key, this.productId});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  static const _maxPhotos = 8;

  final _form = GlobalKey<FormState>();
  // One key per required field, in the order they appear: after a failed save
  // the screen scrolls to the first one that is missing.
  final _nameKey = GlobalKey<FormFieldState<String>>();
  final _categoryKey = GlobalKey<FormFieldState<String>>();
  final _skuKey = GlobalKey<FormFieldState<String>>();
  final _priceKey = GlobalKey<FormFieldState<String>>();
  final _costKey = GlobalKey<FormFieldState<String>>();
  final _stockKey = GlobalKey<FormFieldState<String>>();
  final _lowKey = GlobalKey<FormFieldState<String>>();
  final _brandKey = GlobalKey<FormFieldState<String>>();
  bool _tried = false; // a save was tried: check fields as the seller types
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _category = TextEditingController();
  final _brand = TextEditingController();
  final _source = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  final _cost = TextEditingController();
  final _stock = TextEditingController(text: '0');
  final _low = TextEditingController(text: '5');

  Product? _editing;
  bool _loaded = false;
  bool _active = true;

  /// Photos in display order, cover first. A photo is a saved file, a web
  /// address, or a freshly picked file that is copied into app storage on save.
  final List<String> _photos = [];
  final Set<String> _fresh = {};

  /// Linked social posts, saved with the product.
  final List<SocialPost> _posts = [];
  bool _saving = false;
  bool _dirty = false; // something was typed or changed
  bool _importing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final store = context.store;
    if (widget.productId != null) {
      final p = store.productById(widget.productId!);
      if (p != null) {
        _editing = p;
        _name.text = p.name;
        _sku.text = p.sku;
        _category.text = p.category;
        _brand.text = p.brand;
        _source.text = p.sourceUrl;
        _desc.text = p.description;
        _price.text = plainAmount(p.price);
        _cost.text = plainAmount(p.cost);
        _low.text = p.lowStockAt.toString();
        _active = p.active;
        _photos.addAll(p.images);
        _posts.addAll(p.posts);
      }
    } else {
      _sku.text = store.nextSku();
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _sku,
      _category,
      _brand,
      _source,
      _desc,
      _price,
      _cost,
      _stock,
      _low,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ----------------------------------------------------------------- photos

  Future<void> _pick(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final paths = <String>[];
      if (source == ImageSource.gallery) {
        final xs = await picker.pickMultiImage(
          maxWidth: 1280,
          imageQuality: 82,
        );
        paths.addAll(xs.map((x) => x.path));
      } else {
        final x = await picker.pickImage(
          source: source,
          maxWidth: 1280,
          imageQuality: 82,
        );
        if (x != null) paths.add(x.path);
      }
      if (paths.isEmpty) return;
      setState(() {
        _dirty = true;
        for (final p in paths) {
          if (_photos.length >= _maxPhotos) break;
          _photos.add(p);
          _fresh.add(p);
        }
      });
    } catch (_) {
      if (mounted) {
        showMsg(context, 'Could not open the camera or gallery.', error: true);
      }
    }
  }

  void _addPhotoSheet() {
    if (_photos.length >= _maxPhotos) {
      showMsg(context, 'Up to $_maxPhotos photos per product.', error: true);
      return;
    }
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              subtitle: const Text('You can pick several at once'),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _photoOptions(int i) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (i != 0)
              ListTile(
                leading: const Icon(Icons.star_outline),
                title: const Text('Make cover photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _dirty = true;
                    _photos.insert(0, _photos.removeAt(i));
                  });
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Brand.bad),
              title: const Text(
                'Remove photo',
                style: TextStyle(color: Brand.bad),
              ),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _dirty = true;
                  final gone = _photos.removeAt(i);
                  _fresh.remove(gone);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Copies a freshly picked photo into the app's own folder so it survives
  /// cache clears. (The web preview keeps the browser's own address.)
  Future<String> _persist(String temp, String id) async {
    if (kIsWeb) return temp;
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/product_images');
    if (!folder.existsSync()) folder.createSync(recursive: true);
    final dest =
        '${folder.path}/$id-${DateTime.now().microsecondsSinceEpoch}.jpg';
    await File(temp).copy(dest);
    return dest;
  }

  /// Saves a web photo (from an imported product page) on this phone, so it
  /// still shows offline and if the page changes. If the download fails, the
  /// address is kept and the photo simply loads from the web as before.
  Future<String> _download(String url, String id) async {
    if (kIsWeb || !url.startsWith('http')) return url;
    try {
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200 ||
          res.bodyBytes.isEmpty ||
          res.bodyBytes.length > 8 * 1024 * 1024) {
        return url;
      }
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory('${dir.path}/product_images');
      if (!folder.existsSync()) folder.createSync(recursive: true);
      final dest =
          '${folder.path}/$id-${DateTime.now().microsecondsSinceEpoch}.jpg';
      await File(dest).writeAsBytes(res.bodyBytes);
      return dest;
    } catch (_) {
      return url;
    }
  }

  // --------------------------------------------------------------- autofill

  Future<void> _autofill() async {
    FocusScope.of(context).unfocus();
    setState(() => _importing = true);
    try {
      final info = await fetchLinkInfo(_source.text);
      if (!mounted) return;
      final filled = <String>[];
      if (_name.text.trim().isEmpty && (info.title ?? '').isNotEmpty) {
        _name.text = info.title!;
        filled.add('name');
      }
      if (_desc.text.trim().isEmpty && (info.description ?? '').isNotEmpty) {
        _desc.text = info.description!;
        filled.add('description');
      }
      if (_price.text.trim().isEmpty && info.price != null) {
        final p = info.price!;
        _price.text = p == p.roundToDouble()
            ? p.toStringAsFixed(0)
            : p.toStringAsFixed(2);
        filled.add('price');
      }
      if (_brand.text.trim().isEmpty && (info.brand ?? '').isNotEmpty) {
        _brand.text = info.brand!;
        filled.add('brand');
      }
      var added = 0;
      for (final img in info.images) {
        if (_photos.length >= _maxPhotos) break;
        if (!_photos.contains(img)) {
          _photos.add(img);
          added++;
        }
      }
      if (added > 0) filled.add('$added photo${added == 1 ? '' : 's'}');
      setState(() {});
      showMsg(
        context,
        filled.isEmpty
            ? 'Nothing new to fill in. Your fields already have values.'
            : 'Filled in: ${filled.join(', ')}. Check it and edit anything.',
      );
    } on LinkImportException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  // ------------------------------------------------------------------- save

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      // Show the red messages, then bring the first missing field into view.
      setState(() => _tried = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        scrollToFirstError([
          _nameKey,
          _categoryKey,
          _skuKey,
          _priceKey,
          _costKey,
          _stockKey,
          _lowKey,
        ]);
      });
      showMsg(context, 'Please fill in the fields marked in red.', error: true);
      return;
    }
    final store = context.store;
    setState(() => _saving = true);

    final editing = _editing;
    // Check the SKU before touching the product or copying photos, so a refused
    // save changes nothing.
    if (store.skuTaken(_sku.text.trim(), exceptId: editing?.id)) {
      setState(() => _saving = false);
      showMsg(
        context,
        'That SKU is already used by another product.',
        error: true,
      );
      return;
    }
    final id = editing?.id ?? newId('p');
    final finalPhotos = <String>[];
    try {
      for (final path in _photos) {
        finalPhotos.add(
          _fresh.contains(path)
              ? await _persist(path, id)
              : isRemoteImage(path)
              ? await _download(path, id)
              : path,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        showMsg(context, 'Could not save the photos. Try again.', error: true);
      }
      return;
    }
    if (!mounted) return;

    final category = _category.text.trim();
    final removed = editing == null
        ? <String>[]
        : editing.images.where((e) => !finalPhotos.contains(e)).toList();
    Result res;
    if (editing == null) {
      res = store.addProduct(
        Product(
          id: id,
          sku: _sku.text.trim(),
          name: _name.text.trim(),
          category: category,
          brand: _brand.text.trim(),
          sourceUrl: _source.text.trim(),
          description: _desc.text.trim(),
          price: parseMoney(_price.text),
          cost: parseMoney(_cost.text),
          stock: int.tryParse(_stock.text.trim()) ?? 0,
          lowStockAt: int.tryParse(_low.text.trim()) ?? 5,
          images: finalPhotos,
          posts: _posts,
          active: _active,
        ),
      );
    } else {
      res = store.applyProductEdit(
        editing,
        sku: _sku.text.trim(),
        name: _name.text.trim(),
        category: category,
        brand: _brand.text.trim(),
        sourceUrl: _source.text.trim(),
        description: _desc.text.trim(),
        price: parseMoney(_price.text),
        cost: parseMoney(_cost.text),
        lowStockAt: int.tryParse(_low.text.trim()) ?? 5,
        images: finalPhotos,
        posts: _posts,
        active: _active,
      );
    }

    if (!res.ok) {
      setState(() => _saving = false);
      showMsg(context, res.error!, error: true);
      return;
    }
    for (final path in removed) {
      if (isRemoteImage(path) || isAssetImage(path)) continue;
      try {
        File(path).deleteSync();
      } catch (_) {}
    }
    Navigator.pop(context);
    showMsg(context, editing == null ? 'Product added' : 'Product updated');
  }

  // ------------------------------------------------------------------ build

  Widget _photoStrip() {
    Widget tile(Widget child) => Padding(
      padding: const EdgeInsets.only(right: 10),
      child: SizedBox(width: 88, height: 88, child: child),
    );
    return SizedBox(
      height: 88,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < _photos.length; i++)
            tile(
              GestureDetector(
                onTap: () => _photoOptions(i),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: photoImage(
                        _photos[i],
                        placeholder: () => Container(
                          color: Brand.tint,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: Brand.muted,
                          ),
                        ),
                      ),
                    ),
                    if (i == 0)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          decoration: const BoxDecoration(
                            color: Brand.primary,
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Cover',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          tile(
            InkWell(
              onTap: _addPhotoSheet,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Brand.primary),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined, color: Brand.primary),
                    SizedBox(height: 4),
                    Text(
                      'Add',
                      style: TextStyle(color: Brand.primary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = _editing != null;
    final cats = context.store.categoryOptions;

    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit product' : 'Add product')),
      bottomNavigationBar: FormActionBar(
        child: FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(editing ? 'Save changes' : 'Add product'),
        ),
      ),
      body: Form(
        key: _form,
        autovalidateMode: _tried
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        onChanged: () {
          if (!_dirty) setState(() => _dirty = true);
        },
        canPop: !_dirty,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final leave = await confirmDialog(
            context,
            title: 'Discard this product?',
            message: 'What you entered has not been saved.',
            confirmLabel: 'Discard',
            cancelLabel: 'Keep editing',
            destructive: true,
          );
          if (leave && context.mounted) Navigator.pop(context);
        },
        child: ListView(
          // Build every field, even those far below the screen: a list builds
          // only what is near the screen, and fields that are not built are not
          // checked when saving, so a required field could slip through empty.
          scrollCacheExtent: const ScrollCacheExtent.pixels(100000),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Autofill from a link',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Paste the product page (for example from a2z2go.com). '
                      'We fill in the name, price, description and photos. You can edit everything.',
                      style: TextStyle(color: Brand.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _source,
                            keyboardType: TextInputType.url,
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText: 'https://a2z2go.com/…',
                              prefixIcon: Icon(Icons.link),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _importing ? null : _autofill,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: _importing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Autofill'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Photos (${_photos.length}/$_maxPhotos)',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            const Text(
              'The first photo is the cover. Tap a photo to change it. At least one photo is needed before you can share the product.',
              style: TextStyle(color: Brand.muted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            _photoStrip(),
            const SizedBox(height: 18),
            const _FormHeading('Product details'),
            TextFormField(
              key: _nameKey,
              controller: _name,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(label: reqLabel('Product name')),
              validator: (v) => requiredText(v, 'Product name'),
            ),
            const SizedBox(height: 14),
            PickOrAddField(
              fieldKey: _categoryKey,
              controller: _category,
              label: 'Category',
              noun: 'category',
              required: true,
              options: cats,
            ),
            const SizedBox(height: 14),
            PickOrAddField(
              fieldKey: _brandKey,
              controller: _brand,
              label: 'Brand',
              noun: 'brand',
              options: context.store.brands,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: _skuKey,
              controller: _sku,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(label: reqLabel('SKU')),
              validator: (v) => requiredText(v, 'SKU'),
            ),
            const SizedBox(height: 14),
            const SizedBox(height: 22),
            const _FormHeading('Price and stock'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    key: _priceKey,
                    controller: _price,
                    textInputAction: TextInputAction.next,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: InputDecoration(
                      label: reqLabel('Selling price'),
                      prefixText: '₱ ',
                    ),
                    validator: (v) => moneyValidator(v, allowZero: false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: _costKey,
                    controller: _cost,
                    textInputAction: TextInputAction.next,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: InputDecoration(
                      label: reqLabel('Your cost'),
                      prefixText: '₱ ',
                    ),
                    validator: (v) => moneyValidator(v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!editing) ...[
                  Expanded(
                    child: TextFormField(
                      key: _stockKey,
                      controller: _stock,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        label: reqLabel('Opening stock'),
                      ),
                      validator: (v) => intValidator(v),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: TextFormField(
                    key: _lowKey,
                    controller: _low,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      label: reqLabel('Low-stock alert at'),
                    ),
                    validator: (v) => intValidator(v),
                  ),
                ),
              ],
            ),
            if (editing)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'To change the stock count, use Stock in / out on the product page so there is a history.',
                  style: TextStyle(color: Brand.muted, fontSize: 12),
                ),
              ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _desc,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description',
                helperText:
                    'Buyers read this. Needed before you can share the product (at least $minDescriptionLength letters).',
                helperMaxLines: 3,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              subtitle: const Text(
                'Hidden products cannot be added to new orders',
              ),
              value: _active,
              activeThumbColor: Brand.primary,
              onChanged: (v) => setState(() => _active = v),
            ),
            const Divider(height: 32),
            const Text(
              'Social proof (optional)',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 2),
            const Text(
              'Link Facebook, Instagram, TikTok or YouTube posts about this product and add their comments.',
              style: TextStyle(color: Brand.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            SocialProofSection(posts: _posts, onChanged: () => setState(() {})),
          ],
        ),
      ),
    );
  }
}

/// Small section title inside a long form.
class _FormHeading extends StatelessWidget {
  final String text;
  const _FormHeading(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}
