return {
	package = {
		name = "Storyteller",
		version = "1.13.0",
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
			AgentSkills = {
				rev = "v0.5.0",
				sourceKind = "github",
				source = "https://github.com/flipbook-labs/agent-skills",
			},
		},
	},
}
