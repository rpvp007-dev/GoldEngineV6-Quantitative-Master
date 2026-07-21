//+------------------------------------------------------------------+
//|                                           MarketIntentEngine.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_MARKET_INTENT_ENGINE_MQH
#define GOLDENGINEV2_MARKET_INTENT_ENGINE_MQH

#include "IMarketIntentEngine.mqh"
#include "IMovementEngine.mqh"
#include "../Strategy/IStrategy.mqh" // Full QuantEnginesContainer definition
#include "../Core/Config.mqh"
#include "../Core/Logger.mqh"

//+------------------------------------------------------------------+
//| Concrete Market Intent Engine implementation                     |
//+------------------------------------------------------------------+
class CMarketIntentEngine : public IMarketIntentEngine
{
private:
   CLogger*                   m_logger;
   CConfig*                   m_config;
   MarketIntentContext        m_context;
   bool                       m_isInitialized;

   // Cached engine references
   ITrendEngine*              m_trend;
   IMomentumEngine*           m_momentum;
   IVolatilityEngine*         m_volatility;
   IVolumeEngine*             m_volume;
   ILiquidityEngine*          m_liquidity;
   IMarketStructureEngine*    m_structure;
   IDecisionEngine*           m_decision;
   IMovementEngine*           m_movement;

   /**
    * @brief Helper to convert Breakout Authenticity to string.
    */
   string BreakoutToString(ENUM_BREAKOUT_AUTHENTICITY bo) const
   {
      switch(bo)
      {
         case BREAKOUT_REAL:  return "Real";
         case BREAKOUT_WEAK:  return "Weak";
         case BREAKOUT_FALSE: return "False";
         default:             return "Unknown";
      }
   }

   /**
    * @brief Helper to convert Trap Type to string.
    */
   string TrapToString(ENUM_TRAP_TYPE trap) const
   {
      switch(trap)
      {
         case TRAP_BULL:    return "Bull Trap";
         case TRAP_BEAR:    return "Bear Trap";
         case TRAP_NEUTRAL: return "Neutral";
         default:           return "Unknown";
      }
   }

public:
   /**
    * @brief Constructor.
    */
   CMarketIntentEngine(CLogger* logger, CConfig* config)
      : m_logger(logger),
        m_config(config),
        m_isInitialized(false),
        m_trend(NULL),
        m_momentum(NULL),
        m_volatility(NULL),
        m_volume(NULL),
        m_liquidity(NULL),
        m_structure(NULL),
        m_decision(NULL),
        m_movement(NULL)
   {
      // Reset context
      m_context.BuyerIntent = 0.0;
      m_context.SellerIntent = 0.0;
      m_context.ContinuationProb = 0.0;
      m_context.ReversalProb = 0.0;
      m_context.BreakoutAuthenticity = BREAKOUT_WEAK;
      m_context.LiquidityGrabProb = 0.0;
      m_context.TrapType = TRAP_NEUTRAL;
      m_context.TrapProbability = 0.0;
      m_context.MarketCommitment = COMMITMENT_MEDIUM;
      m_context.MarketCommitmentScore = 0.0;
      m_context.ContinuationFuel = 0.0;
      m_context.IntentNarrative = "Not Initialized";
   }

   /**
    * @brief Destructor.
    */
   ~CMarketIntentEngine() {}

   /**
    * @brief Initializes engine with container references to other engines.
    */
   virtual bool Initialize(const QuantEnginesContainer &engines) override
   {
      m_trend      = engines.Trend;
      m_momentum   = engines.Momentum;
      m_volatility = engines.Volatility;
      m_volume     = engines.Volume;
      m_liquidity  = engines.Liquidity;
      m_structure  = engines.MarketStructure;
      m_decision   = engines.Decision;
      m_movement   = engines.Movement;

      if(m_trend == NULL || m_momentum == NULL || m_volatility == NULL ||
         m_volume == NULL || m_liquidity == NULL || m_structure == NULL || m_decision == NULL || m_movement == NULL)
      {
         m_logger.Error("Market Intent Engine: Failed to resolve core engines references.");
         m_isInitialized = false;
         return false;
      }

      m_isInitialized = true;
      m_logger.Info("Market Intent Engine: Initialized successfully.");
      return true;
   }

