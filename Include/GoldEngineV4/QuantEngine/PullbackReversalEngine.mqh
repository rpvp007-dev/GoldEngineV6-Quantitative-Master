//+------------------------------------------------------------------+
//|                                     PullbackReversalEngine.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_PULLBACK_REVERSAL_ENGINE_MQH
#define GOLDENGINEV2_PULLBACK_REVERSAL_ENGINE_MQH

#include "IPullbackReversalEngine.mqh"
#include "ITrendEngine.mqh"
#include "IMomentumEngine.mqh"
#include "IVolatilityEngine.mqh"
#include "IVolumeEngine.mqh"
#include "ILiquidityEngine.mqh"
#include "IOpportunityEngine.mqh"
#include "IMovementEngine.mqh"
#include "IMarketIntentEngine.mqh"
#include "ITradePlannerEngine.mqh"
#include "ITradeHealthEngine.mqh"
#include "ITradeManager.mqh"

//--- Concrete implementation of Pullback vs Reversal Intelligence Engine
class CPullbackReversalEngine : public IPullbackReversalEngine
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
   ITradeHealthEngine*        m_tradeHealth;
   ITradeManager*             m_tradeManager;

   // Inputs variables
   bool                       m_enable;
   double                     m_minContinuationProb;
   double                     m_minReversalProb;
   double                     m_breakoutThreshold;
   double                     m_fakeBreakoutThreshold;
   int                        m_emaPeriod;
   int                        m_atrPeriod;
   double                     m_weightVolume;
   double                     m_weightMovement;
   double                     m_weightIntent;
   double                     m_weightTradeHealth;
   bool                       m_enableNarratives;

   // Indicator handles
   int                        m_emaHandle;
   int                        m_atrHandle;
   bool                       m_isInitialized;

   // Evaluation context cache
   PullbackReversalContext    m_evalCtx;
   ENUM_PULLBACK_STATE        m_prevLoggedState;

   // Internal computation helper
   void                       EvaluateState(const string symbol);
   double                     GetEMA(int index);
   double                     GetATR(int index);

