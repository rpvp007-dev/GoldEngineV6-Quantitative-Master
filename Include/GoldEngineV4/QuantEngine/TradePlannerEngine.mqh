//+------------------------------------------------------------------+
//|                                         TradePlannerEngine.mqh   |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_TRADE_PLANNER_ENGINE_MQH
#define GOLDENGINEV2_TRADE_PLANNER_ENGINE_MQH

#include "ITradePlannerEngine.mqh"
#include "IOpportunityEngine.mqh"
#include "IMovementEngine.mqh"
#include "IMarketIntentEngine.mqh"
#include "../Strategy/IStrategy.mqh" // Full QuantEnginesContainer definition
#include "../Core/Config.mqh"
#include "../Core/Logger.mqh"

//+------------------------------------------------------------------+
//| Concrete Trade Planner Engine implementation                     |
//+------------------------------------------------------------------+
class CTradePlannerEngine : public ITradePlannerEngine
{
private:
   CLogger*                   m_logger;
   CConfig*                   m_config;
   TradePlanContext           m_context;
   bool                       m_isInitialized;

   // Cached engine references
   IOpportunityEngine*        m_opportunity;
   IMovementEngine*           m_movement;
   IMarketIntentEngine*       m_intent;
   IDecisionEngine*           m_decision;
   IVolatilityEngine*         m_volatility;
   IMarketStructureEngine*    m_structure;
   ITrendEngine*              m_trendEngine; // V5.5: Added for direction confirmation

   /**
    * @brief Helper to convert Execution Mode to string.
    */
   string ModeToString(ENUM_EXECUTION_MODE mode) const
   {
      switch(mode)
      {
         case MODE_AVOID:    return "Avoid";
         case MODE_PROBE:    return "Probe";
         case MODE_SCALP:    return "Scalp";
         case MODE_MOMENTUM: return "Momentum";
         case MODE_RUNNER:   return "Runner";
         default:            return "Unknown";
      }
   }

   /**
    * @brief Helper to convert Direction Recommendation to string.
    */
   string DirectionToString(ENUM_TRADE_DIRECTION_REC dir) const
   {
      switch(dir)
      {
         case REC_DIR_BUY:  return "Buy";
         case REC_DIR_SELL: return "Sell";
         case REC_DIR_NONE: return "None";
         default:           return "Unknown";
      }
   }

public:
   /**
    * @brief Constructor.
    */
   CTradePlannerEngine(CLogger* logger, CConfig* config)
      : m_logger(logger),
        m_config(config),
        m_isInitialized(false),
        m_opportunity(NULL),
        m_movement(NULL),
        m_intent(NULL),
        m_decision(NULL),
        m_volatility(NULL),
        m_structure(NULL),
        m_trendEngine(NULL) // V5.5
   {
      // Reset context
      m_context.DirectionRec = REC_DIR_NONE;
      m_context.ExecutionMode = MODE_AVOID;
      m_context.ExpectedMove = 0.0;
      m_context.ExpectedHoldingTime = 0.0;
      m_context.HoldingTimeUnit = HOLD_MINUTES;
      m_context.EntryQuality = 0.0;
      m_context.RecEntryZoneStart = 0.0;
      m_context.RecEntryZoneEnd = 0.0;
      m_context.RecStopZoneStart = 0.0;
      m_context.RecStopZoneEnd = 0.0;
      m_context.RecProfitZoneStart = 0.0;
      m_context.RecProfitZoneEnd = 0.0;
      m_context.RecPartialExitPrice = 0.0;
      m_context.RecTrailActivationPrice = 0.0;
      m_context.ExpectedRisk = 0.0;
      m_context.ExpectedReward = 0.0;
      m_context.ExpectedRR = 1.0;
      m_context.TradeConfidence = 0.0;
      m_context.TradeNarrative = "Not Initialized";
   }

   /**
    * @brief Destructor.
    */
   ~CTradePlannerEngine() {}

   /**
    * @brief Initializes engine with container references to other engines.
    */
   virtual bool Initialize(const QuantEnginesContainer &engines) override
   {
      m_opportunity = engines.Opportunity;
      m_movement    = engines.Movement;
      m_intent      = engines.Intent;
      m_decision    = engines.Decision;
      m_volatility  = engines.Volatility;
      m_structure   = engines.MarketStructure;
      m_trendEngine = engines.Trend; // V5.5: resolve trend reference

      if(m_opportunity == NULL || m_movement == NULL || m_intent == NULL ||
         m_decision == NULL || m_volatility == NULL || m_structure == NULL)
      {
         m_logger.Error("Trade Planner Engine: Failed to resolve core engines references.");
         m_isInitialized = false;
         return false;
      }

      m_isInitialized = true;
      m_logger.Info("Trade Planner Engine: Initialized successfully.");
      return true;
   }

