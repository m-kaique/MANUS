# Integrated Price Action EA

This repository contains the source code and documentation for the **IntegratedPA_EA**, a modular expert advisor for MetaTrader 5. The EA implements trading strategies based on price action with multi-asset support and extensive risk management.

## Repository Layout
- **IntegratedPA** – main source code and modules written in MQL5
- **EA_Fluxo_Logico.md** – overview of the EA's logical flow
- **Guia para Criar Arquivos MD por Fase no MQL5** – Portuguese guides outlining the trading methodology and development phases
- **Guia_Completo_de_Trading_Versao_Final.pdf** – reference trading guide

## Building
1. Install **MetaTrader 5** and open **MetaEditor**.
2. Copy the contents of the `IntegratedPA` folder into your terminal's `MQL5/Experts/IntegratedPA` directory.
3. Open `IntegratedPA_EA.mq5` in MetaEditor and compile.

Refer to `fase7_finalizacao_entrega.md` for detailed compilation steps and folder structure.

## Usage
After compilation, attach `IntegratedPA_EA` to a chart. Input parameters allow enabling assets (BTC, WDO, WIN), configuring risk limits, and defining trading sessions.

Logs are written to files via `CLogger` and optionally exported to JSON. Consult `EA_Fluxo_Logico.md` for the runtime sequence and module responsibilities.

## Documentation
The `Conhecimento` and guide folders provide extensive Portuguese documentation covering trading concepts, risk management, and recommended coding practices.

