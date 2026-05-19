---
name: "linear-issue-worker"
allowed-tools: tidewave(*), linear-server(*), Bash(gh:*), sequential-thinking(*)
description: Read an issue from linear and generate a comprehensive, detailed plan for completing the task with code samples and thorough analysis.
---

## Context

Read the contents of linear issue $ARGUMENTS. If the issue has any parent or sibling issues, read
those as well since they are important context. Create an EXTREMELY DETAILED plan to complete this
issue with code samples, architectural considerations, and step-by-step implementation details.

## Critical Instructions - READ CAREFULLY

**ULTRATHINK**: You MUST engage in deep, sequential thinking throughout this process. Take time to
analyze, consider alternatives, and think through edge cases. Do not rush - quality over speed.

**USE SEQUENTIAL THINKING**: Break down complex problems into smaller, manageable steps. Think through
each step thoroughly before moving to the next. Question your assumptions and validate your approach.

**BE EXTREMELY DETAILED**: Your plan should be so detailed that another developer could implement it
without asking questions. Include specific file paths, function names, code samples, and architectural decisions.

## Your Comprehensive Task

### Phase 1: Deep Analysis and Understanding

- **MANDATORY**: Read the entirety of linear issue $ARGUMENTS, including its project, labels, and all comments
- **MANDATORY**: Read any parent issues, sub-issues, and related issues for full context
- **MANDATORY**: Analyze the codebase to understand current architecture and patterns
- **MANDATORY**: Identify all affected systems, services, and components
- **MANDATORY**: Research existing similar implementations in the codebase for consistency
- **MANDATORY**: Use sequential-thinking to break down complex requirements into manageable pieces

### Phase 2: Comprehensive Planning

- **MANDATORY**: Create a detailed plan with the following sections:
  - **Executive Summary**: Brief overview of what needs to be done and why
  - **Technical Analysis**: Deep dive into technical requirements and constraints
  - **Architecture Impact**: How this change affects the overall system architecture
  - **Implementation Strategy**: Step-by-step approach with clear milestones
  - **Code Examples**: Specific code samples showing key implementations
  - **File Structure**: Exact file paths and organization
  - **Database Changes**: Any schema modifications needed
  - **API Changes**: New or modified endpoints with request/response examples
  - **Testing Strategy**: Comprehensive test plan with example test cases
  - **Deployment Considerations**: How to safely deploy these changes
  - **Risk Assessment**: Potential issues and mitigation strategies
  - **Performance Impact**: Analysis of performance implications
  - **Security Considerations**: Security review of all changes

### Phase 3: Current State Investigation

- **MANDATORY**: Thoroughly investigate what has already been completed
- **MANDATORY**: Identify any existing code that can be reused or needs modification
- **MANDATORY**: Document the current state with specific file references and line numbers
- **MANDATORY**: Identify gaps between current state and desired end state

### Phase 4: Detailed Implementation Plan

- **MANDATORY**: Break down remaining work into specific, actionable tasks
- **MANDATORY**: Provide code samples for each major component
- **MANDATORY**: Include specific commands to run for testing and validation
- **MANDATORY**: Define acceptance criteria for each task
- **MANDATORY**: Estimate complexity and identify dependencies between tasks

### Phase 5: Quality Assurance Requirements

- **MANDATORY**: Follow all language linting rules, code conventions, and best practices
- **MANDATORY**: Write comprehensive unit tests with example test cases
- **MANDATORY**: Ensure all tests for modified code files pass
- **MANDATORY**: Eliminate all compilation warnings in our code (dependencies may have warnings)
- **MANDATORY**: Include integration test scenarios where applicable
- **MANDATORY**: Validate GraphQL schema changes if applicable
- **MANDATORY**: Test database migrations in both directions (up/down)

### Phase 6: Documentation and Communication

- **MANDATORY**: When the plan is ready, add the COMPLETE DETAILED plan to linear issue $ARGUMENTS as a comment
- **MANDATORY**: When implementation is done, add a comprehensive summary as a comment on linear issue $ARGUMENTS
- **MANDATORY**: Include before/after code comparisons in the summary
- **MANDATORY**: Document any architectural decisions made during implementation

## Plan Quality Requirements

Your plan MUST include:

1. **Specific Code Examples**: Show actual code that will be written, not just descriptions
2. **File Paths**: Exact locations where changes will be made
3. **Function Signatures**: Precise method/function definitions
4. **Database Schema**: Exact column names, types, and relationships
5. **API Contracts**: Request/response formats with examples
6. **Test Cases**: Specific test scenarios with expected outcomes
7. **Error Handling**: How errors will be caught and handled
8. **Edge Cases**: Unusual scenarios and how they're addressed
9. **Performance Metrics**: How success will be measured
10. **Rollback Strategy**: How to undo changes if needed

## Thinking Instructions

- **THINK STEP BY STEP**: Don't jump to conclusions
- **QUESTION EVERYTHING**: Challenge assumptions and validate requirements
- **CONSIDER ALTERNATIVES**: Explore multiple implementation approaches
- **ANTICIPATE PROBLEMS**: Think about what could go wrong
- **VALIDATE DECISIONS**: Ensure each decision is well-reasoned
- **BE THOROUGH**: Better to over-plan than under-plan
- **USE CONCRETE EXAMPLES**: Abstract concepts should be illustrated with specific examples
- **THINK ABOUT MAINTENANCE**: How will this code be maintained and extended?

Remember: The goal is to create a plan so detailed and thoughtful that implementation becomes straightforward execution rather than problem-solving.
