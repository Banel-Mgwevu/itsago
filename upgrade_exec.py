with open('lib/ats_cv_builder_screen.dart', 'r', encoding='utf-8') as f:
    c = f.read()

# Upgrade Executive card preview
old_exec_card = """  Widget _execCardPreview() {
    const navy = Color(0xFF1C1C3A); const gold = Color(0xFFD4AF37);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: double.infinity, color: navy, padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_s('name').toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
          const SizedBox(height: 3), Container(width: 40, height: 2, color: gold), const SizedBox(height: 6),
          if (_s('headline').isNotEmpty) Text(_s('headline'), style: TextStyle(fontSize: 11, color: gold, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text([_s('email'), _s('phone'), _s('location')].where((v) => v.isNotEmpty).join('  -  '),
            style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.7))),
        ])),
      Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_s('summary').isNotEmpty) ...[
          Row(children: [
            Text('PROFESSIONAL SUMMARY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: navy,letterSpacing: 1.5)),
            const SizedBox(width: 6), Expanded(child: Container(height: 1, color: gold)),
          ]),
          const SizedBox(height: 6),
          Text(_s('summary'), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10,height: 1.5, color: Colors.black87)),
          const SizedBox(height: 10),
        ],
        if (_list('skills').isNotEmpty) ...[
          Row(children: [
            Text('SKILLS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: navy, letterSpacing: 1.5)),
            const SizedBox(width: 6), Expanded(child: Container(height: 1, color: gold)),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4,
            children: _list('skills').take(6).map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(border: Border.all(color: gold)),
              child: Text(s, style: const TextStyle(fontSize: 9)))).toList()),
        ],
        const SizedBox(height: 4),
      ])),
    ]);
  }"""

new_exec_card = """  Widget _execCardPreview() {
    const navy = Color(0xFF0D1B2A);
    const gold = Color(0xFFD4AF37);
    const cream = Color(0xFFFAF8F3);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: double.infinity, color: navy, padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 3, height: 36, color: gold),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_s('name').toUpperCase(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
              const SizedBox(height: 3),
              if (_s('headline').isNotEmpty) Text(_s('headline'), style: TextStyle(fontSize: 10, color: gold, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            ])),
          ]),
          const SizedBox(height: 10),
          Container(width: double.infinity, height: 0.5, color: gold.withOpacity(0.4)),
          const SizedBox(height: 8),
          Row(children: [
            if (_s('email').isNotEmpty) ...[
              Icon(Icons.mail_outline, color: gold, size: 9),
              const SizedBox(width: 3),
              Text(_s('email'), style: TextStyle(fontSize: 8, color: Colors.white.withOpacity(0.7))),
              const SizedBox(width: 10),
            ],
            if (_s('phone').isNotEmpty) ...[
              Icon(Icons.phone_outlined, color: gold, size: 9),
              const SizedBox(width: 3),
              Text(_s('phone'), style: TextStyle(fontSize: 8, color: Colors.white.withOpacity(0.7))),
            ],
          ]),
        ])),
      Container(color: cream, padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_s('summary').isNotEmpty) ...[
          Row(children: [
            Container(width: 12, height: 12, color: navy),
            const SizedBox(width: 6),
            Text('PROFESSIONAL SUMMARY', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: navy, letterSpacing: 1.5)),
            const SizedBox(width: 6),
            Expanded(child: Container(height: 0.5, color: gold)),
          ]),
          const SizedBox(height: 6),
          Text(_s('summary'), maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, height: 1.6, color: Colors.grey[800])),
          const SizedBox(height: 10),
        ],
        if (_exp().isNotEmpty) ...[
          Row(children: [
            Container(width: 12, height: 12, color: gold),
            const SizedBox(width: 6),
            Text('EXPERIENCE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: navy, letterSpacing: 1.5)),
            const SizedBox(width: 6),
            Expanded(child: Container(height: 0.5, color: gold)),
          ]),
          const SizedBox(height: 6),
          Text((_exp().first['title'] ?? '').toString().toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: navy)),
          Text((_exp().first['company'] ?? '').toString(), style: TextStyle(fontSize: 8, color: gold, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
        ],
        if (_list('skills').isNotEmpty) ...[
          Row(children: [
            Container(width: 12, height: 12, color: navy.withOpacity(0.5)),
            const SizedBox(width: 6),
            Text('CORE SKILLS', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: navy, letterSpacing: 1.5)),
            const SizedBox(width: 6),
            Expanded(child: Container(height: 0.5, color: gold)),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing: 4, runSpacing: 4, children: _list('skills').take(5).map((s) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: navy, border: Border.all(color: gold, width: 0.5)),
            child: Text(s, style: const TextStyle(fontSize: 8, color: Colors.white)))).toList()),
        ],
        const SizedBox(height: 4),
      ])),
    ]);
  }"""

