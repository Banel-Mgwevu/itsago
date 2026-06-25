import re

# Fix completion_screen.dart — remove stray "} else" and missing closing brace
with open('lib/completion_screen.dart', 'r', encoding='utf-8') as f:
    c = f.read()

# Remove leftover "} else { throw Exception..." lines
c = re.sub(r"\s*\} else \{ throw Exception\('\$\{res\.statusCode\}'\); \}", '', c)
# Add missing import for CloudFunctionService
if 'cloud_function_service' not in c:
    c = c.replace("import 'notification_service.dart';", 
                  "import 'notification_service.dart';\nimport 'cloud_function_service.dart';")

with open('lib/completion_screen.dart', 'w', encoding='utf-8') as f:
    f.write(c)
print('Fixed completion_screen.dart')

# Fix ai_coach_screen.dart — remove stray "} else { throw..." and fix brace
with open('lib/ai_coach_screen.dart', 'r', encoding='utf-8') as f:
    c = f.read()

c = re.sub(r"\s*\} else \{ throw Exception\('\$\{res\.statusCode\}'\); \}", '', c)

with open('lib/ai_coach_screen.dart', 'w', encoding='utf-8') as f:
    f.write(c)
print('Fixed ai_coach_screen.dart')

# Fix drill_session_screen.dart — fix broken callClaude calls
with open('lib/drill_session_screen.dart', 'r', encoding='utf-8') as f:
    c = f.read()

# Add missing import
if 'cloud_function_service' not in c:
    c = c.replace("import 'app_config.dart';",
                  "import 'app_config.dart';\nimport 'cloud_function_service.dart';")

# Fix broken callClaude with body: jsonEncode pattern
c = re.sub(r'await CloudFunctionService\.callClaude\(\s*\n\s*\n\s*\n\s*\n\s*\n\s*\n\s*body: jsonEncode\(\{', 
           'await CloudFunctionService.callClaude(\n        ', c)
c = re.sub(r'body: jsonEncode\(\{', '', c)

# Fix model named params inside callClaude
c = re.sub(r"model: '(claude-[^']+)',", r"model: '\1',", c)

with open('lib/drill_session_screen.dart', 'w', encoding='utf-8') as f:
    f.write(c)
print('Fixed drill_session_screen.dart')

# Fix loading_screen.dart
with open('lib/loading_screen.dart', 'r', encoding='utf-8') as f:
    c = f.read()

if 'cloud_function_service' not in c:
    c = c.replace("import 'app_config.dart';",
                  "import 'app_config.dart';\nimport 'cloud_function_service.dart';")

c = re.sub(r'await CloudFunctionService\.callClaude\(\s*\n\s*\n\s*\n\s*\n\s*\n\s*\n\s*body: jsonEncode\(\{',
           'await CloudFunctionService.callClaude(\n        ', c)
c = re.sub(r'body: jsonEncode\(\{', '', c)

# Remove leftover statusCode checks
c = re.sub(r'\s*\} else \{ throw Exception\([^)]+\); \}', '', c)

with open('lib/loading_screen.dart', 'w', encoding='utf-8') as f:
    f.write(c)
print('Fixed loading_screen.dart')

# Fix ats_scoring_service.dart
with open('lib/ats_scoring_service.dart', 'r', encoding='utf-8') as f:
    c = f.read()

if 'cloud_function_service' not in c:
    c = c.replace("import 'app_config.dart';",
                  "import 'app_config.dart';\nimport 'cloud_function_service.dart';")

c = re.sub(r'await CloudFunctionService\.callClaude\(\s*\n\s*\n\s*\n\s*\n\s*\n\s*\n\s*body: jsonEncode\(\{',
           'await CloudFunctionService.callClaude(\n        ', c)
c = re.sub(r'body: jsonEncode\(\{', '', c)

with open('lib/ats_scoring_service.dart', 'w', encoding='utf-8') as f:
    f.write(c)
print('Fixed ats_scoring_service.dart')

# Fix interview_manager.dart - restore class structure
with open('lib/interview_manager.dart', 'r', encoding='utf-8') as f:
    c = f.read()

if 'cloud_function_service' not in c:
    c = c.replace("import 'app_config.dart';",
                  "import 'app_config.dart';\nimport 'cloud_function_service.dart';")

with open('lib/interview_manager.dart', 'w', encoding='utf-8') as f:
    f.write(c)
print('Fixed interview_manager.dart')

print('All done.')