   /**
    * @brief Updates intent calculations for the closed candle (shift=1).
    */
   virtual void UpdateIntent(const string symbol, ENUM_TIMEFRAMES tf) override
   {
      if(!m_isInitialized) return;

      // Fetch common variables
      double h = iHigh(symbol, tf, 1);
      double l = iLow(symbol, tf, 1);
      double c = iClose(symbol, tf, 1);
      double range = h - l;
      double closeLoc = (range > 0.0) ? (c - l) / range : 0.5;
      
      double rvol = m_volume.GetRelativeVolume();
      double momScore = m_momentum.GetMomentumScore();
      double atr = m_volatility.GetATR(symbol, tf, 14, 1);
      if(atr <= 0.0) atr = SymbolInfoDouble(symbol, SYMBOL_POINT) * 10.0;

      // 1. Calculate Buyer Intent
      double buyerIntent = (closeLoc * rvol * 50.0) + (momScore * 0.5);
      if(buyerIntent > 100.0) buyerIntent = 100.0;
      if(buyerIntent < 0.0)  buyerIntent = 0.0;

      // 2. Calculate Seller Intent
      double sellerIntent = ((1.0 - closeLoc) * rvol * 50.0) + ((100.0 - momScore) * 0.5);
      if(sellerIntent > 100.0) sellerIntent = 100.0;
      if(sellerIntent < 0.0)  sellerIntent = 0.0;

      // 3. Continuation Probability
      double trendCont = m_decision.GetDecisionContext().TrendContinuationProb;
      double efficiency = m_movement.GetMovementContext().Efficiency;
      double continuationProb = 0.7 * trendCont + 0.3 * efficiency;

      // 4. Reversal Probability
      double decisionRev = m_decision.GetDecisionContext().ReversalProb;
      double exhaustion = m_movement.GetMovementContext().Exhaustion;
      double reversalProb = 0.6 * decisionRev + 0.4 * exhaustion;

      // 5. Breakout Authenticity
      double bbUpper = 0.0, bbMiddle = 0.0, bbLower = 0.0;
      m_volatility.GetBollingerBands(symbol, tf, 20, 2.0, 1, bbUpper, bbMiddle, bbLower);
      bool isUpperBO = (c > bbUpper);
      bool isLowerBO = (c < bbLower);
      
      ENUM_BREAKOUT_AUTHENTICITY breakoutAuthenticity = BREAKOUT_WEAK;
      if(isUpperBO || isLowerBO)
      {
         if(rvol >= 1.5)      breakoutAuthenticity = BREAKOUT_REAL;
         else if(rvol < 0.8)  breakoutAuthenticity = BREAKOUT_FALSE;
         else                 breakoutAuthenticity = BREAKOUT_WEAK;
      }
      else
      {
         double swingHigh = m_structure.GetLastSwingHighPrice();
         double swingLow = m_structure.GetLastSwingLowPrice();
         if(swingHigh > 0.0 && swingLow > 0.0)
         {
            if(c > swingHigh || c < swingLow)
            {
               if(rvol >= 1.5)      breakoutAuthenticity = BREAKOUT_REAL;
               else if(rvol < 0.8)  breakoutAuthenticity = BREAKOUT_FALSE;
               else                 breakoutAuthenticity = BREAKOUT_WEAK;
            }
         }
      }

      // 6. Liquidity Grab Probability
      bool buySweep = false, sellSweep = false;
      m_liquidity.IsLiquiditySweep(buySweep, sellSweep);
      bool stopHunt = m_liquidity.IsStopHuntActive();
      double liqGrabProb = 10.0;
      if(stopHunt || buySweep || sellSweep)
      {
         liqGrabProb = 90.0;
      }
      else if(breakoutAuthenticity == BREAKOUT_FALSE)
      {
         liqGrabProb = 70.0;
      }

      // 7. Trap Probability
      ENUM_TRAP_TYPE trapType = TRAP_NEUTRAL;
      double trapProb = 10.0;
      double swingHighVal = m_structure.GetLastSwingHighPrice();
      double swingLowVal = m_structure.GetLastSwingLowPrice();
      if((c > bbUpper || (swingHighVal > 0.0 && c > swingHighVal)) && breakoutAuthenticity == BREAKOUT_FALSE)
      {
         trapType = TRAP_BULL;
         trapProb = 85.0;
      }
      else if((c < bbLower || (swingLowVal > 0.0 && c < swingLowVal)) && breakoutAuthenticity == BREAKOUT_FALSE)
      {
         trapType = TRAP_BEAR;
         trapProb = 85.0;
      }

      // 8. Market Commitment
      double commitmentScore = rvol * 30.0 + efficiency * 0.7;
      if(commitmentScore > 100.0) commitmentScore = 100.0;
      if(commitmentScore < 0.0)  commitmentScore = 0.0;
      ENUM_MARKET_COMMITMENT marketCommitment = COMMITMENT_MEDIUM;
      if(commitmentScore >= 70.0)      marketCommitment = COMMITMENT_STRONG;
      else if(commitmentScore < 30.0)  marketCommitment = COMMITMENT_WEAK;

      // 9. Continuation Fuel
      double continuationFuel = 100.0 - exhaustion;
      if(continuationFuel > 100.0) continuationFuel = 100.0;
      if(continuationFuel < 0.0)  continuationFuel = 0.0;

      // Populate context
      m_context.BuyerIntent = buyerIntent;
      m_context.SellerIntent = sellerIntent;
      m_context.ContinuationProb = continuationProb;
      m_context.ReversalProb = reversalProb;
      m_context.BreakoutAuthenticity = breakoutAuthenticity;
      m_context.LiquidityGrabProb = liqGrabProb;
      m_context.TrapType = trapType;
      m_context.TrapProbability = trapProb;
      m_context.MarketCommitment = marketCommitment;
      m_context.MarketCommitmentScore = commitmentScore;
      m_context.ContinuationFuel = continuationFuel;

      // Human narrative explainability
      string commitStr = "Medium";
      if(marketCommitment == COMMITMENT_STRONG) commitStr = "Strong";
      if(marketCommitment == COMMITMENT_WEAK)   commitStr = "Weak";
      
      string boStr = BreakoutToString(breakoutAuthenticity);
      string trapStr = TrapToString(trapType);
      
      m_context.IntentNarrative = StringFormat(
         "%s commitment | Buyer Intent %.1f | Seller Intent %.1f | BO=%s | Trap=%s (%.1f%%) | Fuel %.1f%%",
         commitStr, buyerIntent, sellerIntent, boStr, trapStr, trapProb, continuationFuel
      );

      m_logger.Debug("Market Intent Engine: Updated context: " + m_context.IntentNarrative);
   }

   /**
    * @brief Retrieves the calculated intent context data.
    */
   virtual MarketIntentContext GetMarketIntentContext() const override
   {
      return m_context;
   }
};

#endif // GOLDENGINEV2_MARKET_INTENT_ENGINE_MQH
