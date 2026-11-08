import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _pageSize = 6;
const _maximumPrice = 150.0;
const _forest = Color(0xFF4F7D32);
const _sunshine = Color(0xFFFFD16A);
const _gold = Color(0xFFF5B52E);
const _tomato = Color(0xFFD9361E);
// A soft warm tint keeps the palette's yellow influence without flooding the UI.
const _paper = Color(0xFFFFF9EC);
const _ink = Color(0xFF263321);

const _sampleImages = <String, String>{
  'Canvas Backpack':
      'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=1000&q=85',
  'Insulated Water Bottle':
      'https://www.chillys.com/cdn/shop/files/7_B500SSSTL_PS.jpg?v=1749820543',
  'Wireless Mouse':
      'https://images.unsplash.com/photo-1707592691247-5c3a1c7ba0e3?auto=format&fit=crop&w=1000&q=85',
  'Desk Lamp':
      'https://assets.mitre10.co.nz/sys-master/productimages/he4/hf7/10464549568542/376697xlg.jpg',
  'Bluetooth Speaker':
      'https://images.unsplash.com/photo-1589003077984-894e133dabab?auto=format&fit=crop&w=1000&q=85',
  'Mechanical Keyboard':
      'https://images.unsplash.com/photo-1632079003110-d694908500da?auto=format&fit=crop&w=1000&q=85',
  'Running Shoes':
      'https://decathlonpro.vtexassets.com/arquivos/ids/2462545/support-m-shoes-red2411.jpg?v=637166207440600000',
  'Travel Mug':
      'https://m.media-amazon.com/images/I/71vExSpxwgL._AC_SL1000_.jpg',
  'Wireless Earbuds':
      'https://images.unsplash.com/photo-1640901821270-6e9c47fbdc07?auto=format&fit=crop&w=1000&q=85',
  'Smart Watch':
      'https://images.unsplash.com/photo-1624096104992-9b4fa3a279dd?auto=format&fit=crop&w=1000&q=85',
  'Tablet Stand':
      'https://lamicallshop.com/cdn/shop/files/DT04.jpg?v=1756349526',
  'USB-C Hub':
      'https://img.gsmnet.ro/800x800/products/238805/hub-usb-c-ugreen-cm511-75642-6in1-gri-1772097917897.jpg',
};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config =
      jsonDecode(await rootBundle.loadString('supabase_config.json'))
          as Map<String, dynamic>;
  final supabaseUrl = config['SUPABASE_URL'] as String? ?? '';
  final publishableKey = config['SUPABASE_PUBLISHABLE_KEY'] as String? ?? '';
  final isConfigured = supabaseUrl.isNotEmpty && publishableKey.isNotEmpty;
  String? authCallbackError;

  if (isConfigured) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: publishableKey,
      // Exchange auth callback codes explicitly before rendering the recovery
      // screen, so it never appears before its session is ready.
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
    );

    final callbackUri = Uri.base;
    final hasAuthCallback =
        callbackUri.queryParameters.containsKey('code') ||
        callbackUri.queryParameters.containsKey('error') ||
        callbackUri.queryParameters.containsKey('error_code') ||
        callbackUri.fragment.contains('type=recovery');
    if (hasAuthCallback) {
      try {
        await Supabase.instance.client.auth.getSessionFromUrl(callbackUri);
      } catch (error) {
        authCallbackError = error.toString();
      }
    }
  }

  runApp(
    ShopApp(isConfigured: isConfigured, authCallbackError: authCallbackError),
  );
}

class ShopApp extends StatelessWidget {
  const ShopApp({
    super.key,
    required this.isConfigured,
    this.authCallbackError,
  });

  final bool isConfigured;
  final String? authCallbackError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E-commerce',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _paper,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _forest,
          primary: _forest,
          secondary: _gold,
          surface: _paper,
          error: _tomato,
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: _paper,
          foregroundColor: _ink,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: isConfigured
          ? AuthFlowGate(callbackError: authCallbackError)
          : const MissingKeyPage(),
    );
  }
}

