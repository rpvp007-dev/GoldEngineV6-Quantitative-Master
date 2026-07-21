//+------------------------------------------------------------------+
//|                                                 MarketQuality.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_MARKET_QUALITY_MQH
#define GOLDENGINEV2_MARKET_QUALITY_MQH

#include "IMarketQuality.mqh"

//+------------------------------------------------------------------+
//| Market Quality Score Concrete Implementation (GITS V2.4)          |
//+------------------------------------------------------------------+
class CMarketQuality : public IMarketQuality
{
private:
   CConfig*                   m_config;
   ITrendEngine*              m_trend;
   IMomentumEngine*           m_momentum;
   IVolatilityEngine*         m_volatility;
   IVolumeEngine*             m_volume;
   IMarketStructureEngine*    m_structure;
   ILiquidityEngine*          m_liquidity;
   ISessionEngine*            m_session;
   bool                       m_isInitialized;

public:
   /**
    * @brief Constructor.
    */
   CMarketQuality()
      : m_config(NULL),
        m_trend(NULL), m_momentum(NULL), m_volatility(NULL), m_volume(NULL),
        m_structure(NULL), m_liquidity(NULL), m_session(NULL),
        m_isInitialized(false)
   {}

   /**
    * @brief Destructor.
    */
   ~CMarketQuality() {}

   /**
    * @brief Links config and engine instances.
    */
   virtual bool Initialize(
      CConfig*                config,
      ITrendEngine*           trend,
      IMomentumEngine*        momentum,
      IVolatilityEngine*      volatility,
      IVolumeEngine*          volume,
      IMarketStructureEngine* structure,
      ILiquidityEngine*       liquidity,
      ISessionEngine*         session) override
   {
      m_config     = config;
      m_trend      = trend;
      m_momentum   = momentum;
      m_volatility = volatility;
      m_volume     = volume;
      m_structure  = structure;
      m_liquidity  = liquidity;
      m_session    = session;

      if(m_config == NULL || m_trend == NULL || m_momentum == NULL || m_volatility == NULL ||
         m_volume == NULL || m_structure == NULL || m_liquidity == NULL || m_session == NULL)
      {
         m_isInitialized = false;
         return false;
      }

      m_isInitialized = true;
      return true;
   }

   /**
    * @brief Computes composite Market Quality Score (0 to 100).
    */
   virtual double CalculateMarketQualityScore() override
   {
      if(!m_isInitialized) return 50.0;
 
      // 1. Gather scores from engines
      double trendScore = m_trend.GetTrendStrength(_Symbol, _Period);
      double momentumScore = m_momentum.GetMomentumScore();
      double volatilityScore = m_volatility.GetVolatilityScore(_Symbol, _Period);
      double volumeScore = m_volume.GetVolumeStrengthScore();
 
      // Structure Score mapping
      double structureScore = 40.0; // Default Range
      string structState = m_structure.GetStructureState();
      if(structState == "Bullish" || structState == "Bearish") structureScore = 85.0;
      else if(structState == "Transition") structureScore = 65.0;
 
      // Liquidity Score mapping
      double liquidityScore = 40.0;
      bool buySweep = false, sellSweep = false;
      if(m_liquidity.IsStopHuntActive())
      {
         liquidityScore = 95.0; // institutional sweeps denote quality expansion
      }
      else if(m_liquidity.IsLiquiditySweep(buySweep, sellSweep))
      {
         liquidityScore = 80.0;
      }
      else if(m_liquidity.IsLiquidityPresent())
      {
         liquidityScore = 60.0 + (m_liquidity.GetLiquidityStrength() * 0.20);
      }
 
      // Session Score mapping
      double sessionScore = 20.0; // Default Off-hours
      if(m_session.IsOverlapActive()) sessionScore = 95.0;
      else if(m_session.IsSessionActive("LONDON")) sessionScore = 85.0;
      else if(m_session.IsSessionActive("NEWYORK")) sessionScore = 75.0;
      else if(m_session.IsSessionActive("ASIA")) sessionScore = 45.0;
 
      // 2. Fetch weights from configuration
      double wTrend      = m_config.GetTrendWeight();
      double wMomentum   = m_config.GetMomentumWeight();
      double wVolatility = m_config.GetVolatilityWeight();
      double wVolume     = m_config.GetVolumeWeight();
      double wStructure  = m_config.GetStructureWeight();
      double wLiquidity  = m_config.GetLiquidityWeight();
      double wSession    = m_config.GetSessionWeight();
 
      double sumWeights = wTrend + wMomentum + wVolatility + wVolume + wStructure + wLiquidity + wSession;
      if(sumWeights <= 0.0) return 50.0;
 
      double weightedSum = (trendScore * wTrend) +
                           (momentumScore * wMomentum) +
                           (volatilityScore * wVolatility) +
                           (volumeScore * wVolume) +
                           (structureScore * wStructure) +
                           (liquidityScore * wLiquidity) +
                           (sessionScore * wSession);
 
      double finalScore = weightedSum / sumWeights;
      if(finalScore < 0.0) finalScore = 0.0;
      if(finalScore > 100.0) finalScore = 100.0;
 
      return finalScore;
   }

   /**
    * @brief Interprets final score into tags.
    */
   virtual string GetMarketQualityInterpretation() override
   {
      double score = CalculateMarketQualityScore();
      if(score < 20.0) return "Poor Market";
      if(score < 40.0) return "Weak";
      if(score < 60.0) return "Average";
      if(score < 80.0) return "Good";
      return "Excellent";
   }
};

#endif // GOLDENGINEV2_MARKET_QUALITY_MQH
