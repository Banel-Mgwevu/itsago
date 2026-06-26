with open('lib/ats_cv_builder_screen.dart', 'r', encoding='utf-8') as f:
    c = f.read()

# Fix Ubuntu design - company/duration line
c = c.replace(
    'pw.Text("${e["company"]}  -  ${e["duration"]}", style: pw.TextStyle(fontSize: 9, color: green, fontWeight: pw.FontWeight.bold)),',
    "pw.Text('${e['company']}  -  ${e['duration']}', style: pw.TextStyle(fontSize: 9, color: green, fontWeight: pw.FontWeight.bold)),"
)

# Fix Ubuntu design - institution/year line
c = c.replace(
    'pw.Text("${e["institution"]}  -  ${e["year"]}", style: pw.TextStyle(fontSize: 9, color: green)),',
    "pw.Text('${e['institution']}  -  ${e['year']}', style: pw.TextStyle(fontSize: 9, color: green)),"
)

# Fix Ubuntu design - bullet line
c = c.replace(
    'pw.Text("- $b", style: pw.TextStyle(fontSize: 9, color: dark, lineSpacing: 1.5))',
    "pw.Text('- $b', style: pw.TextStyle(fontSize: 9, color: dark, lineSpacing: 1.5))"
)

# Fix Vivid design - company/duration line
c = c.replace(
    'pw.Text("${e["company"]}  -  ${e["duration"]}", style: pw.TextStyle(fontSize: 9, color: pink, fontWeight: pw.FontWeight.bold)),',
    "pw.Text('${e['company']}  -  ${e['duration']}', style: pw.TextStyle(fontSize: 9, color: pink, fontWeight: pw.FontWeight.bold)),"
)

# Fix Vivid design - institution/year line
c = c.replace(
    'pw.Text("${e["institution"]}  -  ${e["year"]}", style: pw.TextStyle(fontSize: 9, color: purple)),',
    "pw.Text('${e['institution']}  -  ${e['year']}', style: pw.TextStyle(fontSize: 9, color: purple)),"
)

# Fix Vivid design - bullet line  
c = c.replace(
    'pw.Text("-  $b", style: pw.TextStyle(fontSize: 9, color: dark, lineSpacing: 1.5))',
    "pw.Text('-  $b', style: pw.TextStyle(fontSize: 9, color: dark, lineSpacing: 1.5))"
)

with open('lib/ats_cv_builder_screen.dart', 'w', encoding='utf-8') as f:
    f.write(c)
print('Fixed.')