/// Routes password recovery links to a dedicated password form. Supabase emits
/// [AuthChangeEvent.passwordRecovery] after it processes the recovery URL.
class AuthFlowGate extends StatefulWidget {
  const AuthFlowGate({super.key, this.callbackError});

  final String? callbackError;

  @override
  State<AuthFlowGate> createState() => _AuthFlowGateState();
}

class _AuthFlowGateState extends State<AuthFlowGate> {
  StreamSubscription<AuthState>? _authSubscription;
  // PKCE recovery links return as `/?code=...`; implicit-flow links return
  // with `#type=recovery`. Supabase exchanges a PKCE code during initialization,
  // so detect the callback URL here as well as listening for the auth event.
  bool _isRecoveringPassword =
      Uri.base.queryParameters.containsKey('code') ||
      Uri.base.fragment.contains('type=recovery');

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) {
      if (!mounted) return;
      if (state.event == AuthChangeEvent.passwordRecovery) {
        setState(() => _isRecoveringPassword = true);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.callbackError != null) {
      return RecoveryLinkErrorPage(details: widget.callbackError!);
    }
    if (_isRecoveringPassword) {
      return PasswordRecoveryPage(
        onComplete: () => setState(() => _isRecoveringPassword = false),
      );
    }
    return const ProductShopPage();
  }
}

class RecoveryLinkErrorPage extends StatelessWidget {
  const RecoveryLinkErrorPage({super.key, required this.details});

  final String details;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This reset link could not be verified',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Request a fresh link from this app and open it in the same '
                    'Chrome profile where you requested it. Recovery links are '
                    'one-use and expire quickly.',
                  ),
                  const SizedBox(height: 12),
                  Text(details, style: const TextStyle(color: _tomato)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PasswordRecoveryPage extends StatefulWidget {
  const PasswordRecoveryPage({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSaving = false;
  String? _error;
  bool _complete = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _savePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );
      if (mounted) setState(() => _complete = true);
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not update password: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: _complete
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: _forest,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Password updated',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your password has been changed. You can sign in with it now.',
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: widget.onComplete,
                          child: const Text('Return to the shop'),
                        ),
                      ],
                    )
                  : Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Set a new password',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Choose a password with at least 8 characters.',
                          ),
                          const SizedBox(height: 22),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            autofocus: true,
                            decoration: const InputDecoration(
                              labelText: 'New password',
                            ),
                            validator: (value) => (value?.length ?? 0) < 8
                                ? 'Use at least 8 characters'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirmController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Confirm password',
                            ),
                            validator: (value) =>
                                value != _passwordController.text
                                ? 'Passwords do not match'
                                : null,
                            onFieldSubmitted: (_) => _savePassword(),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              style: const TextStyle(color: _tomato),
                            ),
                          ],
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: _isSaving ? null : _savePassword,
                            child: _isSaving
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Update password'),
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

class MissingKeyPage extends StatelessWidget {
  const MissingKeyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Add the Supabase URL and publishable key to '
            'supabase_config.json, then run flutter run.',
          ),
        ),
      ),
    );
  }
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.imageUrl,
  });

  final int id;
  final String name;
  final String description;
  final double price;
  final String? imageUrl;

  factory Product.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? 'Unnamed product';
    final databaseImage = (json['image_url'] as String?)?.trim();
    return Product(
      id: (json['id'] as num).toInt(),
      name: name,
      description: json['description'] as String? ?? '',
      price: (json['price'] as num).toDouble(),
      imageUrl: databaseImage == null || databaseImage.isEmpty
          ? _sampleImages[name]
          : databaseImage,
    );
  }
}

class ProductsController extends ChangeNotifier {
  ProductsController(this._client);

  final SupabaseClient _client;
  RangeValues _priceRange = const RangeValues(0, _maximumPrice);
  List<Product> _products = [];
  bool _isLoading = false;
  bool _hasNextPage = false;
  int _currentPage = 1;
  String _searchQuery = '';
  String? _error;

