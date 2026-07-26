# Legacy Prediction Boundary

This folder marks the old prediction cluster as compatibility-only.

Current intent:
- Keep `Modules/PredictionCore.lua`, `Modules/NPCPrediction.lua`, and `Modules/PvPPrediction.lua` available for old callers.
- Move new runtime work to `Modules/Combat/Predictor.lua` and the `Modules/Combat/Prediction/*` pipeline.
- Use `CompatAdapter.lua` as the migration seam for any remaining code that expects the old `PredictionCore`-style API.

Long-term target:
1. Point all callers at the modern pipeline or the compat adapter.
2. Stop instantiating `PredictionCore` directly.
3. Delete the God-file cluster after the last compatibility dependency is removed.
