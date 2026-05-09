return {
	luau = {
		languagemode = "strict",
		aliases = {
			lute = "~/.lute/typedefs/1.0.1/lute",
			std = "~/.lute/typedefs/1.0.1/std",
			lint = "~/.lute/typedefs/1.0.1/lint",
			luaupkg = "~/.loom/store",
			pkg = "./Packages",
			repo = "./",
			root = "./src",

			-- Remove this alias once we don't have to write such unwieldy paths
			-- to our batteries
			batteries = "~/.loom/store/Lute@v1.0.1-nightly.20260508/batteries",
		},
	},
}
