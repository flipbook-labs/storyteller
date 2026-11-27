return {
	bump = "minor",
	category = "Changes",
	kind = "loading",
	summary = "Upgrade to ModuleLoader 1.0, so a loader passed to Storyteller's load functions must come from `createModuleLoader`.",
	body = [[
`loadStorybookModule`, `loadStoryModule` and `loadStoriesFromModule` take an optional loader, and Storyteller now calls it with ModuleLoader 1.0's functions, such as `loader.require(module)`. A loader made with `ModuleLoader.new()` from 0.13 no longer works there. Make one with `ModuleLoader.createModuleLoader()` instead.

A story record's `problem` still starts with the error's message and follows it with the stack. ModuleLoader 1.0 raises the message on its own, and Storyteller reads the stack from `getLastError`.
]],
}
