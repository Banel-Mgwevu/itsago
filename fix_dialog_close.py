with open('lib/ats_cv_builder_screen.dart', 'r', encoding='utf-8') as f:
    c = f.read()

old_button = """            GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                final svc = PurchaseService();
                await svc.buyPremiumTemplates();
              },
              child: Container(width: double.infinity, height: 52,
                decoration: BoxDecoration(color: const Color(0xFF1C1C3A), border: Border.all(color: Colors.black, width: 2),
                  boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4,4), blurRadius: 0)]),
                child: const Center(child: Text('UNLOCK PREMIUM', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2))))),"""

new_button = """            GestureDetector(
              onTap: () async {
                final svc = PurchaseService();
                final started = await svc.buyPremiumTemplates();
                if (mounted) {
                  Navigator.pop(context);
                  if (!started) {
                    // error already shown via onPurchaseError callback
                  }
                }
              },
              child: Container(width: double.infinity, height: 52,
                decoration: BoxDecoration(color: const Color(0xFF1C1C3A), border: Border.all(color: Colors.black, width: 2),
                  boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4,4), blurRadius: 0)]),
                child: const Center(child: Text('UNLOCK PREMIUM', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2))))),"""

c = c.replace(old_button, new_button)

with open('lib/ats_cv_builder_screen.dart', 'w', encoding='utf-8') as f:
    f.write(c)
print('Fixed.')
