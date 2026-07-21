//+------------------------------------------------------------------+
//|                                         MarketContextEngine.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_MARKET_CONTEXT_ENGINE_MQH
#define GOLDENGINEV2_MARKET_CONTEXT_ENGINE_MQH

#include "IMarketContextEngine.mqh"

//+------------------------------------------------------------------+
//| Institutional Market Context Engine Concrete Implementation       |
//+------------------------------------------------------------------+
class CMarketContextEngine : public IMarketContextEngine
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
   CMarketQuality*            m_quality;

   bool                       m_isInitialized;
   MarketContext              m_context;

   /**
    * @brief Helper to convert liquidity state to string.
    */
   string GetLiquidityStateDesc(ENUM_LIQUIDITY_STATE state)
   {
      switch(state)
      {
         case LIQ_STATE_NO_LIQUIDITY: return "NO LIQUIDITY";
         case LIQ_STATE_BUILDING:     return "BUILDING";
         case LIQ_STATE_TARGETING:    return "TARGETING";
         case LIQ_STATE_SWEEPING:     return "SWEEPING";
         case LIQ_STATE_POST_SWEEP:   return "POST SWEEP";
         default:                     return "UNKNOWN";
      }
   }

public:
   /**
    * @brief Constructor.
    */
   CMarketContextEngine()
      : m_trend(NULL), m_momentum(NULL), m_volatility(NULL), m_volume(NULL),
        m_vwap(NULL), m_liquidity(NULL), m_pattern(NULL), m_session(NULL),
        m_structure(NULL), m_quality(NULL), m_isInitialized(false)
   {
      ZeroMemory(m_context);
   }

   /**
    * @brief Destructor.
    */
   ~CMarketContextEngine() {}

   /**
    * @brief Initialize context engine pointers.
    */
   virtual bool Initialize(const QuantEnginesContainer &engines, CMarketQuality* quality) override
   {
      m_trend      = engines.Trend;
      m_momentum   = engines.Momentum;
      m_volatility = engines.Volatility;
      m_volume     = engines.Volume;
      m_vwap       = engines.Vwap;
      m_liquidity  = engines.Liquidity;
      m_pattern    = engines.Pattern;
      m_session    = engines.Session;
      m_structure  = engines.MarketStructure;
      m_quality    = quality;

      if(m_trend == NULL || m_momentum == NULL || m_volatility == NULL || m_volume == NULL ||
         m_liquidity == NULL || m_session == NULL || m_structure == NULL || m_quality == NULL)
      {
         m_isInitialized = false;
         return false;
      }

      m_isInitialized = true;
      return true;
   }

   /**
    * @brief Evaluates all engines and updates context structure.
    */
   virtual void UpdateContext(const string symbol, ENUM_TIMEFRAMES tf) override
   {
      if(!m_isInitialized) return;

      // 1. Gather all inputs from Quant Engines
      int trendDir = m_trend.GetTrendDirection(symbol, tf);
      double trendStrength = m_trend.GetTrendStrength(symbol, tf);
      double alignmentConf = m_trend.GetEmaAlignmentConfidence(symbol, tf);

      double rsiVal = m_momentum.GetRSIValue(1);
      double momScore = m_momentum.GetMomentumScore();

      double volatilityScore = m_volatility.GetVolatilityScore(symbol, tf);
      string volatilityRegime = m_volatility.GetVolatilityRegime(symbol, tf);

      double rvol = m_volume.GetRelativeVolume();
      double volumeScore = m_volume.GetVolumeStrengthScore();

      bool buySweep = false, sellSweep = false;
      bool isSweep = m_liquidity.IsLiquiditySweep(buySweep, sellSweep);
      bool stopHunt = m_liquidity.IsStopHuntActive();
      bool hasLiquidity = m_liquidity.IsLiquidityPresent();

      string structState = m_structure.GetStructureState();

      double close = iClose(symbol, tf, 1);
      double ema20 = m_trend.GetEmaValue(symbol, tf, 20, 1);

      // 2. Classify Volatility State
      ENUM_VOLATILITY_STATE volState = VOL_STATE_NORMAL;
      if(volatilityRegime == "Low") volState = VOL_STATE_LOW;
      else if(volatilityRegime == "Normal") volState = VOL_STATE_NORMAL;
      else if(volatilityRegime == "High") volState = VOL_STATE_HIGH;
      else if(volatilityRegime == "Extreme") volState = VOL_STATE_EXPLODING;

      // 3. Classify Liquidity State
      ENUM_LIQUIDITY_STATE liqState = LIQ_STATE_NO_LIQUIDITY;
      if(stopHunt) liqState = LIQ_STATE_SWEEPING;
      else if(isSweep) liqState = LIQ_STATE_POST_SWEEP;
      else if(hasLiquidity) liqState = LIQ_STATE_TARGETING;
      else liqState = LIQ_STATE_BUILDING;

      // 4. Classify Structure State
      ENUM_STRUCTURE_STATE structStateEnum = STRUCT_STATE_TRANSITION;
      if(structState == "Bullish") structStateEnum = STRUCT_STATE_BULLISH;
      else if(structState == "Bearish") structStateEnum = STRUCT_STATE_BEARISH;
      else if(structState == "Range") structStateEnum = STRUCT_STATE_RANGE;
      else if(structState == "Transition") structStateEnum = STRUCT_STATE_TRANSITION;

      // 5. Classify Momentum State
      ENUM_MOMENTUM_STATE momState = MOM_STATE_NEUTRAL;
      if(rsiVal > 60.0 && momScore > 65.0) momState = MOM_STATE_ACCELERATING_BULLISH;
      else if(rsiVal < 40.0 && momScore > 65.0) momState = MOM_STATE_ACCELERATING_BEARISH;
      else if(momScore < 40.0) momState = MOM_STATE_DECELERATING;

      // 6. Classify Market Regime
      ENUM_MARKET_REGIME marketRegime = REGIME_TRANSITION;
      if(volState == VOL_STATE_LOW && rvol < 1.0)
         marketRegime = REGIME_COMPRESSION;
      else if((volState == VOL_STATE_HIGH || volState == VOL_STATE_EXPLODING) && rvol > 1.5)
         marketRegime = REGIME_EXPANSION;
      else if(rvol > 2.0 && structState == "Transition")
         marketRegime = REGIME_BREAKOUT;
      else if(trendStrength >= 70.0 && trendDir != 0)
         marketRegime = REGIME_TRENDING;
      else if(trendStrength < 40.0 && trendDir == 0)
         marketRegime = REGIME_RANGING;

      // 7. Classify Trend Phase
      ENUM_TREND_PHASE trendPhase = PHASE_NONE;
      if(trendDir != 0)
      {
         if(trendStrength > 30.0 && trendStrength < 60.0)
            trendPhase = PHASE_EARLY_TREND;
         else if(trendStrength >= 70.0 && trendStrength < 90.0)
            trendPhase = PHASE_MATURE_TREND;
         else if(trendStrength >= 90.0 && momScore < 45.0)
            trendPhase = PHASE_EXHAUSTION;
         else if((trendDir == 1 && close < ema20) || (trendDir == -1 && close > ema20))
            trendPhase = PHASE_PULLBACK;
         else
            trendPhase = PHASE_CONTINUATION;
      }

      // 8. Classify Active Session
      string sessionName = "None";
      if(m_session.IsOverlapActive()) sessionName = "London/NY Overlap";
      else if(m_session.IsSessionActive("LONDON")) sessionName = "London";
      else if(m_session.IsSessionActive("NEWYORK")) sessionName = "New York";
      else if(m_session.IsSessionActive("ASIA")) sessionName = "Asia";

      // 9. Fetch Market Quality Score & Interpretation
      double mqScore = m_quality.CalculateMarketQualityScore();
      string mqDesc = m_quality.GetMarketQualityInterpretation();

      // 10. Calculate Trade Environment Score (0 to 100)
      double structScore = (structStateEnum == STRUCT_STATE_BULLISH || structStateEnum == STRUCT_STATE_BEARISH) ? 100.0 : (structStateEnum == STRUCT_STATE_RANGE ? 50.0 : 30.0);
      double liqScore = (liqState == LIQ_STATE_SWEEPING) ? 100.0 : ((liqState == LIQ_STATE_POST_SWEEP) ? 80.0 : 50.0);
      
      double envScore = (trendStrength * 0.20) + 
                        (momScore * 0.15) + 
                        (volumeScore * 0.15) + 
                        (volatilityScore * 0.15) + 
                        (structScore * 0.15) + 
                        (liqScore * 0.10) + 
                        (mqScore * 0.10);

      string envDesc = "Average";
      if(envScore < 20.0) envDesc = "Avoid";
      else if(envScore < 40.0) envDesc = "Poor";
      else if(envScore < 60.0) envDesc = "Average";
      else if(envScore < 80.0) envDesc = "Good";
      else envDesc = "Excellent";

      // 11. Calculate Confidence Levels
      double trendConf = alignmentConf;
      double momentumConf = MathMin(100.0, MathAbs(rsiVal - 50.0) * 4.0); // 50 RSI = 0% conf, 25/75 = 100% conf
      double structureConf = structScore;
      double liquidityConf = liqScore;
      double volatilityConf = volatilityScore;
      
      double sessionConf = 20.0;
      if(sessionName == "London/NY Overlap") sessionConf = 100.0;
      else if(sessionName == "London") sessionConf = 90.0;
      else if(sessionName == "New York") sessionConf = 80.0;
      else if(sessionName == "Asia") sessionConf = 50.0;

      double overallConf = (trendConf * 0.25) + 
                           (structureConf * 0.25) + 
                           (momentumConf * 0.15) + 
                           (volatilityConf * 0.15) + 
                           (liquidityConf * 0.10) + 
                           (sessionConf * 0.10);

      // 12. Format Market Narrative
      string trendDirectionStr = (trendDir == 1) ? "Bullish" : ((trendDir == -1) ? "Bearish" : "Neutral");
      string activeLiquiditySweep = stopHunt ? "Active Stop Hunt sweep detected" : (isSweep ? "completed liquidity sweep" : "no sweep active");
      string structureDirectionStr = (structStateEnum == STRUCT_STATE_BULLISH ? "Bullish BOS" : (structStateEnum == STRUCT_STATE_BEARISH ? "Bearish BOS" : "Range Structure"));

      string narrative = StringFormat(
         "%s session is active.\n"
         "%s trend is established.\n"
         "Liquidity state: %s (%s).\n"
         "Market structure confirms %s.\n"
         "Momentum state: %s.\n"
         "Volatility is %s.\n"
         "Market quality is %s.\n"
         "Trade Environment Score = %.1f (%s).",
         sessionName,
         trendDirectionStr,
         GetLiquidityStateDesc(liqState),
         activeLiquiditySweep,
         structureDirectionStr,
         (momState == MOM_STATE_ACCELERATING_BULLISH ? "ACCELERATING BULLISH" : (momState == MOM_STATE_ACCELERATING_BEARISH ? "ACCELERATING BEARISH" : (momState == MOM_STATE_DECELERATING ? "DECELERATING" : "NEUTRAL"))),
         volatilityRegime,
         mqDesc,
         envScore,
         envDesc
      );

      // 13. Populate context structure
      m_context.TrendRegime       = trendDir;
      m_context.MarketRegime      = marketRegime;
      m_context.TrendPhase        = trendPhase;
      m_context.VolatilityRegime  = volState;
      m_context.LiquidityState     = liqState;
      m_context.StructureState    = structStateEnum;
      m_context.MomentumState     = momState;
      m_context.SessionState      = sessionName;
      m_context.MarketQuality     = mqDesc;
      m_context.ContextConfidence = overallConf;
      m_context.TradeEnvScore     = envScore;
      m_context.TradeEnvironment  = envDesc;
      m_context.Narrative         = narrative;
   }

   /**
    * @brief Returns current context.
    */
   virtual MarketContext GetContext() const override
   {
      return m_context;
   }
};

#endif // GOLDENGINEV2_MARKET_CONTEXT_ENGINE_MQH
