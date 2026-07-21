//+------------------------------------------------------------------+
//|                                            OpportunityEngine.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_OPPORTUNITY_ENGINE_MQH
#define GOLDENGINEV2_OPPORTUNITY_ENGINE_MQH

#include "IOpportunityEngine.mqh"
#include "IMovementEngine.mqh"
#include "IMarketIntentEngine.mqh"
#include "../Strategy/IStrategy.mqh" // Full QuantEnginesContainer definition
#include "../Core/Config.mqh"
#include "../Core/Logger.mqh"

//+------------------------------------------------------------------+
//| Concrete Opportunity Engine implementation                       |
//+------------------------------------------------------------------+
class COpportunityEngine : public IOpportunityEngine
{
private:
   CConfig*                   m_config;
   CLogger*                   m_logger;
   OpportunityContext         m_context;
   bool                       m_isInitialized;

   // Cached engine references
   ITrendEngine*              m_trend;
   IMomentumEngine*           m_momentum;
   IVolatilityEngine*         m_volatility;
   IVolumeEngine*             m_volume;
   IMarketStructureEngine*    m_structure;
   IMarketContextEngine*      m_marketContext;
   IDecisionEngine*           m_decision;
   IMovementEngine*           m_movement;
   IMarketIntentEngine*       m_intent;

   /**
    * @brief Helper to convert Opportunity Class to string.
    */
   string ClassToString(ENUM_OPPORTUNITY_CLASS cls) const
   {
      switch(cls)
      {
         case OPPORTUNITY_CLASS_VERY_LOW: return "Very Low";
         case OPPORTUNITY_CLASS_LOW:      return "Low";
         case OPPORTUNITY_CLASS_MEDIUM:   return "Medium";
         case OPPORTUNITY_CLASS_HIGH:     return "High";
         case OPPORTUNITY_CLASS_EXTREME:  return "Extreme";
         default:                         return "Unknown";
      }
   }

public:
   /**
    * @brief Constructor.
    */
   COpportunityEngine(CLogger* logger, CConfig* config)
      : m_logger(logger),
        m_config(config),
        m_isInitialized(false),
        m_trend(NULL),
        m_momentum(NULL),
        m_volatility(NULL),
        m_volume(NULL),
        m_structure(NULL),
        m_marketContext(NULL),
        m_decision(NULL),
        m_movement(NULL),
        m_intent(NULL)
   {
      // Reset context
      m_context.OpportunityScore = 0.0;
      m_context.OpportunityClass = OPPORTUNITY_CLASS_VERY_LOW;
      m_context.ExpectedMove = 0.0;
      m_context.ExpectedRisk = 0.0;
      m_context.ExpectedReward = 0.0;
      m_context.ExpectedRR = 1.0;
      m_context.TradeWindow = TRADE_WINDOW_NO_TRADE;
      m_context.OpportunityNarrative = "Not Initialized";
      m_context.ScalpRec = SCALP_RECOMMENDATION_AVOID;
      m_context.RunnerRec = SCALP_RECOMMENDATION_AVOID;
   }

   /**
    * @brief Destructor.
    */
   ~COpportunityEngine() {}

   /**
    * @brief Initializes engine with container references to other engines.
    */
   virtual bool Initialize(const QuantEnginesContainer &engines) override
   {
      m_trend         = engines.Trend;
      m_momentum      = engines.Momentum;
      m_volatility    = engines.Volatility;
      m_volume        = engines.Volume;
      m_structure     = engines.MarketStructure;
      m_marketContext = engines.MarketContext;
      m_decision      = engines.Decision;
      m_movement      = engines.Movement;
      m_intent        = engines.Intent;

      if(m_trend == NULL || m_momentum == NULL || m_volatility == NULL ||
         m_volume == NULL || m_structure == NULL || m_marketContext == NULL || m_decision == NULL || m_movement == NULL || m_intent == NULL)
      {
         m_logger.Error("Opportunity Engine: Failed to resolve core engines references.");
         m_isInitialized = false;
         return false;
      }

      m_isInitialized = true;
      m_logger.Info("Opportunity Engine: Initialized successfully.");
      return true;
   }

