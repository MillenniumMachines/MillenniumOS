# MillenniumOS-Next Development Workflow

This document outlines the development process, branching strategy, and code review workflow to be followed for the MillenniumOS-Next rewrite. The primary goal is to ensure all changes are structured, reviewed, and aligned with the project's core principles of simplicity and accuracy.

---

## 1. Guiding Principles

*   **Scope:** All development work should be scoped to a specific feature or a small group of related features as outlined in `FEATURES.md`.
*   **Clarity:** Commits, branches, and Pull Requests should have clear and descriptive names and messages.
*   **Clean History:** A clean, readable git history is preferred. A single feature should ideally be represented by a single, well-documented commit on the `next` branch upon merging.

---

## 2. Branching Strategy

1.  **Main Integration Branch (`next`):**
    *   The `next` branch is the primary target for all new development. It should always represent the current state of the rewrite.

2.  **Direct Commits to `next`:**
    *   Only initial project scaffolding, core loading/variable scripts, and documentation changes (like this one) may be committed directly to the `next` branch.

3.  **Feature Branches:**
    *   All other feature development, bug fixes, or refactoring must be done in a separate feature branch, created from the latest `next` branch.
    *   Branch names should be descriptive, for example: `feature/probing-engine` or `fix/tool-change-logic`.

---

## 3. Pull Request (PR) and Code Review Process

All feature branches must be merged into `next` via a Pull Request (PR). This ensures that every change is reviewed.

1.  **PR Creation:**
    *   Once a feature is complete and tested on its branch, a PR will be created targeting the `next` branch using the `gh pr create` command.
    *   The PR title and description will be clear, referencing the feature(s) from `FEATURES.md` that it implements.

2.  **Mandatory Self-Review:**
    *   Immediately after creating a PR, the role of developer will switch to that of a reviewer.
    *   A thorough self-review of the PR's changes will be conducted using the `gh` tool (e.g., `gh pr diff --json`).

3.  **Review Criteria:**
    *   The review will focus on identifying:
        *   Potential logic errors or bugs.
        *   Typographical errors in code or comments.
        *   Fragile or overly complex code that violates the principle of simplicity.
        *   Unused, unneeded, or dead code.
        *   Deviations from the agreed-upon architecture or feature requirements.

4.  **Correcting and Amending Commits:**
    *   If issues are found during the self-review, they will first be documented as comments on the PR using `gh pr review --comment` for transparency.
    *   The code will then be corrected on the local feature branch.
    *   Instead of creating a new 'fixup' commit, `git commit --amend` will be used to incorporate the corrections directly into the original commit.
    *   The commit message will be updated during the amend process to include a brief note about the fixes made (e.g., "docs: Add DEVELOPMENT.md... [fix: corrected review criteria]"), preserving a clear history of changes within the single commit.

5.  **Human Approval (Strictly Enforced):**
    *   **I will never approve or merge my own Pull Request.**
    *   After the self-review is complete and any necessary corrections are made, the PR will be left in a "pending review" state for a human (you) to perform the final review, approval, and merge.

---

## 4. Tracking Progress

1.  **User Confirmation:**
    *   After a feature's PR has been successfully merged into the `next` branch by you, I will ask for your confirmation that the feature is considered complete and meets the requirements.

2.  **Updating `FEATURES.md`:**
    *   Once you grant confirmation, I will create a new commit directly on the `next` branch.
    *   This commit will edit the `FEATURES.md` file to mark the completed feature with a checkmark (e.g., changing `- [ ]` to `- [x]`). This will serve as our living progress tracker for the project.