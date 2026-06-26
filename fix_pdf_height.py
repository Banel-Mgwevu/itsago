with open('lib/ats_cv_builder_screen.dart', 'r', encoding='utf-8') as f:
    c = f.read()

# Fix Vivid - reduce content to fit page
c = c.replace(
    "..._exp().map((e) => pw.Container(\n                margin: const pw.EdgeInsets.only(bottom: 12),\n                padding: const pw.EdgeInsets.all(10),\n                color: light,",
    "..._exp().take(3).map((e) => pw.Container(\n                margin: const pw.EdgeInsets.only(bottom: 8),\n                padding: const pw.EdgeInsets.all(8),\n                color: light,"
)

# Fix Ubuntu - reduce content to fit page
c = c.replace(
    "..._exp().map((e) => pw.Container(margin: const pw.EdgeInsets.only(bottom: 12),",
    "..._exp().take(3).map((e) => pw.Container(margin: const pw.EdgeInsets.only(bottom: 10),"
)

with open('lib/ats_cv_builder_screen.dart', 'w', encoding='utf-8') as f:
    f.write(c)
print('Fixed PDF height.')
