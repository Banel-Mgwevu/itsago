with open('lib/ats_cv_builder_screen.dart', 'r', encoding='utf-8') as f:
    c = f.read()

old_price = """            const Text('One time payment', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 4),
            const Text('R29', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),"""

new_price = """            Container(
              width: double.infinity,
              color: Color(0xFFFFD700),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Center(child: Text('LIMITED LAUNCH OFFER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: 2)))),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('R59', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.grey, decoration: TextDecoration.lineThrough)),
              const SizedBox(width: 12),
              Text('R29', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF1C1C3A))),
            ]),
            const SizedBox(height: 4),
            const Text('You save R30 - 50% off', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),"""

c = c.replace(old_price, new_price)

with open('lib/ats_cv_builder_screen.dart', 'w', encoding='utf-8') as f:
    f.write(c)
print('Pricing updated.')
