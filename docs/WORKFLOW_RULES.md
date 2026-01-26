# Workflow Rules (M2DG Build Method)

## Rule 1 — Finish-to-Launch
We do NOT move to the next page/module until the current one is launch-ready.

Launch-ready checklist:
- ✅ Loading state
- ✅ Empty state
- ✅ Error state with retry
- ✅ Mobile layout polished
- ✅ No obvious dev toggles visible in release builds
- ✅ Navigation complete
- ✅ No major analyzer errors

## Rule 2 — Small Steps
One feature goal per commit.
Commit message format:
- "feat(courts): ____"
- "fix(courts): ____"
- "ui(courts): ____"

## Rule 3 — Keep it Clean
No big refactors unless required.
Prefer reusable widgets only when duplication is real.

## Rule 4 — Agent Output Standard
Any AI agent must:
- Provide full updated file contents when editing files
- Provide terminal commands to run
- Confirm what state was added or improved (loading/empty/error/etc)