  RangeValues get priceRange => _priceRange;
  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  bool get hasNextPage => _hasNextPage;
  int get currentPage => _currentPage;
  String? get error => _error;
  bool get isAdmin => _client.auth.currentUser?.appMetadata['role'] == 'admin';

  Future<void> _createProduct(_ProductInput input) async {
    await _client.from('products').insert(input.toJson());
    await loadPage();
  }

  Future<void> _updateProduct(int id, _ProductInput input) async {
    await _client.from('products').update(input.toJson()).eq('id', id);
    await loadPage();
  }

  Future<void> deleteProduct(int id) async {
    final deletedRows = await _client
        .from('products')
        .delete()
        .eq('id', id)
        .select('id');
    if (deletedRows.isEmpty) {
      throw Exception(
        'Supabase did not delete this row. Check that admin_crud.sql has been '
        'run and that you signed in again after assigning the admin role.',
      );
    }
    await loadPage();
  }

  void updatePriceRange(RangeValues values) {
    _priceRange = values;
    _currentPage = 1;
    notifyListeners();
  }

  Future<void> applyPriceRange() => loadPage();

  Future<void> setSearchQuery(String value) async {
    final query = value.trim();
    if (query == _searchQuery) return;
    _searchQuery = query;
    _currentPage = 1;
    await loadPage();
  }

  Future<void> goToPage(int page) async {
    if (page < 1 ||
        page == _currentPage ||
        (page > _currentPage && !_hasNextPage)) {
      return;
    }
    _currentPage = page;
    await loadPage();
  }

  Future<void> loadPage() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final from = (_currentPage - 1) * _pageSize;
    // Fetch one extra row to detect another page; only six products display.
    final to = from + _pageSize;

