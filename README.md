# Acorn Library

This repository houses all of the Acorn library image definitions.

## Style / Guidelines for library acorns

1. Use official images from the Docker library if available.
1. Use specific version tags of images, at least to the minor in semver.
1. Use automatically generated secrets, and allow the user to specify values if needed.
1. Prefer to handle the application in cuelang vs. string interpolations.
1. Do not use master - slave terminology.  Use terms like leader / follower, worker / agents, replicas, etc.
1. When adding parameters:

      1. Use `scale` to represent number of containers running of the exact same config.
      1. Use `replicas` to represent multiple instances with the same role.

1. Create a secret `"user-secret-data": type: "opaque"` to allow users to bind in secret data for use inside the acorn.
1. For consistency and readability create Acorn cue with top level keys in the following order:

    1. args
    1. containers
    1. jobs
    1. volumes
    1. acorns
    1. secrets
    1. localData

1. If you are using if blocks to deploy an optional component, the if block should add/modify keys in the overall acorn key order.
1. When merging user provided structs with default structs, place the user provided struct variable first. `args.deploy.userData & {...acorn defined data}`.
