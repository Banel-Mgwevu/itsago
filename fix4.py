# Fix ats_scoring_service.dart - misplaced return and extra brace
with open('lib/ats_scoring_service.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Lines 51-59 are broken - fix the structure
fixed = []
for i, line in enumerate(lines):
    # Remove the extra closing brace on line 57 (0-indexed: 56)
    if i == 56 and line.strip() == '}':
        fixed.append('        return ATSScore.fromJson(data);\n')
        fixed.append('      } catch (_) {}\n')
        fixed.append('    return ATSScore.failed();\n')
        fixed.append('  }\n')
        # Skip next 2 lines (return and extra })
    elif i == 57 and 'return ATSScore.failed' in line:
        pass  # skip
    elif i == 58 and line.strip() == '}':
        pass  # skip
    else:
        fixed.append(line)

with open('lib/ats_scoring_service.dart', 'w', encoding='utf-8') as f:
    f.writelines(fixed)
print('Fixed ats_scoring_service.dart')

# Fix completion_screen.dart - stray closing brace on line 96
with open('lib/completion_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

fixed = []
for i, line in enumerate(lines):
    # Line 96 (0-indexed: 95) has stray "}"
    if i == 95 and line.strip() == '}':
        pass  # remove it
    else:
        fixed.append(line)

with open('lib/completion_screen.dart', 'w', encoding='utf-8') as f:
    f.writelines(fixed)
print('Fixed completion_screen.dart')

# Fix loading_screen.dart - stray closing brace on line 103
with open('lib/loading_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

fixed = []
for i, line in enumerate(lines):
    if i == 102 and line.strip() == '}':
        pass  # remove stray brace
    else:
        fixed.append(line)

with open('lib/loading_screen.dart', 'w', encoding='utf-8') as f:
    f.writelines(fixed)
print('Fixed loading_screen.dart')

# Fix ats_cv_builder_screen.dart - broken _hdrs method
with open('lib/ats_cv_builder_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

fixed = []
for i, line in enumerate(lines):
    # Line 1755 has broken _hdrs - replace with empty map and close
    if i == 1754 and "_hdrs()" in line:
        fixed.append("  Map<String, String> _hdrs() => {};\n")
    elif i == 1755 and line.strip() == '':
        pass  # skip blank line after broken hdrs
    else:
        fixed.append(line)

with open('lib/ats_cv_builder_screen.dart', 'w', encoding='utf-8') as f:
    f.writelines(fixed)
print('Fixed ats_cv_builder_screen.dart')

print('All done.')
