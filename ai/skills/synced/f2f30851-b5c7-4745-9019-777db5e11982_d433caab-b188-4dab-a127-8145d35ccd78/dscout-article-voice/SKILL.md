---
name: dscout-article-voice
description: >
  Apply Dscout's official brand voice, tone, and writing guidelines when creating any content at Dscout.
  Use this skill whenever drafting emails, writing copy, creating slide content, composing Slack messages,
  writing help docs, creating marketing content, drafting social posts, writing internal communications,
  or producing ANY written content on behalf of Dscout — even if the user doesn't explicitly say "use brand guidelines."
  If the content is meant to represent Dscout or go out under a Dscout name, this skill should trigger.
---

# Dscout Voice & Brand Writing Skill

This skill ensures all written content aligns with Dscout's official brand voice, tone, and language
standards as documented in **Article** — Dscout's internal content system in Notion.

---

## ⚠️ Source of Truth: Always Fetch From Notion First

**Before applying any brand or style guidance, retrieve the current content from Notion.**

The Article content system is the single source of truth for all Dscout writing standards.
The rules embedded below in this Skill are a **fallback only** — if there is any conflict between
what's here and what's in Notion, **Notion always wins.**

### Main page
```
https://www.notion.so/dscout/Article-Dscout-s-content-system-5c2a4913533b46cb848fb697f07e39a7
```

### Subpages — fetch the one(s) most relevant to the task at hand

| Section | URL |
|---|---|
| Defining Dscout | https://www.notion.so/13017a66c83d80d78f6ec7d80770343d |
| Writing principles | https://www.notion.so/14b17a66c83d806aa362c94dd2abccd9 |
| Language and grammar | https://www.notion.so/13017a66c83d803499dffd1530554a5a |
| Brand | https://www.notion.so/13017a66c83d802091d1d6587dabf1f0 |
| Team rules | https://www.notion.so/14b17a66c83d800a9bbfe7a884842d65 |
| Content system 101 | https://www.notion.so/13517a66c83d80f89d67f16127e90a3f |
| Voice and tone | https://www.notion.so/18417a66c83d80acaa48db4a21321158 |
| Inclusive language | https://www.notion.so/17717a66c83d80289b85e99b7e29ec65 |
| Boiler copy / Defining Dscout | https://www.notion.so/13017a66c83d80d78f6ec7d80770343d |
| Word list | https://www.notion.so/13017a66c83d8069a0dcc728ebe68df7 |
| People Team tone chart | https://www.notion.so/1f817a66c83d803f8767ca840040699a |
| Callout standards (Product) | https://www.notion.so/13517a66c83d802bbf7cf813b7d5ea76 |
| Confirmation modal standards (Product) | https://www.notion.so/2bc17a66c83d80c59f75f3245b60fa49 |
| Article GPT guidelines | https://www.notion.so/1b417a66c83d80829f45c466566e3af8 |
| All updates | https://www.notion.so/14b17a66c83d80d98db1d7671a7ad2ed |

### How to decide which subpages to fetch

- **Any writing task** → Always start with Writing principles and Language and grammar
- **Channel-specific copy** (marketing, product UI, sales) → Also fetch Team rules
- **People Team content** → Also fetch People Team tone chart
- **Product UI copy** (buttons, modals, callouts) → Also fetch Callout standards and Confirmation modal standards
- **Boilerplate / "what is Dscout" copy** → Fetch Defining Dscout / Boiler copy
- **Inclusive or gender-neutral language questions** → Fetch Inclusive language
- **Capitalization or word-specific questions** → Fetch Word list

---

## Fallback: Brand Guidelines Summary

**Only if the Notion Connector is unavailable** or a subpage cannot be retrieved, instruct the user to re-connect Claude to Notion, then use the rules below to offer tentative guidance. These rules reflect the Article content system as of early 2026 and may not reflect the latest updates.

### Brand Persona

Dscout is:
- **Eclectic** — Has personality, keeps it fun but professional. Business casual, not business formal.
- **Intentional** — Focused, thoughtful, quality-first. Never rushed or sloppy.
- **Thought-partner** — Here to collaborate, not lecture. We're People Nerds, like our audience.

### The Dscout Voice (Always Consistent)

| Voice Trait | What It Means |
|---|---|
| **Plainspoken** | Concise and honest. Avoid jargon. Research is for everyone. Don't ramble. |
| **Kind** | Uplift the audience. Treat readers with respect. Practice inclusive, accessible writing. |
| **Confident** | Dscout is made up of very smart people. Writing should reflect that authority and trustworthiness. |
| **Witty** | Keep it lighthearted — chuckle, not LOL. |

### Tone by Channel

| Channel | Tone Mix |
|---|---|
| **Marketing website** | Confident + plainspoken + occasional witty |
| **Help docs** | Plainspoken + confident + dash of kind |
| **People Nerds** | All four traits equally |
| **Sales collateral** | Confident + plainspoken |
| **Emails / internal comms** | Casual lean, kind, plainspoken |
| **Product UI** | See the Product tone chart in Notion |

**Default lean**: Casual. Dscout is a research thought partner, not a teacher or boss.

### Top 10 Writing Rules

1. **Capitalization** — "Dscout" capitalized in text (logo is lowercase). "Scout/Scouts" capitalized. Core tools capitalized. "People Nerds" both words capitalized.
2. **Sentence case** — Not title case, except blog titles and proper nouns.
3. **Active voice** — "She solved the problem" not "The problem was solved by her."
4. **Write small** — Paragraphs 2–3 sentences max. Use subheadings. Concise > comprehensive.
5. **Conversational over formal** — Write as you'd speak. Approachable beats impressive.
6. **Use contractions** — "Don't" not "do not." No need to be stiff.
7. **Avoid research jargon** — "Self-guided / survey-style" not "unmoderated research" (unless audience is seasoned UXRs).
8. **Inclusive, accessible language** — Singular they/them. Gender-neutral roles. "hey all/folks" not "hey guys." Anti-racist alternatives: "block list" not "blacklist," "legacy" not "grandfathered in," "main/primary" not "master."
9. **Localization awareness** — Consider the reader's location for spelling (color vs. colour).
10. **Punctuation rules** — No ampersands (use "and"). Em dashes (—) not en dashes (-), no spaces around them. Oxford comma always.

### Quick Checklist Before Finishing Any Content

- [ ] Sentence case (not title case)?
- [ ] Active voice throughout?
- [ ] Contractions used naturally?
- [ ] No unnecessary jargon?
- [ ] Paragraphs short (2–3 sentences)?
- [ ] Tone appropriate for this channel?
- [ ] Inclusive, gender-neutral language?
- [ ] Oxford comma present in lists?
- [ ] Em dashes used (not hyphens)?
- [ ] "and" not "&" (unless company name)?

## Behavior Guidelines

- **Always cite the Notion pages** when providing guidance. Link to the specific pages
  when possible, not just the top-level URL.
- **Do not invent rules or guidelines.** If the Notion pages don't address something, say so
  and direct the person to the appropriate Slack channel.
- **Direct users to the #ask-article Slack channel** if users press for clarification that isn't present in the Notion pages, or if they express that something is inaccurate.