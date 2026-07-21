//+------------------------------------------------------------------+
//|                                         AdaptiveExitAIEngine.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_ADAPTIVE_EXIT_AI_ENGINE_MQH
#define GOLDENGINEV2_ADAPTIVE_EXIT_AI_ENGINE_MQH

#include "IAdaptiveExitAIEngine.mqh"
#include "IPullbackReversalEngine.mqh"
#include "ITradeHealthEngine.mqh"
#include "ITradeManager.mqh"

//--- Concrete implementation of Adaptive Exit AI Engine
class CAdaptiveExitAIEngine : public IAdaptiveExitAIEngine
{
private:
   // Engine references
   ITrendEngine*              m_trend;
   IMomentumEngine*           m_momentum;
   IVolatilityEngine*         m_volatility;
   IVolumeEngine*             m_volume;
   ILiquidityEngine*          m_liquidity;
   IOpportunityEngine*        m_opportunity;
   IMovementEngine*           m_movement;
   IMarketIntentEngine*       m_intent;
   IMarketContextEngine*      m_context;
   ITradePlannerEngine*       m_planner;
   ITradeHealthEngine*        m_tradeHealth;
   IPullbackReversalEngine*   m_pullback;
   ITradeManager*             m_tradeManager;

   // Inputs settings
   bool                       m_enable;
   double                     m_holdThreshold;
   double                     m_exitThreshold;
   double                     m_runnerThreshold;
   double                     m_trailThreshold;
   double                     m_confidenceThreshold;

   bool                       m_isInitialized;

   // Context cache
   AdaptiveExitContext        m_exitCtx;
   ENUM_ADAPTIVE_EXIT_ACTION  m_prevLoggedAction;

   // Internal computation helpers
   void                       EvaluateAIExit(const string symbol);
   double                     GetATR(const string symbol);

public:
   CAdaptiveExitAIEngine();
   virtual ~CAdaptiveExitAIEngine();

   virtual bool Initialize(const QuantEnginesContainer &engines,
                           bool     enable,
                           double   holdThreshold,
                           double   exitThreshold,
                           double   runnerThreshold,
                           double   trailThreshold,
                           double   confidenceThreshold) override;