    try {
      final rows = await _client
          .from('products')
          .select('id, name, description, price, image_url')
          .gte('price', _priceRange.start)
          .lte('price', _priceRange.end)
          .ilike('name', '%$_searchQuery%')
          .order('id')
          .range(from, to);

      final fetched = rows
          .map((row) => Product.fromJson(row))
          .toList(growable: false);
      _hasNextPage = fetched.length > _pageSize;
      _products = fetched.take(_pageSize).toList(growable: false);
    } catch (error) {
      _products = [];
      _hasNextPage = false;
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

class ProductShopPage extends StatefulWidget {
  const ProductShopPage({super.key});

  @override
  State<ProductShopPage> createState() => _ProductShopPageState();
}

class _ProductShopPageState extends State<ProductShopPage> {
  late final ProductsController _controller;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  StreamSubscription<dynamic>? _authSubscription;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _controller = ProductsController(client)..loadPage();
    _authSubscription = client.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _authSubscription?.cancel();
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 320),
      () => _controller.setSearchQuery(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      floatingActionButton: _controller.isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showProductForm(),
              backgroundColor: _forest,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add product'),
            )
          : null,
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1260),
                    child: Column(
                      children: [
                        _buildIntro(context),
                        _buildSearch(context),
                        _buildPriceFilter(context),
                        _buildSectionHeading(context),
                      ],
                    ),
                  ),
                ),
              ),
              ..._buildCatalogSlivers(context),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      toolbarHeight: 76,
      titleSpacing: 22,
      title: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _forest,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.shopping_bag_rounded, color: _sunshine),
          ),
          const SizedBox(width: 11),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'E-commerce',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: _forest,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
              ),
              const Text(
                'GOOD THINGS, EVERY DAY',
                style: TextStyle(
                  color: _tomato,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.15,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: _controller.isAdmin ? 'Sign out of admin' : 'Admin sign in',
          onPressed: _handleAdminAccess,
          icon: Icon(
            _controller.isAdmin
                ? Icons.admin_panel_settings_rounded
                : Icons.admin_panel_settings_outlined,
            color: _forest,
          ),
        ),
        if (MediaQuery.sizeOf(context).width >= 440)
          Padding(
            padding: const EdgeInsets.only(right: 22),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: _sunshine.withValues(alpha: 0.38),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    color: _tomato,
                    size: 17,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Fresh finds',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildIntro(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_forest, Color(0xFF668A4B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -4,
              top: -7,
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 62,
                color: _sunshine,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _sunshine,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'A LITTLE SOMETHING FOR YOU',
                    style: TextStyle(
                      color: _forest,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 13),
                Text(
                  'Find your next\nfavorite thing.',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    height: 1.04,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Thoughtful picks for work, play, and everywhere in between.',
                  style: TextStyle(color: Color(0xFFE9F0E1), fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search the collection',
          hintStyle: const TextStyle(color: Color(0xFF899080)),
          prefixIcon: const Icon(Icons.search_rounded, color: _forest),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                    setState(() {});
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 17),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFECE8DE)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: _forest, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildPriceFilter(BuildContext context) {
    final range = _controller.priceRange;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 13, 16, 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFECE8DE)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Price',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  '\$${range.start.toStringAsFixed(0)}  -  '
                  '\$${range.end.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: _forest,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: _forest,
                inactiveTrackColor: const Color(0xFFE5EBDD),
                rangeThumbShape: const RoundRangeSliderThumbShape(
                  enabledThumbRadius: 7,
                  elevation: 1,
                ),
                rangeTickMarkShape: const RoundRangeSliderTickMarkShape(
                  tickMarkRadius: 1.5,
                ),
                thumbColor: _forest,
                overlayColor: _forest.withValues(alpha: 0.08),
                activeTickMarkColor: _paper,
                inactiveTickMarkColor: const Color(0xFFC8D3BD),
                rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
                trackHeight: 3,
                showValueIndicator: ShowValueIndicator.never,
              ),
              child: RangeSlider(
                values: range,
                min: 0,
                max: _maximumPrice,
                divisions: 6,
                onChanged: _controller.updatePriceRange,
                onChangeEnd: (_) => _controller.applyPriceRange(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (index) {
                  final stop = index * 25;
                  return Text(
                    '\$$stop',
                    style: const TextStyle(
                      color: Color(0xFF7E8476),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeading(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 2, 22, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The good stuff',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _ink,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'A handpicked collection for your everyday.',
                  style: TextStyle(color: Color(0xFF828779), fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _sunshine.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'PAGE ${_controller.currentPage}',
              style: const TextStyle(
                color: _forest,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCatalogSlivers(BuildContext context) {
    if (_controller.isLoading) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator(color: _forest)),
        ),
      ];
    }

    if (_controller.error case final error?) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _CatalogMessage(
            icon: Icons.cloud_off_rounded,
            title: 'We could not load the collection',
            message: error,
            action: FilledButton.icon(
              onPressed: _controller.loadPage,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ),
        ),
      ];
    }

    if (_controller.products.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _CatalogMessage(
            icon: Icons.search_off_rounded,
            title: 'Nothing in this range yet',
            message: 'Try another search or widen your price range.',
          ),
        ),
      ];
    }

    return [
      SliverLayoutBuilder(
        builder: (context, constraints) {
          final viewportWidth = constraints.crossAxisExtent;
          final sidePadding = viewportWidth > 1304
              ? (viewportWidth - 1260) / 2
              : 22.0;
          final gridWidth = viewportWidth - sidePadding * 2;
          final columns = gridWidth >= 1100
              ? 4
              : gridWidth >= 680
              ? 3
              : gridWidth >= 280
              ? 2
              : 1;
          final cardWidth = (gridWidth - (columns - 1) * 14) / columns;
          final cardHeight = cardWidth < 180
              ? 250.0
              : cardWidth < 260
              ? 300.0
              : 330.0;

          return SliverPadding(
            padding: EdgeInsets.fromLTRB(sidePadding, 0, sidePadding, 16),
            sliver: SliverGrid.builder(
              itemCount: _controller.products.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                mainAxisExtent: cardHeight,
              ),
              itemBuilder: (context, index) {
                final product = _controller.products[index];
                return ProductCard(
                  product: product,
                  isAdmin: _controller.isAdmin,
                  onTap: () => _showProductDetails(product),
                  onEdit: () => _showProductForm(product: product),
                  onDelete: () => _deleteProduct(product),
                );
              },
            ),
          );
        },
      ),
      SliverToBoxAdapter(child: _buildPagination(context)),
    ];
  }

  Widget _buildPagination(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PageButton(
            icon: Icons.arrow_back_rounded,
            label: 'Previous',
            onPressed: _controller.currentPage == 1
                ? null
                : () => _controller.goToPage(_controller.currentPage - 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              '${_controller.currentPage}',
              style: const TextStyle(
                color: _forest,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
          _PageButton(
            icon: Icons.arrow_forward_rounded,
            label: 'Next',
            trailing: true,
            onPressed: !_controller.hasNextPage
                ? null
                : () => _controller.goToPage(_controller.currentPage + 1),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAdminAccess() async {
    final auth = Supabase.instance.client.auth;
    if (_controller.isAdmin) {
      await auth.signOut();
      return;
    }

    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final signInAction = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Admin sign in'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
              onSubmitted: (_) => Navigator.pop(dialogContext, 'sign-in'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'recover'),
            child: const Text('Forgot password?'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'sign-in'),
            child: const Text('Sign in'),
          ),
        ],
      ),
    );

    if (signInAction == 'recover') {
      await _sendPasswordRecovery(emailController.text.trim());
    } else if (signInAction == 'sign-in') {
      try {
        await auth.signInWithPassword(
          email: emailController.text.trim(),
          password: passwordController.text,
        );
        if (!_controller.isAdmin) {
          await auth.signOut();
          throw Exception('This account does not have the admin role.');
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Admin sign in failed: $error')),
          );
        }
      }
    }

    emailController.dispose();
    passwordController.dispose();
  }

  Future<void> _sendPasswordRecovery(String suggestedEmail) async {
    final emailController = TextEditingController(text: suggestedEmail);
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset your password'),
        content: TextField(
          controller: emailController,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Account email'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, emailController.text.trim()),
            child: const Text('Send reset link'),
          ),
        ],
      ),
    );
    emailController.dispose();
    if (email == null || email.isEmpty) return;

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'http://localhost:3000',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'If the account exists, a password reset email was sent.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send reset email: $error')),
        );
      }
    }
  }

  Future<void> _showProductForm({Product? product}) async {
    final input = await showDialog<_ProductInput>(
      context: context,
      builder: (_) => _ProductFormDialog(product: product),
    );
    if (input == null || !mounted) return;

    try {
      if (product == null) {
        await _controller._createProduct(input);
      } else {
        await _controller._updateProduct(product.id, input);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save product: $error')),
        );
      }
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('Remove "${product.name}" from the catalog?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _tomato),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _controller.deleteProduct(product.id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete product: $error')),
        );
      }
    }
  }

  void _showProductDetails(Product product) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductDetailsSheet(product: product),
    );
  }
}