   /**
    * @brief Updates opportunity calculations for the closed candle (shift=1).
    */
   virtual void UpdateOpportunity(const string symbol, ENUM_TIMEFRAMES tf) override
   {
      if(!m_isInitialized) return;

      // 1. Retrieve Movement Score (M) from Movement Engine
      double M = 0.0;
      if(m_movement != NULL)
      {
         M = m_movement.GetMovementContext().MovementScore;
      }

      // 2. Calculate Market Pressure Score (P)
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      int copied = CopyRates(symbol, tf, 1, 5, rates);
      double num = 0.0;
      double den = 0.0;
      if(copied > 0)
      {
         for(int i = 0; i < copied; i++)
         {
            double body = rates[i].close - rates[i].open;
            double range = rates[i].high - rates[i].low;
            double volume = (double)rates[i].tick_volume;
            num += body * volume;
            den += range * volume;
         }
      }
      double P = 50.0;
      if(den > 0.0)
      {
         P = 50.0 + 50.0 * (num / den);
      }
      if(P > 100.0) P = 100.0;
      if(P < 0.0) P = 0.0;

      // 3. Calculate Entry Quality (EQ)
      double sLive = (double)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
      double sMax = (double)m_config.GetMaximumSpreadPoints();
      if(sMax <= 0) sMax = 35.0;
      double spreadFactor = 1.0 - (sLive / sMax);
      if(spreadFactor < 0.0) spreadFactor = 0.0;

      double rAvg = m_volatility.GetAverageCandleSize(symbol, tf, 14);
      if(rAvg <= 0) rAvg = SymbolInfoDouble(symbol, SYMBOL_POINT) * 100;

      double closePrice = SymbolInfoDouble(symbol, SYMBOL_BID);
      double swingHigh = m_structure.GetLastSwingHighPrice();
      double swingLow = m_structure.GetLastSwingLowPrice();

      double dPivot = rAvg;
      if(swingHigh > 0 && swingLow > 0)
      {
         double dHigh = MathAbs(closePrice - swingHigh);
         double dLow = MathAbs(closePrice - swingLow);
         dPivot = MathMin(dHigh, dLow);
      }
      double pivotFactor = dPivot / rAvg;
      if(pivotFactor > 1.0) pivotFactor = 1.0;

      double EQ = 100.0 * spreadFactor * pivotFactor;
      if(EQ > 100.0) EQ = 100.0;
      if(EQ < 0.0) EQ = 0.0;

      // 4. Calculate Exit Quality (ExQ) Consuming ContinuationFuel
      double revProb = m_decision.GetDecisionContext().ReversalProb;
      double momentumAccel = m_momentum.GetMomentumAcceleration();
      double aDecay = (momentumAccel < 0.0) ? MathAbs(momentumAccel) * 100.0 : 0.0;
      if(aDecay > 100.0) aDecay = 100.0;
      
      double fuel = 50.0;
      if(m_intent != NULL)
      {
         fuel = m_intent.GetMarketIntentContext().ContinuationFuel;
      }
      
      double ExQ = 0.4 * (100.0 - aDecay) + 0.4 * (100.0 - revProb) + 0.2 * fuel;
      if(ExQ > 100.0) ExQ = 100.0;
      if(ExQ < 0.0) ExQ = 0.0;

      // 5. Calculate Scalping Confidence (SC)
      double g_M = MathExp(-0.5 * MathPow((M - 65.0) / 25.0, 2.0));
      double h_EQ = EQ / 100.0;
      double f_P = 0.5 + 0.5 * (MathAbs(P - 50.0) / 50.0);
      double SC = 100.0 * g_M * h_EQ * f_P;
      if(SC > 100.0) SC = 100.0;
      if(SC < 0.0) SC = 0.0;

      // 6. Calculate Runner Confidence (RC)
      double alignHTF = m_trend.GetEmaAlignmentConfidence(symbol, PERIOD_H1) / 100.0;
      double volExp = m_volume.GetRelativeVolume() / 1.5;
      if(volExp > 1.0) volExp = 1.0;
      if(volExp < 0.0) volExp = 0.0;
      double RC = SC * alignHTF * volExp;
      if(RC > 100.0) RC = 100.0;
      if(RC < 0.0) RC = 0.0;

      // 7. Composite Opportunity Score (O)
      double O = 0.5 * SC + 0.2 * RC + 0.3 * EQ;
      if(O > 100.0) O = 100.0;
      if(O < 0.0) O = 0.0;

      m_context.OpportunityScore = O;

      // Classify Opportunity Classes
      if(O < 20.0)      m_context.OpportunityClass = OPPORTUNITY_CLASS_VERY_LOW;
      else if(O < 40.0) m_context.OpportunityClass = OPPORTUNITY_CLASS_LOW;
      else if(O < 65.0) m_context.OpportunityClass = OPPORTUNITY_CLASS_MEDIUM;
      else if(O < 85.0) m_context.OpportunityClass = OPPORTUNITY_CLASS_HIGH;
      else              m_context.OpportunityClass = OPPORTUNITY_CLASS_EXTREME;

      // Classify Trade Window
      if(O < 20.0)      m_context.TradeWindow = TRADE_WINDOW_NO_TRADE;
      else if(O < 40.0) m_context.TradeWindow = TRADE_WINDOW_VERY_SHORT;
      else if(O < 65.0) m_context.TradeWindow = TRADE_WINDOW_SHORT;
      else if(O < 85.0) m_context.TradeWindow = TRADE_WINDOW_MEDIUM;
      else              m_context.TradeWindow = TRADE_WINDOW_LONG;

      // Estimate Expected Move (in points)
      double pt = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(pt <= 0.0) pt = 0.01;
      double atrLive = m_volatility.GetATR(symbol, tf, 14, 1);
      m_context.ExpectedMove = atrLive / pt;
      m_context.ExpectedRisk = (atrLive * 1.5) / pt;
      m_context.ExpectedReward = m_context.ExpectedMove;
      m_context.ExpectedRR = (m_context.ExpectedRisk > 0.0) ? (m_context.ExpectedReward / m_context.ExpectedRisk) : 1.0;
      m_context.EntryQuality = EQ;
      m_context.ExitQuality = ExQ;

      // Scalp & Runner Recommendations
      if(O < 40.0)       m_context.ScalpRec = SCALP_RECOMMENDATION_AVOID;
      else if(O < 65.0)  m_context.ScalpRec = SCALP_RECOMMENDATION_SCALP;
      else if(O < 85.0)  m_context.ScalpRec = SCALP_RECOMMENDATION_NORMAL;
      else               m_context.ScalpRec = SCALP_RECOMMENDATION_RUNNER;

      if(RC < 40.0)      m_context.RunnerRec = SCALP_RECOMMENDATION_AVOID;
      else if(RC < 60.0) m_context.RunnerRec = SCALP_RECOMMENDATION_SCALP;
      else if(RC < 80.0) m_context.RunnerRec = SCALP_RECOMMENDATION_NORMAL;
      else               m_context.RunnerRec = SCALP_RECOMMENDATION_RUNNER;

      // Build Opportunity Narrative
      string oppClassStr = ClassToString(m_context.OpportunityClass);
      string movementRegime = m_volatility.GetVolatilityRegime(symbol, tf);
      m_context.OpportunityNarrative = StringFormat(
         "Opp Score: %.1f (%s) | Movement M=%.1f (%s) | Pressure P=%.1f | Entry EQ=%.1f | Exit ExQ=%.1f | ScalpRec=%d",
         O, oppClassStr, M, movementRegime, P, EQ, ExQ, m_context.ScalpRec
      );

      m_logger.Debug("Opportunity Engine: Updated context: " + m_context.OpportunityNarrative);
   }

   /**
    * @brief Retrieves the calculated opportunity context data.
    */
   virtual OpportunityContext GetOpportunityContext() const override
   {
      return m_context;
   }
};

#endif // GOLDENGINEV2_OPPORTUNITY_ENGINE_MQH
