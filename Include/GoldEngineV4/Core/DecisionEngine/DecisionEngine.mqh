//+------------------------------------------------------------------+
//|                                           DecisionEngine.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_DECISION_ENGINE_MQH
#define GOLDENGINEV2_DECISION_ENGINE_MQH

#include "IDecisionEngine.mqh"

//+------------------------------------------------------------------+
//| Institutional Decision Engine Concrete Implementation              |
//+------------------------------------------------------------------+
class CDecisionEngine : public IDecisionEngine
{
private:
   IMarketContextEngine*      m_contextEngine;
   bool                       m_isInitialized;
   DecisionContext            m_decisionCtx;

   /**
    * @brief Helper to convert decision enum to string description.
    */
   string GetDecisionStr(ENUM_TRADE_DECISION dec)
   {
      switch(dec)
      {
         case DECISION_BUY:  return "BUY";
         case DECISION_SELL: return "SELL";
         case DECISION_WAIT: return "WAIT";
         case DECISION_AVOID:return "AVOID";
         default:            return "UNKNOWN";
      }
   }

public:
   /**
    * @brief Constructor.
    */
   CDecisionEngine()
      : m_contextEngine(NULL),
        m_isInitialized(false)
   {
      ZeroMemory(m_decisionCtx);
   }

   /**
    * @brief Destructor.
    */
   ~CDecisionEngine() {}

   /**
    * @brief Link context engine.
    */
   virtual bool Initialize(IMarketContextEngine* contextEngine) override
   {
      m_contextEngine = contextEngine;
      if(m_contextEngine == NULL)
      {
         m_isInitialized = false;
         return false;
      }
      m_isInitialized = true;
      return true;
   }