public:
   CPullbackReversalEngine();
   virtual ~CPullbackReversalEngine();

   virtual bool Initialize(const QuantEnginesContainer &engines,
                           bool     enable,
                           double   minContinuationProb,
                           double   minReversalProb,
                           double   breakoutThreshold,
                           double   fakeBreakoutThreshold,
                           int      emaPeriod,
                           int      atrPeriod,
                           double   weightVolume,
                           double   weightMovement,
                           double   weightIntent,
                           double   weightTradeHealth,
                           bool     enableNarratives) override;

   virtual void Update(const string symbol) override;
   virtual PullbackReversalContext GetEvaluationContext() const override { return m_evalCtx; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CPullbackReversalEngine::CPullbackReversalEngine()
   : m_trend(NULL), m_momentum(NULL), m_volatility(NULL), m_volume(NULL),
     m_liquidity(NULL), m_opportunity(NULL), m_movement(NULL), m_intent(NULL),
     m_context(NULL), m_tradeHealth(NULL), m_tradeManager(NULL), m_enable(true),
     m_minContinuationProb(60.0), m_minReversalProb(60.0), m_breakoutThreshold(70.0),
     m_fakeBreakoutThreshold(65.0), m_emaPeriod(20), m_atrPeriod(14),
     m_weightVolume(25.0), m_weightMovement(25.0), m_weightIntent(25.0),
     m_weightTradeHealth(25.0), m_enableNarratives(true),
     m_emaHandle(INVALID_HANDLE), m_atrHandle(INVALID_HANDLE), m_isInitialized(false),
     m_prevLoggedState(PULLBACK_STATE_NONE)
{
   ZeroMemory(m_evalCtx);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CPullbackReversalEngine::~CPullbackReversalEngine()
{
   if(m_emaHandle != INVALID_HANDLE) IndicatorRelease(m_emaHandle);
   if(m_atrHandle != INVALID_HANDLE) IndicatorRelease(m_atrHandle);
}

//+------------------------------------------------------------------+
//| Initializer                                                      |
//+------------------------------------------------------------------+
bool CPullbackReversalEngine::Initialize(const QuantEnginesContainer &engines,
                                         bool     enable,
                                         double   minContinuationProb,
                                         double   minReversalProb,
                                         double   breakoutThreshold,
                                         double   fakeBreakoutThreshold,
                                         int      emaPeriod,
                                         int      atrPeriod,
                                         double   weightVolume,
                                         double   weightMovement,
                                         double   weightIntent,
                                         double   weightTradeHealth,
                                         bool     enableNarratives)
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
   m_tradeHealth  = engines.TradeHealth;
   m_tradeManager = engines.TradeManager;

   m_enable = enable;
   m_minContinuationProb = minContinuationProb;
   m_minReversalProb = minReversalProb;
   m_breakoutThreshold = breakoutThreshold;
   m_fakeBreakoutThreshold = fakeBreakoutThreshold;
   m_emaPeriod = emaPeriod;
   m_atrPeriod = atrPeriod;
   m_weightVolume = weightVolume;
   m_weightMovement = weightMovement;
   m_weightIntent = weightIntent;
   m_weightTradeHealth = weightTradeHealth;
   m_enableNarratives = enableNarratives;

   // Normalize weights to sum to 1.0 internally
   double tot = m_weightVolume + m_weightMovement + m_weightIntent + m_weightTradeHealth;
   if(tot <= 0) tot = 100.0;
   m_weightVolume /= tot;
   m_weightMovement /= tot;
   m_weightIntent /= tot;
   m_weightTradeHealth /= tot;

   m_isInitialized = true;
   return true;
}

//+------------------------------------------------------------------+
//| Update tick updates                                              |
//+------------------------------------------------------------------+
void CPullbackReversalEngine::Update(const string symbol)
{
   if(!m_enable || !m_isInitialized) return;

   // Dynamically construct handles if not done yet
   if(m_emaHandle == INVALID_HANDLE)
   {
      m_emaHandle = iMA(symbol, Period(), m_emaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   }
   if(m_atrHandle == INVALID_HANDLE)
   {
      m_atrHandle = iATR(symbol, Period(), m_atrPeriod);
   }

   EvaluateState(symbol);

   // Log only when state changes
   if(m_evalCtx.State != m_prevLoggedState)
   {
      Print(StringFormat("[PULLBACK ENGINE] %s | Continuation %.0f%% | Recommendation %s | Narrative: %s",
                         PullbackStateToString(m_evalCtx.State),
                         m_evalCtx.ContinuationProb,
                         PullbackRecToString(m_evalCtx.Recommendation),
                         m_evalCtx.Narrative));
      m_prevLoggedState = m_evalCtx.State;
   }
}

//+------------------------------------------------------------------+
//| Core State Evaluation calculations                               |
//+------------------------------------------------------------------+
void CPullbackReversalEngine::EvaluateState(const string symbol)
{
   double atr = GetATR(0);
   if(atr <= 0) atr = 0.50; // clamp fallback
   double ema = GetEMA(0);

   // Retrieve current positions details matching symbol and magic
   ulong ticket = 0;
   double entryPrice = 0.0;
   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
   ENUM_POSITION_TYPE posType = POSITION_TYPE_BUY;
   bool hasTrade = false;
   double mfe = 0.0, mae = 0.0, health = 50.0;

   int totalPos = PositionsTotal();
   for(int i = 0; i < totalPos; i++)
   {
      if(PositionGetSymbol(i) == symbol)
      {
         ticket = PositionGetInteger(POSITION_TICKET);
         entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
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

   // 1. Gather Pillar Engine Metrics
   double volumeScore = (m_volume != NULL) ? m_volume.GetRelativeVolume() * 50.0 : 50.0; // scale RVOL
   double movementScore = (m_movement != NULL) ? m_movement.GetMovementContext().MovementScore : 50.0;
   double opportunityScore = (m_opportunity != NULL) ? m_opportunity.GetOpportunityContext().OpportunityScore : 50.0;
   
   double buyerIntent = 50.0, sellerIntent = 50.0;
   if(m_intent != NULL)
   {
      buyerIntent = m_intent.GetMarketIntentContext().BuyerIntent;
      sellerIntent = m_intent.GetMarketIntentContext().SellerIntent;
   }

   double trendDir = (m_trend != NULL) ? (double)m_trend.GetTrendDirection(symbol, Period()) : 1.0;

   // 2. Probability calculations
   double pullbackProb = 0.0;
   double continuationProb = 50.0;
   double reversalProb = 0.0;
   double breakoutAuth = 50.0;
   double fakeBreakoutProb = 0.0;
   double recoveryProb = 50.0;
   
   ENUM_PULLBACK_STATE state = PULLBACK_STATE_NONE;
   ENUM_PULLBACK_RECOMMENDATION rec = PULLBACK_REC_WAIT;
   string narrative = "Neutral market conditions.";

   if(!hasTrade)
   {
      // A. NO ACTIVE TRADE: Evaluate Breakout Authenticity vs Fake Breakout
      double movAcc = MathMin(100.0, movementScore * 1.2);
      
      // If movement is very strong but volume and intent are weak -> Fake Breakout
      double volumeVal = (m_volume != NULL) ? m_volume.GetRelativeVolume() : 1.0;
      if(movementScore > 65.0)
      {
         if(volumeVal < 0.8 && MathAbs(buyerIntent - sellerIntent) < 15.0)
         {
            fakeBreakoutProb = 75.0 + (movementScore - 65.0);
            breakoutAuth = 100.0 - fakeBreakoutProb;
            state = PULLBACK_STATE_FALSE_BREAKOUT;
            rec = PULLBACK_REC_WAIT;
            narrative = "False breakout detected.";
         }
         else
         {
            breakoutAuth = 75.0 + (volumeVal * 10.0);
            fakeBreakoutProb = 100.0 - breakoutAuth;
            state = PULLBACK_STATE_TRUE_BREAKOUT;
            rec = PULLBACK_REC_ADD_POSITION;
            narrative = "Continuation remains strong.";
         }
      }
      else
      {
         state = PULLBACK_STATE_NONE;
         rec = PULLBACK_REC_WAIT;
         narrative = "No active trade setup.";
      }
   }
   else
   {
      // B. ACTIVE TRADE: Evaluate Pullback vs Reversal
      double retracement = 0.0;
      if(posType == POSITION_TYPE_BUY)
      {
         retracement = entryPrice - currentPrice;
      }
      else
      {
         retracement = currentPrice - entryPrice;
      }

      double retRatio = (atr > 0) ? (retracement / atr) : 0.0;
      bool isRetracing = (retracement > 0);

      // Continuation Factors (weighted)
      double contFactor = 50.0;
      if(posType == POSITION_TYPE_BUY)
      {
         contFactor += (buyerIntent - 50.0) * 0.4;
         contFactor += (trendDir > 0) ? 15.0 : -15.0;
      }
      else
      {
         contFactor += (sellerIntent - 50.0) * 0.4;
         contFactor += (trendDir < 0) ? 15.0 : -15.0;
      }
      contFactor += (health - 50.0) * 0.3;
      contFactor = MathMax(0.0, MathMin(100.0, contFactor));

      // Reversal Factors
      double revFactor = 50.0;
      if(posType == POSITION_TYPE_BUY)
      {
         revFactor += (sellerIntent - 50.0) * 0.4;
         revFactor += (trendDir < 0) ? 15.0 : -15.0;
      }
      else
      {
         revFactor += (buyerIntent - 50.0) * 0.4;
         revFactor += (trendDir > 0) ? 15.0 : -15.0;
      }
      revFactor += (50.0 - health) * 0.3;
      revFactor += (mae > 0) ? (mae / 10.0) : 0.0; // MAE excursion adds reversal probability
      revFactor = MathMax(0.0, MathMin(100.0, revFactor));

      continuationProb = contFactor;
      reversalProb = revFactor;
      pullbackProb = isRetracing ? (50.0 + retRatio * 20.0) : 0.0;
      pullbackProb = MathMin(100.0, pullbackProb);
      recoveryProb = contFactor;

      if(isRetracing)
      {
         if(reversalProb > m_minReversalProb && reversalProb > continuationProb)
         {
            state = PULLBACK_STATE_REVERSAL;
            rec = PULLBACK_REC_EXIT;
            narrative = "Momentum collapsing. Reversal likely.";
         }
         else if(continuationProb > m_minContinuationProb)
         {
            if(retRatio < 0.5)
            {
               state = PULLBACK_STATE_HEALTHY_PULLBACK;
               rec = PULLBACK_REC_HOLD;
               narrative = "Healthy pullback inside strong trend.";
            }
            else if(retRatio < 1.0)
            {
               state = PULLBACK_STATE_NORMAL_PULLBACK;
               rec = PULLBACK_REC_HOLD;
               narrative = "Normal pullback, key supports holding.";
            }
            else if(retRatio < 1.5)
            {
               state = PULLBACK_STATE_DEEP_PULLBACK;
               rec = PULLBACK_REC_TIGHTEN_STOP;
               narrative = "Deep pullback. Tightening stops.";
            }
            else
            {
               state = PULLBACK_STATE_FAILED_PULLBACK;
               rec = PULLBACK_REC_MOVE_BREAK_EVEN;
               narrative = "Pullback failed. Defensive measures recommended.";
            }
         }
         else
         {
            state = PULLBACK_STATE_TREND_EXHAUSTION;
            rec = PULLBACK_REC_WAIT;
            narrative = "Trend exhaustion detected. Awaiting recovery.";
         }
      }
      else
      {
         // Trade is in profit
         state = PULLBACK_STATE_NONE;
         rec = PULLBACK_REC_TRAIL;
         narrative = "Continuation remains strong.";
      }
   }

   // 3. Populate evaluation context
   m_evalCtx.State = state;
   m_evalCtx.ContinuationProb = NormalizeDouble(continuationProb, 1);
   m_evalCtx.ReversalProb = NormalizeDouble(reversalProb, 1);
   m_evalCtx.TrendRecoveryProb = NormalizeDouble(recoveryProb, 1);
   m_evalCtx.BreakoutAuthenticity = NormalizeDouble(breakoutAuth, 1);
   m_evalCtx.FakeBreakoutProb = NormalizeDouble(fakeBreakoutProb, 1);
   m_evalCtx.PullbackProb = NormalizeDouble(pullbackProb, 1);
   m_evalCtx.Recommendation = rec;
   m_evalCtx.Narrative = m_enableNarratives ? narrative : "";
   
   // Confidence is the difference between continuation and reversal (or breakout vs fake)
   double conf = hasTrade ? MathAbs(continuationProb - reversalProb) : MathAbs(breakoutAuth - fakeBreakoutProb);
   m_evalCtx.Confidence = NormalizeDouble(conf, 1);
}

//+------------------------------------------------------------------+
//| Helper to read EMA values                                        |
//+------------------------------------------------------------------+
double CPullbackReversalEngine::GetEMA(int index)
{
   if(m_emaHandle == INVALID_HANDLE) return 0.0;
   double values[1];
   if(CopyBuffer(m_emaHandle, 0, index, 1, values) > 0)
   {
      return values[0];
   }
   return 0.0;
}

//+------------------------------------------------------------------+
//| Helper to read ATR values                                        |
//+------------------------------------------------------------------+
double CPullbackReversalEngine::GetATR(int index)
{
   if(m_atrHandle == INVALID_HANDLE) return 0.0;
   double values[1];
   if(CopyBuffer(m_atrHandle, 0, index, 1, values) > 0)
   {
      return values[0];
   }
   return 0.0;
}

#endif // GOLDENGINEV2_PULLBACK_REVERSAL_ENGINE_MQH
