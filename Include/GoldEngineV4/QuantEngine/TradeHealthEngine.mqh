//+------------------------------------------------------------------+
//|                                            TradeHealthEngine.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_TRADE_HEALTH_ENGINE_MQH
#define GOLDENGINEV2_TRADE_HEALTH_ENGINE_MQH

#include "ITradeHealthEngine.mqh"
#include "../QuantEngine/IOpportunityEngine.mqh"
#include "../QuantEngine/IMovementEngine.mqh"
#include "../QuantEngine/IMarketIntentEngine.mqh"

//--- Concrete implementation of Trade Health Evaluation Engine
class CTradeHealthEngine : public ITradeHealthEngine
{
private:
   ITrendEngine*              m_trend;
   IMomentumEngine*           m_momentum;
   IVolatilityEngine*         m_volatility;
   IVolumeEngine*             m_volume;
   IVwapEngine*               m_vwap;
   ILiquidityEngine*          m_liquidity;
   IPatternEngine*            m_pattern;
   ISessionEngine*            m_session;
   IMarketStructureEngine*    m_structure;
   IOpportunityEngine*        m_opportunity;
   IMovementEngine*           m_movement;
   IMarketIntentEngine*       m_intent;

   bool                       m_isInitialized;

public:
   /**
    * @brief Constructor.
    */
   CTradeHealthEngine()
      : m_trend(NULL), m_momentum(NULL), m_volatility(NULL), m_volume(NULL),
        m_vwap(NULL), m_liquidity(NULL), m_pattern(NULL), m_session(NULL),
        m_structure(NULL), m_opportunity(NULL), m_movement(NULL), m_intent(NULL),
        m_isInitialized(false)
   {}

   /**
    * @brief Destructor.
    */
   virtual ~CTradeHealthEngine() {}

   /**
    * @brief Initializer.
    */
   virtual bool Initialize(const QuantEnginesContainer &engines) override
   {
      m_trend        = engines.Trend;
      m_momentum     = engines.Momentum;
      m_volatility   = engines.Volatility;
      m_volume       = engines.Volume;
      m_vwap         = engines.Vwap;
      m_liquidity    = engines.Liquidity;
      m_pattern      = engines.Pattern;
      m_session      = engines.Session;
      m_structure    = engines.MarketStructure;
      m_opportunity  = engines.Opportunity;
      m_movement     = engines.Movement;
      m_intent       = engines.Intent;

      m_isInitialized = (m_trend != NULL && m_momentum != NULL && m_volatility != NULL &&
                         m_volume != NULL && m_liquidity != NULL && m_structure != NULL);
      
      return m_isInitialized;
   }

