//+------------------------------------------------------------------+
//|                                             MovementEngine.mqh   |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_MOVEMENT_ENGINE_MQH
#define GOLDENGINEV2_MOVEMENT_ENGINE_MQH

#include "IMovementEngine.mqh"
#include "../Strategy/IStrategy.mqh" // Full QuantEnginesContainer definition
#include "../Core/Config.mqh"
#include "../Core/Logger.mqh"

//+------------------------------------------------------------------+
//| Concrete Movement Intelligence Engine implementation             |
//+------------------------------------------------------------------+
class CMovementEngine : public IMovementEngine
{
private:
   CLogger*                   m_logger;
   CConfig*                   m_config;
   MovementContext            m_context;
   bool                       m_isInitialized;

   // Cached engine references
   ITrendEngine*              m_trend;
   IMomentumEngine*           m_momentum;
   IVolatilityEngine*         m_volatility;
   IVolumeEngine*             m_volume;
   IMarketStructureEngine*    m_structure;

   /**
    * @brief Helper to convert Movement State to string.
    */
   string StateToString(ENUM_MOVEMENT_STATE state) const
   {
      switch(state)
      {
         case MOVEMENT_STATE_DEAD:      return "Dead";
         case MOVEMENT_STATE_SLOW:      return "Slow";
         case MOVEMENT_STATE_HEALTHY:   return "Healthy";
         case MOVEMENT_STATE_FAST:      return "Fast";
         case MOVEMENT_STATE_EXPLOSIVE: return "Explosive";
         default:                       return "Unknown";
      }
   }

   /**
    * @brief Helper to convert Acceleration to string.
    */
   string AccelToString(ENUM_PRICE_ACCELERATION accel) const
   {
      switch(accel)
      {
         case ACCEL_STRONG_NEGATIVE: return "Strong Negative";
         case ACCEL_NEGATIVE:        return "Negative";
         case ACCEL_NEUTRAL:         return "Neutral";
         case ACCEL_POSITIVE:        return "Positive";
         case ACCEL_STRONG_POSITIVE: return "Strong Positive";
         default:                    return "Unknown";
      }
   }

public:
   /**
    * @brief Constructor.
    */
   CMovementEngine(CLogger* logger, CConfig* config)
      : m_logger(logger),
        m_config(config),
        m_isInitialized(false),
        m_trend(NULL),
        m_momentum(NULL),
        m_volatility(NULL),
        m_volume(NULL),
        m_structure(NULL)
   {
      // Reset context
      m_context.MovementScore = 0.0;
      m_context.MovementState = MOVEMENT_STATE_DEAD;
      m_context.Velocity = 0.0;
      m_context.Acceleration = ACCEL_NEUTRAL;
      m_context.Persistence = 0.0;
      m_context.PullbackQuality = PULLBACK_HEALTHY;
      m_context.BreakoutEnergy = 0.0;
      m_context.Compression = 0.0;
      m_context.Expansion = 0.0;
      m_context.Exhaustion = 0.0;
      m_context.Efficiency = 0.0;
      m_context.MovementNarrative = "Not Initialized";
   }

   /**
    * @brief Destructor.
    */
   ~CMovementEngine() {}

   /**
    * @brief Initializes engine with container references to other engines.
    */
   virtual bool Initialize(const QuantEnginesContainer &engines) override
   {
      m_trend      = engines.Trend;
      m_momentum   = engines.Momentum;
      m_volatility = engines.Volatility;
      m_volume     = engines.Volume;
      m_structure  = engines.MarketStructure;

      if(m_trend == NULL || m_momentum == NULL || m_volatility == NULL ||
         m_volume == NULL || m_structure == NULL)
      {
         m_logger.Error("Movement Engine: Failed to resolve core engines references.");
         m_isInitialized = false;
         return false;
      }

      m_isInitialized = true;
      m_logger.Info("Movement Engine: Initialized successfully.");
      return true;
   }

