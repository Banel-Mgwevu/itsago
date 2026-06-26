with open('lib/ats_cv_builder_screen.dart', 'r', encoding='utf-8') as f:
    c = f.read()

# Fix the broken initState block
old_block = """  @override
  void initState() {
    super.initState();
    super.initState();
    _initPurchases();
    _init();
  Future<void> _initPurchases() async {
    final svc = PurchaseService();
    svc.onPurchaseSuccess = () {
      if (mounted) setState(() => _isPremium = true);
    };
    await svc.init();
    if (mounted) setState(() => _isPremium = svc.isPremium);
  }
  File?  _file;"""

new_block = """  @override
  void initState() {
    super.initState();
    _initPurchases();
    _init();
  }

  Future<void> _initPurchases() async {
    final svc = PurchaseService();
    svc.onPurchaseSuccess = () {
      if (mounted) setState(() => _isPremium = true);
    };
    await svc.init();
    if (mounted) setState(() => _isPremium = svc.isPremium);
  }

  File?  _file;"""

c = c.replace(old_block, new_block)

# Also remove the stray @override with nothing after it
c = c.replace("  String? _docErrorMsg;\n\n  @override\n\n\n  static const _sessionKey", "  String? _docErrorMsg;\n\n  static const _sessionKey")

with open('lib/ats_cv_builder_screen.dart', 'w', encoding='utf-8') as f:
    f.write(c)
print('Fixed.')
