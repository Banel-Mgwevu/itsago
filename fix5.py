with open('lib/ats_scoring_service.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Rewrite lines 43-60 (0-indexed 42-59)
new_block = """    try {
      final res = await CloudFunctionService.callClaude(
        model: 'claude-haiku-4-5-20251001',
        maxTokens: 800,
        messages: [{'role': 'user', 'content': prompt}],
      );
      final raw   = CloudFunctionService.extractText(res);
      final clean = raw.replaceAll('```json','').replaceAll('```','').trim();
      final data  = jsonDecode(clean) as Map<String, dynamic>;
      return ATSScore.fromJson(data);
    } catch (_) {}
    return ATSScore.failed();
  }
}
"""

fixed = lines[:42] + [new_block]
with open('lib/ats_scoring_service.dart', 'w', encoding='utf-8') as f:
    f.writelines(fixed)
print('Fixed ats_scoring_service.dart')

# Fix ai_coach_screen.dart - setState is being called wrong
# The issue is setState is defined somewhere as taking 0 args
# Check for duplicate setState definition
with open('lib/ai_coach_screen.dart', 'r', encoding='utf-8') as f:
    c = f.read()

# Remove any accidental setState redefinition
import re
c = re.sub(r'void setState\(\) \{[^}]+\}', '', c)

with open('lib/ai_coach_screen.dart', 'w', encoding='utf-8') as f:
    f.write(c)
print('Fixed ai_coach_screen.dart')

# Fix ats_cv_builder_screen.dart - extra closing brace at line 1907
with open('lib/ats_cv_builder_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Find and remove the extra } at line 1907
fixed = []
for i, line in enumerate(lines):
    if i == 1906 and line.strip() == '}':
        pass  # skip extra brace
    else:
        fixed.append(line)

with open('lib/ats_cv_builder_screen.dart', 'w', encoding='utf-8') as f:
    f.writelines(fixed)
print('Fixed ats_cv_builder_screen.dart')

print('All done.')
