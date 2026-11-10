# Ario — shell module

This is the first structural shell for Ario, currently staged inside the Souren
repository so the host integration can be reviewed before the module is moved
to its own repository.

## Module boundary

- Android library module: `:ario`
- Namespace: `ir.ario.shell`
- Host application ID remains: `ir.souren.souren`
- Entry activity: `ArioActivity`
- Souren bridge: MethodChannel `souren/ario`, method `open`
- Optional launcher alias: `ir.souren.souren.ArioLauncher` (disabled by default)
- Ario storage namespace: `ArioStorage`

## Important Android constraint

Because this is an Android library embedded in Souren, it is part of the same
installed Android package. It can have its own activity, launcher alias,
preferences, database and private files, but Android cannot uninstall this
library independently from Souren. The launcher alias can be disabled and
Ario-owned local data can be cleared independently. Data that must survive
deactivation needs to be synchronized/backed up before local clearing.

## Current scope

The activity intentionally contains only a neutral background and the word
“Ario”. No product UI, business logic, network access, account system or
synchronization is implemented yet.

## Repository plan

Keep Ario's source in a separate private repository once that repository is
created, then consume a pinned revision from Souren's build. This staging copy
exists only to validate the Android module boundary and host launch bridge.
