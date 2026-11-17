return {
	package = {
		name = "Storyteller",
		version = "1.12.0",
		dependencies = {
			FlipbookBatteries = {
				rev = "v0.13.0",
				sourceKind = "github",
				source = "https://github.com/flipbook-labs/flipbook-batteries",
			},
			Batteries = {
				rev = "v1.0.1-nightly.20261115",
				sourceKind = "github",
				source = "https://github.com/luau-lang/lute",
				target = "batteries",
			},
		},
		dev_dependencies = {
			CodeQuality = {
				rev = "v0.2.0",
				sourceKind = "github",
				source = "https://github.com/flipbook-labs/code-quality",
			},
			AgentSkills = {
				rev = "v0.7.0",
				sourceKind = "github",
				source = "https://github.com/flipbook-labs/agent-skills",
			},
		},
	},
}
