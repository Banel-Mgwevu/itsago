with open('lib/ats_cv_builder_screen.dart', 'r', encoding='utf-8') as f:
    c = f.read()

ubuntu_design = '''
  Future<Uint8List> _ubuntuDesign() async {
    const green = PdfColor.fromInt(0xFF2D6A4F);
    const lightGreen = PdfColor.fromInt(0xFF52B788);
    const dark = PdfColor.fromInt(0xFF1A1A1A);
    const gray = PdfColor.fromInt(0xFF555555);
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (ctx) => [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Container(width: 4, height: 60, color: green),
          pw.SizedBox(width: 12),
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(_s("name").toUpperCase(), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: dark, letterSpacing: 2)),
            pw.SizedBox(height: 4),
            if (_s("headline").isNotEmpty) pw.Text(_s("headline"), style: pw.TextStyle(fontSize: 11, color: green, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(_contact(), style: pw.TextStyle(fontSize: 9, color: gray)),
          ])),
        ]),
        pw.SizedBox(height: 12),
        pw.Container(width: double.infinity, height: 1.5, color: lightGreen),
        pw.SizedBox(height: 16),
        if (_s("summary").isNotEmpty) ...[
          _ubuSec("PROFILE", green, lightGreen),
          pw.SizedBox(height: 8),
          pw.Text(_s("summary"), style: pw.TextStyle(fontSize: 10, color: dark, lineSpacing: 1.8)),
          pw.SizedBox(height: 16),
        ],
        if (_list("skills").isNotEmpty) ...[
          _ubuSec("SKILLS", green, lightGreen),
          pw.SizedBox(height: 8),
          pw.Wrap(spacing: 8, runSpacing: 6, children: _list("skills").map((s) => pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            color: PdfColor.fromInt(0xFFD8F3DC),
            child: pw.Text(s, style: pw.TextStyle(fontSize: 9, color: green, fontWeight: pw.FontWeight.bold)))).toList()),
          pw.SizedBox(height: 16),
        ],
        if (_exp().isNotEmpty) ...[
          _ubuSec("EXPERIENCE", green, lightGreen),
          pw.SizedBox(height: 10),
          ..._exp().map((e) => pw.Container(margin: const pw.EdgeInsets.only(bottom: 12),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(e["title"].toString(), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: dark)),
              pw.Text("\${e["company"]}  -  \${e["duration"]}", style: pw.TextStyle(fontSize: 9, color: green, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              ..._bullets(e).take(3).map((b) => pw.Text("-  \$b", style: pw.TextStyle(fontSize: 9, color: dark, lineSpacing: 1.5))),
            ]))),
        ],
        if (_edu().isNotEmpty) ...[
          _ubuSec("EDUCATION", green, lightGreen),
          pw.SizedBox(height: 8),
          ..._edu().map((e) => pw.Container(margin: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(e["degree"].toString(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: dark)),
              pw.Text("\${e["institution"]}  -  \${e["year"]}", style: pw.TextStyle(fontSize: 9, color: green)),
            ]))),
        ],
      ]));
    return doc.save();
  }

  pw.Widget _ubuSec(String t, PdfColor green, PdfColor light) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    pw.Row(children: [
      pw.Container(width: 20, height: 3, color: green),
      pw.SizedBox(width: 6),
      pw.Text(t, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: green, letterSpacing: 2)),
    ]),
    pw.SizedBox(height: 4),
    pw.Container(width: double.infinity, height: 0.5, color: light),
  ]);
'''

vivid_design = '''
  Future<Uint8List> _vividDesign() async {
    const purple = PdfColor.fromInt(0xFF6B2D8B);
    const pink = PdfColor.fromInt(0xFFE91E8C);
    const dark = PdfColor.fromInt(0xFF1A1A1A);
    const light = PdfColor.fromInt(0xFFF3E5F5);
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (ctx) => [
        pw.Container(
          width: double.infinity,
          color: purple,
          padding: const pw.EdgeInsets.all(28),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(_s("name").toUpperCase(), style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 3)),
            pw.SizedBox(height: 6),
            if (_s("headline").isNotEmpty) pw.Text(_s("headline"), style: pw.TextStyle(fontSize: 11, color: PdfColor(1,1,1,0.8))),
            pw.SizedBox(height: 8),
            pw.Container(width: 60, height: 3, color: pink),
            pw.SizedBox(height: 8),
            pw.Text(_contact(), style: pw.TextStyle(fontSize: 9, color: PdfColor(1,1,1,0.7))),
          ])),
        pw.Container(
          padding: const pw.EdgeInsets.all(28),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            if (_s("summary").isNotEmpty) ...[
              _vividSec("ABOUT ME", purple, pink),
              pw.SizedBox(height: 8),
              pw.Text(_s("summary"), style: pw.TextStyle(fontSize: 10, color: dark, lineSpacing: 1.8)),
              pw.SizedBox(height: 16),
            ],
            if (_list("skills").isNotEmpty) ...[
              _vividSec("SKILLS", purple, pink),
              pw.SizedBox(height: 8),
              pw.Wrap(spacing: 8, runSpacing: 6, children: _list("skills").map((s) => pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: pink, width: 1)),
                child: pw.Text(s, style: pw.TextStyle(fontSize: 9, color: purple)))).toList()),
              pw.SizedBox(height: 16),
            ],
            if (_exp().isNotEmpty) ...[
              _vividSec("EXPERIENCE", purple, pink),
              pw.SizedBox(height: 10),
              ..._exp().map((e) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                padding: const pw.EdgeInsets.all(10),
                color: light,
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(e["title"].toString(), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: dark)),
                  pw.Text("\${e["company"]}  -  \${e["duration"]}", style: pw.TextStyle(fontSize: 9, color: pink, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  ..._bullets(e).take(3).map((b) => pw.Text("-  \$b", style: pw.TextStyle(fontSize: 9, color: dark, lineSpacing: 1.5))),
                ]))),
            ],
            if (_edu().isNotEmpty) ...[
              _vividSec("EDUCATION", purple, pink),
              pw.SizedBox(height: 8),
              ..._edu().map((e) => pw.Container(margin: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(e["degree"].toString(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: dark)),
                  pw.Text("\${e["institution"]}  -  \${e["year"]}", style: pw.TextStyle(fontSize: 9, color: purple)),
                ]))),
            ],
          ])),
      ]));
    return doc.save();
  }

  pw.Widget _vividSec(String t, PdfColor purple, PdfColor pink) => pw.Row(children: [
    pw.Container(width: 16, height: 16, color: pink),
    pw.SizedBox(width: 8),
    pw.Text(t, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: purple, letterSpacing: 2)),
  ]);
'''

# Insert both designs before the closing of the class
insert_before = "  Map<String, String> _hdrs() => {};"
c = c.replace(insert_before, ubuntu_design + vivid_design + insert_before)

with open('lib/ats_cv_builder_screen.dart', 'w', encoding='utf-8') as f:
    f.write(c)
print('Step 2 done - PDF generation added')
