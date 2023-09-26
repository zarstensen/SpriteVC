# Tests

This extension implements a test configuration, which tests the extensions functionallity when installed in an aseprite application. Additionally, the test can be run in a docker container, in order to increase ease of use and repetability of the tests.

## Running tests

### Locally With Docker

[Docker Desktop](https://www.docker.com/) or other similar software is required to be installed and running for this step.

A bat script is provided which runs all of the neccesarry docker commands to run the tests. This command needs to be executed at the root of the repository. Since this requires aseprite to be built from source, it might take a while the first time the tests are run (~15 min), subsequent runs should be significantly faster (1-10 seconds).

```bash
run-tests.bat
```

If you want to manually do it, you can build and run the 'test' tag, using the following command at the root of the repository.

```bash
docker compose run --build --rm test
```

After running the container, any dangling images can be cleaned up with the following command.

```bash
docker image prune -f
```

### Github Actions

See [test workflow file](/.github/workflows/test.yml).

### Locally Without Docker

*WARNING:* This approach will install the test extension on your current aseprite installation. If the extension has a critical error which leads to a crash, this installation will break your installation of aseprite until the extension is manually removed from the extension folder. Additionally, the tests will run **every time** aseprite is started (even if not in batch mode). Therefore it is recommended you use either the [Locally With Docker](#locally-with-docker) or [Github Actions](#github-actions) approach when running tests.

Perform the following steps to set up testing locally without docker.
[Python](https://www.python.org/) and [aseprite](https://www.aseprite.org/) is required for this to work.

- Publish a test configuration of the extension using the following command at the root of the repo.

  ```bash
  python publish.py test none zip publish
  ```

- Install the published extension through aseprite.
- Run aseprite in batch mode, to see the test results.

  ```bash
  aseprite --batch
  ```
