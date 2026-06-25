import re
import os

files = [
    'lib/ai_coach_screen.dart',
    'lib/completion_screen.dart',
    'lib/drill_session_screen.dart',
    'lib/interview_manager.dart',
    'lib/loading_screen.dart',
    'lib/ats_scoring_service.dart',
    'lib/ats_cv_builder_screen.dart',
]

reductions = {
    'maxTokens: 1024': 'maxTokens: 600',
    'maxTokens: 1200': 'maxTokens: 800',
    'maxTokens: 800':  'maxTokens: 600',
    'maxTokens: 500':  'maxTokens: 400',
    'maxTokens: 400':  'maxTokens: 300',
    'maxTokens: 300':  'maxTokens: 250',
}

for filepath in files:
    if not os.path.exists(filepath):
        continue
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    original = content
    for old, new in reductions.items():
        content = content.replace(old, new)
    if content != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print('Reduced tokens: ' + filepath)
    else:
        print('No change: ' + filepath)

print('All done.')
