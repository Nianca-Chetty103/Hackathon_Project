import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'chats.dart';
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
  final _searchController = TextEditingController();
  final Set<String> _purchasingListings = {};
  String? _selectedCategory;
  bool _isLoading = true;
  String? _error;
  bool get _canCreate => widget.profile['role'] == 'student';
  bool get _canPurchase => widget.profile['role'] == 'investor';

  @override
  void initState() {
    super.initState();
    _loadListings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      } else if (listing.type == 'service' && listing.images.isNotEmpty) {
        await FeatureApi.uploadServicePriceList(
          token: widget.token,
          serviceId: listingId,
          image: listing.images.single,
        );
      }
      await _loadListings();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            listing.images.isEmpty
                ? 'Your listing was added.'
                : listing.type == 'product'
                ? 'Your listing and product photos were added.'
                : 'Your service and price-list image were added.',
          ),
        ),
      );
    } on FeatureApiException catch (error) {
      if (listingId != null && listing.images.isNotEmpty) {
        await _loadListings();
        _showError(
          'The listing was created, but its image could not be uploaded: ${error.message}',
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
      } else if (type == 'service' && edited.images.isNotEmpty) {
        await FeatureApi.uploadServicePriceList(
          token: widget.token,
          serviceId: listing['id'] as int,
          image: edited.images.single,
        );
      }
      await _loadListings();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            edited.images.isEmpty
                ? 'Your listing was updated.'
                : type == 'product'
                ? 'Your listing and product photos were updated.'
                : 'Your service and price-list image were updated.',
          ),
        ),
      );
    } on FeatureApiException catch (error) {
      if (edited.images.isNotEmpty) {
        await _loadListings();
        _showError(
          'The listing was updated, but its image could not be uploaded: ${error.message}',
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

  Future<void> _chatAboutListing(
    Map<String, dynamic> listing,
    String type,
  ) async {
    try {
      final chatId = await FeatureApi.openMarketplaceChat(
        token: widget.token,
        listingType: type,
        listingId: listing['id'] as int,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PrivateChatPage(
            token: widget.token,
            chatId: chatId,
            chatType: 'marketplace',
            title: listing['seller'] as String? ?? 'Seller',
            subtitle: listing['title'] as String? ?? 'Marketplace listing',
          ),
        ),
      );
    } on FeatureApiException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _purchaseListing(
    Map<String, dynamic> listing,
    String type,
  ) async {
    final id = listing['id'];
    if (!_canPurchase || id is! int) return;
    final key = '$type-$id';
    if (!_purchasingListings.add(key)) return;
    setState(() {});
    try {
      final checkoutUrl = await FeatureApi.marketplacePurchaseCheckout(
        token: widget.token,
        listingType: type,
        listingId: id,
      );
      final uri = Uri.tryParse(checkoutUrl);
      if (uri == null || !{'http', 'https'}.contains(uri.scheme)) {
        throw const FeatureApiException(
          'The server returned an invalid PayFast checkout link.',
        );
      }
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        _showError('Could not open the PayFast payment page.');
      }
    } on FeatureApiException catch (error) {
      if (mounted) _showError(error.message);
    } on PlatformException {
      if (mounted) _showError('Could not open the PayFast payment page.');
    } finally {
      _purchasingListings.remove(key);
      if (mounted) setState(() {});
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final showMyListings = widget.profile['role'] != 'admin' && !_canPurchase;
    return DefaultTabController(
      length: showMyListings ? 2 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Marketplace'),
          bottom: TabBar(
            tabs: [
              const Tab(text: 'Marketplace'),
              if (showMyListings) const Tab(text: 'My Listings'),
            ],
          ),
        ),
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
            : showMyListings
            ? TabBarView(
                children: [
                  _listingTab(onlyMine: false),
                  _listingTab(onlyMine: true),
                ],
              )
            : _listingTab(onlyMine: false),
      ),
    );
  }

  Widget _listingTab({required bool onlyMine}) {
    List<Map<String, dynamic>> visibleListings(
      List<Map<String, dynamic>> listings,
      String type,
    ) => listings.where((listing) {
      if (listing['is_mine'] != onlyMine) return false;
      if (_selectedCategory != null && _selectedCategory != type) return false;
      final query = _searchController.text.trim().toLowerCase();
      if (query.isEmpty) return true;
      final searchableText = [
        listing['title'],
        listing['description'],
        listing['seller'],
        listing['price'],
      ].whereType<Object>().join(' ').toLowerCase();
      return searchableText.contains(query);
    }).toList();

    final products = visibleListings(_products, 'product');
    final services = visibleListings(_services, 'service');
    return ListView(
      key: ValueKey(
        onlyMine ? 'my-marketplace-listings' : 'marketplace-listings',
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
      children: [
        Text(
          onlyMine ? 'Your marketplace listings' : 'Campus finds and services',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          onlyMine
              ? 'Manage the products and services you have posted.'
              : 'Discover products and services from the Eduvos community.',
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('marketplace-search-field'),
          controller: _searchController,
          onChanged: (_) => setState(() {
            _selectedCategory = null;
          }),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search products and services',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    key: const ValueKey('clear-marketplace-search'),
                    tooltip: 'Clear search',
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: _MarketplaceCategoryPill(
                    key: const ValueKey('marketplace-services-filter'),
                    label: 'Services',
                    icon: Icons.handyman_outlined,
                    selected: _selectedCategory == 'service',
                    onTap: () => setState(() {
                      _selectedCategory = _selectedCategory == 'service'
                          ? null
                          : 'service';
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MarketplaceCategoryPill(
                    key: const ValueKey('marketplace-products-filter'),
                    label: 'Products',
                    icon: Icons.shopping_bag_outlined,
                    selected: _selectedCategory == 'product',
                    onTap: () => setState(() {
                      _selectedCategory = _selectedCategory == 'product'
                          ? null
                          : 'product';
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _ListingSection(
          title: 'Products',
          listings: products,
          type: 'product',
          token: widget.token,
          onEdit: _editListing,
          onDelete: _deleteListing,
          onChat: _chatAboutListing,
          canPurchase: _canPurchase,
          purchasingListings: _purchasingListings,
          onPurchase: _purchaseListing,
        ),
        _ListingSection(
          title: 'Services',
          listings: services,
          type: 'service',
          token: widget.token,
          onEdit: _editListing,
          onDelete: _deleteListing,
          onChat: _chatAboutListing,
          canPurchase: _canPurchase,
          purchasingListings: _purchasingListings,
          onPurchase: _purchaseListing,
        ),
        if (products.isEmpty && services.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _searchController.text.trim().isNotEmpty
                  ? 'No listings match your search.'
                  : _selectedCategory != null
                  ? 'No ${_selectedCategory == 'product' ? 'products' : 'services'} found.'
                  : onlyMine
                  ? 'You have not posted any marketplace listings yet.'
                  : 'No listings yet. Be the first to add a product or service.',
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

class _MarketplaceCategoryPill extends StatelessWidget {
  const _MarketplaceCategoryPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? colors.primary : colors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? colors.onPrimary : colors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? colors.onPrimary : colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatMarketplacePrice(Object price) {
  final amount = price.toString().replaceFirst(
    RegExp(r'^R\s*', caseSensitive: false),
    '',
  );
  return 'R $amount';
}

class _ListingSection extends StatelessWidget {
  const _ListingSection({
    required this.title,
    required this.listings,
    required this.type,
    required this.token,
    required this.onEdit,
    required this.onDelete,
    required this.onChat,
    required this.canPurchase,
    required this.purchasingListings,
    required this.onPurchase,
  });

  final String title;
  final List<Map<String, dynamic>> listings;
  final String type;
  final String token;
  final Future<void> Function(Map<String, dynamic>, String) onEdit;
  final Future<void> Function(Map<String, dynamic>, String) onDelete;
  final Future<void> Function(Map<String, dynamic>, String) onChat;
  final bool canPurchase;
  final Set<String> purchasingListings;
  final Future<void> Function(Map<String, dynamic>, String) onPurchase;

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
            clipBehavior: Clip.antiAlias,
            margin: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ListingImageCard(
                  images: listing['images'] is List
                      ? (listing['images'] as List)
                            .whereType<Map>()
                            .map(Map<String, dynamic>.from)
                            .toList()
                      : const [],
                  type: type,
                  token: token,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              listing['title'] as String? ?? '',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (listing['price'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _formatMarketplacePrice(listing['price']),
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        listing['description'] as String? ?? '',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .secondaryContainer,
                            child: Icon(
                              Icons.person_outline_rounded,
                              size: 17,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Posted by ${listing['seller'] ?? 'Student'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
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
                      if (listing['can_chat'] == true)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            key: ValueKey('chat-listing-${listing['id']}'),
                            onPressed: () => onChat(listing, type),
                            icon: const Icon(Icons.chat_bubble_outline_rounded),
                            label: const Text('Message seller'),
                          ),
                        ),
                      if (canPurchase && listing['can_purchase'] == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              key: ValueKey(
                                'purchase-listing-${listing['id']}',
                              ),
                              onPressed:
                                  purchasingListings.contains(
                                    '$type-${listing['id']}',
                                  )
                                  ? null
                                  : () => onPurchase(listing, type),
                              icon:
                                  purchasingListings.contains(
                                    '$type-${listing['id']}',
                                  )
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.shopping_cart_outlined),
                              label: const Text('Purchase'),
                            ),
                          ),
                        ),
                    ],
                  ),
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
  int get _imageLimit => _type == 'product' ? 5 : 1;
  int get _imageCountForLimit => _type == 'service' ? 0 : _existingImageCount;

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
    final remaining =
        _imageLimit - _imageCountForLimit - _selectedImages.length;
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
            'Each listing image must be smaller than 5 MB.',
          );
        }
        selected.add(_PickedProductImage(file: file, bytes: bytes));
      }
      if (!mounted) return;
      setState(() => _selectedImages.addAll(selected));
    } on FeatureApiException catch (error) {
      _showDialogError(error.message);
    } catch (error) {
      _showDialogError('Could not load the selected listing image: $error');
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              _isEditing
                  ? Icons.edit_outlined
                  : Icons.add_shopping_cart_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isEditing ? 'Edit your listing' : 'Create a marketplace listing',
            ),
          ),
        ],
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
            ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _type == 'product'
                      ? 'Product photos (${_existingImageCount + _selectedImages.length}/$_imageLimit)'
                      : _selectedImages.isNotEmpty
                      ? 'New service price list selected'
                      : _existingImageCount > 0
                      ? 'Replace the existing service price list'
                      : 'Service price list image',
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
                            key: ValueKey('remove-listing-image-$index'),
                            tooltip: 'Remove selected image',
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              setState(() => _selectedImages.removeAt(index));
                            },
                            icon: const Icon(Icons.close, size: 16),
                          ),
                        ),
                      ],
                    ),
                  if (_type == 'service'
                      ? _selectedImages.isEmpty
                      : _existingImageCount + _selectedImages.length <
                            _imageLimit)
                    OutlinedButton.icon(
                      key: const ValueKey('add-listing-images-button'),
                      onPressed: _isPickingImages ? null : _pickImages,
                      icon: _isPickingImages
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(
                        _isPickingImages
                            ? 'Loading'
                            : _type == 'product'
                            ? 'Add photos'
                            : _existingImageCount > 0
                            ? 'Replace price list'
                            : 'Add price list',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _type == 'product'
                      ? 'Choose up to 5 JPEG, PNG, or WebP images.'
                      : 'Add one JPEG, PNG, or WebP image showing your fees or price list.',
                ),
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

class _ListingImageCard extends StatelessWidget {
  const _ListingImageCard({
    required this.images,
    required this.type,
    required this.token,
  });

  final List<Map<String, dynamic>> images;
  final String type;
  final String token;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 220,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (images.isEmpty)
            ColoredBox(
              color: colors.surfaceContainerHighest,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    type == 'product'
                        ? Icons.shopping_bag_outlined
                        : Icons.handyman_outlined,
                    size: 42,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    type == 'product' ? 'Product listing' : 'Service listing',
                  ),
                ],
              ),
            )
          else
            PageView.builder(
              itemCount: images.length,
              itemBuilder: (context, index) {
                final id = images[index]['id'];
                if (id is! int) {
                  return ColoredBox(
                    color: colors.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image_outlined),
                  );
                }
                return Image.network(
                  FeatureApi.listingImageUrl(id, type: type).toString(),
                  fit: BoxFit.cover,
                  headers: {'Authorization': 'Bearer $token'},
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: colors.surfaceContainerHighest,
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined, size: 36),
                    ),
                  ),
                );
              },
            ),
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                type == 'product' ? 'PRODUCT' : 'SERVICE',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
          if (images.length > 1)
            Positioned(
              right: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${images.length} photos',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