   /**
    * @brief Evaluates current context to calculate probability metrics and decisions.
    */
   virtual void EvaluateDecision(const string symbol, ENUM_TIMEFRAMES tf) override
   {
      if(!m_isInitialized) return;

      // 1. Fetch current synthesized Market Context
      MarketContext ctx = m_contextEngine.GetContext();

      // 2. Trend Continuation Probability
      double continuationProb = 0.0;
      if(ctx.TrendRegime != 0)
      {
         continuationProb = ctx.ContextConfidence; // Base probability from EMA alignment confidence
         
         if(ctx.MarketRegime == REGIME_TRENDING) continuationProb += 15.0;
         else if(ctx.MarketRegime == REGIME_EXPANSION) continuationProb += 10.0;

         if(ctx.TrendPhase == PHASE_EARLY_TREND) continuationProb += 15.0;
         else if(ctx.TrendPhase == PHASE_CONTINUATION) continuationProb += 15.0;
         else if(ctx.TrendPhase == PHASE_MATURE_TREND) continuationProb += 10.0;
         else if(ctx.TrendPhase == PHASE_EXHAUSTION) continuationProb -= 40.0; // Exhaustion drops continuation likelihood
         else if(ctx.TrendPhase == PHASE_PULLBACK) continuationProb += 5.0;

         if(ctx.MomentumState == MOM_STATE_ACCELERATING_BULLISH && ctx.TrendRegime == 1) continuationProb += 10.0;
         else if(ctx.MomentumState == MOM_STATE_ACCELERATING_BEARISH && ctx.TrendRegime == -1) continuationProb += 10.0;
         else if(ctx.MomentumState == MOM_STATE_DECELERATING) continuationProb -= 15.0;

         continuationProb = MathMax(0.0, MathMin(100.0, continuationProb));
      }

      // 3. Reversal Probability
      double reversalProb = 10.0;
      if(ctx.TrendPhase == PHASE_EXHAUSTION) reversalProb += 30.0;
      if(ctx.StructureState == STRUCT_STATE_CHOCH) reversalProb += 30.0;
      if(ctx.LiquidityState == LIQ_STATE_SWEEPING || ctx.LiquidityState == LIQ_STATE_POST_SWEEP) reversalProb += 20.0;
      if(ctx.MomentumState == MOM_STATE_DECELERATING) reversalProb += 10.0;
      reversalProb = MathMax(0.0, MathMin(100.0, reversalProb));

      // 4. Breakout Probability
      double breakoutProb = 20.0;
      if(ctx.MarketRegime == REGIME_COMPRESSION) breakoutProb += 35.0;
      if(ctx.StructureState == STRUCT_STATE_BOS) breakoutProb += 25.0;
      if(ctx.MarketRegime == REGIME_BREAKOUT) breakoutProb += 20.0;
      if(ctx.VolatilityRegime == VOL_STATE_HIGH || ctx.VolatilityRegime == VOL_STATE_EXPLODING) breakoutProb += 10.0;
      breakoutProb = MathMax(0.0, MathMin(100.0, breakoutProb));

      // 5. Range Probability
      double rangeProb = 15.0;
      if(ctx.MarketRegime == REGIME_RANGING) rangeProb += 45.0;
      if(ctx.StructureState == STRUCT_STATE_RANGE) rangeProb += 20.0;
      if(ctx.VolatilityRegime == VOL_STATE_LOW) rangeProb += 20.0;
      rangeProb = MathMax(0.0, MathMin(100.0, rangeProb));

      // 6. Select Overall Trade Probability matching market regime
      double tradeProb = 0.0;
      if(ctx.MarketRegime == REGIME_TRENDING)
      {
         tradeProb = continuationProb;
      }
      else if(ctx.MarketRegime == REGIME_BREAKOUT || ctx.MarketRegime == REGIME_EXPANSION)
      {
         tradeProb = MathMax(continuationProb, breakoutProb);
      }
      else if(ctx.MarketRegime == REGIME_COMPRESSION)
      {
         tradeProb = breakoutProb;
      }
      else if(ctx.MarketRegime == REGIME_REVERSAL)
      {
         tradeProb = reversalProb;
      }
      else if(ctx.MarketRegime == REGIME_RANGING)
      {
         tradeProb = rangeProb;
      }
      else
      {
         tradeProb = MathMax(continuationProb, MathMax(reversalProb, breakoutProb));
      }

      // 7. Determine Decision State
      ENUM_TRADE_DECISION decision = DECISION_WAIT;

      if(ctx.MarketQuality == "Poor Market" || ctx.MarketQuality == "Weak" || ctx.TradeEnvScore < 30.0)
      {
         decision = DECISION_AVOID;
      }
      else if(ctx.VolatilityRegime == VOL_STATE_LOW)
      {
         decision = DECISION_AVOID; // Avoid low volatility chop
      }
      else if(ctx.SessionState == "None")
      {
         decision = DECISION_AVOID; // Avoid out-of-session hours
      }
      else if(ctx.TrendPhase == PHASE_PULLBACK)
      {
         decision = DECISION_WAIT; // Pullbacks are developing, wait for trigger
         tradeProb = 50.0;
      }
      else if(ctx.MarketRegime == REGIME_COMPRESSION && tradeProb < 60.0)
      {
         decision = DECISION_WAIT; // Compression phase, waiting for expansion
      }
      else if(tradeProb < 60.0)
      {
         decision = DECISION_WAIT; // Probabilities too low
      }
      else
      {
         if(ctx.TrendRegime == 1 || ctx.StructureState == STRUCT_STATE_BULLISH)
         {
            decision = DECISION_BUY;
         }
         else if(ctx.TrendRegime == -1 || ctx.StructureState == STRUCT_STATE_BEARISH)
         {
            decision = DECISION_SELL;
         }
         else
         {
            decision = DECISION_WAIT;
         }
      }

      // 8. Expected Reward/Risk Ratio calculation (base 2.0, scaling with trend strength)
      double expectedRR = 2.0;
      if(ctx.TrendRegime != 0)
      {
         expectedRR = 2.0 + (ctx.ContextConfidence / 100.0) * 1.0; // Scale 2.0 up to 3.0
      }
      else if(ctx.MarketRegime == REGIME_RANGING)
      {
         expectedRR = 1.5; // range fade has lower target RR
      }

      // 9. Trade Confidence
      ENUM_TRADE_CONFIDENCE tradeConfidence = TRADE_CONF_LOW;
      if(tradeProb >= 75.0) tradeConfidence = TRADE_CONF_HIGH;
      else if(tradeProb >= 60.0) tradeConfidence = TRADE_CONF_MEDIUM;

      // 10. Generate Narrative
      string regimeName = (ctx.MarketRegime == REGIME_TRENDING) ? "Trending" : 
                          ((ctx.MarketRegime == REGIME_RANGING) ? "Ranging" : 
                           ((ctx.MarketRegime == REGIME_BREAKOUT) ? "Breakout" : 
                            ((ctx.MarketRegime == REGIME_REVERSAL) ? "Reversal" : 
                             ((ctx.MarketRegime == REGIME_COMPRESSION) ? "Compression" : 
                              ((ctx.MarketRegime == REGIME_EXPANSION) ? "Expansion" : "Transition")))));

      string confStr = (tradeConfidence == TRADE_CONF_HIGH) ? "HIGH" : 
                       ((tradeConfidence == TRADE_CONF_MEDIUM) ? "MEDIUM" : "LOW");

      string narrative = StringFormat(
         "Market is %s.\n"
         "Trade Probability = %.1f%%.\n"
         "Expected RR = %.1f.\n"
         "Trade Confidence = %s.\n"
         "Decision = %s.",
         regimeName,
         tradeProb,
         expectedRR,
         confStr,
         GetDecisionStr(decision)
      );

      // 11. Populate decision context structure
      m_decisionCtx.TradeProbability      = tradeProb;
      m_decisionCtx.TrendContinuationProb = continuationProb;
      m_decisionCtx.ReversalProb          = reversalProb;
      m_decisionCtx.BreakoutProb          = breakoutProb;
      m_decisionCtx.RangeProb             = rangeProb;
      m_decisionCtx.ExpectedRR            = expectedRR;
      m_decisionCtx.TradeConfidence       = tradeConfidence;
      m_decisionCtx.Decision              = decision;
      m_decisionCtx.Reason                = narrative;
   }

   /**
    * @brief Returns current context.
    */
   virtual DecisionContext GetDecisionContext() const override
   {
      return m_decisionCtx;
   }
};

#endif // GOLDENGINEV2_DECISION_ENGINE_MQH
