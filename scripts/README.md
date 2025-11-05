# Helper Scripts

This folder has some helper scripts. Ok, it just has one right now. But if we have more in the future we'll put them here too.

## Mongo Migration

Pro tip: if you are setting up a Workbench instance from scratch, you won't need this at all!

For a long time we had the reference mongo container in the compose.yaml file pinned to mongo:5 which is no longer supported.
Luckily for us, the migration process from 5 to 8 is fairly straightforward for the way we use MongoDB.

The script in [mongo-migration](mongo-migration/) walks you through the process if you have an existing mongodb
that needs to be upgraded in place.
It automatically runs to commands which are discussed in the README.md in that folder

Let us know if you run into any issues!
