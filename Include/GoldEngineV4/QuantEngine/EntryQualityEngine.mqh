#ifndef GOLDENGINEV2_ENTRY_QUALITY_ENGINE_MQH
#define GOLDENGINEV2_ENTRY_QUALITY_ENGINE_MQH

#include "../Core/CoreDefines.mqh"
#include "../QuantEngine/TradeManagerDefines.mqh"
#include "../QuantEngine/IVolatilityEngine.mqh"
#include "../QuantEngine/IVolumeEngine.mqh"
#include "../QuantEngine/ITrendEngine.mqh"
#include "../QuantEngine/IMomentumEngine.mqh"
#include "../QuantEngine/ILiquidityEngine.mqh"
#include "../QuantEngine/ISessionEngine.mqh"
#include "../QuantEngine/IMarketStructureEngine.mqh"
#include "../QuantEngine/IPullbackReversalEngine.mqh"
#include "../QuantEngine/IOpportunityEngine.mqh"
#include "../QuantEngine/IMarketIntentEngine.mqh"

struct EntryQualityContext
{
   double EntryQualityScore;
   double RecoveryProbability;
};

class CEntryQualityEngine
{
public:
   static double CalculateEntryQuality(const string symbol, ENUM_GEV2_SIGNAL_TYPE dir, 
                                       ITrendEngine* trend, IMarketStructureEngine* structure,
                                       IPullbackReversalEngine* pullback, IMomentumEngine* momentum,
                                       IVolumeEngine* volume, ILiquidityEngine* liquidity,
                                       IVolatilityEngine* volatility, ISessionEngine* session,
                                       IMarketIntentEngine* intent, IOpportunityEngine* opportunity)
   {
      double scoreSum = 0.0;
      double weightSum = 0.0;

      // 1. Trend (0-100)
      if(trend != NULL)
      {
         double tStrength = trend.GetTrendStrength(symbol, _Period);
         int tDir = trend.GetTrendDirection(symbol, _Period);
         double trendScore = tStrength;
         if((dir == GEV2_SIGNAL_BUY && tDir < 0) || (dir == GEV2_SIGNAL_SELL && tDir > 0))
            trendScore = MathMax(0.0, 100.0 - tStrength); // counter-trend penalty
         scoreSum += trendScore * 1.5;
         weightSum += 1.5;
      }

      // 2. Structure (0-100)
      if(structure != NULL)
      {
         string st = structure.GetStructureState();
         double stScore = 50.0;
         if(st == "Bullish" || st == "Bearish") stScore = 100.0;
         else if(st == "Transition") stScore = 70.0;
         scoreSum += stScore * 1.0;
         weightSum += 1.0;
      }

      // 3. Pullback (0-100)
      if(pullback != NULL)
      {
         PullbackReversalContext pb = pullback.GetEvaluationContext();
         double pbScore = pb.ContinuationProb;
         scoreSum += pbScore * 1.2;
         weightSum += 1.2;
      }

      // 4. Momentum (0-100)
      if(momentum != NULL)
      {
         double mom = momentum.GetMomentumScore();
         scoreSum += mom * 1.0;
         weightSum += 1.0;
      }

      // 5. Volume (0-100)
      if(volume != NULL)
      {
         double vol = volume.GetVolumeStrengthScore();
         scoreSum += vol * 1.0;
         weightSum += 1.0;
      }

      // 6. Liquidity (0-100)
      if(liquidity != NULL)
      {
         double liq = 50.0;
         if(liquidity.IsStopHuntActive()) liq = 100.0;
         else if(liquidity.IsLiquidityPresent()) liq = 75.0;
         scoreSum += liq * 0.8;
         weightSum += 0.8;
      }

      // 7. Volatility (0-100)
      if(volatility != NULL)
      {
         double vola = volatility.GetVolatilityScore(symbol, _Period);
         scoreSum += vola * 0.8;
         weightSum += 0.8;
      }

      // 8. Spread (0-100)
      double spreadPoints = (double)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
      double spreadScore = MathMax(0.0, 100.0 - (spreadPoints * 2.0)); 
      scoreSum += spreadScore * 0.5;
      weightSum += 0.5;

      // 9. Market Intent (0-100)
      if(intent != NULL)
      {
         MarketIntentContext it = intent.GetMarketIntentContext();
         double intentScore = (dir == GEV2_SIGNAL_BUY) ? it.BuyerIntent : it.SellerIntent;
         scoreSum += intentScore * 1.0;
         weightSum += 1.0;
      }

      // 10. Opportunity (0-100)
      if(opportunity != NULL)
      {
         OpportunityContext opp = opportunity.GetOpportunityContext();
         scoreSum += opp.OpportunityScore * 1.2;
         weightSum += 1.2;
      }

      // 11. Session (0-100)
      if(session != NULL)
      {
         string sess = session.GetCurrentSession();
         double sessScore = 40.0;
         if(session.IsOverlapActive()) sessScore = 100.0;
         else if(sess == "LONDON" || sess == "NEWYORK") sessScore = 85.0;
         else if(sess == "ASIA") sessScore = 60.0;
         scoreSum += sessScore * 0.8;
         weightSum += 0.8;
      }

      if(weightSum <= 0.0) return 50.0;
      return scoreSum / weightSum;
   }

   static double CalculateRecoveryProbability(const string symbol, ENUM_GEV2_SIGNAL_TYPE dir,
                                              ITrendEngine* trend, IPullbackReversalEngine* pullback,
                                              IMarketIntentEngine* intent)
   {
      double prob = 50.0;
      if(pullback != NULL)
      {
         prob = pullback.GetEvaluationContext().TrendRecoveryProb;
      }
      else
      {
         double score = 50.0;
         int tDir = (trend != NULL) ? trend.GetTrendDirection(symbol, _Period) : 0;
         if((dir == GEV2_SIGNAL_BUY && tDir > 0) || (dir == GEV2_SIGNAL_SELL && tDir < 0))
            score += 15.0;
         else if(tDir != 0)
            score -= 15.0;

         if(intent != NULL)
         {
            MarketIntentContext it = intent.GetMarketIntentContext();
            double diff = it.BuyerIntent - it.SellerIntent;
            if(dir == GEV2_SIGNAL_BUY) score += diff * 0.2;
            else score -= diff * 0.2;
         }
         prob = MathMax(0.0, MathMin(100.0, score));
      }
      return prob;
   }
};

#endif // GOLDENGINEV2_ENTRY_QUALITY_ENGINE_MQH
