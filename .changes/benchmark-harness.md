---
bump: patch
category: Changes
---

Add a StorytellerStore benchmark suite behind a --benchmarks flag (`lute run test --benchmarks`) with a non-blocking CI job. Bench files use the .bench suffix and never run in the regular spec pass.
