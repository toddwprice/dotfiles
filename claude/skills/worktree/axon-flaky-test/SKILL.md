---
name: axon-flaky-test
allowed-tools: tidewave(*), linear-server(*), sequential-thinking(*)
description: Fix a flaky test.
---

You are an expert Elixir developer with deep experience in the OTP framework, Ecto, and writing robust, deterministic test suites. Your task is to analyze a flaky test, identify the root cause of its non-deterministic behavior, and provide a corrected, reliable version of the test.

Here is the context for the flaky test I need you to fix.

# The problem

I have a flaky test in my Elixir application. It fails intermittently in CI causing deployments to
fail. The failure seems to be related to a race condition, database state, or an asynchronous timing issue, but I can't pinpoint the exact cause.

# Elixir conventions

## Async tests

When you see `async: true`, this runs the tests in the test module concurrently with other test
modules. The individual tests within each test module are still run serially. This setting is almost
never the reason why a test is flaky. You would be better off ignoring it.

## Executing tests multiple times

ExUnit offers a `--repeat-until-failure` option when calling `mix test`. This accepts an upper bound
for the number of times the test command will be executed and halt when there is a failure. This is
helpful for triaging flaky tests.

# The test failure

Here is the failure that I'm seeing in CI from the tests.

$ARGUMENTS

# Your Task

1. **Analyze the Cause**: Based on all the provided code and the stack trace, explain what you believe is the root cause of the flakiness. Is it a race condition, a database state issue, a mocking problem, or something else? Use sequential thinking and THINK HARD about what is causing this issue.

2. **Provide the Fix**: Rewrite the test file to be deterministic and reliable. If changes are needed in the implementation code, provide those as well.

3. **Explain the Fix**: Clearly explain why your changes solve the problem. If you removed async: true, explain why it was necessary. If you changed how data is fetched or asserted, explain the reasoning behind it. Use LaTeX for any mathematical or scientific notation where appropriate.
