---
name: ste-writer
description: Write or edit technical documentation — manuals, procedures, instructions, warnings, cautions, maintenance steps — according to the ASD-STE100 Simplified Technical English (STE) standard. Trigger this whenever the user asks to draft a manual, write instructions or procedural text, "apply STE," "convert to STE," "make it Simplified Technical English," "use ASD-STE100," simplify a procedure, edit a warning, or clean up an instruction — even if they don't name the standard directly but the goal is clear, unambiguous, easy-to-translate technical writing for engineering, maintenance, or aerospace/defense audiences.
---

# ASD-STE100 Simplified Technical English (STE)

## Purpose
Write and edit technical documentation according to the official **ASD-STE100 standard**. STE eliminates ambiguity, standardizes vocabulary, and makes text easy to translate and safe for global engineering, maintenance, and technical teams to act on.

## Core STE Writing Rules
Apply these constraints to all output text.

### 1. Vocabulary Controls
- **One Word, One Meaning:** Use approved words only in their designated grammatical category (e.g., use "CLOSE" only as a verb, never as an adjective like "close to the wall").
- **No Synonyms:** Do not use different words for the same object or action. Use "START", not "begin", "launch", or "initiate". Use "CHOOSE", not "select".
- **Approved Nouns:** Use clear, standardized nomenclature for tools, parts, and equipment.

### 2. Sentence Structure & Length
- **Maximum Length:** Procedural sentences (instructions) must not exceed **20 words**. Descriptive sentences must not exceed **25 words**.
- **One Thought Per Sentence:** Provide only one action or piece of information per sentence.
- **Active Voice:** Write all instructions in the imperative mood (e.g., "Open the valve," not "The valve should be opened").
- **Paragraph Limits:** Paragraphs must not contain more than **6 sentences**.

### 3. Safety and Warnings
- **Command Structure:** Start safety steps with a clear, direct command.
- **Precedence:** Place instructions, warnings, or cautions *before* the action occurs, never after.

## Execution Workflow
Process the input through these exact steps:

1. **Analyze:** Scan the raw input text for passive voice, forbidden synonyms, and over-length sentences.
2. **Translate:** Convert unapproved words into approved STE alternatives. Break down complex sentences into short, one-action fragments.
3. **Validate:** Count the words in every generated sentence to guarantee they fall below the 20/25-word thresholds.
4. **Output:** Provide the finalized STE text.

## Examples for Reference

* **Non-STE:** "Prior to the initiation of the test sequence, ensure that the primary valve is fully closed by the operator."
* **STE (Approved):** "Close the primary valve. Start the test."

* **Non-STE:** "The indicator light will begin flashing rapidly if the internal temperature exceeds acceptable thresholds."
* **STE (Approved):** "If the temperature is too high, the indicator light flashes fast."
