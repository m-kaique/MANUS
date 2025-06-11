# IntegratedPA Structure

This project is being reorganized to improve maintainability.

## Directories

- `Core/` – core components for the EA
- `Engine/` – trading engines and orchestration logic
- `Risk/` – risk management modules such as `RiskManager` and `CircuitBreaker`
- `Execution/` – trade execution components
- `Analysis/` – market analysis utilities
- `Indicators/` – indicator handle wrappers
- `Strategies/` – trading strategies
- `Utils/` – shared utility code
- `Logging/` – logging infrastructure (`Logger.mqh`, `JsonLog.mqh`)
- `UI/` – interface elements
- `Tests/` – test scripts and examples

Most of the original monolithic files were moved:

- Core components like `Structures.mqh`, `Constants.mqh`, `MetricsCollector.mqh`
  and `PerformanceTracker.mqh` now live in `Core/`.
- Market analysis utilities such as `MarketContext.mqh` and `SetupClassifier.mqh`
  were relocated to `Analysis/`.
- The main trading engine `SignalEngine.mqh` sits in `Engine/` while
  `TradeExecutor.mqh` is under `Execution/`.
- Risk modules including `RiskManager.mqh`, `CircuitBreaker.mqh` and
  `VolatilityAdjuster.mqh` are placed in `Risk/`.
- User interface code (`VisualPanel.mqh`) resides in `UI/` and helpers like
  `Utils.mqh` were moved to `Utils/`.

Include paths in all modules were updated to reflect this hierarchy.
