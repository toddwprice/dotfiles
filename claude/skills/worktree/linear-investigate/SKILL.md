---
name: "linear-investigate"
allowed-tools: tidewave(*), linear-server(*), Bash(gh:*), sequential-thinking(*), Glob(*), Grep(*), Read(*), notion(*)
description: Investigate a Linear issue by analyzing the issue context and conducting a thorough codebase investigation to understand the problem and potential resolution paths.
---

## Context

Read the contents of Linear issue $ARGUMENTS and conduct a comprehensive investigation. This includes analyzing parent/sibling issues for context, then thoroughly investigating the codebase to understand the problem domain and identify potential resolution paths.

## Critical Instructions - READ CAREFULLY

**THINK SYSTEMATICALLY**: Use ultrathink and sequential thinking to break down the investigation into logical phases. Take time to understand the problem deeply before jumping into code analysis.

**BE THOROUGH**: Your investigation should be comprehensive enough to understand both the business problem and the technical implementation details needed for resolution.

**FOCUS ON UNDERSTANDING**: The goal is investigation and analysis, not implementation. Understand what exists, what's broken, and what paths forward are available.

**PRESENT BEFORE ACTION**: ALWAYS present your complete investigation summary to the user before performing any write/create actions through MCP tools (Linear comments, Notion updates, etc.). The user must review your findings before you proceed with documentation.

## Your Investigation Task

### Phase 1: Issue Context Analysis

- **MANDATORY**: Read the entirety of Linear issue $ARGUMENTS, including project, labels, description, and all comments
- **MANDATORY**: Identify and read any parent issues, sub-issues, and sibling issues for full context
- **MANDATORY**: Analyze the issue type (bug, feature, enhancement, etc.) and priority level
- **MANDATORY**: Extract key technical terms, component names, and system references from the issue
- **MANDATORY**: Identify the affected user journey or business process
- **MANDATORY**: Search Notion workspace for related documentation, specs, or context

### Phase 2: Codebase Investigation Strategy

- **MANDATORY**: Use sequential-thinking to plan the investigation approach based on issue context
- **MANDATORY**: Identify the likely affected systems/services (axon, dendra, astro, soma) based on issue description
- **MANDATORY**: Determine key search terms, function names, file patterns, and database tables to investigate
- **MANDATORY**: Plan the investigation sequence from high-level architecture down to specific implementations

### Phase 3: Deep Codebase Analysis

- **MANDATORY**: Search for relevant code patterns, functions, and components mentioned in the issue
- **MANDATORY**: Analyze the current implementation of related functionality
- **MANDATORY**: Investigate database schema and data models if applicable
- **MANDATORY**: Review API endpoints and GraphQL schemas related to the issue
- **MANDATORY**: Examine test files to understand expected behavior
- **MANDATORY**: Look for recent changes or commits related to the problem area
- **MANDATORY**: Identify configuration files and environment variables that may be relevant

### Phase 4: Problem Analysis and Patterns

- **MANDATORY**: Document the current state of the system related to the issue
- **MANDATORY**: Identify the root cause if this is a bug report
- **MANDATORY**: Find similar implementations in the codebase for consistency patterns
- **MANDATORY**: Analyze error handling and edge cases in related code
- **MANDATORY**: Review logging and monitoring capabilities in the affected area
- **MANDATORY**: Assess the complexity and scope of the issue

### Phase 5: Investigation Report Generation

- **MANDATORY**: Create a comprehensive investigation report with the following sections:
  - **Issue Summary**: Clear problem statement and context
  - **Business Impact**: How this affects users and business processes
  - **Technical Analysis**: Current implementation details and architecture
  - **Root Cause Analysis**: If applicable, what's causing the problem
  - **Code Locations**: Specific files, functions, and line numbers involved
  - **Data Flow**: How data moves through the system for this feature/bug
  - **Dependencies**: What other systems or components are involved
  - **Complexity Assessment**: How complex would a resolution be
  - **Resolution Approaches**: Different paths forward with pros/cons
  - **Risk Assessment**: What could go wrong with various approaches
  - **Testing Considerations**: What areas need testing coverage

### Phase 6: Investigation Summary Presentation

- **MANDATORY**: Present a comprehensive investigation summary to the user before performing any write/create actions
- **MANDATORY**: The investigation summary must be written by Claude and include all key findings from the investigation
- **MANDATORY**: The summary must be clearly presented to the user for review before proceeding with any MCP tool actions like adding comments to Linear or updating Notion documents
- **MANDATORY**: Wait for user acknowledgment or feedback before proceeding with documentation actions

### Phase 7: Documentation and Communication

- **CONDITIONAL**: Only after presenting the investigation summary to the user, proceed with the following:
- **MANDATORY**: Add the complete investigation report as a comment to Linear issue $ARGUMENTS
- **MANDATORY**: Include specific file paths and line numbers for all code references
- **MANDATORY**: Provide code snippets showing current implementation where relevant
- **MANDATORY**: Tag the investigation comment appropriately for easy reference

## Investigation Quality Requirements

Your investigation MUST include:

1. **Specific Code References**: Exact file paths, function names, and line numbers
2. **Current Implementation Analysis**: How the system currently works
3. **Data Flow Documentation**: How data moves through the affected systems
4. **Architecture Context**: How this fits into the overall system design
5. **Similar Patterns**: Other implementations in the codebase for reference
6. **Dependency Mapping**: What other components depend on or are depended upon
7. **Error Scenarios**: How errors are currently handled in this area
8. **Configuration Analysis**: Relevant config files and environment variables
9. **Recent Changes**: Git history analysis for related recent modifications
10. **Test Coverage**: Existing test coverage for the affected functionality

## Investigation Approach

- **START BROAD**: Begin with high-level system understanding
- **NARROW DOWN**: Focus on specific components as you gather information
- **FOLLOW DATA**: Trace how data flows through the system
- **QUESTION ASSUMPTIONS**: Verify your understanding with code evidence
- **DOCUMENT FINDINGS**: Keep detailed notes with specific references
- **THINK LIKE A DETECTIVE**: Follow clues and build a complete picture
- **CONSIDER HISTORY**: Look at git history to understand how we got here
- **ASSESS IMPACT**: Understand the broader implications of any changes

## Output Format

Your investigation should result in a detailed report that answers:

- What exactly is the problem or requirement?
- How does the current system work in this area?
- What are the technical components involved?
- What are the possible approaches to resolution?
- What are the risks and considerations for each approach?
- What would be the scope and complexity of implementation?

Remember: The goal is deep understanding and analysis, not implementation. You're building the knowledge foundation that will enable effective problem resolution.
