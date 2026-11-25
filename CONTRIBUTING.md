# Contributing to Storyteller

Thanks for helping improve Storyteller. You can prepare a pull request without access to any Flipbook Labs secrets.

## Quick start

Install [Rokit](https://github.com/rojo-rbx/rokit/) before running the setup commands below.

1. [Fork Storyteller](https://github.com/flipbook-labs/storyteller/fork), then clone your fork and add the main repository as `upstream`:

   ```sh
   git clone https://github.com/<your-account>/storyteller.git
   cd storyteller
   git remote add upstream https://github.com/flipbook-labs/storyteller.git
   ```

2. Create a branch from the latest `main`:

   ```sh
   git fetch upstream
   git switch -c my-change upstream/main
   ```

3. Install the pinned tools and packages. `npm ci` needs Node.js 24 and installs Prettier, which `lute run lint` uses to check Markdown:

   ```sh
   rokit install
   lute run install
   npm ci
   ```

4. Make your change and add one file under [`.changes/`](.changes/README.md) describing its effect for people who use Storyteller.

5. Run the checks that need no credentials:

   ```sh
   lute run lint
   lute run analyze
   lute run test --build-only
   ```

   `lute run test --build-only` builds the test place without running it. Running the tests needs an Open Cloud API key, so if you have one, set `ROBLOX_API_KEY` in a `.env` file (see `.env.template`) and run `lute run test`.

6. Push your branch to your fork and open a pull request against `flipbook-labs/storyteller:main`.

Fork pull requests build the test place on a runner without secrets. A maintainer then approves a separate protected job that runs the tests from that place with the repository's key. The protected job uses the test runner scripts from `main`, so changes to `.lute/` scripts take effect in CI once they merge.

See the [contributing guide](https://flipbook-labs.github.io/storyteller/contributing/) for build channels and writing tests.