   /**
    * @brief Dynamically calculates trade health.
    */
   virtual TradeHealthContext EvaluateTradeHealth(
      ulong ticket, 
      double currentProfitPoints, 
      double mfe, 
      double mae, 
      int durationSec
   ) override
   {
      TradeHealthContext context;
      context.HealthScore = 0.0;
      context.HealthState = HEALTH_CRITICAL;
      context.HealthNarrative = "Engine offline.";

      if(!m_isInitialized) return context;

      // Select position
      if(!PositionSelectByTicket(ticket))
      {
         context.HealthNarrative = "Position not found.";
         return context;
      }

      string symbol = PositionGetString(POSITION_SYMBOL);
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool isBuy = (type == POSITION_TYPE_BUY);

      double score = 0.0;

      // 1. Trend Alignment (Max 10 pts)
      int trendDir = m_trend.GetTrendDirection(symbol, Period());
      if((isBuy && trendDir == 1) || (!isBuy && trendDir == -1))
      {
         score += 10.0;
      }
      else if(trendDir == 0)
      {
         score += 5.0; // neutral
      }

      // 2. Momentum Strength (Max 10 pts)
      double momScore = m_momentum.GetMomentumScore();
      string momDesc = m_momentum.GetMomentumDirectionDesc();
      if(momScore >= 60.0)
      {
         if((isBuy && momDesc == "Increasing") || (!isBuy && momDesc == "Decreasing"))
            score += 10.0;
         else
            score += 7.0;
      }
      else if(momScore >= 40.0)
      {
         score += 5.0;
      }
      else
      {
         score += 2.0;
      }

      // 3. Movement Score (Max 10 pts)
      double moveScore = 0.0;
      if(m_movement != NULL)
      {
         moveScore = m_movement.GetMovementContext().MovementScore;
      }
      score += MathMin(10.0, moveScore * 0.1);

      // 4. Opportunity Score (Max 10 pts)
      double oppScore = 0.0;
      if(m_opportunity != NULL)
      {
         oppScore = m_opportunity.GetOpportunityContext().OpportunityScore;
      }
      score += MathMin(10.0, oppScore * 0.1);

      // 5. Market Intent Alignment (Max 10 pts)
      double buyerInt = 0.0, sellerInt = 0.0;
      if(m_intent != NULL)
      {
         buyerInt = m_intent.GetMarketIntentContext().BuyerIntent;
         sellerInt = m_intent.GetMarketIntentContext().SellerIntent;
      }
      if(isBuy)
      {
         if(buyerInt > sellerInt) score += 10.0;
         else if(MathAbs(buyerInt - sellerInt) < 2.0) score += 5.0;
         else score += 1.0;
      }
      else
      {
         if(sellerInt > buyerInt) score += 10.0;
         else if(MathAbs(buyerInt - sellerInt) < 2.0) score += 5.0;
         else score += 1.0;
      }

      // 6. Volume Quality (Max 10 pts)
      double rvol = m_volume.GetRelativeVolume();
      if(rvol >= 1.2) score += 10.0;
      else if(rvol >= 0.8) score += 7.0;
      else score += 4.0;

      // 7. Volatility Quality (Max 10 pts)
      string voltRegime = m_volatility.GetVolatilityRegime(symbol, Period());
      if(voltRegime == "Normal" || voltRegime == "Low") score += 10.0;
      else if(voltRegime == "High") score += 6.0;
      else score += 2.0; // Extreme volatility increases risk of whipsaw

      // 8. Structure Integrity (Max 10 pts)
      string structState = m_structure.GetStructureState();
      if(isBuy)
      {
         if(structState == "Bullish") score += 10.0;
         else if(structState == "Range" || structState == "Transition") score += 6.0;
         else score += 2.0;
      }
      else
      {
         if(structState == "Bearish") score += 10.0;
         else if(structState == "Range" || structState == "Transition") score += 6.0;
         else score += 2.0;
      }

      // 9. Liquidity Quality (Max 10 pts)
      double liqStrength = m_liquidity.GetLiquidityStrength();
      bool sweepBuy = false, sweepSell = false;
      bool isSweep = m_liquidity.IsLiquiditySweep(sweepBuy, sweepSell);
      if(isSweep)
      {
         // Sweep in our trade direction is highly positive
         if((isBuy && sweepSell) || (!isBuy && sweepBuy)) score += 10.0;
         else score += 2.0; // Sweep in adverse direction is critical threat
      }
      else
      {
         if(liqStrength >= 50.0) score += 8.0;
         else score += 5.0;
      }

      // 10. Profit & Excursion Behavior (Max 10 pts)
      if(currentProfitPoints > 0)
      {
         if(currentProfitPoints >= 50.0) score += 10.0;
         else score += 8.0;
      }
      else
      {
         if(mae <= 30.0) score += 5.0;
         else if(mae <= 80.0) score += 2.0;
         else score += 0.0;
      }

      // Trade Age Penalty (Max -10 pts)
      double agePenalty = 0.0;
      if(durationSec > 1800) agePenalty = 10.0;
      else if(durationSec > 900) agePenalty = 7.0;
      else if(durationSec > 300) agePenalty = 3.0;
      score = MathMax(0.0, score - agePenalty);

      // Deep Drawdown Penalty
      double atr = m_volatility.GetATR(symbol, Period(), 14, 1);
      if(atr > 0 && mae > (atr * 1.5 * 10.0)) // convert ATR to points if needed, ATR is in price units
      {
         score = MathMax(0.0, score - 15.0);
      }

      // Clamp score
      context.HealthScore = MathMin(100.0, MathMax(0.0, score));

      // Classify state
      if(context.HealthScore >= 85.0) context.HealthState = HEALTH_EXCELLENT;
      else if(context.HealthScore >= 70.0) context.HealthState = HEALTH_HEALTHY;
      else if(context.HealthScore >= 55.0) context.HealthState = HEALTH_STABLE;
      else if(context.HealthScore >= 40.0) context.HealthState = HEALTH_WEAKENING;
      else if(context.HealthScore >= 25.0) context.HealthState = HEALTH_DANGER;
      else context.HealthState = HEALTH_CRITICAL;

      // Classify dynamic explanation narrative
      if(context.HealthState == HEALTH_EXCELLENT)
      {
         context.HealthNarrative = "Trend aligned, strong continuation momentum.";
      }
      else if(context.HealthState == HEALTH_HEALTHY)
      {
         if(currentProfitPoints < 0)
            context.HealthNarrative = "Healthy pullback, trend remains intact.";
         else
            context.HealthNarrative = "Healthy trend expansion, volume stable.";
      }
      else if(context.HealthState == HEALTH_STABLE)
      {
         context.HealthNarrative = "Stable consolidation, momentum flat.";
      }
      else if(context.HealthState == HEALTH_WEAKENING)
      {
         if(isSweep && ((isBuy && sweepBuy) || (!isBuy && sweepSell)))
            context.HealthNarrative = "Continuation weakening. Swept liquidations detected.";
         else
            context.HealthNarrative = "Pullback deepening, weakening volume support.";
      }
      else if(context.HealthState == HEALTH_DANGER)
      {
         if(isBuy && sellerInt > buyerInt * 1.5)
            context.HealthNarrative = "Buyer exhaustion detected. Sellers building intent.";
         else if(!isBuy && buyerInt > sellerInt * 1.5)
            context.HealthNarrative = "Seller exhaustion detected. Buyers building intent.";
         else
            context.HealthNarrative = "Severe adverse excursion, high trap risk.";
      }
      else
      {
         context.HealthNarrative = "Possible reversal. Stop loss protection recommended.";
      }

      return context;
   }
};

#endif // GOLDENGINEV2_TRADE_HEALTH_ENGINE_MQH
