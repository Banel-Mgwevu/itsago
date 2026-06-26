with open('lib/notification_service.dart', 'r', encoding='utf-8') as f:
    c = f.read()

premium_methods = """
  // Premium conversion notifications
  Future<void> onCVBuilt() async {
    if (!_isInitialized) await initialize();
    if (!await _enabled()) return;
    final prefs = await SharedPreferences.getInstance();
    final alreadyPremium = prefs.getBool('premium_templates') ?? false;
    if (alreadyPremium) return;
    final count = (prefs.getInt('cv_build_count') ?? 0) + 1;
    await prefs.setInt('cv_build_count', count);
    // Only show on first and third CV build
    if (count == 1 || count == 3) {
      await _schedule(
        id: 600,
        ch: 'comeback_channel',
        chName: 'Practice Reminders',
        title: 'Make Your CV Stand Out Even More',
        body: 'Unlock 3 premium CV designs for just R29. Limited launch price.',
        scheduledTime: DateTime.now().add(const Duration(minutes: 30)));
    }
  }

  Future<void> onWeeklyLimitReached() async {
    if (!_isInitialized) await initialize();
    if (!await _enabled()) return;
    final prefs = await SharedPreferences.getInstance();
    final alreadyPremium = prefs.getBool('premium_templates') ?? false;
    if (alreadyPremium) return;
    await _schedule(
      id: 601,
      ch: 'comeback_channel',
      chName: 'Practice Reminders',
      title: 'Need More CV Builds?',
      body: 'Unlock premium for unlimited CV builds plus 3 premium designs. R29 once, yours forever.',
      scheduledTime: DateTime.now().add(const Duration(minutes: 5)));
  }

  Future<void> schedulePremiumReminder() async {
    if (!_isInitialized) await initialize();
    if (!await _enabled()) return;
    final prefs = await SharedPreferences.getInstance();
    final alreadyPremium = prefs.getBool('premium_templates') ?? false;
    if (alreadyPremium) return;
    final installDate = prefs.getString('install_date');
    if (installDate == null) {
      await prefs.setString('install_date', DateTime.now().toIso8601String());
    }
    // Send once after 3 days
    final sent = prefs.getBool('premium_reminder_sent') ?? false;
    if (!sent) {
      await _schedule(
        id: 602,
        ch: 'comeback_channel',
        chName: 'Practice Reminders',
        title: 'ITSAGO — Launch Offer Ending Soon',
        body: 'Unlock Grid, Ubuntu and Vivid CV templates for R29. Price goes up soon.',
        scheduledTime: DateTime.now().add(const Duration(days: 3)));
      await prefs.setBool('premium_reminder_sent', true);
    }
  }
"""

# Insert before the last closing brace
c = c.rstrip()
if c.endswith('}'):
    c = c[:-1] + premium_methods + '\n}'

with open('lib/notification_service.dart', 'w', encoding='utf-8') as f:
    f.write(c)
print('Premium notifications added.')
