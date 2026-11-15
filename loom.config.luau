return {
	package = {
		name = "Storyteller",
		version = "1.12.0",
		dependencies = {
			FlipbookBatteries = {
				rev = "v0.12.0",
				sourceKind = "github",
				source = "https://github.com/flipbook-labs/flipbook-batteries",
			},
			Lute = {
				rev = "v1.0.1-nightly.20260701",
				sourceKind = "github",
				source = "https://github.com/luau-lang/lute",
			},
		},
		dev_dependencies = {
			CodeQuality = {
				rev = "abafa51fdac79cda09bb2e54c6b21af628840b33",
				sourceKind = "github",
				source = "https://github.com/flipbook-labs/code-quality",
			},
			AgentSkills = {
				rev = "v0.5.0",
				sourceKind = "github",
				source = "https://github.com/flipbook-labs/agent-skills",
			},
		},
	},
}
