# Debugging

The project ships a focused local check for the aim pipeline:

```powershell
.\Tools\Check.ps1
```

It runs every Luau spec, lints the aim modules with Selene, and analyzes the
host-independent policy/state modules with `luau-analyze`.

To refresh the local dependency graph too:

```powershell
.\Tools\Check.ps1 -Graph
```

Required commands: `luau`, `luau-analyze`, and `selene`. Graph refreshes also
require `graphify`. Generated Graphify output and API keys are intentionally
excluded from Git.
