# NeXT Coding Style Guide

This document outlines the coding conventions and style guidelines to be followed in the NeXT rewrite. Consistent coding style ensures readability, maintainability, and reduces errors in the codebase.

---

## 1. General Principles

- **Readability First:** Code should be written to be easily understood by other developers. Prioritize clarity over brevity.
- **Consistency:** Follow the established patterns in this document. When in doubt, match the style of existing code.
- **Comments:** Use comments to explain complex logic, assumptions, or non-obvious behavior. Comments should be concise but informative.

---

## 2. Variable Naming

- **Global Variables:** All global variables must be prefixed with `nxt` to avoid conflicts with other plugins or user variables (e.g., `nxtDeltaMachine`).
- **Descriptive Names:** Use full, descriptive names instead of abbreviations (e.g., `nxtCoolantFloodID` instead of `nxtCFID`).
- **Case:** Use camelCase for variable names (e.g., `nxtProbeResults`).

---

## 3. Expression Handling in Conditionals

- **Wrapping Required:** All expressions in the conditional part of `if` statements must be wrapped in curly braces `{}` to ensure proper parsing of complex expressions.
- **Examples:**
  - Correct: `if { exists(param.S) && param.S > 0 }`
  - Incorrect: `if exists(param.S) && param.S > 0`
- **Reason:** This prevents parsing ambiguities, especially with logical operators like `&&` and `||`.

---

## 4. G-code and M-code Conventions

- **Industry Standards:** Adhere to NIST standards for G-code numbering where possible.
- **Extensions:** For functionality not implemented by RepRapFirmware (RRF), use standard G-codes (e.g., `G37` for tool measurement).
- **Wrapper Macros:** To add safety or features to existing RRF commands (e.g., `M3`, `M5`), create "wrapper" macros with a decimal extension (e.g., `M3.9`, `M5.9`). These wrappers contain custom logic and then call the base RRF command.
- **Post-Processor Configuration:** Ensure post-processors are configured to output these extended codes.

---

## 5. Macro Structure

- **File Naming:** Core system files should use the `nxt` prefix where appropriate (e.g., `nxt.g`, `nxt-vars.g`).
- **Error Handling:** Use `abort` for fatal errors with descriptive messages.
- **Validation:** Validate parameters early in macros to prevent runtime errors.

---

## 6. Comments and Documentation

- **Header Comments:** Each macro file should start with a comment describing its purpose, usage, and parameters.
- **Inline Comments:** Use inline comments for complex calculations or non-standard logic.
- **Variable Comments:** Comment global variable declarations with their purpose.

---

## 7. Best Practices

- **Avoid Magic Numbers:** Use named constants or variables instead of hard-coded numbers.
- **Modular Code:** Break down complex logic into smaller, reusable functions or macros.
- **Testing:** Write code with testing in mind; ensure macros can be tested independently.</content>
<parameter name="filePath">/home/ben/Documents/CAD/Millennium Milo/Repos/OS/docs/CODE.md