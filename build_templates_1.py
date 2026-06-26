import re

with open('lib/ats_cv_builder_screen.dart', 'r', encoding='utf-8') as f:
    c = f.read()

# 1. Update design names to include 2 premium templates
c = c.replace(
    "static const _designNames = ['EXECUTIVE', 'SPECTRUM', 'MINIMAL', 'GRID'];",
    "static const _designNames = ['EXECUTIVE', 'SPECTRUM', 'MINIMAL', 'GRID', 'UBUNTU', 'VIVID'];\n  static const _premiumDesigns = {4, 5};"
)

# 2. Update tags in design picker
c = c.replace(
    "final tags   = ['CORPORATE', 'CREATIVE', 'UNIVERSAL', 'TECH'];",
    "final tags   = ['CORPORATE', 'CREATIVE', 'UNIVERSAL', 'TECH', 'ENTRY LEVEL', 'CREATIVE'];"
)

# 3. Update colors in design picker
c = c.replace(
    "final colors = [const Color(0xFF1C1C3A), const Color(0xFF2E4057), const Color(0xFF333333), AppColors.blue];",
    "final colors = [const Color(0xFF1C1C3A), const Color(0xFF2E4057), const Color(0xFF333333), AppColors.blue, const Color(0xFF2D6A4F), const Color(0xFF6B2D8B)];"
)

# 4. Update itemCount from 4 to 6
c = c.replace("        itemCount: 4,", "        itemCount: 6,")

# 5. Update cvCardPreview switch
c = c.replace(
    """  Widget _cvCardPreview(int i) {
    switch (i) {
      case 0: return _execCardPreview();
      case 1: return _specCardPreview();
      case 2: return _minCardPreview();
      case 3: return _gridCardPreview();
      default: return _execCardPreview();
    }
  }""",
    """  Widget _cvCardPreview(int i) {
    switch (i) {
      case 0: return _execCardPreview();
      case 1: return _specCardPreview();
      case 2: return _minCardPreview();
      case 3: return _gridCardPreview();
      case 4: return _ubuntuCardPreview();
      case 5: return _vividCardPreview();
      default: return _execCardPreview();
    }
  }

  Widget _ubuntuCardPreview() {
    const green = Color(0xFF2D6A4F);
    const lightGreen = Color(0xFF52B788);
    return Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: double.infinity, padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border(left: BorderSide(color: green, width: 4))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_s('name').toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 3),
          if (_s('headline').isNotEmpty) Text(_s('headline'), style: TextStyle(fontSize: 11, color: green, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text([_s('email'), _s('phone')].where((v) => v.isNotEmpty).join('  .  '), style: TextStyle(fontSize: 9, color: Colors.grey[600])),
        ])),
      const SizedBox(height: 10),
      Container(width: double.infinity, height: 1, color: lightGreen),
      const SizedBox(height: 10),
      if (_s('summary').isNotEmpty) ...[
        Text('PROFILE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: green, letterSpacing: 2)),
        const SizedBox(height: 4),
        Text(_s('summary'), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, height: 1.5)),
        const SizedBox(height: 8),
      ],
      if (_list('skills').isNotEmpty) ...[
        Text('SKILLS', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: green, letterSpacing: 2)),
        const SizedBox(height: 4),
        Wrap(spacing: 6, runSpacing: 4, children: _list('skills').take(6).map((s) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          color: lightGreen.withOpacity(0.15),
          child: Text(s, style: TextStyle(fontSize: 9, color: green, fontWeight: FontWeight.w600)))).toList()),
      ],
    ]));
  }

  Widget _vividCardPreview() {
    const purple = Color(0xFF6B2D8B);
    const pink = Color(0xFFE91E8C);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: double.infinity,
        decoration: BoxDecoration(gradient: LinearGradient(colors: [purple, pink], begin: Alignment.centerLeft, end: Alignment.centerRight)),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_s('name').toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
          const SizedBox(height: 3),
          if (_s('headline').isNotEmpty) Text(_s('headline'), style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text([_s('email'), _s('phone')].where((v) => v.isNotEmpty).join('  .  '), style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.7))),
        ])),
      Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_s('summary').isNotEmpty) ...[
          Row(children: [Container(width: 16, height: 16, color: pink, child: const SizedBox()), const SizedBox(width: 6), Text('ABOUT ME', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: purple, letterSpacing: 2))]),
          const SizedBox(height: 6),
          Text(_s('summary'), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, height: 1.5)),
          const SizedBox(height: 10),
        ],
        if (_list('skills').isNotEmpty) ...[
          Row(children: [Container(width: 16, height: 16, color: purple, child: const SizedBox()), const SizedBox(width: 6), Text('SKILLS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: purple, letterSpacing: 2))]),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4, children: _list('skills').take(6).map((s) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(border: Border.all(color: pink), borderRadius: BorderRadius.circular(12)),
            child: Text(s, style: TextStyle(fontSize: 9, color: purple)))).toList()),
        ],
      ])),
    ]);
  }"""
)

# 6. Update download UI labels
c = c.replace(
    "final labels   = ['Executive', 'Spectrum', 'Minimal', 'Grid'];",
    "final labels   = ['Executive', 'Spectrum', 'Minimal', 'Grid', 'Ubuntu', 'Vivid'];"
)

# 7. Update generation list
c = c.replace(
    "      final gens = [_execDesign, _spectrumDesign, _minimalDesign, _gridDesign];\n      for (int i = 0; i < gens.length; i++) {\n        try {\n          _pdfs.add(await gens[i]());\n          setState(() => _genProgress = 0.08 + ((i + 1) / 4) * 0.92);",
    "      final gens = [_execDesign, _spectrumDesign, _minimalDesign, _gridDesign, _ubuntuDesign, _vividDesign];\n      for (int i = 0; i < gens.length; i++) {\n        try {\n          _pdfs.add(await gens[i]());\n          setState(() => _genProgress = 0.08 + ((i + 1) / 6) * 0.92);"
)

# 8. Update design error names
c = c.replace(
    'throw Exception(\'Design ${"EXEC","SPEC","MIN","GRID"][i]} failed: $e\');',
    'throw Exception(\'Design ${"EXEC","SPEC","MIN","GRID","UBU","VVD"][i]} failed: $e\');'
)

# 9. Update progress dots from 4 to 6
c = c.replace(
    "          children: List.generate(4, (i) {",
    "          children: List.generate(6, (i) {"
)

with open('lib/ats_cv_builder_screen.dart', 'w', encoding='utf-8') as f:
    f.write(c)
print('Step 1 done - UI and previews added')