class _ProductFormDialog extends StatefulWidget {
  const _ProductFormDialog({this.product});

  final Product? product;

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _imageController;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product?.name ?? '');
    _priceController = TextEditingController(
      text: product == null ? '' : product.price.toStringAsFixed(2),
    );
    _descriptionController = TextEditingController(
      text: product?.description ?? '',
    );
    _imageController = TextEditingController(text: product?.imageUrl ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _ProductInput(
        name: _nameController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        description: _descriptionController.text.trim(),
        imageUrl: _imageController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return AlertDialog(
      title: Text(product == null ? 'Add a product' : 'Edit product'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a product name'
                      : null,
                ),
                TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Price'),
                  validator: (value) {
                    final price = double.tryParse(value?.trim() ?? '');
                    return price == null || price < 0
                        ? 'Enter a valid non-negative price'
                        : null;
                  },
                ),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Full description',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a product description'
                      : null,
                ),
                TextFormField(
                  controller: _imageController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Image URL (optional)',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(product == null ? 'Add product' : 'Save changes'),
        ),
      ],
    );
  }
}

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.isAdmin,
    required this.onEdit,
    required this.onDelete,
  });

  final Product product;
  final VoidCallback onTap;
  final bool isAdmin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ProductImage(product: product),
                  Positioned(
                    top: 11,
                    left: 11,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.91),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'PICKED FOR YOU',
                        style: TextStyle(
                          color: _forest,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.55,
                        ),
                      ),
                    ),
                  ),
                  if (isAdmin)
                    Positioned(
                      top: 5,
                      right: 5,
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.94),
                        shape: const CircleBorder(),
                        child: PopupMenuButton<String>(
                          tooltip: 'Manage product',
                          icon: const Icon(
                            Icons.more_horiz_rounded,
                            color: _ink,
                          ),
                          onSelected: (value) {
                            if (value == 'edit') onEdit();
                            if (value == 'delete') onDelete();
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                leading: Icon(Icons.edit_outlined),
                                title: Text('Edit'),
                                dense: true,
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(Icons.delete_outline),
                                title: Text('Delete'),
                                dense: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Text(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: _forest,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.arrow_outward_rounded,
                        color: _tomato,
                        size: 16,
                      ),
                    ],
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

class ProductImage extends StatelessWidget {
  const ProductImage({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) return _fallback();

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _fallback(showProgress: true);
      },
      errorBuilder: (context, error, stackTrace) => _fallback(),
    );
  }

  Widget _fallback({bool showProgress = false}) {
    final icon = switch (product.name) {
      'Canvas Backpack' => Icons.backpack_rounded,
      'Insulated Water Bottle' => Icons.water_drop_rounded,
      'Wireless Mouse' => Icons.mouse_rounded,
      'Desk Lamp' => Icons.lightbulb_rounded,
      'Bluetooth Speaker' => Icons.speaker_rounded,
      'Mechanical Keyboard' => Icons.keyboard_rounded,
      'Running Shoes' => Icons.directions_run_rounded,
      'Travel Mug' => Icons.local_cafe_rounded,
      'Wireless Earbuds' => Icons.headphones_rounded,
      'Smart Watch' => Icons.watch_rounded,
      'Tablet Stand' => Icons.tablet_android_rounded,
      'USB-C Hub' => Icons.usb_rounded,
      _ => Icons.shopping_bag_rounded,
    };

    return ColoredBox(
      color: _sunshine.withValues(alpha: 0.22),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -35,
            bottom: -45,
            child: Container(
              width: 125,
              height: 125,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: showProgress
                ? const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _forest,
                  )
                : Container(
                    padding: const EdgeInsets.all(17),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: _forest, size: 36),
                  ),
          ),
        ],
      ),
    );
  }
}

