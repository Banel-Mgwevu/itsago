import re

files = [
    'lib/ai_coach_screen.dart',
    'lib/ats_cv_builder_screen.dart',
    'lib/ats_scoring_service.dart',
    'lib/completion_screen.dart',
    'lib/loading_screen.dart',
    'lib/interview_manager.dart',
    'lib/drill_session_screen.dart',
]

old_response = "jsonDecode(res.body)['content'][0]['text'] as String"
new_response = "CloudFunctionService.extractText(res)"

for f in files:
    try:
        with open(f, 'r', encoding='utf-8') as fp:
            c = fp.read()

        # Fix response parsing
        c = c.replace(old_response, new_response)

        # Fix http.post to CloudFunctionService
        c = re.sub(
            r'await http\.post\(\s*Uri\.parse\(\'https://api\.anthropic\.com/v1/messages\'\),\s*headers:\s*\{[^\}]+\},\s*body:\s*jsonEncode\(\{',
            'await CloudFunctionService.callClaude(\n        ',
            c, flags=re.DOTALL
        )

        # Fix timeout endings
        c = re.sub(r'\}\)\)\.timeout\(const Duration\(seconds: \d+\)\)', ')', c)

        # Remove statusCode check
        c = re.sub(r'if \(res\.statusCode == 200\) \{', '', c)

        # Fix named params
        c = re.sub(r"'model':\s*", 'model: ', c)
        c = re.sub(r"'max_tokens':\s*", 'maxTokens: ', c)
        c = re.sub(r"'messages':\s*", 'messages: ', c)
        c = re.sub(r"'system':\s*", 'system: ', c)

        # Remove API key lines
        c = re.sub(r"\s*'x-api-key':[^\n]+\n", '\n', c)
        c = re.sub(r"\s*'anthropic-version':[^\n]+\n", '\n', c)
        c = re.sub(r"\s*'Content-Type':[^\n]+\n", '\n', c)
        c = re.sub(r"\s*Uri\.parse\([^\n]+\n", '\n', c)
        c = re.sub(r"\s*headers:\s*\{\s*\},", '', c)

        # Remove AppConfig.claudeApiKey
        c = c.replace('AppConfig.claudeApiKey', '')

        with open(f, 'w', encoding='utf-8') as fp:
            fp.write(c)
        print(f'Fixed: {f}')
    except Exception as e:
        print(f'Error in {f}: {e}')

print('All done.')
