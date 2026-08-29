# Codebase Review Rule

Whenever we make a drastic change (modifying more than 10 lines of code) or add new functions, you MUST always spawn the codebase review subagent (e.g., using `invoke_subagent` with the `research` subagent).

The subagent should be instructed to review the newly changed files for architectural leaks, tight coupling, performance issues, and unoptimized queries, and to continuously update the `C:\Users\MITUL PATEL\.gemini\antigravity\brain\650aaa8f-8c3f-43bd-9815-342e77096136\codebase_review.md` artifact.

## Feature Development Rule

NEVER add new functionality to a semi-working project or build a new feature without EXPLICITLY confirming with the user first. Before writing code for a new feature, you must always describe in detail the proposed approach and explain the workflow, everything that will be done, and the components that will be used.
