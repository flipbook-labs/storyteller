return {
	bump = "minor",
	category = "Changes",
	kind = "loading",
	summary = "Upgrade to ModuleLoader 1.0, so a loader passed to Storyteller's load functions must come from `createModuleLoader`.",
	body = [[
`loadStorybookModule`, `loadStoryModule` and `loadStoriesFromModule` take an optional loader, and Storyteller now calls it with ModuleLoader 1.0's functions, such as `loader.require(module)`. A loader made with `ModuleLoader.new()` from 0.13 no longer works there. Make one with `ModuleLoader.createModuleLoader()` instead.

When a Storybook or story module fails to load, the error from `loadStorybookModule` or `loadStoryModule` and a story record's `problem` still include the stack after the message. ModuleLoader 1.0 raises the message on its own, so Storyteller now reads the stack from `getLastError`.
]],
}
