# Short Report

## Design Decisions
I chose **Python** as the target language because its indentation and readability align with beginner-focused teaching. AOBL uses Afan Oromo keywords (`yoo`, `hanga`, `hojii`, `deebi'i`) and keeps grammar intentionally small.

## Why this helps beginners
- Learners can reason in their familiar language first.
- Common programming structures map 1:1 to Python concepts.
- Error messages are localized (`Dogoggora: ...`) to improve feedback clarity.
- Natural syntax (`yoo ... ta'e`) reduces intimidation for first-time learners.

## Challenges
- Balancing natural language forms with deterministic parsing.
- Supporting Unicode and apostrophe-containing keywords consistently.
- Keeping the type checker simple while still catching mismatch mistakes.
