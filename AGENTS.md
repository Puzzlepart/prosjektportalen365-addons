# Agent guidelines

## Scripts/AI

- **Never edit `Scripts/AI/AutoRunbooks/*.ps1` by hand.** They are build artifacts.
  `Scripts/AI/SetupRunbooks.ps1` generates them by taking each source script and
  replacing its `. .\CommonPPAI.ps1` line with the full contents of `CommonPPAI.ps1`
  (Azure Automation does not support dot-sourcing sibling files), then importing the
  result into Azure Automation. Any manual change to a file under `AutoRunbooks/` is
  overwritten the next time `SetupRunbooks.ps1` runs.
- Make changes only in the source scripts under `Scripts/AI/` and in
  `CommonPPAI.ps1`. Put shared/common functions in `CommonPPAI.ps1` — they are
  inlined into the runbooks automatically by the build.
- The list of scripts that get turned into runbooks lives in the `$AutoRunbooks`
  array in `Scripts/AI/SetupRunbooks.ps1`.
