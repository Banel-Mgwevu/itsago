with open('lib/ats_cv_builder_screen.dart', 'r', encoding='utf-8') as f:
    c = f.read()

old = """            onTap: () async {
              if (isLocked) {
                _showPremiumDialog();
                return;
              }
              setState(() => _selectedDesign = i);
            },"""

new = """            onTap: () async {
              if (isLocked) {
                if (FirebaseAuth.instance.currentUser == null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Please sign in first to unlock premium templates.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    backgroundColor: AppColors.red, duration: const Duration(seconds: 4)));
                  return;
                }
                _showPremiumDialog();
                return;
              }
              setState(() => _selectedDesign = i);
            },"""

c = c.replace(old, new)

with open('lib/ats_cv_builder_screen.dart', 'w', encoding='utf-8') as f:
    f.write(c)
print('Fixed.')