   virtual void Update(const string symbol) override;
   virtual AdaptiveExitContext GetExitContext() const override { return m_exitCtx; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CAdaptiveExitAIEngine::CAdaptiveExitAIEngine()
   : m_trend(NULL), m_momentum(NULL), m_volatility(NULL), m_volume(NULL),
     m_liquidity(NULL), m_opportunity(NULL), m_movement(NULL), m_intent(NULL),
     m_context(NULL), m_planner(NULL), m_tradeHealth(NULL), m_pullback(NULL),
     m_tradeManager(NULL), m_enable(true), m_holdThreshold(60.0), m_exitThreshold(60.0),
     m_runnerThreshold(75.0), m_trailThreshold(50.0), m_confidenceThreshold(60.0),
     m_isInitialized(false), m_prevLoggedAction(ADAPTIVE_EXIT_WAIT)
{
   ZeroMemory(m_exitCtx);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CAdaptiveExitAIEngine::~CAdaptiveExitAIEngine()
{
}

//+------------------------------------------------------------------+
//| Initializer                                                      |
//+------------------------------------------------------------------+
bool CAdaptiveExitAIEngine::Initialize(const QuantEnginesContainer &engines,
                                       bool     enable,
                                       double   holdThreshold,
                                       double   exitThreshold,
                                       double   runnerThreshold,
                                       double   trailThreshold,
                                       double   confidenceThreshold)
{
   m_trend        = engines.Trend;
   m_momentum     = engines.Momentum;
   m_volatility   = engines.Volatility;
   m_volume       = engines.Volume;
   m_liquidity    = engines.Liquidity;
   m_opportunity  = engines.Opportunity;
   m_movement     = engines.Movement;
   m_intent       = engines.Intent;
   m_context      = engines.MarketContext;
   m_planner      = engines.Planner;
   m_tradeHealth  = engines.TradeHealth;
   m_pullback     = engines.PullbackReversal;
   m_tradeManager = engines.TradeManager;

   m_enable = enable;
   m_holdThreshold = holdThreshold;
   m_exitThreshold = exitThreshold;
   m_runnerThreshold = runnerThreshold;
   m_trailThreshold = trailThreshold;
   m_confidenceThreshold = confidenceThreshold;

   m_isInitialized = true;
   return true;
}

//+------------------------------------------------------------------+
//| Update tick updates                                              |
//+------------------------------------------------------------------+
void CAdaptiveExitAIEngine::Update(const string symbol)
{
   if(!m_enable || !m_isInitialized) return;

   EvaluateAIExit(symbol);

   // Log only when action recommendation shifts
   if(m_exitCtx.Recommendation != m_prevLoggedAction)
   {
      Print(StringFormat("[ADAPTIVE EXIT AI] Decision: %s | Confidence: %.0f%% | Narrative: %s",
                         AdaptiveExitActionToString(m_exitCtx.Recommendation),
                         m_exitCtx.Confidence,
                         m_exitCtx.Narrative));
      m_prevLoggedAction = m_exitCtx.Recommendation;
   }
}

//+------------------------------------------------------------------+
//| Evaluates active position exit recommendation                   |
//+------------------------------------------------------------------+
void CAdaptiveExitAIEngine::EvaluateAIExit(const string symbol)
{
   // Retrieve current positions details matching symbol and magic
   ulong ticket = 0;
   double entryPrice = 0.0;
   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
   ENUM_POSITION_TYPE posType = POSITION_TYPE_BUY;
   bool hasTrade = false;
   double mfe = 0.0, mae = 0.0, health = 50.0;
   int durationSec = 0;
   double profitVal = 0.0;
   double stopLossPrice = 0.0;

   int totalPos = PositionsTotal();
   for(int i = 0; i < totalPos; i++)
   {
      if(PositionGetSymbol(i) == symbol)
      {
         ticket = PositionGetInteger(POSITION_TICKET);
         entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         stopLossPrice = PositionGetDouble(POSITION_SL);
         posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         profitVal = PositionGetDouble(POSITION_PROFIT);
         durationSec = (int)(TimeCurrent() - PositionGetInteger(POSITION_TIME));
         hasTrade = true;

         // Load health & excursions
         if(m_tradeManager != NULL)
         {
            for(int j = 0; j < m_tradeManager.GetActiveTrackingCount(); j++)
            {
               TradeTrackingState snap;
               if(m_tradeManager.GetTrackingState(j, snap) && snap.Ticket == ticket)
               {
                  mfe = snap.MaxProfitReachedPoints;
                  mae = snap.MaxLossReachedPoints;
                  health = snap.HealthScore;
                  break;
               }
            }
         }
         break;
      }
   }

   // 1. Gather all sub-engine metrics
   double pbCont = 50.0, pbRev = 0.0;
   if(m_pullback != NULL)
   {
      PullbackReversalContext pb = m_pullback.GetEvaluationContext();
      pbCont = pb.ContinuationProb;
      pbRev = pb.ReversalProb;
   }

   double volumeVal = (m_volume != NULL) ? m_volume.GetRelativeVolume() : 1.0;
   double movementScore = (m_movement != NULL) ? m_movement.GetMovementContext().MovementScore : 50.0;
   double opportunityScore = (m_opportunity != NULL) ? m_opportunity.GetOpportunityContext().OpportunityScore : 50.0;

   double buyerIntent = 50.0, sellerIntent = 50.0;
   if(m_intent != NULL)
   {
      buyerIntent = m_intent.GetMarketIntentContext().BuyerIntent;
      sellerIntent = m_intent.GetMarketIntentContext().SellerIntent;
   }
   double intentAlign = (posType == POSITION_TYPE_BUY) ? buyerIntent : sellerIntent;

   double plannerConf = (m_planner != NULL) ? m_planner.GetTradePlanContext().TradeConfidence : 50.0;

   // Duration Decay score (5% weight)
   double durScore = 100.0;
   if(durationSec > 1800) durScore = 30.0;
   else if(durationSec > 600) durScore = 65.0;

   // 2. Perform weighted computations
   // Hold Score (Health 25%, PullbackCont 20%, Movement 15%, Intent 15%, Opp 10%, Planner 10%, Duration 5%)
   double holdScore = (health * 0.25) +
                      (pbCont * 0.20) +
                      (movementScore * 0.15) +
                      (intentAlign * 0.15) +
                      (opportunityScore * 0.10) +
                      (plannerConf * 0.10) +
                      (durScore * 0.05);

   // Exit Score (Opposite logic)
   double exitScore = ((100.0 - health) * 0.25) +
                      (pbRev * 0.20) +
                      ((100.0 - movementScore) * 0.15) +
                      ((100.0 - intentAlign) * 0.15) +
                      ((100.0 - opportunityScore) * 0.10) +
                      ((100.0 - plannerConf) * 0.10) +
                      ((100.0 - durScore) * 0.05);

   // Profit points conversion
   double pointsProfit = 0.0;
   double pointVal = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(pointVal > 0)
   {
      if(posType == POSITION_TYPE_BUY)
      {
         pointsProfit = (currentPrice - entryPrice) / pointVal;
      }
      else
      {
         pointsProfit = (entryPrice - currentPrice) / pointVal;
      }
   }

   // Runner Score: high hold score + profit accumulation
   double runnerScore = (holdScore * 0.70) + (MathMax(0.0, pointsProfit) / 20.0) * 30.0;
   runnerScore = MathMin(100.0, runnerScore);

   // 3. Evaluate Output Recommendations
   ENUM_ADAPTIVE_EXIT_ACTION rec = ADAPTIVE_EXIT_WAIT;
   double conf = 50.0;
   string narrative = "Awaiting clear trend confirmation.";
   string risk = "Low";
   double expectedMove = (m_planner != NULL) ? m_planner.GetTradePlanContext().ExpectedRR * 100.0 : 150.0; // dummy expected points
   double recommendedSL = stopLossPrice;
   double recommendedTrail = 50.0;

   if(!hasTrade)
   {
      rec = ADAPTIVE_EXIT_WAIT;
      conf = 50.0;
      narrative = "No active positions. Monitoring market.";
      risk = "Low";
   }
   else
   {
      // Classify Risk Level
      if(exitScore > 75) risk = "Critical";
      else if(exitScore > 55) risk = "High";
      else if(exitScore > 35) risk = "Medium";
      else risk = "Low";

      // Recommended stops: tighten stops if exit score increases
      double atr = GetATR(symbol);
      if(atr > 0)
      {
         recommendedTrail = 2.0 * atr / pointVal;
         if(posType == POSITION_TYPE_BUY)
         {
            recommendedSL = currentPrice - (1.5 * atr);
         }
         else
         {
            recommendedSL = currentPrice + (1.5 * atr);
         }
      }

      // Decision rules
      // V5.5: Minimum hold time guard — FULL_EXIT cannot fire in first 45 seconds
      // Trades need time to develop before the AI can recommend closure
      if(exitScore > m_exitThreshold && exitScore > holdScore)
      {
         if(durationSec < 45)
         {
            // Downgrade: hold and trail instead of exiting immediately
            rec = ADAPTIVE_EXIT_TRAIL;
            conf = holdScore;
            narrative = "Exit suppressed: trade too new (<45s). Trailing stop applied.";
         }
         else
         {
            rec = ADAPTIVE_EXIT_FULL_EXIT;
            conf = exitScore;
            narrative = "Momentum collapsing. Exit recommended.";
         }
      }
      else if(runnerScore > m_runnerThreshold && pointsProfit > 150.0) // 15 points
      {
         rec = ADAPTIVE_EXIT_CONVERT_TO_RUNNER;
         conf = runnerScore;
         narrative = "Exceptional trend. Convert to runner.";
      }
      else if(holdScore > m_trailThreshold && exitScore > 40.0)
      {
         rec = ADAPTIVE_EXIT_TRAIL;
         conf = holdScore;
         narrative = "Healthy pullback detected. Do not exit.";
      }
      else if(holdScore > m_holdThreshold)
      {
         rec = ADAPTIVE_EXIT_HOLD;
         conf = holdScore;
         narrative = "Trade remains healthy. Hold position.";
      }
      else
      {
         rec = ADAPTIVE_EXIT_HOLD;
         conf = holdScore;
         narrative = "Trade environment stable. Holding.";
      }
   }

   // Cache the variables
   m_exitCtx.Recommendation = rec;
   m_exitCtx.Confidence = NormalizeDouble(conf, 1);
   m_exitCtx.Narrative = narrative;
   m_exitCtx.RiskLevel = risk;
   m_exitCtx.ExpectedRemainingMove = NormalizeDouble(expectedMove, 1);
   m_exitCtx.RecommendedStop = NormalizeDouble(recommendedSL, 2);
   m_exitCtx.RecommendedTrail = NormalizeDouble(recommendedTrail, 1);
   
   m_exitCtx.HoldScore = NormalizeDouble(holdScore, 1);
   m_exitCtx.ExitScore = NormalizeDouble(exitScore, 1);
   m_exitCtx.RunnerScore = NormalizeDouble(runnerScore, 1);
}

//+------------------------------------------------------------------+
//| Reads current ATR value                                          |
//+------------------------------------------------------------------+
double CAdaptiveExitAIEngine::GetATR(const string symbol)
{
   int handle = iATR(symbol, Period(), 14);
   if(handle == INVALID_HANDLE) return 0.0;
   double values[1];
   if(CopyBuffer(handle, 0, 0, 1, values) > 0)
   {
      IndicatorRelease(handle);
      return values[0];
   }
   IndicatorRelease(handle);
   return 0.0;
}

#endif // GOLDENGINEV2_ADAPTIVE_EXIT_AI_ENGINE_MQH
