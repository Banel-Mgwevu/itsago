import os

files = [
    'lib/ai_coach_screen.dart',
    'lib/completion_screen.dart',
    'lib/drill_session_screen.dart',
    'lib/interview_manager.dart',
    'lib/loading_screen.dart',
    'lib/ats_cv_builder_screen.dart',
    'lib/main_menu_screen.dart',
]

for filepath in files:
    if not os.path.exists(filepath):
        continue
    with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
        content = f.read()
    
    content = content.replace('\u00c3\u00a2\u00e2\u0082\u00ac\u00e2\u0080\u009c', '-')
    content = content.replace('\u00c3\u00a2\u00e2\u0082\u00ac\u00c2\u00a2', "'")
    content = content.replace('\u00c3\u00a2\u00e2\u0082\u00ac\u00e2\u0084\u00a2', "'")
    content = content.replace('\u00c2\u00b7', '.')
    content = content.replace('\u00c2\u00a0', ' ')
    content = content.replace('\u00c2\u00bb', '')
    content = content.replace('\u00c3\u00a2\u00e2\u0082\u00ac\u00c2\u00a6', '...')
    content = content.replace('\u00c3\u0083\u00c2\u00a2\u00c3\u0082\u00e2\u0082\u00ac\u00c3\u0082\u00c2\u00a6', '...')
    content = content.replace('\u00c3\u00a2\u00e2\u0082\u00ac\u0090', '-')
    
    # Fix common garbled dash patterns
    import re
    content = re.sub(r'[^\x00-\x7F\n\r\t ]+', lambda m: '-' if 'â' in m.group() or 'Ã' in m.group() else m.group(), content)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print('Fixed: ' + filepath)

print('All done.')
