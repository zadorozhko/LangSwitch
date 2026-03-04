Check what can be enhanced in this project
-------
Based on my analysis, here's what can be enhanced in this LangSwitch project:

## Code Organization
- **AppDelegate.swift** (510 lines) is too large - should be split into smaller managers (KeyboardManager, SoundManager, etc.)
- Duplicate `keyCodes` definitions in both `AppDelegate.swift:30` and `ContextProvider.swift:14`
- Duplicate `keyen` string in both files

## Code Quality Issues
- **Force unwrapping**: `url!` at line 384, `try!` at line 384 - can crash
- **TODO comments**: `addException()` at line 62, `flush()` at line 79 - unimplemented
- **Dead/commented code**: Lines 71-86 in AppDelegate, lines 90-147 in WordChecker (Linux-only Hunspell)
- **Unused variables**: `anotherClicked`, `lastPressTime` at lines 121-122

## Memory & Performance
- `WordChecker` creates new `NSSpellChecker` instance per word check (line 67)
- PermissionsService polls every second but doesn't stop once trusted

## User Experience
- No settings/preferences window (only About window exists)
- Auto-correction is detected (line 210) but not actually performed
- No way to configure sounds, keyboard shortcuts, or languages
- Status bar icon only shows "$" or "₽" - not very informative

## Bugs/Risks
- No error handling for `CGEvent` creation failures
- Race conditions possible with global key event monitoring
- Optional handling issues throughout (`pos ?? -1`)

## Modern Swift Improvements
- Use `@Observable` macro instead of `NSKeyValueObservation`
- Replace polling with async/await
- Use SwiftUI for About window instead of AppKit
- Proper error handling instead of `print()` statements