   /**
    * @brief Updates trade planning context for the closed candle.
    */
   virtual void UpdatePlan(const string symbol, ENUM_TIMEFRAMES tf) override
   {
      if(!m_isInitialized) return;

      // Extract Context data from other engines
      OpportunityContext oppCtx = m_opportunity.GetOpportunityContext();
      MovementContext movCtx = m_movement.GetMovementContext();
      MarketIntentContext intentCtx = m_intent.GetMarketIntentContext();
      DecisionContext decCtx = m_decision.GetDecisionContext();

      double closePrice = iClose(symbol, tf, 1);
      double atr = m_volatility.GetATR(symbol, tf, 14, 1);
      if(atr <= 0.0) atr = SymbolInfoDouble(symbol, SYMBOL_POINT) * 10.0;

      // 1. Determine Trade Direction Recommendation
      // V5.5: Require trend alignment in addition to intent alignment
      // This prevents BUY signals being generated into confirmed bearish trends
      ENUM_TRADE_DIRECTION_REC dir = REC_DIR_NONE;
      int trendDir = (m_trendEngine != NULL) ? m_trendEngine.GetTrendDirection(symbol, tf) : 0;

      if(decCtx.Decision == DECISION_BUY && intentCtx.BuyerIntent > intentCtx.SellerIntent)
      {
         // V5.5: Only confirm BUY if trend is not confirmed bearish (trendDir >= 0)
         // If trend is -1 (confirmed bear), this remains REC_DIR_NONE (incurs -10 score penalty in X001)
         if(trendDir >= 0)
            dir = REC_DIR_BUY;
         // trendDir == -1: leave as REC_DIR_NONE — counter-trend BUY needs exceptional score to execute
      }
      else if(decCtx.Decision == DECISION_SELL && intentCtx.SellerIntent > intentCtx.BuyerIntent)
      {
         // V5.5: Only confirm SELL if trend is not confirmed bullish (trendDir <= 0)
         if(trendDir <= 0)
            dir = REC_DIR_SELL;
         // trendDir == 1: leave as REC_DIR_NONE — counter-trend SELL needs exceptional score
      }

      // 2. Select Execution Mode
      ENUM_EXECUTION_MODE mode = MODE_AVOID;
      if(oppCtx.OpportunityScore >= 30.0)
      {
         if(oppCtx.OpportunityScore >= 70.0)
         {
            if(intentCtx.ContinuationProb >= 70.0) mode = MODE_RUNNER;
            else                                  mode = MODE_SCALP;
         }
         else if(oppCtx.OpportunityScore >= 50.0)
         {
            if(intentCtx.BuyerIntent >= 75.0 || intentCtx.SellerIntent >= 75.0) mode = MODE_MOMENTUM;
            else                                                               mode = MODE_SCALP;
         }
         else
         {
            mode = MODE_PROBE;
         }
      }

      // 3. Plan Expected Move & Holding Time Duration
      double expectedMove = oppCtx.ExpectedMove;
      double holdingTime = 0.0;
      ENUM_HOLDING_TIME_UNIT timeUnit = HOLD_MINUTES;

      if(mode == MODE_SCALP)
      {
         holdingTime = 15.0; // 15 mins
         timeUnit = HOLD_MINUTES;
         if(expectedMove < 50.0)  expectedMove = 50.0;  // 5 points minimum
         if(expectedMove > 100.0) expectedMove = 100.0; // 10 points maximum
      }
      else if(mode == MODE_PROBE)
      {
         holdingTime = 5.0;
         timeUnit = HOLD_MINUTES;
         expectedMove = 30.0; // 3 points target
      }
      else if(mode == MODE_MOMENTUM)
      {
         holdingTime = 45.0;
         timeUnit = HOLD_MINUTES;
      }
      else if(mode == MODE_RUNNER)
      {
         holdingTime = 2.0;
         timeUnit = HOLD_HOURS;
         // Scale targets if continuation probability is high
         if(intentCtx.ContinuationProb >= 85.0 && expectedMove > 0.0)
         {
            expectedMove *= 1.5;
         }
      }

      // 4. Calculate Entry Quality
      double entryQuality = oppCtx.ExpectedReward > 0.0 ? oppCtx.ExpectedReward : 50.0;

      // 5. Entry Zone Planning
      double entryStart = 0.0;
      double entryEnd = 0.0;
      if(dir == REC_DIR_BUY)
      {
         entryStart = closePrice - 0.2 * atr;
         entryEnd = closePrice + 0.1 * atr;
      }
      else if(dir == REC_DIR_SELL)
      {
         entryStart = closePrice - 0.1 * atr;
         entryEnd = closePrice + 0.2 * atr;
      }

      // 6. Stop Zone Planning
      double sl = 0.0;
      double stopStart = 0.0;
      double stopEnd = 0.0;
      double swingHigh = m_structure.GetLastSwingHighPrice();
      double swingLow = m_structure.GetLastSwingLowPrice();

      if(dir == REC_DIR_BUY)
      {
         sl = (swingLow > 0.0 && swingLow < closePrice) ? swingLow - 0.1 * atr : closePrice - 1.5 * atr;
         stopStart = sl - 0.2 * atr;
         stopEnd = sl;
      }
      else if(dir == REC_DIR_SELL)
      {
         sl = (swingHigh > 0.0 && swingHigh > closePrice) ? swingHigh + 0.1 * atr : closePrice + 1.5 * atr;
         stopStart = sl;
         stopEnd = sl + 0.2 * atr;
      }

      // 7. Profit Zone Planning
      double tp = 0.0;
      double profitStart = 0.0;
      double profitEnd = 0.0;

      if(dir == REC_DIR_BUY)
      {
         tp = closePrice + expectedMove;
         profitStart = tp - 0.2 * atr;
         profitEnd = tp + 0.2 * atr;
      }
      else if(dir == REC_DIR_SELL)
      {
         tp = closePrice - expectedMove;
         profitStart = tp - 0.2 * atr;
         profitEnd = tp + 0.2 * atr;
      }

      // 8. Partial Exit & Trail Activation
      double partialExit = 0.0;
      double trailActivation = 0.0;
      if(dir == REC_DIR_BUY)
      {
         partialExit = closePrice + 0.5 * expectedMove;
         trailActivation = closePrice + 1.0 * atr;
      }
      else if(dir == REC_DIR_SELL)
      {
         partialExit = closePrice - 0.5 * expectedMove;
         trailActivation = closePrice - 1.0 * atr;
      }

      // 9. Risk / Reward metrics
      double expRisk = MathAbs(closePrice - sl);
      double expReward = MathAbs(closePrice - tp);
      double rr = (expRisk > 0.0) ? expReward / expRisk : 1.0;

      // 10. Trade Confidence
      double confidence = 0.6 * oppCtx.OpportunityScore + 0.4 * intentCtx.MarketCommitmentScore;
      if(confidence > 100.0) confidence = 100.0;
      if(confidence < 0.0)  confidence = 0.0;

      // Save Context
      m_context.DirectionRec = dir;
      m_context.ExecutionMode = mode;
      m_context.ExpectedMove = expectedMove;
      m_context.ExpectedHoldingTime = holdingTime;
      m_context.HoldingTimeUnit = timeUnit;
      m_context.EntryQuality = entryQuality;
      m_context.RecEntryZoneStart = entryStart;
      m_context.RecEntryZoneEnd = entryEnd;
      m_context.RecStopZoneStart = stopStart;
      m_context.RecStopZoneEnd = stopEnd;
      m_context.RecProfitZoneStart = profitStart;
      m_context.RecProfitZoneEnd = profitEnd;
      m_context.RecPartialExitPrice = partialExit;
      m_context.RecTrailActivationPrice = trailActivation;
      m_context.ExpectedRisk = expRisk;
      m_context.ExpectedReward = expReward;
      m_context.ExpectedRR = rr;
      m_context.TradeConfidence = confidence;

      // Narrative representation
      string dirStr = DirectionToString(dir);
      string modeStr = ModeToString(mode);
      string unitStr = (timeUnit == HOLD_HOURS) ? "hours" : "mins";
      
      m_context.TradeNarrative = StringFormat(
         "Plan: %s %s | Target: %.1f pts | Time: %.0f %s | RR: %.2f | Stop: %.2f | Entry Quality: %.1f%%",
         modeStr, dirStr, expectedMove, holdingTime, unitStr, rr, sl, entryQuality
      );

      m_logger.Debug("Trade Planner Engine: Update Plan context: " + m_context.TradeNarrative);
   }

   /**
    * @brief Retrieves the calculated trade plan context data.
    */
   virtual TradePlanContext GetTradePlanContext() const override
   {
      return m_context;
   }
};

#endif // GOLDENGINEV2_TRADE_PLANNER_ENGINE_MQH
