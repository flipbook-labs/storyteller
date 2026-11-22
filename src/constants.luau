return {
	STORY_NAME_PATTERN = "%.story$",
	STORYBOOK_NAME_PATTERN = "%.storybook$",

	-- The top-level fields stories and storybooks used to name their UI library
	-- before `packages` existed. `migrateLegacyPackages` moves them into
	-- `packages`.
	LEGACY_PACKAGE_FIELDS = table.freeze({ "roact", "react", "reactRoblox" }),
}
