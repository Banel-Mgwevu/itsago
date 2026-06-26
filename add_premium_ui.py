with open('lib/ats_cv_builder_screen.dart', 'r', encoding='utf-8') as f:
    c = f.read()

# Update design picker item to show premium lock
old_picker = """          final isSelected = _selectedDesign == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedDesign = i),"""

new_picker = """          final isSelected = _selectedDesign == i;
          final isPremiumDesign = _premiumDesigns.contains(i);
          final isLocked = isPremiumDesign && !_isPremium;
          return GestureDetector(
            onTap: () {
              if (isLocked) {
                _showPremiumDialog();
                return;
              }
              setState(() => _selectedDesign = i);
            },"""

c = c.replace(old_picker, new_picker)

# Add premium badge to header
old_header = """                    Text(_designNames[i], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
                    const SizedBox(width: 8),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), color: Colors.white24,
                      child: Text(tags[i], style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1))),
                    const Spacer(),
                    if (isSelected) const Icon(Icons.check_circle, color: Colors.white, size: 18)
                    else Text('TAP TO SELECT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color:Colors.white70, letterSpacing: 1)),"""

new_header = """                    Text(_designNames[i], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
                    const SizedBox(width: 8),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), color: Colors.white24,
                      child: Text(tags[i], style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1))),
                    if (isLocked) ...[
                      const SizedBox(width: 6),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), color: const Color(0xFFFFD700),
                        child: const Text('PREMIUM', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 1))),
                    ],
                    const Spacer(),
                    if (isLocked) const Icon(Icons.lock_rounded, color: Colors.white70, size: 18)
                    else if (isSelected) const Icon(Icons.check_circle, color: Colors.white, size: 18)
                    else Text('TAP TO SELECT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color:Colors.white70, letterSpacing: 1)),"""

c = c.replace(old_header, new_header)

# Add premium dialog method before _hdrs
c = c.replace(
    "  Map<String, String> _hdrs() => {};",
    """  void _showPremiumDialog() {
    showDialog(context: context, builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4,4), blurRadius: 0)]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: double.infinity, color: const Color(0xFF1C1C3A), padding: const EdgeInsets.all(16),
            child: const Column(children: [
              Icon(Icons.lock_open_rounded, color: Color(0xFFFFD700), size: 32),
              SizedBox(height: 8),
              Text('PREMIUM TEMPLATES', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
              SizedBox(height: 4),
              Text('Unlock Grid, Ubuntu and Vivid', style: TextStyle(fontSize: 11, color: Colors.white70)),
            ])),
          Padding(padding: const EdgeInsets.all(20), child: Column(children: [
            _premiumFeature(Icons.grid_view_rounded, 'Grid Template', 'Modern tech layout'),
            _premiumFeature(Icons.eco_rounded, 'Ubuntu Template', 'Clean entry-level design'),
            _premiumFeature(Icons.palette_rounded, 'Vivid Template', 'Bold creative design'),
            const SizedBox(height: 16),
            const Text('One time payment', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 4),
            const Text('R29', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                final svc = PurchaseService();
                await svc.buyPremiumTemplates();
              },
              child: Container(width: double.infinity, height: 52,
                decoration: BoxDecoration(color: const Color(0xFF1C1C3A), border: Border.all(color: Colors.black, width: 2),
                  boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4,4), blurRadius: 0)]),
                child: const Center(child: Text('UNLOCK PREMIUM', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2))))),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                await PurchaseService().restorePurchases();
              },
              child: const Text('Restore purchase', style: TextStyle(fontSize: 11, color: Colors.grey, decoration: TextDecoration.underline))),
          ])),
        ]))));
  }

  Widget _premiumFeature(IconData icon, String title, String sub) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Icon(icon, color: const Color(0xFF1C1C3A), size: 20),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        Text(sub, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ]),
    ]));

  Map<String, String> _hdrs() => {};"""
)

with open('lib/ats_cv_builder_screen.dart', 'w', encoding='utf-8') as f:
    f.write(c)
print('Premium dialog added.')
