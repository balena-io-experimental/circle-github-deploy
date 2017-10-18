# circle-github-deploy
Parallel CircleCI workflow with automatic artifacts deployment to GitHub Releases

Overview
--------

This projects is a template for creating parallel CircleCI workflows producing build artifacts that have to be stored as  GitHub Releases assets.

There are two CircleCI stages involved:
  * build stage consisting of a number of parallel jobs, e.g. jobs producing builds for different system architectures.
  * deployment stage that is executed only on git tag pushes, which creates a GitHub tagged release and uploads the artifacts.

```
+---------------+
| aarch64 build |\
+---------------+ \
                   \
+---------------+   \
|  amd64 build  |\   \
+---------------+ -\  \
                    -\ \
+---------------+     -\\  +---------------+
| armv7hf build |--------x-| GitHub deploy |
+---------------+     -//  +---------------+
                    -/ /
+---------------+ -/  /
|  i386 build   |/   /
+---------------+   /
                   /
+---------------+ /
|   rpi build   |/
+---------------+
```

Prerequisites
-------------

You will need two environment variables added in your CircleCI project settings:
  * GITHUB_TOKEN - a GitHub personal access token that is used to access the GitHub API.
  * CIRCLE_TOKEN - a CircleCI API token used for interacting with the CircleCI API.

Build stage
-----------

The build stage consists of multiple parallel jobs defined in the `.circleci/config.yml` CircleCI configuration. Each example job creates a .tar.gz archive with a dummy binary file, simulating creating build artifact for a system architecture. The archive of each build is then added as a CircleCI job artifact.

Deployment stage
----------------

The deployment stage is more complex and is implemented as a bash script: `scripts/deploy.sh`. It consists of the following steps:
  * Exits if CIRCLE_TAG is not defined by CircleCI -- not running a git tag push triggered build.
  * Invokes the CircleCI API to get a build summary for each of the last 30 builds.
  * Identifies the build numbers of the previously run build jobs corresponding to the current deployment job.
  * Queries the CircleCI API for a list with downloadable artifacts from the previously executed build jobs.
  * Downloads the artifacts of each build job in `/tmp/artifacts`.
  * Parses the `CHANGELOG.md` file from the repository to get a description for the current release. You should probably modify this step to suit the needs of your project, if you are using a different format for storing release information.
  * Creates a GitHub Release using the provided CIRCLE_TAG and the description from the changelog file.
  * Iterates and uploads all the previously stored build artifacts to the newly created GitHub release.
