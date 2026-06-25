import re

# Fix ats_scoring_service.dart - missing closing brace on score() method
with open('lib/ats_scoring_service.dart', 'r', encoding='utf-8') as f:
    c = f.read()

# The callClaude result block is missing a closing brace
c = c.replace(
    "        return ATSScore.fromJson(data);\n      }\n    } catch (_) {}",
    "        return ATSScore.fromJson(data);\n    } catch (_) {}\n  }"
)

with open('lib/ats_scoring_service.dart', 'w', encoding='utf-8') as f:
    f.write(c)
print('Fixed ats_scoring_service.dart')

# Fix ats_cv_builder_screen.dart - missing closing brace on class
with open('lib/ats_cv_builder_screen.dart', 'r', encoding='utf-8') as f:
    c = f.read()

# Find _hdrs method and ensure class closes before _NotCVException
# Add missing closing brace before _NotCVException class
c = c.replace(
    "\nclass _NotCVException implements Exception {",
    "\n}\n\nclass _NotCVException implements Exception {"
)

with open('lib/ats_cv_builder_screen.dart', 'w', encoding='utf-8') as f:
    f.write(c)
print('Fixed ats_cv_builder_screen.dart')

print('All done.')
