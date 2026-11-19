-- Aliases for Storyteller's own modules, relative to this folder. The Lute
-- package of Storyteller ships this file (see `files` in `pkg.luau`). A
-- consumer that installs it with `lute pkg install --vendor` gets a copy
-- inside their own repo, and Luau resolves each alias from the nearest config
-- that defines it. So `@root` keeps pointing here rather than at the
-- consumer's `@root`. The repo-root `.config.luau` doesn't ship, because its
-- aliases point at folders in this repo, like `.lpm` and `Packages`. Aliases
-- for dependencies, like `@pkg` for the Wally packages, come from the
-- consumer's config.
return {
	luau = {
		aliases = {
			root = "./",
		},
	},
}
