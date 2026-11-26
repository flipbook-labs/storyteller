return {
	bump = "minor",
	category = "Features",
	kind = "loading",
	summary = "Keep a Story's last working version loaded when an edit stops it loading, and report the error in the record's new `problem` field.",
	body = "A record's `problem`, on Loaded and Unavailable records alike, is the error's message alone, without ModuleLoader's traceback or a \"Failed to load story\" prefix.",
}
