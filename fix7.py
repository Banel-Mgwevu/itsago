with open('lib/interview_manager.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

fixed = []
i = 0
while i < len(lines):
    line = lines[i]
    # Fix broken callClaude pattern - empty lines between callClaude( and model:
    if 'await CloudFunctionService.callClaude(' in line:
        # Collect indent
        indent = len(line) - len(line.lstrip())
        fixed.append(line)
        i += 1
        # Skip empty/whitespace-only lines until we hit model:
        while i < len(lines) and lines[i].strip() == '':
            i += 1
        continue
    # Fix stray closing brace after return inside try block
    # Pattern: return value;\n      }\n    } catch
    elif line.strip() == '}' and i + 1 < len(lines) and '} catch' in lines[i+1]:
        # Skip this stray brace
        i += 1
        continue
    else:
        fixed.append(line)
        i += 1

with open('lib/interview_manager.dart', 'w', encoding='utf-8') as f:
    f.writelines(fixed)
print('Fixed interview_manager.dart')

# Also fix the same pattern in loading_screen.dart
with open('lib/loading_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

fixed = []
i = 0
while i < len(lines):
    line = lines[i]
    if 'await CloudFunctionService.callClaude(' in line:
        fixed.append(line)
        i += 1
        while i < len(lines) and lines[i].strip() == '':
            i += 1
        continue
    elif line.strip() == '}' and i + 1 < len(lines) and '} catch' in lines[i+1]:
        i += 1
        continue
    else:
        fixed.append(line)
        i += 1

with open('lib/loading_screen.dart', 'w', encoding='utf-8') as f:
    f.writelines(fixed)
print('Fixed loading_screen.dart')

print('All done.')