   /**
    * @brief Updates movement calculations for the closed candle (shift=1).
    */
   virtual void UpdateMovement(const string symbol, ENUM_TIMEFRAMES tf) override
   {
      if(!m_isInitialized) return;

      // 1. Calculate Price Velocity
      double atr = m_volatility.GetATR(symbol, tf, 14, 1);
      if(atr <= 0.0) atr = SymbolInfoDouble(symbol, SYMBOL_POINT) * 10.0;
      double c1 = iClose(symbol, tf, 1);
      double c2 = iClose(symbol, tf, 2);
      double velocity = (atr > 0.0) ? (MathAbs(c1 - c2) / atr) * 50.0 : 0.0;
      if(velocity > 100.0) velocity = 100.0;

      // 2. Calculate Price Acceleration
      double r1 = MathAbs(iClose(symbol, tf, 1) - iOpen(symbol, tf, 1));
      double r2 = MathAbs(iClose(symbol, tf, 2) - iOpen(symbol, tf, 2));
      double r3 = MathAbs(iClose(symbol, tf, 3) - iOpen(symbol, tf, 3));
      double diff1 = r1 - r2;
      double diff2 = r2 - r3;
      ENUM_PRICE_ACCELERATION acceleration = ACCEL_NEUTRAL;
      if(diff1 > 0.0 && diff2 > 0.0)      acceleration = ACCEL_STRONG_POSITIVE;
      else if(diff1 > 0.0)               acceleration = ACCEL_POSITIVE;
      else if(diff1 < 0.0 && diff2 < 0.0) acceleration = ACCEL_STRONG_NEGATIVE;
      else if(diff1 < 0.0)               acceleration = ACCEL_NEGATIVE;

      // 3. Directional Persistence
      int buyCount = 0;
      int sellCount = 0;
      for(int i = 1; i <= 7; i++)
      {
         double body = iClose(symbol, tf, i) - iOpen(symbol, tf, i);
         if(body > 0.0) buyCount++;
         if(body < 0.0) sellCount++;
      }
      int dominant = MathMax(buyCount, sellCount);
      double persistence = (dominant / 7.0) * 100.0;

      // 4. Pullback Quality
      double swingHigh = m_structure.GetLastSwingHighPrice();
      double swingLow = m_structure.GetLastSwingLowPrice();
      double closeVal = SymbolInfoDouble(symbol, SYMBOL_BID);
      ENUM_PULLBACK_QUALITY pullbackQuality = PULLBACK_HEALTHY;
      double pullbackScore = 50.0;
      if(swingHigh > swingLow && swingLow > 0.0)
      {
         double swingRange = swingHigh - swingLow;
         double retrace = 0.0;
         if(closeVal < swingHigh && closeVal > swingLow)
         {
            retrace = (swingHigh - closeVal) / swingRange;
         }
         else if(closeVal > swingLow)
         {
            retrace = (closeVal - swingLow) / swingRange;
         }
         
         if(retrace > 1.0)
         {
            pullbackQuality = PULLBACK_FAILED;
            pullbackScore = 10.0;
         }
         else if(retrace > 0.618)
         {
            pullbackQuality = PULLBACK_DEEP;
            pullbackScore = 40.0;
         }
         else if(retrace >= 0.382)
         {
            pullbackQuality = PULLBACK_HEALTHY;
            pullbackScore = 100.0;
         }
         else
         {
            pullbackQuality = PULLBACK_WEAK;
            pullbackScore = 70.0;
         }
      }

      // 5. Breakout Energy
      double bbUpper = 0.0, bbMiddle = 0.0, bbLower = 0.0;
      m_volatility.GetBollingerBands(symbol, tf, 20, 2.0, 1, bbUpper, bbMiddle, bbLower);
      double breakoutEnergy = 0.0;
      double rangeBB = bbUpper - bbLower;
      if(rangeBB > 0.0)
      {
         double cPrice = iClose(symbol, tf, 1);
         if(cPrice > bbUpper)
         {
            breakoutEnergy = MathMin(100.0, ((cPrice - bbUpper) / atr) * 50.0 + 50.0);
         }
         else if(cPrice < bbLower)
         {
            breakoutEnergy = MathMin(100.0, ((bbLower - cPrice) / atr) * 50.0 + 50.0);
         }
         else
         {
            double distOuter = MathMin(bbUpper - cPrice, cPrice - bbLower);
            breakoutEnergy = (1.0 - (distOuter / (rangeBB * 0.5))) * 50.0;
         }
      }

      // 6 & 7. Compression and Expansion
      double bandwidthLive = rangeBB;
      double avgRange = m_volatility.GetAverageCandleSize(symbol, tf, 50);
      if(avgRange <= 0.0) avgRange = SymbolInfoDouble(symbol, SYMBOL_POINT) * 100.0;
      double ratio = (bandwidthLive / (avgRange * 4.0));
      double compression = 0.0;
      if(ratio < 1.0) compression = (1.0 - ratio) * 100.0;
      if(compression > 100.0) compression = 100.0;

      double expansion = 0.0;
      if(ratio > 1.0) expansion = (ratio - 1.0) * 100.0;
      if(expansion > 100.0) expansion = 100.0;

      // 8. Exhaustion
      double ema200 = m_trend.GetEmaValue(symbol, tf, 200, 1);
      double distEma200 = MathAbs(iClose(symbol, tf, 1) - ema200);
      double distScore = (atr > 0.0) ? (distEma200 / atr) * 5.0 : 0.0;
      double rsi = m_momentum.GetRSIValue(1);
      double rsiScore = 0.0;
      if(rsi > 70.0)      rsiScore = (rsi - 70.0) * 3.33;
      else if(rsi < 30.0) rsiScore = (30.0 - rsi) * 3.33;
      double exhaustion = 0.4 * distScore + 0.6 * rsiScore;
      if(exhaustion > 100.0) exhaustion = 100.0;

      // 9. Movement Efficiency
      double startC = iClose(symbol, tf, 5);
      double endC = iClose(symbol, tf, 1);
      double displacement = MathAbs(endC - startC);
      double sumRanges = 0.0;
      for(int i = 1; i <= 5; i++)
      {
         sumRanges += (iHigh(symbol, tf, i) - iLow(symbol, tf, i));
      }
      double efficiency = (sumRanges > 0.0) ? (displacement / sumRanges) * 100.0 : 50.0;
      if(efficiency > 100.0) efficiency = 100.0;

      // 10. Final Movement Score (MS)
      double MS = 0.3 * velocity + 0.3 * persistence + 0.2 * expansion + 0.2 * efficiency;
      if(MS > 100.0) MS = 100.0;
      if(MS < 0.0)  MS = 0.0;

      m_context.MovementScore = MS;
      m_context.Velocity = velocity;
      m_context.Acceleration = acceleration;
      m_context.Persistence = persistence;
      m_context.PullbackQuality = pullbackQuality;
      m_context.BreakoutEnergy = breakoutEnergy;
      m_context.Compression = compression;
      m_context.Expansion = expansion;
      m_context.Exhaustion = exhaustion;
      m_context.Efficiency = efficiency;

      // Classify Movement States
      if(MS < 15.0)      m_context.MovementState = MOVEMENT_STATE_DEAD;
      else if(MS < 40.0) m_context.MovementState = MOVEMENT_STATE_SLOW;
      else if(MS < 70.0) m_context.MovementState = MOVEMENT_STATE_HEALTHY;
      else if(MS < 90.0) m_context.MovementState = MOVEMENT_STATE_FAST;
      else               m_context.MovementState = MOVEMENT_STATE_EXPLOSIVE;

      // Build humanity explanation narrative
      string stateStr = StateToString(m_context.MovementState);
      string accelStr = AccelToString(m_context.Acceleration);
      m_context.MovementNarrative = StringFormat(
         "%s movement with %s acceleration, velocity=%.1f, persistence=%.1f%%, exhaustion=%.1f%%, efficiency=%.1f%%",
         stateStr, accelStr, velocity, persistence, exhaustion, efficiency
      );

      m_logger.Debug("Movement Engine: Updated context: " + m_context.MovementNarrative);
   }

   /**
    * @brief Retrieves the calculated movement context data.
    */
   virtual MovementContext GetMovementContext() const override
   {
      return m_context;
   }
};

#endif // GOLDENGINEV2_MOVEMENT_ENGINE_MQH
