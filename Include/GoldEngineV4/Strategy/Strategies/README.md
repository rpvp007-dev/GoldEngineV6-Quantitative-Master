# GITS Production Strategy Development Guidelines

This directory is designated for hosting all production-grade algorithmic trading strategies for the **Gold Institutional Trading System (GITS)**.

Every strategy developed for GITS must comply with the following strict guidelines and architectural design patterns.

---

## Technical Specifications

1. **Inheritance**: All strategies must inherit from the base interface class `IStrategy` defined in [IStrategy.mqh](file:///Users/vivekpanchal/Documents/MT5%20Gold%20Trading%20Bot/GoldEngineV2/Include/GoldEngineV2/Strategy/IStrategy.mqh).
2. **Namespace & File Naming**:
   - File name should be prefixed with strategy ID, e.g., `Strategy_002_SwingEMA.mqh`.
   - The class name should match the file name, e.g., `class CStrategy_002_SwingEMA : public IStrategy`.
3. **Indicator Bindings**: Strategies must NOT instantiate indicators globally or independently. They must query data exclusively through the `QuantEnginesContainer` reference injected via `Initialize()`.

---

## Strategy Rules of Conduct

To maintain high cohesion and decoupling, every strategy must respect these system boundaries:
* **DO NOT calculate account risk or balance constraints**: Let the **Risk Guardian** handle position sizing and risk verification.
* **DO NOT place, modify, or close orders directly**: The strategy's only action is to return a signal. The **Execution Engine** is the sole module allowed to route order transactions.
* **DO NOT query active positions or balance tables**: Keep the strategy stateless. The coordinator and Analytics Engine maintain historical tracking.
* **DO NOT communicate with other strategies**: A strategy must remain isolated. It should be possible to delete one strategy without affecting another.
* **Return standard responses**: The `Evaluate()` loop must return a populated `StrategyResponse` struct defined in [StrategyDefines.mqh](file:///Users/vivekpanchal/Documents/MT5%20Gold%20Trading%20Bot/GoldEngineV2/Include/GoldEngineV2/Strategy/StrategyDefines.mqh).

---

## Implementation Template

```cpp
#ifndef GOLDENGINEV2_STRATEGY_002_SWING_EMA_MQH
#define GOLDENGINEV2_STRATEGY_002_SWING_EMA_MQH

#include "../IStrategy.mqh"

class CStrategy_002_SwingEMA : public IStrategy
{
private:
   bool              m_enabled;
   string            m_name;
   
   // References to injected Quant Engines
   ITrendEngine*     m_trend;
   IMomentumEngine*  m_momentum;

public:
   CStrategy_002_SwingEMA()
      : m_enabled(true),
        m_name("S-002-SwingEMA"),
        m_trend(NULL),
        m_momentum(NULL)
   {}
   
   ~CStrategy_002_SwingEMA() {}

   virtual bool Initialize(const QuantEnginesContainer &engines) override
   {
      m_trend = engines.Trend;
      m_momentum = engines.Momentum;
      
      // Ensure required dependencies are resolved
      return (m_trend != NULL && m_momentum != NULL);
   }

   virtual StrategyResponse Evaluate(const string symbol) override
   {
      StrategyResponse response;
      response.Signal = GEV2_SIGNAL_NONE;
      response.EntryPrice = 0.0;
      response.StopLoss = 0.0;
      response.TakeProfit = 0.0;
      response.Confidence = 0.0;
      response.Reason = "No Setup";
      response.StrategyName = m_name;

      if(!m_enabled)
      {
         response.Reason = "Strategy disabled";
         return response;
      }

      // 1. Fetch values from Quant Engines
      int direction = m_trend.GetTrendDirection(symbol, PERIOD_M15);
      double rsi = m_momentum.GetRSI(symbol, PERIOD_M15, 14, 1);

      // 2. Perform mock entry setups checks (no indicators logic implementation in core architecture)
      if(direction > 0 && rsi < 30.0)
      {
         response.Signal = GEV2_SIGNAL_BUY;
         response.EntryPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
         response.StopLoss = response.EntryPrice - 150 * SymbolInfoDouble(symbol, SYMBOL_POINT);
         response.TakeProfit = response.EntryPrice + 450 * SymbolInfoDouble(symbol, SYMBOL_POINT);
         response.Confidence = 0.90;
         response.Reason = "Oversold Trend Alignment Pullback Found";
      }

      return response;
   }

   virtual string GetName() const override { return m_name; }
   virtual void SetEnabled(bool enabled) override { m_enabled = enabled; }
   virtual bool IsEnabled() const override { return m_enabled; }
};

#endif // GOLDENGINEV2_STRATEGY_002_SWING_EMA_MQH
```
