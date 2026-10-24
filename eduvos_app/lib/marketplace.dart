import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'feature_api.dart';

class MarketplacePage extends StatefulWidget {
  const MarketplacePage({
    required this.profile,
    required this.token,
    super.key,
  });

  final Map<String, dynamic> profile;
  final String token;

  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _services = [];
  bool _isLoading = true;
  String? _error;
  bool get _canCreate => widget.profile['role'] == 'student';

  @override
  void initState() {
    super.initState();
    _loadListings();
  }

  Future<void> _loadListings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await FeatureApi.marketplace(widget.token);
      final data = response['data'];
      if (data is! Map ||
          data['products'] is! List ||
          data['services'] is! List) {
        throw const FeatureApiException(
          'The server returned invalid marketplace listings.',
        );
      }
      if (!mounted) return;
      setState(() {
        _products = (data['products'] as List)
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList();
        _services = (data['services'] as List)
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList();
        _isLoading = false;
      });
    } on FeatureApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _createListing() async {
    final listing = await showDialog<_NewListing>(
      context: context,
      builder: (context) => const _MarketplaceListingDialog(),
    );
    if (listing == null || !mounted) return;
    int? listingId;
    try {
      listingId = await FeatureApi.createMarketplaceListing(
        token: widget.token,
        type: listing.type,
        title: listing.title,
        description: listing.description,
        price: listing.price,
      );
      if (listing.type == 'product' && listing.images.isNotEmpty) {
        await FeatureApi.uploadProductImages(
          token: widget.token,
          productId: listingId,
          images: listing.images,
        );
      }
      await _loadListings();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            listing.images.isEmpty || listing.type != 'product'
                ? 'Your listing was added.'
                : 'Your listing and product photos were added.',
          ),
        ),
      );
    } on FeatureApiException catch (error) {
      if (listingId != null &&
          listing.type == 'product' &&
          listing.images.isNotEmpty) {
        await _loadListings();
        _showError(
          'The listing was created, but its photos could not be uploaded: ${error.message}',
        );
      } else {
        _showError(error.message);
      }
    }
  }

  Future<void> _editListing(Map<String, dynamic> listing, String type) async {
    final edited = await showDialog<_NewListing>(
      context: context,
      builder: (context) =>
          _MarketplaceListingDialog(existingListing: listing, type: type),
    );
    if (edited == null || !mounted) return;
    try {
      await FeatureApi.updateMarketplaceListing(
        token: widget.token,
        type: type,
        id: listing['id'] as int,
        title: edited.title,
        description: edited.description,
        price: edited.price,
      );
      if (type == 'product' && edited.images.isNotEmpty) {
        await FeatureApi.uploadProductImages(
          token: widget.token,
          productId: listing['id'] as int,
          images: edited.images,
        );
      }
      await _loadListings();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            edited.images.isEmpty
                ? 'Your listing was updated.'
                : 'Your listing and product photos were updated.',
          ),
        ),
      );
    } on FeatureApiException catch (error) {
      if (type == 'product' && edited.images.isNotEmpty) {
        await _loadListings();
        _showError(
          'The listing was updated, but its photos could not be uploaded: ${error.message}',
        );
      } else {
        _showError(error.message);
      }
    }
  }

  Future<void> _deleteListing(Map<String, dynamic> listing, String type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete listing?'),
        content: Text('Delete "${listing['title']}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await FeatureApi.deleteMarketplaceListing(
        token: widget.token,
        type: type,
        id: listing['id'] as int,
      );
      await _loadListings();
    } on FeatureApiException catch (error) {
      _showError(error.message);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Marketplace')),
      floatingActionButton: _canCreate
          ? FloatingActionButton.extended(
              key: const ValueKey('create-listing-button'),
              onPressed: _isLoading ? null : _createListing,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Sell or advertise'),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _loadListings,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
              children: [
                Text(
                  'Campus finds and student services',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text('Discover what students are making and offering.'),
                const SizedBox(height: 16),
                _ListingSection(
                  title: 'Products',
                  listings: _products,
                  type: 'product',
                  token: widget.token,
                  onEdit: _editListing,
                  onDelete: _deleteListing,
                ),
                _ListingSection(
                  title: 'Services',
                  listings: _services,
                  type: 'service',
                  token: widget.token,
                  onEdit: _editListing,
                  onDelete: _deleteListing,
                ),
                if (_products.isEmpty && _services.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No listings yet. Be the first to add a product or service.',
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ListingSection extends StatelessWidget {
  const _ListingSection({
    required this.title,
    required this.listings,
    required this.type,
    required this.token,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final List<Map<String, dynamic>> listings;
  final String type;
  final String token;
  final Future<void> Function(Map<String, dynamic>, String) onEdit;
  final Future<void> Function(Map<String, dynamic>, String) onDelete;

  @override
  Widget build(BuildContext context) {
    if (listings.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 10),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        for (final listing in listings)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.storefront_outlined),
                  ),
                  title: Text(listing['title'] as String? ?? ''),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${listing['description'] ?? ''}\n'
                      'Posted by ${listing['seller'] ?? 'Student'}'
                      '${listing['price'] == null ? '' : ' · ${listing['price']}'}',
                    ),
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (listing['can_edit'] == true)
                        IconButton(
                          key: ValueKey('edit-listing-${listing['id']}'),
                          tooltip: 'Edit listing',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => onEdit(listing, type),
                        ),
                      if (listing['can_delete'] == true)
                        IconButton(
                          tooltip: 'Delete listing',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => onDelete(listing, type),
                        ),
                    ],
                  ),
                ),
                if (type == 'product' && listing['images'] is List)
                  _ProductImageGallery(
                    images: (listing['images'] as List)
                        .whereType<Map>()
                        .map(Map<String, dynamic>.from)
                        .toList(),
                    token: token,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _NewListing {
  const _NewListing({
    required this.type,
    required this.title,
    required this.description,
    required this.images,
    this.price,
  });

  final String type;
  final String title;
  final String description;
  final List<XFile> images;
  final String? price;
}

class _MarketplaceListingDialog extends StatefulWidget {
  const _MarketplaceListingDialog({this.existingListing, this.type});

  final Map<String, dynamic>? existingListing;
  final String? type;

  @override
  State<_MarketplaceListingDialog> createState() =>
      _MarketplaceListingDialogState();
}

class _MarketplaceListingDialogState extends State<_MarketplaceListingDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late String _type;
  final ImagePicker _imagePicker = ImagePicker();
  final List<_PickedProductImage> _selectedImages = [];
  bool _isPickingImages = false;

  bool get _isEditing => widget.existingListing != null;
  int get _existingImageCount =>
      (widget.existingListing?['images'] as List?)?.length ?? 0;

  @override
  void initState() {
    super.initState();
    final listing = widget.existingListing;
    _type = widget.type ?? 'product';
    _titleController = TextEditingController(
      text: listing?['title'] as String? ?? '',
    );
    _descriptionController = TextEditingController(
      text: listing?['description'] as String? ?? '',
    );
    final price = listing?['price'];
    _priceController = TextEditingController(
      text: price == null ? '' : '$price',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final price = _priceController.text.trim();
    if (title.isEmpty || description.isEmpty) return;
    if (price.isNotEmpty && double.tryParse(price) == null) return;
    Navigator.pop(
      context,
      _NewListing(
        type: _type,
        title: title,
        description: description,
        price: price.isEmpty ? null : price,
        images: _selectedImages.map((image) => image.file).toList(),
      ),
    );
  }

  Future<void> _pickImages() async {
    final remaining = 5 - _existingImageCount - _selectedImages.length;
    if (remaining <= 0) return;
    setState(() => _isPickingImages = true);
    try {
      final picked = await _imagePicker.pickMultiImage(
        limit: remaining,
        maxWidth: 1600,
        imageQuality: 85,
      );
      final selected = <_PickedProductImage>[];
      for (final file in picked) {
        final bytes = await file.readAsBytes();
        if (bytes.length > 5 * 1024 * 1024) {
          throw const FeatureApiException(
            'Each product photo must be smaller than 5 MB.',
          );
        }
        selected.add(_PickedProductImage(file: file, bytes: bytes));
      }
      if (!mounted) return;
      setState(() => _selectedImages.addAll(selected));
    } on FeatureApiException catch (error) {
      _showDialogError(error.message);
    } catch (error) {
      _showDialogError('Could not load the selected product photos: $error');
    } finally {
      if (mounted) setState(() => _isPickingImages = false);
    }
  }

  void _showDialogError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _isEditing ? 'Edit your listing' : 'Create a marketplace listing',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isEditing)
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Listing type'),
                items: const [
                  DropdownMenuItem(value: 'product', child: Text('Product')),
                  DropdownMenuItem(value: 'service', child: Text('Service')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _type = value;
                      if (_type != 'product') _selectedImages.clear();
                    });
                  }
                },
              ),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
            TextField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Price (optional)',
                prefixText: 'R ',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            if (_type == 'product') ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Product photos (${_existingImageCount + _selectedImages.length}/5)',
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var index = 0; index < _selectedImages.length; index++)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            _selectedImages[index].bytes,
                            width: 76,
                            height: 76,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton.filledTonal(
                            key: ValueKey('remove-product-photo-$index'),
                            tooltip: 'Remove selected photo',
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              setState(() => _selectedImages.removeAt(index));
                            },
                            icon: const Icon(Icons.close, size: 16),
                          ),
                        ),
                      ],
                    ),
                  if (_existingImageCount + _selectedImages.length < 5)
                    OutlinedButton.icon(
                      key: const ValueKey('add-product-photos-button'),
                      onPressed: _isPickingImages ? null : _pickImages,
                      icon: _isPickingImages
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(_isPickingImages ? 'Loading' : 'Add photos'),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Choose up to 5 JPEG, PNG, or WebP images.'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isEditing ? 'Save changes' : 'Post listing'),
        ),
      ],
    );
  }
}

class _PickedProductImage {
  const _PickedProductImage({required this.file, required this.bytes});

  final XFile file;
  final Uint8List bytes;
}

class _ProductImageGallery extends StatelessWidget {
  const _ProductImageGallery({required this.images, required this.token});

  final List<Map<String, dynamic>> images;
  final String token;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 132,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final id = images[index]['id'];
          if (id is! int) return const SizedBox.shrink();
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              FeatureApi.productImageUrl(id).toString(),
              width: 150,
              height: 120,
              fit: BoxFit.cover,
              headers: {'Authorization': 'Bearer $token'},
              errorBuilder: (_, _, _) => const SizedBox(
                width: 150,
                height: 120,
                child: ColoredBox(
                  color: Color(0xFFE8EEF2),
                  child: Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
