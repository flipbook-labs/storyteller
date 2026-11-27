return {
	package = {
		name = "Storyteller",
		version = "1.15.0",
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
			archivist = {
				rev = "v0.3.1",
				sourceKind = "github",
				source = "https://github.com/flipbook-labs/archivist",
			},
			["flipbook-batteries"] = {
				rev = "v0.13.1",
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
				rev = "v0.8.0",
				sourceKind = "github",
				source = "https://github.com/flipbook-labs/code-quality",
			},
			["agent-skills"] = {
				rev = "v0.9.0",
				sourceKind = "github",
				source = "https://github.com/flipbook-labs/agent-skills",
			},
		},
	},
}
