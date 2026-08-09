---
description: Implement a change test-first with red-green cycles
argument-hint: "<task>"
---
Use test-driven development for this task:

${ARGUMENTS:-Use the task already described in the conversation. If there is no clear task, ask me what to implement.}

Before coding, inspect the existing tests and test configuration. Ensure names and behavior match the project's domain language and architectural decisions.

## Choose the seam

A seam is the public boundary where behavior can be observed without reaching into internals. Identify the public interface and propose the important seam or seams to test; confirm them with me before writing tests. Focus effort on critical behavior and complex logic rather than exhaustive low-value coverage.

## Write tests worth keeping

Tests should read like behavioral specifications and remain valid through internal refactors. Exercise public interfaces, use expected values from an independent source of truth such as the specification or a worked example, and follow the repository's existing test conventions.

Avoid tests that:

- Call private methods or verify internal collaboration
- Overuse mocks where a public boundary can be exercised directly
- Recompute expected values using the same logic as the implementation
- Observe behavior through a side channel instead of the chosen seam

## Work in red-green slices

Implement one vertical slice at a time:

1. Write one meaningful test for behavior at the agreed seam.
2. Run it and confirm it fails for the expected reason.
3. Add only enough production code to make that test pass.
4. Run it again and confirm green before choosing the next behavior.

Let each cycle inform the next. Do not write the entire test suite up front, anticipate future tests, or add speculative functionality. Keep broad refactoring separate from the red-green implementation loop; perform it only after behavior is covered and passing.

When finished, run the relevant test suite and report the seams tested, red-green cycles, and results.