c = c.replace(old_exec_card, new_exec_card)

# Upgrade Executive PDF design
old_exec_pdf = """  Future<Uint8List> _execDesign() async {
    const navy = PdfColor.fromInt(0xFF1C1C3A); const gold = PdfColor.fromInt(0xFFD4AF37);
    const dark = PdfColor.fromInt(0xFF1A1A1A); const muted = PdfColor.fromInt(0xFF666666);
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, margin: pw.EdgeInsets.zero, build: (ctx) => [
      pw.Container(color: navy, padding: const pw.EdgeInsets.all(30), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(_s('name').toUpperCase(), style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 3)),
        pw.SizedBox(height: 6), pw.Container(width: 60, height: 3, color: gold), pw.SizedBox(height: 8),
        if (_s('headline').isNotEmpty) pw.Text(_s('headline'), style: pw.TextStyle(fontSize: 12, color: gold, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Text(_contact(), style: pw.TextStyle(fontSize: 10, color: PdfColor(1,1,1,0.7))),
        if (_s('linkedin').isNotEmpty) ...[pw.SizedBox(height: 4), pw.Text(_s('linkedin'), style: pw.TextStyle(fontSize: 9, color: PdfColor(1,1,1,0.54)))],
      ])),
      pw.Container(padding: const pw.EdgeInsets.all(30), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        if (_s('summary').isNotEmpty) ...[_eSec('PROFESSIONAL SUMMARY', gold, navy), pw.SizedBox(height: 8), pw.Text(_s('summary'), style: pw.TextStyle(fontSize: 11, color: dark, lineSpacing: 2)), pw.SizedBox(height: 20)],
        if (_exp().isNotEmpty) ...[_eSec('PROFESSIONAL EXPERIENCE', gold, navy), pw.SizedBox(height: 10),
          ..._exp().map((e) => pw.Container(margin: const pw.EdgeInsets.only(bottom: 16), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(e['title'].toString().toUpperCase(), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: dark)),
            pw.SizedBox(height: 2),
            pw.Text('\${e[\\'company\\']}  |  \${e[\\'duration\\']}', style: pw.TextStyle(fontSize: 10, color: muted, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            ..._bullets(e).map((b) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('- ', style: pw.TextStyle(fontSize: 10, color: gold)),
                pw.Expanded(child: pw.Text(b, style: pw.TextStyle(fontSize: 10, color: dark, lineSpacing: 1.5))),
              ]))),
          ]))), pw.SizedBox(height: 10)],
        if (_edu().isNotEmpty) ...[_eSec('EDUCATION', gold, navy), pw.SizedBox(height: 10),
          ..._edu().map((e) => pw.Container(margin: const pw.EdgeInsets.only(bottom: 10), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(e['degree'].toString().toUpperCase(), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: dark)),
            pw.Text('\${e[\\'institution\\']}  |  \${e[\\'year\\']}', style: pw.TextStyle(fontSize: 10, color: muted)),
          ]))), pw.SizedBox(height: 10)],
        if (_list('certifications').isNotEmpty) ...[_eSec('CERTIFICATIONS', gold, navy), pw.SizedBox(height: 10),
          ..._list('certifications').map((c) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Row(children: [pw.Container(width: 6, height: 6, color: gold), pw.SizedBox(width: 8), pw.Text(c, style: pw.TextStyle(fontSize: 10, color: dark))]))),"""

