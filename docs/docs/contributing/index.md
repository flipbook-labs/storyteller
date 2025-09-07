# Contributing

Thank you for your interest in contributing to Storyteller! This guide will help you get your environment setup so you can have the best possible development experience.

## First-time setup

We use [Visual Studio Code](https://code.visualstudio.com/) to work on this project, so you'll get the best mileage from using it too. We also have several [recommended extensions](https://github.com/flipbook-labs/flipbook/blob/main/.vscode/extensions.json) that should be installed.

You will also need [Rokit](https://github.com/rojo-rbx/rokit/) for installing the various command-line tools we use.

With the above requirements satisfied, run the following commands from your clone of the repo to start developing:

```sh
# Install command-line tools (like Lune)
$ rokit install

# Install packages
$ lune run install
```

## Testing

Run the following to run all unit tests for the project:

```sh
$ lune run test
```

We use jsdotlua's [Jest](https://github.com/jsdotlua/jest-lua) fork for authoring and executing unit tests. [Read the docs](https://jsdotlua.github.io/jest-lua/) and look to our existing `.spec.luau` modules for how to write tests.

:::tip
If your code is not properly tested, maintainers will let you know and offer suggestions on how to improve your tests so you can get your pull request merged.
:::

## Building

Part of our build process uses [darklua](https://github.com/seaofvoices/darklua) to compile our Luau source code for Roblox. This is largely to support string requires so our Storyteller source code can use the same syntax as our Lune scripts.

Run the following to build the project:

```sh
$ lune run build
```

By default, the project is built for a production environment, so all development files like our unit tests are pruned from the resulting build. To keep development files, pass the `--target` flag to set the environment to build for:

```sh
$ lune run build --target dev
```

