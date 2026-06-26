with open('lib/ats_cv_builder_screen.dart', 'r', encoding='utf-8') as f:
    c = f.read()

# Add import
if 'purchase_service.dart' not in c:
    c = c.replace(
        "import 'remote_config_service.dart';",
        "import 'remote_config_service.dart';\nimport 'purchase_service.dart';"
    )

# Update premium designs set - Grid(3), Ubuntu(4), Vivid(5)
c = c.replace(
    "static const _premiumDesigns = {4, 5};",
    "static const _premiumDesigns = {3, 4, 5};"
)

# Add isPremium state variable after _savedCount
c = c.replace(
    "  int _savedCount = 0;",
    "  int _savedCount = 0;\n  bool _isPremium = false;"
)

# Add initState to load purchase service
c = c.replace(
    "  _S _state = _S.upload;",
    "  _S _state = _S.upload;\n\n  @override\n  void initState() {\n    super.initState();\n    _initPurchases();\n  }\n\n  Future<void> _initPurchases() async {\n    final svc = PurchaseService();\n    svc.onPurchaseSuccess = () {\n      if (mounted) setState(() => _isPremium = true);\n    };\n    await svc.init();\n    if (mounted) setState(() => _isPremium = svc.isPremium);\n  }"
)

with open('lib/ats_cv_builder_screen.dart', 'w', encoding='utf-8') as f:
    f.write(c)
print('Purchase integration added.')
