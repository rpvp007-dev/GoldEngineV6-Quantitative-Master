# 🏛️ GoldEngineV6: Quantitative Multi-Regime Master Architecture

**GoldEngineV6** is the flagship commercial-grade quantitative trading engine for Gold (`XAUUSD`), engineered to solve multi-day market cycle drawdown and deliver consistent high-expectancy returns across all market regimes.

---

## 🏛️ The 5 Institutional Pillars of GoldEngineV6:

1. **🧠 Pillar 1: Market Regime State Classifier (`MarketRegimeEngine.mqh`)**:
   * **`REGIME_STATE_TRENDING`**: ADX $\ge$ 25 & ATR $\ge$ 10.0 pips. Activates trend strategies with **Long Targets (+80 to +120 Pips)**.
   * **`REGIME_STATE_RANGING`**: ADX < 25. Disables trend strategies, activates mean-reversion scalpers with **Short Targets (+12 to +15 Pips)**.
   * **`REGIME_STATE_CHOP_DEAD`**: ATR < 6.0 pips or ADX < 14. **HALTS ALL TRADING 100%** to save capital during flat sideways chop!

2. **🎯 Pillar 2: Dynamic Target & Exit Intelligence (`DynamicTargetEngine.mqh`)**:
   * Dynamically expands TP/SL targets based on real-time market regime (Long Targets on trend days, Short Targets on range days).

3. **🌊 Pillar 3: Liquidity Pool & FVG Matrix (`LiquidityMatrixEngine.mqh`)**:
   * Detects PDH/PDL sweeps, Asian Range High/Low sweeps, and Fair Value Gaps (FVG) for institutional precision.

4. **📐 Pillar 4: Statistical Expectancy Gatekeeper**:
   * Rejects any trade signal where mathematical expected payout $\le \$0.00$.

5. **💰 Pillar 5: Daily Profit Protection & Equity Guard**:
   * $20 Capital Floor protection + $50 dynamic compounding lot ladder.

---

## 🛠️ Main Source Files:
* `Experts/GoldEngineV6.mq5`
* `Experts/GoldEngineV6_Decoupled.mq5`
* `Include/GoldEngineV4/QuantEngine/MarketRegimeEngine.mqh`
* `Include/GoldEngineV4/QuantEngine/DynamicTargetEngine.mqh`
* `Include/GoldEngineV4/QuantEngine/LiquidityMatrixEngine.mqh`

---

## 🔒 Intellectual Property Notice
All source code, quant architecture, and proprietary algorithms are protected. Unauthorized distribution or reproduction is prohibited.
