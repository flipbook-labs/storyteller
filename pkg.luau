return {
	package = {
		name = "Storyteller",
		version = "1.12.0",
		-- What the Lute package of Storyteller ships. Specs, stories and benchmarks
		-- stay out, and so do `e2e` and `test-utils`, which the prod build also
		-- prunes from `dist/`. `files` skips hidden files unless a pattern names
		-- them, so `src/.config.luau` is listed on its own.
		files = {
			"/src/**",
			"!/src/e2e/**",
			"!/src/test-utils/**",
			"!**/*.spec.luau",
			"!**/*.story.luau",
			"!**/*.storybook.luau",
			"!**/*.bench.luau",
			"!**/jest.config.luau",
			"/src/.config.luau",
			"/README.md",
			"/LICENSE",
		},
		dependencies = {
			["flipbook-batteries"] = {
				rev = "v0.13.0",
				sourceKind = "github",
				source = "https://github.com/flipbook-labs/flipbook-batteries",
			},
			batteries = {
				rev = "v1.0.1-nightly.20261115",
				sourceKind = "github",
				source = "https://github.com/luau-lang/lute",
				target = "batteries",
			},
		},
		dev_dependencies = {
			["code-quality"] = {
				rev = "v0.3.0",
				sourceKind = "github",
				source = "https://github.com/flipbook-labs/code-quality",
			},
			["agent-skills"] = {
				rev = "v0.7.0",
				sourceKind = "github",
				source = "https://github.com/flipbook-labs/agent-skills",
			},
		},
	},
}
