# Fix drill_session_screen.dart - broken braces in _initVoice and _analyzePlanDrills and _scoreAnswer
with open('lib/drill_session_screen.dart', 'r', encoding='utf-8') as f:
    c = f.read()

# Fix broken _initVoice - missing closing brace for initialize callback
c = c.replace(
    """        if (s == 'done' || s == 'notListening') {
          if (mounted && _listening) _stopListening();
        }

      onError: (_) {
        if (mounted && _listening) _stopListening();
      });""",
    """        if (s == 'done' || s == 'notListening') {
          if (mounted && _listening) _stopListening();
        }
      },
      onError: (_) {
        if (mounted && _listening) _stopListening();
      });"""
)

# Fix broken _startListening - missing closing brace for listen callback
c = c.replace(
    """        if (r.finalResult) _finalAnswer = r.recognizedWords;
        });

      listenFor: Duration(seconds: _maxSecs),
      pauseFor: const Duration(seconds: 4),
      localeId: 'en_ZA');""",
    """        if (r.finalResult) _finalAnswer = r.recognizedWords;
        });
      },
      listenFor: Duration(seconds: _maxSecs),
      pauseFor: const Duration(seconds: 4),
      localeId: 'en_ZA');"""
)

# Fix broken _analyzePlanDrills - stray closing brace after return
c = c.replace(
    """        if (mounted) setState(() => _phase = _DrillPhase.intro);
        return;
      }
    } catch (_) {}""",
    """        if (mounted) setState(() => _phase = _DrillPhase.intro);
        return;
    } catch (_) {}"""
)

# Fix broken _scoreAnswer - stray closing brace after return
c = c.replace(
    """        await _speak('Score: ${result.score} out of 10. ${result.spokenFeedback}');
        return;
      }
    } catch (_) {}""",
    """        await _speak('Score: ${result.score} out of 10. ${result.spokenFeedback}');
        return;
    } catch (_) {}"""
)

# Fix broken GestureDetector - missing closing paren
c = c.replace(
    """          Center(child: GestureDetector(
            onTap: () {
              if (_listening)        _stopListening();
              else if (_canSpeak)   _startListening();

            child: AnimatedBuilder(""",
    """          Center(child: GestureDetector(
            onTap: () {
              if (_listening)        _stopListening();
              else if (_canSpeak)   _startListening();
            },
            child: AnimatedBuilder("""
)

# Fix broken model param
c = c.replace("model: 'claude-sonnet-4-20250514',", "model: 'claude-haiku-4-5-20251001',")

with open('lib/drill_session_screen.dart', 'w', encoding='utf-8') as f:
    f.write(c)
print('Fixed drill_session_screen.dart')

# Fix ai_coach_screen.dart - same broken _initVoice pattern
with open('lib/ai_coach_screen.dart', 'r', encoding='utf-8') as f:
    c = f.read()

c = c.replace(
    """        if (s == 'done' || s == 'notListening') {
          if (mounted) setState(() => _listening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      });""",
    """        if (s == 'done' || s == 'notListening') {
          if (mounted) setState(() => _listening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      });"""
)

# Also fix broken onStatus/onError if not already fixed
if "onStatus: (s) {\n        if (s == 'done'" in c and "        }\n\n      onError:" in c:
    c = c.replace(
        "        }\n\n      onError:",
        "        },\n      onError:"
    )

with open('lib/ai_coach_screen.dart', 'w', encoding='utf-8') as f:
    f.write(c)
print('Fixed ai_coach_screen.dart')

print('All done.')