class ProductDetailsSheet extends StatelessWidget {
  const ProductDetailsSheet({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.88;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Container(
          height: height,
          decoration: const BoxDecoration(
            color: _paper,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD6D8CF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _ink,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: AspectRatio(
                          aspectRatio: 1.12,
                          child: ProductImage(product: product),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _sunshine.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'A GOOD FIND',
                          style: TextStyle(
                            color: _forest,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        product.name,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: _ink,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.7,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: _forest,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Divider(color: Color(0xFFE8E5DA)),
                      const SizedBox(height: 12),
                      Text(
                        'About this find',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: _ink,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        product.description,
                        style: const TextStyle(
                          color: Color(0xFF626858),
                          height: 1.65,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogMessage extends StatelessWidget {
  const _CatalogMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: _forest, size: 42),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF737969), height: 1.5),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.trailing = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool trailing;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: _forest,
        disabledForegroundColor: const Color(0xFFB3B8AC),
        side: BorderSide(
          color: onPressed == null ? const Color(0xFFE5E6DF) : _forest,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: trailing
            ? [Text(label), const SizedBox(width: 7), Icon(icon, size: 17)]
            : [Icon(icon, size: 17), const SizedBox(width: 7), Text(label)],
      ),
    );
  }
}

class _ProductInput {
  const _ProductInput({
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
  });

  final String name;
  final String description;
  final double price;
  final String imageUrl;

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'price': price,
    'image_url': imageUrl.isEmpty ? null : imageUrl,
  };
}
