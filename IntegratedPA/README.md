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

Existing files are being moved into these folders gradually.
