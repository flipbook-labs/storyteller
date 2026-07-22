export type StoryModuleRequestPriority = "Background" | "Interactive"

local StoryModuleRequestPriority = table.freeze({
	Background = "Background" :: "Background",
	Interactive = "Interactive" :: "Interactive",
})

return StoryModuleRequestPriority
