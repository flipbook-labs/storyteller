# Contributing

Thank you for your interest in contributing to Storyteller! This guide will help you get your environment setup so you can have the best possible development experience.

## First-time setup

We use [Visual Studio Code](https://code.visualstudio.com/) to work on this project, so you'll get the best mileage from using it too. We also have several [recommended extensions](https://github.com/flipbook-labs/flipbook/blob/main/.vscode/extensions.json) that should be installed.

You will also need [Rokit](https://github.com/rojo-rbx/rokit/) for installing the various command-line tools we use, plus Node.js 24 and npm for Markdown formatting. The repository's `.node-version` file configures compatible Node version managers.

With the above requirements satisfied, run the following commands from your clone of the repo to start developing:

```sh
# Install command-line tools (like Lute)
$ rokit install

# Install packages
$ lute run install

# Install development tools
$ npm ci
```

## Testing

Run the following to run all unit tests for the project:

```sh
$ lute run test
```

The tests run in the cloud through Open Cloud Luau Execution, so `lute run test` needs an API key in the `ROBLOX_API_KEY` environment variable or a `.env` file (see `.env.template`). Without a key, you can still check that the test place builds:

```sh
$ lute run test --build-only
```

Pull requests from forks run the tests in CI once a maintainer approves them, so you do not need a key to contribute.

We use jsdotlua's [Jest](https://github.com/jsdotlua/jest-lua) fork for authoring and executing unit tests. [Read the docs](https://jsdotlua.github.io/jest-lua/) and look to our existing `.spec.luau` modules for how to write tests.

:::tip

If your code is not properly tested, maintainers will let you know and offer suggestions on how to improve your tests so you can get your pull request merged.

:::

## Building

Storyteller's source code uses string requires, the same syntax as our Lute scripts. The build copies `src/` to `dist/` and rewrites each string require into an instance require like `require(script.Parent.Foo)` so the build runs in Roblox.

Run the following to build the project:

```sh
$ lute run build
```

By default, the project is built for a production environment, so all development files like our unit tests are pruned from the resulting build. To keep development files, pass the `--channel` flag to set the environment to build for:

```sh
$ lute run build --channel dev
```