new_exec_pdf = """  Future<Uint8List> _execDesign() async {
    const navy = PdfColor.fromInt(0xFF0D1B2A);
    const gold = PdfColor.fromInt(0xFFD4AF37);
    const cream = PdfColor.fromInt(0xFFFAF8F3);
    const dark = PdfColor.fromInt(0xFF1A1A1A);
    const muted = PdfColor.fromInt(0xFF555555);
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, margin: pw.EdgeInsets.zero, build: (ctx) => [
      // Premium header with left accent bar
      pw.Container(color: navy, padding: const pw.EdgeInsets.fromLTRB(0, 28, 30, 28),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Container(width: 6, color: gold),
          pw.SizedBox(width: 24),
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(_s('name').toUpperCase(), style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 3)),
            pw.SizedBox(height: 6),
            if (_s('headline').isNotEmpty) pw.Text(_s('headline'), style: pw.TextStyle(fontSize: 12, color: gold, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5)),
            pw.SizedBox(height: 14),
            pw.Container(width: double.infinity, height: 0.5, color: PdfColor(1,1,1,0.2)),
            pw.SizedBox(height: 10),
            pw.Row(children: [
              if (_s('email').isNotEmpty) ...[pw.Text(_s('email'), style: pw.TextStyle(fontSize: 9, color: PdfColor(1,1,1,0.7))), pw.SizedBox(width: 16)],
              if (_s('phone').isNotEmpty) ...[pw.Text(_s('phone'), style: pw.TextStyle(fontSize: 9, color: PdfColor(1,1,1,0.7))), pw.SizedBox(width: 16)],
              if (_s('location').isNotEmpty) pw.Text(_s('location'), style: pw.TextStyle(fontSize: 9, color: PdfColor(1,1,1,0.7))),
            ]),
            if (_s('linkedin').isNotEmpty) ...[pw.SizedBox(height: 4), pw.Text(_s('linkedin'), style: pw.TextStyle(fontSize: 8, color: PdfColor(1,1,1,0.45)))],
          ])),
        ])),
      // Body on cream background
      pw.Container(color: cream, padding: const pw.EdgeInsets.all(30), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        if (_s('summary').isNotEmpty) ...[_eSec('PROFESSIONAL SUMMARY', gold, navy), pw.SizedBox(height: 8), pw.Text(_s('summary'), style: pw.TextStyle(fontSize: 10.5, color: dark, lineSpacing: 2.2)), pw.SizedBox(height: 22)],
        if (_exp().isNotEmpty) ...[_eSec('PROFESSIONAL EXPERIENCE', gold, navy), pw.SizedBox(height: 12),
          ..._exp().map((e) => pw.Container(margin: const pw.EdgeInsets.only(bottom: 16),
            child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Container(width: 3, color: gold, margin: const pw.EdgeInsets.only(right: 12, top: 2), height: 14),
              pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(e['title'].toString().toUpperCase(), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: navy, letterSpacing: 0.5)),
                pw.SizedBox(height: 2),
                pw.Text(e['company'].toString() + '   |   ' + e['duration'].toString(), style: pw.TextStyle(fontSize: 9.5, color: muted, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                ..._bullets(e).map((b) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Container(width: 5, height: 5, color: gold, margin: const pw.EdgeInsets.only(top: 3, right: 8)),
                    pw.Expanded(child: pw.Text(b, style: pw.TextStyle(fontSize: 10, color: dark, lineSpacing: 1.6))),
                  ]))),
              ])),
            ]))), pw.SizedBox(height: 10)],
        if (_edu().isNotEmpty) ...[_eSec('EDUCATION', gold, navy), pw.SizedBox(height: 10),
          ..._edu().map((e) => pw.Container(margin: const pw.EdgeInsets.only(bottom: 10), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(e['degree'].toString().toUpperCase(), style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: navy)),
            pw.Text(e['institution'].toString() + '   |   ' + e['year'].toString(), style: pw.TextStyle(fontSize: 9.5, color: muted)),
          ]))), pw.SizedBox(height: 12)],
        if (_list('certifications').isNotEmpty) ...[_eSec('CERTIFICATIONS', gold, navy), pw.SizedBox(height: 10),
          ..._list('certifications').map((c) => pw.Padding(padding: const pw.EdgeInsets.only(bottom: 5),
            child: pw.Row(children: [pw.Container(width: 5, height: 5, color: gold), pw.SizedBox(width: 10), pw.Text(c, style: pw.TextStyle(fontSize: 10, color: dark))]))),"""

c = c.replace(old_exec_pdf, new_exec_pdf)

with open('lib/ats_cv_builder_screen.dart', 'w', encoding='utf-8') as f:
    f.write(c)
print('Executive upgraded.')
