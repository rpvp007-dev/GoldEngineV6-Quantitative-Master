//+------------------------------------------------------------------+
//|                                      X001_OpportunityScalp.mqh   |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
// V4.4 — Adaptive Opportunity Consumer
//   Scoring model replaced with 5-Pillar Additive Composite Score.
//   Hard entry filters replaced with soft, weighted contributions.
//   3-Layer direction resolution — REC_DIR_NONE is no longer a hard reject.
//   Adaptive TP/SL selection based on market regime and composite score.
//   Configurable aggressiveness bonus, sideways/trend targets, momentum exit.
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_X001_OPPORTUNITY_SCALP_MQH
#define GOLDENGINEV2_X001_OPPORTUNITY_SCALP_MQH

#include "../../IStrategy.mqh"
#include "../../../Bridge/BridgeDefines.mqh"
#include "../../../Core/Config.mqh"
#include "../../../Analytics/TradeMemory.mqh"
#include "../../../Core/Logger.mqh"
#include "../../../QuantEngine/IOpportunityEngine.mqh"
#include "../../../QuantEngine/IMovementEngine.mqh"
#include "../../../QuantEngine/IMarketIntentEngine.mqh"
#include "../../../QuantEngine/ITradePlannerEngine.mqh"
#include "../../../Core/DecisionEngine/IDecisionEngine.mqh"
#include <Trade/Trade.mqh>

//--- Local telemetry snapshot structures
struct X001TradeSnapshot
{
   ulong    PositionID;
   double   EntryScore;
   string   EntryReason;
   string   TradeType;
   double   EntryPrice;
   int      Direction;         // 1=Buy, -1=Sell
   double   MFE;               // Maximum Favourable Excursion (points)
   double   MAE;               // Maximum Adverse Excursion (points)
   double   Profit;
   double   HoldingTime;       // in seconds
   datetime EntryTime;
   datetime ExitTime;
   string   ExitReason;
   string   Session;           // Session at entry
   int      Hour;              // Hour of entry (0-23)
   string   MarketContext;     // Market context regime at entry
   // V4.4 — per-pillar scores stored for research
   double   PillarMovement;
   double   PillarOpportunity;
   double   PillarIntent;
   double   PillarContext;
   double   PillarVolume;
};

//--- Input Group: GITS-X X001 Strategy Settings
input group "--- GITS-X X001 High Frequency Scalper ---"
input bool     InpX001ResearchMode           = true;          // X001: Enable Research Mode
input double   InpX001ResearchMinScore       = 15.0;          // X001: Research Min Entry Score (0-100)
input double   InpX001MinEntryScore          = 55.0;          // X001: Min Composite Entry Score (0-100) (V5.5: Raised to 55.0 for high probability/profitable entries only)
input double   InpX001AggressivenessBonus    = 10.0;          // X001: Aggressiveness Bonus (flat score boost)
input int      InpX001MaxBuyPositions        = 3;             // X001: Max BUY Positions (V5.5: Reduced to 3 to limit correlation risk)
input int      InpX001MaxSellPositions       = 3;             // X001: Max SELL Positions (V5.5: Reduced to 3 to limit correlation risk)
input int      InpX001MinSpacingPoints       = 50;            // X001: Min Spacing between entries (Points) (V5.5: Increased to 50 points/5 pips)
input double   InpX001MaxTotalExposure       = 1.0;           // X001: Max Total Exposure (lots) (V5.5: Reduced to 1.0 lots to protect small capital)
input int      InpX001MaxTradesPerHour       = 1000;          // X001: Max Trades per Hour (V5.5: Raised to 1000 to remove cap limit)
input int      InpX001MaxTradesPerSession    = 5000;          // X001: Max Trades per Session (V5.5: Raised to 5000 to remove cap limit)
input double   InpX001MomentumExitThreshold  = 12.0;          // X001: Min Movement Score before exit
input int      InpX001MinExitHoldSeconds     = 60;            // X001: Min Exit Hold Seconds (V5.5)

input double   InpX001ProbeTPPoints          = 50.0;          // X001: Probe TP (Points)
input double   InpX001ProbeSLPoints          = 30.0;          // X001: Probe SL (Points)
input double   InpX001ScalpTPPoints          = 100.0;         // X001: Scalp TP (Points)
input double   InpX001ScalpSLPoints          = 50.0;          // X001: Scalp SL (Points)
input double   InpX001MomentumTPPoints       = 150.0;         // X001: Momentum TP (Points)
input double   InpX001MomentumSLPoints       = 75.0;          // X001: Momentum SL (Points)
input double   InpX001RunnerTrailPoints      = 50.0;          // X001: Runner Trailing Stop (Points)
input double   InpX001RunnerActivationPts    = 80.0;          // X001: Runner Trail Activation (Points)

input double   InpX001SidewaysTPPoints       = 60.0;          // X001: Sideways/Ranging TP override (Points)
input double   InpX001TrendTPPoints          = 150.0;         // X001: Trending/Breakout TP override (Points)

//+------------------------------------------------------------------+
//| CX001_OpportunityScalp strategy implementation                   |
//+------------------------------------------------------------------+
class CX001_OpportunityScalp : public IStrategy
{
private:
   bool                       m_enabled;
   string                     m_name;
   
   // --- Dynamic overrides (Control Center V4.4)
   bool                       m_researchMode;
   double                     m_researchMinScore;
   double                     m_minEntryScore;
   double                     m_aggressivenessBonus;
   int                        m_maxBuyPositions;
   int                        m_maxSellPositions;
   int                        m_minSpacingPoints;
   double                     m_maxTotalExposure;
   int                        m_maxTradesPerHour;
   int                        m_maxTradesPerSession;
   double                     m_momentumExitThreshold;
   int                        m_minExitHoldSeconds;   // V5.5
   CTradeMemory*              m_tradeMemory;          // V5.5
   bool                       m_useModeOverride;      // V5.5
   ENUM_EXECUTION_MODE        m_modeOverride;         // V5.5
   
   double                     m_probeTPPoints;
   double                     m_probeSLPoints;
   double                     m_scalpTPPoints;
   double                     m_scalpSLPoints;
   double                     m_momentumTPPoints;
   double                     m_momentumSLPoints;
   double                     m_runnerTrailPoints;
   double                     m_runnerActivationPts;
   double                     m_sidewaysTPPoints;
   double                     m_trendTPPoints;

   CLogger*                   m_logger;
   CConfig*                   m_config;
   CTrade                     m_trade;

   // Quant Engine references
   IOpportunityEngine*        m_opportunity;
   IMovementEngine*           m_movement;
   IMarketIntentEngine*       m_intent;
   ITradePlannerEngine*       m_planner;

   // Extra engines for composite Entry Score
   ITrendEngine*              m_trendEngine;
   IVolatilityEngine*         m_volatilityEngine;
   IVolumeEngine*             m_volumeEngine;
   IMarketContextEngine*      m_marketContext;
   ISessionEngine*            m_sessionEngine;

   // Local Telemetry Tracking
   X001TradeSnapshot          m_tradeSnapshots[];
   int                        m_snapshotCount;
   double                     m_lastEntryScore;
   string                     m_lastEntryReason;
   string                     m_lastTradeType;
   double                     m_lastPillarMV;
   double                     m_lastPillarOPP;
   double                     m_lastPillarINT;
   double                     m_lastPillarCTX;
   double                     m_lastPillarVOL;

   // Research Mode Telemetry Counters
   struct RejectionReasonCount
   {
      string Reason;
      int    Count;
   };
   RejectionReasonCount       m_rejections[];
   int                        m_rejectionCount;
   int                        m_totalOpportunities;
   int                        m_totalTradesTaken;
   int                        m_opportunitiesRejected;
   double                     m_entryScoreSum;

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

   /**
    * @brief Records a rejection reason and its frequency.
    */
   void RecordRejection(string reason)
   {
      m_opportunitiesRejected++;
      for(int i = 0; i < m_rejectionCount; i++)
      {
         if(m_rejections[i].Reason == reason)
         {
            m_rejections[i].Count++;
            return;
         }
      }
      ArrayResize(m_rejections, m_rejectionCount + 1);
      m_rejections[m_rejectionCount].Reason = reason;
      m_rejections[m_rejectionCount].Count = 1;
      m_rejectionCount++;
   }

   /**
    * @brief Translates Market Regime to string.
    */
   string GetMarketRegimeString(ENUM_MARKET_REGIME regime)
   {
      switch(regime)
      {
         case REGIME_TRENDING:    return "Trending";
         case REGIME_RANGING:     return "Ranging";
         case REGIME_BREAKOUT:    return "Breakout";
         case REGIME_REVERSAL:    return "Reversal";
         case REGIME_COMPRESSION: return "Compression";
         case REGIME_EXPANSION:   return "Expansion";
         case REGIME_TRANSITION:  return "Transition";
         default:                 return "Unknown";
      }
   }

   /**
    * @brief V4.4 — 3-Layer Direction Resolution.
    *
    * Layer 1: Use TradePlanner recommendation if definitive.
    * Layer 2: Fallback to MarketContext TrendRegime (1=Bull, -1=Bear).
    * Layer 3: Fallback to last completed candle body direction.
    * If all layers neutral → returns REC_DIR_NONE (triggers score penalty, not hard reject)
    */
   ENUM_TRADE_DIRECTION_REC ResolveDirection(const string symbol,
                                             const TradePlanContext &planCtx,
                                             const MarketContext   &marketCtx)
   {
      // Get Higher Timeframe Trends to align with (M5 and M15)
      int m5Trend  = (m_trendEngine != NULL) ? m_trendEngine.GetTrendDirection(symbol, PERIOD_M5) : 0;
      int m15Trend = (m_trendEngine != NULL) ? m_trendEngine.GetTrendDirection(symbol, PERIOD_M15) : 0;

      // Layer 1 — TradePlanner (must align with M5 or M15 trend if established)
      if(planCtx.DirectionRec == REC_DIR_BUY || planCtx.DirectionRec == REC_DIR_SELL)
      {
         bool isBuyAllowed  = (m5Trend >= 0 || m15Trend >= 0);
         bool isSellAllowed = (m5Trend <= 0 || m15Trend <= 0);
         
         if(planCtx.DirectionRec == REC_DIR_BUY  && isBuyAllowed)  return REC_DIR_BUY;
         if(planCtx.DirectionRec == REC_DIR_SELL && isSellAllowed) return REC_DIR_SELL;
      }

      // Layer 2 — Multi-Timeframe Trend Agreement
      if(m5Trend > 0 && m15Trend >= 0) return REC_DIR_BUY;
      if(m5Trend < 0 && m15Trend <= 0) return REC_DIR_SELL;

      // If higher timeframe trends are Neutral (0), we do not trade (returns NONE)
      // This removes the candle color guessing loophole entirely.
      return REC_DIR_NONE;
   }

   /**
    * @brief V4.4 — 5-Pillar Additive Composite Score (max 100 pts).
    *
    * Pillar 1 — Movement    (max 25 pts): Based on MovementState enum.
    * Pillar 2 — Opportunity (max 25 pts): Based on OpportunityClass enum.
    * Pillar 3 — Intent      (max 20 pts): Based on MarketCommitment + trap penalty.
    * Pillar 4 — Context     (max 20 pts): Based on MarketRegime enum.
    * Pillar 5 — Volume      (max 10 pts): Based on RVOL thresholds.
    *
    * Direction penalty: -10 pts if direction is unresolved (REC_DIR_NONE).
    * Aggressiveness bonus: flat +InpX001AggressivenessBonus added to final score.
    *
    * @param[out] mvScore    Pillar 1 raw score
    * @param[out] oppScore   Pillar 2 raw score
    * @param[out] intScore   Pillar 3 raw score
    * @param[out] ctxScore   Pillar 4 raw score
    * @param[out] volScore   Pillar 5 raw score
    * @returns Composite Entry Score (clamped 0–100)
    */
   double ComputeCompositeScore(const MovementContext      &movCtx,
                                const OpportunityContext   &oppCtx,
                                const MarketIntentContext  &intentCtx,
                                const MarketContext        &marketCtx,
                                ENUM_TRADE_DIRECTION_REC    direction,
                                double                     &mvScore,
                                double                     &oppScore,
                                double                     &intScore,
                                double                     &ctxScore,
                                double                     &volScore)
   {
      // --- Pillar 1: Movement (max 25)
      switch(movCtx.MovementState)
      {
         case MOVEMENT_STATE_EXPLOSIVE: mvScore = 25.0; break;
         case MOVEMENT_STATE_FAST:      mvScore = 20.0; break;
         case MOVEMENT_STATE_HEALTHY:   mvScore = 15.0; break;
         case MOVEMENT_STATE_SLOW:      mvScore =  8.0; break;
         case MOVEMENT_STATE_DEAD:
         default:                       mvScore =  0.0; break;
      }

      // --- Pillar 2: Opportunity (max 25)
      switch(oppCtx.OpportunityClass)
      {
         case OPPORTUNITY_CLASS_EXTREME:  oppScore = 25.0; break;
         case OPPORTUNITY_CLASS_HIGH:     oppScore = 20.0; break;
         case OPPORTUNITY_CLASS_MEDIUM:   oppScore = 12.0; break;
         case OPPORTUNITY_CLASS_LOW:      oppScore =  5.0; break;
         case OPPORTUNITY_CLASS_VERY_LOW:
         default:                         oppScore =  0.0; break;
      }

      // --- Pillar 3: Intent (max 20, min -5 with trap penalty)
      switch(intentCtx.MarketCommitment)
      {
         case COMMITMENT_STRONG: intScore = 20.0; break;
         case COMMITMENT_MEDIUM: intScore = 12.0; break;
         case COMMITMENT_WEAK:
         default:                intScore =  5.0; break;
      }
      // Trap penalty — directional traps reduce intent score
      bool trapActive = false;
      if(direction == REC_DIR_BUY  && intentCtx.TrapType == TRAP_BULL && intentCtx.TrapProbability > 50.0)
         trapActive = true;
      if(direction == REC_DIR_SELL && intentCtx.TrapType == TRAP_BEAR && intentCtx.TrapProbability > 50.0)
         trapActive = true;
      if(trapActive) intScore -= 5.0;

      // --- Pillar 4: Context / Regime (max 20)
      switch(marketCtx.MarketRegime)
      {
         case REGIME_TRENDING:    ctxScore = 20.0; break;
         case REGIME_BREAKOUT:    ctxScore = 18.0; break;
         case REGIME_EXPANSION:   ctxScore = 15.0; break;
         case REGIME_REVERSAL:    ctxScore = 10.0; break;
         case REGIME_RANGING:     ctxScore =  8.0; break;
         case REGIME_TRANSITION:  ctxScore =  6.0; break;
         case REGIME_COMPRESSION:
         default:                 ctxScore =  4.0; break;
      }

      // --- Pillar 5: Volume (max 10)
      double rvol = m_volumeEngine.GetRelativeVolume();
      if(rvol >= 1.5)      volScore = 10.0;
      else if(rvol >= 1.0) volScore =  7.0;
      else if(rvol >= 0.7) volScore =  4.0;
      else                 volScore =  1.0;

      // --- Direction penalty
      double dirPenalty = (direction == REC_DIR_NONE) ? -10.0 : 0.0;

      // --- V5.5: Trend Alignment Penalties
      double trendAlignmentPenalty = 0.0;
      if(marketCtx.TrendRegime != 0)
      {
         bool isDisagree = (direction == REC_DIR_BUY && marketCtx.TrendRegime < 0) ||
                           (direction == REC_DIR_SELL && marketCtx.TrendRegime > 0);
         if(isDisagree)
         {
            trendAlignmentPenalty -= 15.0; // General trend disagreement penalty
            
            // Layer 4 Confirmed Trend Check: extra penalty if not explosive movement
            if(movCtx.MovementState != MOVEMENT_STATE_EXPLOSIVE)
            {
               trendAlignmentPenalty -= 20.0; 
            }
         }
      }

      // --- V5.5: Chop & News Spike Penalties
      double chopSpikePenalty = 0.0;
      int m5Trend = (m_trendEngine != NULL) ? m_trendEngine.GetTrendDirection(_Symbol, PERIOD_M5) : 0;
      
      // Chop Penalty: if M5 is Neutral, apply a -20.0 penalty to discourage entries during ranges
      if(m5Trend == 0)
      {
         chopSpikePenalty -= 20.0;
      }
      
      // Exploding Volatility (News Spike/Drop) Guard:
      // If volatility is exploding AND volume is extremely high (typical of news release),
      // apply a heavy -40.0 penalty to block buying/selling at the peak of a wild news spike.
      if(marketCtx.VolatilityRegime == VOL_STATE_EXPLODING && rvol >= 2.5)
      {
         chopSpikePenalty -= 40.0;
      }

      // --- Assemble and clamp
      double raw = mvScore + oppScore + intScore + ctxScore + volScore + dirPenalty + trendAlignmentPenalty + chopSpikePenalty + m_aggressivenessBonus;
      return MathMax(0.0, MathMin(100.0, raw));
   }

   /**
    * @brief Determines whether the current regime is sideways (low-directional).
    */
   bool IsSidewaysRegime(ENUM_MARKET_REGIME regime)
   {
      return (regime == REGIME_RANGING || regime == REGIME_COMPRESSION);
   }

   /**
    * @brief Determines whether the current regime is trending/breakout (high-directional).
    */
   bool IsTrendingRegime(ENUM_MARKET_REGIME regime)
   {
      return (regime == REGIME_TRENDING || regime == REGIME_BREAKOUT || regime == REGIME_EXPANSION);
   }

   /**
    * @brief Caches entry snapshot mapping for high-frequency telemetry.
    */
   void CachePositionSnapshot(ulong ticket, string defaultType)
   {
      for(int i = 0; i < m_snapshotCount; i++)
      {
         if(m_tradeSnapshots[i].PositionID == ticket) return;
      }
      ArrayResize(m_tradeSnapshots, m_snapshotCount + 1);
      m_tradeSnapshots[m_snapshotCount].PositionID   = ticket;
      m_tradeSnapshots[m_snapshotCount].EntryScore   = m_lastEntryScore;
      m_tradeSnapshots[m_snapshotCount].EntryReason  = m_lastEntryReason;
      m_tradeSnapshots[m_snapshotCount].MFE          = 0.0;
      m_tradeSnapshots[m_snapshotCount].MAE          = 0.0;
      m_tradeSnapshots[m_snapshotCount].Profit       = 0.0;
      m_tradeSnapshots[m_snapshotCount].HoldingTime  = 0.0;
      m_tradeSnapshots[m_snapshotCount].ExitTime     = 0;
      m_tradeSnapshots[m_snapshotCount].ExitReason   = "";
      m_tradeSnapshots[m_snapshotCount].PillarMovement    = m_lastPillarMV;
      m_tradeSnapshots[m_snapshotCount].PillarOpportunity = m_lastPillarOPP;
      m_tradeSnapshots[m_snapshotCount].PillarIntent      = m_lastPillarINT;
      m_tradeSnapshots[m_snapshotCount].PillarContext     = m_lastPillarCTX;
      m_tradeSnapshots[m_snapshotCount].PillarVolume      = m_lastPillarVOL;

      string posType    = defaultType;
      double entryPrice = 0.0;
      int    direction  = 1;
      datetime entryTime = TimeCurrent();
      if(PositionSelectByTicket(ticket))
      {
         string comm = PositionGetString(POSITION_COMMENT);
         if(comm != "") posType = comm;
         entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         direction  = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
         entryTime  = (datetime)PositionGetInteger(POSITION_TIME);
      }
      string session = (m_sessionEngine != NULL) ? m_sessionEngine.GetCurrentSession() : "Unknown";
      MqlDateTime dt;
      TimeToStruct(entryTime, dt);

      m_tradeSnapshots[m_snapshotCount].TradeType     = posType;
      m_tradeSnapshots[m_snapshotCount].EntryPrice    = entryPrice;
      m_tradeSnapshots[m_snapshotCount].Direction     = direction;
      m_tradeSnapshots[m_snapshotCount].EntryTime     = entryTime;
      m_tradeSnapshots[m_snapshotCount].Session       = session;
      m_tradeSnapshots[m_snapshotCount].Hour          = dt.hour;
      m_tradeSnapshots[m_snapshotCount].MarketContext = GetMarketRegimeString(m_marketContext.GetContext().MarketRegime);
      m_snapshotCount++;
   }

   /**
    * @brief Dynamic position management and exit control block.
    */
   void CheckAndManageExits(const string symbol)
   {
      ulong magicNumber    = m_config.GetMagicNumber();
      int   totalPositions = PositionsTotal();

      for(int i = totalPositions - 1; i >= 0; i--)
      {
         if(PositionGetSymbol(i) == symbol)
         {
            if(PositionGetInteger(POSITION_MAGIC) == magicNumber)
            {
               ulong ticket = PositionGetInteger(POSITION_TICKET);
               CachePositionSnapshot(ticket, m_lastTradeType);

               double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
               ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
               double currentPrice = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);

               // Trailing stop logic for Runner positions
               string comment = PositionGetString(POSITION_COMMENT);
               if(comment == "X001_Runner" && m_runnerActivationPts > 0.0)
               {
                  double triggerPrice = (type == POSITION_TYPE_BUY) 
                     ? entryPrice + m_runnerActivationPts * SymbolInfoDouble(symbol, SYMBOL_POINT)
                     : entryPrice - m_runnerActivationPts * SymbolInfoDouble(symbol, SYMBOL_POINT);
                  
                  bool active = (type == POSITION_TYPE_BUY) ? (currentPrice >= triggerPrice) : (currentPrice <= triggerPrice);
                  if(active)
                  {
                     double newSL = (type == POSITION_TYPE_BUY)
                        ? currentPrice - m_runnerTrailPoints * SymbolInfoDouble(symbol, SYMBOL_POINT)
                        : currentPrice + m_runnerTrailPoints * SymbolInfoDouble(symbol, SYMBOL_POINT);
                     
                     newSL = NormalizeDouble(newSL, _Digits);
                     double currentSL = PositionGetDouble(POSITION_SL);
                     
                     bool modify = false;
                     if(type == POSITION_TYPE_BUY  && (currentSL == 0.0 || newSL > currentSL)) modify = true;
                     if(type == POSITION_TYPE_SELL && (currentSL == 0.0 || newSL < currentSL)) modify = true;
                     
                     if(modify)
                     {
                        m_trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
                     }
                  }
               }

               // Excursion tracking updates
               for(int k = 0; k < m_snapshotCount; k++)
               {
                  if(m_tradeSnapshots[k].PositionID == ticket)
                  {
                     double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
                     if(point <= 0.0) point = 0.0001;

                     double pDiff = currentPrice - entryPrice;
                     if(type == POSITION_TYPE_BUY)
                     {
                        double mfePoints = pDiff / point;
                        double maePoints = -pDiff / point;
                        if(mfePoints > m_tradeSnapshots[k].MFE) m_tradeSnapshots[k].MFE = mfePoints;
                        if(maePoints > m_tradeSnapshots[k].MAE) m_tradeSnapshots[k].MAE = maePoints;
                     }
                     else
                     {
                        double mfePoints = -pDiff / point;
                        double maePoints =  pDiff / point;
                        if(mfePoints > m_tradeSnapshots[k].MFE) m_tradeSnapshots[k].MFE = mfePoints;
                        if(maePoints > m_tradeSnapshots[k].MAE) m_tradeSnapshots[k].MAE = maePoints;
                     }
                     break;
                  }
               }

               MovementContext movement = m_movement.GetMovementContext();
               string exitReason = "";

               // V5.5: Exit when momentum collapses below configurable threshold (with minimum hold time guard)
               datetime posTime = (datetime)PositionGetInteger(POSITION_TIME);
               int durationSec = (int)(TimeCurrent() - posTime);
               if(movement.MovementScore < m_momentumExitThreshold && durationSec >= m_minExitHoldSeconds)
               {
                  exitReason = StringFormat("Momentum collapsed (%.1f < %.1f) after %ds", movement.MovementScore, m_momentumExitThreshold, durationSec);
                  m_logger.Info(StringFormat("[X001] Closing trade ticket #%I64u dynamically. Reason: %s", ticket, exitReason));
                  m_trade.PositionClose(ticket);
                  continue;
               }
            }
         }
      }
   }

   struct X001GroupStats
   {
      string Name;
      int    Total;
      int    Wins;
      int    Losses;
      double NetProfit;
      double ProfitSum;
      double LossSum;
      double HoldTimeSum;
      double MfesSum;
      double MaesSum;
   };

   /**
    * @brief Accumulates telemetry metrics for a group range.
    */
   void AccumulateX001Group(X001GroupStats &arr[], string name, double profit, double holdingSec, double mfe, double mae)
   {
      int size     = ArraySize(arr);
      int foundIdx = -1;
      for(int i = 0; i < size; i++)
      {
         if(arr[i].Name == name)
         {
            foundIdx = i;
            break;
         }
      }
      if(foundIdx == -1)
      {
         ArrayResize(arr, size + 1);
         foundIdx = size;
         arr[foundIdx].Name       = name;
         arr[foundIdx].Total      = 0;
         arr[foundIdx].Wins       = 0;
         arr[foundIdx].Losses     = 0;
         arr[foundIdx].NetProfit  = 0.0;
         arr[foundIdx].ProfitSum  = 0.0;
         arr[foundIdx].LossSum    = 0.0;
         arr[foundIdx].HoldTimeSum = 0.0;
         arr[foundIdx].MfesSum    = 0.0;
         arr[foundIdx].MaesSum    = 0.0;
      }

      arr[foundIdx].Total++;
      arr[foundIdx].NetProfit += profit;
      if(profit > 0.0)
      {
         arr[foundIdx].Wins++;
         arr[foundIdx].ProfitSum += profit;
      }
      else
      {
         arr[foundIdx].Losses++;
         arr[foundIdx].LossSum += MathAbs(profit);
      }
      arr[foundIdx].HoldTimeSum += holdingSec;
      arr[foundIdx].MfesSum += mfe;
      arr[foundIdx].MaesSum += mae;
   }

   /**
    * @brief Helper to display statistics for grouped records.
    */
   void PrintX001GroupReport(string title, X001GroupStats &arr[])
   {
      m_logger.Info("--------------------------------------------------");
      m_logger.Info(" Group-by: " + title);
      m_logger.Info("--------------------------------------------------");
      int size = ArraySize(arr);
      for(int i = 0; i < size; i++)
      {
         double winRate   = (arr[i].Total > 0) ? (arr[i].Wins / (double)arr[i].Total) * 100.0 : 0.0;
         double avgWin    = (arr[i].Wins > 0)  ? arr[i].ProfitSum / arr[i].Wins          : 0.0;
         double avgLoss   = (arr[i].Losses > 0)? arr[i].LossSum   / arr[i].Losses        : 0.0;
         double pf        = (arr[i].LossSum > 0.0) ? arr[i].ProfitSum / arr[i].LossSum : (arr[i].ProfitSum > 0.0 ? 99.9 : 0.0);
         double expectancy = (arr[i].Total > 0) ? arr[i].NetProfit / arr[i].Total        : 0.0;
         double avgHold   = (arr[i].Total > 0) ? arr[i].HoldTimeSum / arr[i].Total       : 0.0;
         double avgMFE    = (arr[i].Total > 0) ? arr[i].MfesSum / arr[i].Total           : 0.0;
         double avgMAE    = (arr[i].Total > 0) ? arr[i].MaesSum / arr[i].Total           : 0.0;

         m_logger.Info(StringFormat(" %s: Count=%d | Net=%.2f | WinRate=%.1f%% | PF=%.2f | Expectancy=%.2f",
            arr[i].Name, arr[i].Total, arr[i].NetProfit, winRate, pf, expectancy));
         m_logger.Info(StringFormat("   AvgWin=%.2f | AvgLoss=%.2f | AvgHold=%.0f sec | MFE=%.1f pts | MAE=%.1f pts",
            avgWin, avgLoss, avgHold, avgMFE, avgMAE));
      }
   }

   /**
    * @brief Audits closed deals inside history to compile segregated telemetry.
    */
   void PrintCumulativeBacktestMetrics()
   {
      if(!HistorySelect(0, TimeCurrent())) return;

      int totalDeals = HistoryDealsTotal();
      X001GroupStats tradeTypeStats[];
      X001GroupStats entryScoreStats[];
      X001GroupStats sessionStats[];
      X001GroupStats hourStats[];
      X001GroupStats contextStats[];

      double totalHoldTime   = 0.0;
      double totalMFE        = 0.0;
      double totalMAE        = 0.0;
      int    closedTradesCount = 0;

      for(int i = 0; i < totalDeals; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket == 0) continue;

         long magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
         if(magic != m_config.GetMagicNumber()) continue;

         long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
         if(entry != DEAL_ENTRY_OUT) continue;

         string comment  = HistoryDealGetString(ticket, DEAL_COMMENT);
         double profit   = HistoryDealGetDouble(ticket, DEAL_PROFIT)
                         + HistoryDealGetDouble(ticket, DEAL_SWAP)
                         + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         long   timeOut  = HistoryDealGetInteger(ticket, DEAL_TIME);

         ulong positionId = HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
         long  timeIn     = 0;
         if(HistorySelectByPosition(positionId))
         {
            int posDeals = HistoryDealsTotal();
            for(int j = 0; j < posDeals; j++)
            {
               ulong ticketIn = HistoryDealGetTicket(j);
               if(HistoryDealGetInteger(ticketIn, DEAL_ENTRY) == DEAL_ENTRY_IN)
               {
                  timeIn = HistoryDealGetInteger(ticketIn, DEAL_TIME);
                  break;
               }
            }
         }
         double holdingSec = (timeIn > 0) ? (double)(timeOut - timeIn) : 0.0;

         // Resolve snapshot telemetry parameters
         double entryScore     = 0.0;
         string entryReason    = "";
         string actualTradeType = comment;
         double mfe            = 0.0;
         double mae            = 0.0;
         string session        = "Unknown";
         int    hour           = 0;
         string context        = "Unknown";
         for(int k = 0; k < m_snapshotCount; k++)
         {
            if(m_tradeSnapshots[k].PositionID == positionId)
            {
               entryScore      = m_tradeSnapshots[k].EntryScore;
               entryReason     = m_tradeSnapshots[k].EntryReason;
               actualTradeType = m_tradeSnapshots[k].TradeType;
               mfe             = m_tradeSnapshots[k].MFE;
               mae             = m_tradeSnapshots[k].MAE;
               session         = m_tradeSnapshots[k].Session;
               hour            = m_tradeSnapshots[k].Hour;
               context         = m_tradeSnapshots[k].MarketContext;
               break;
            }
         }

         closedTradesCount++;
         totalHoldTime += holdingSec;
         totalMFE      += mfe;
         totalMAE      += mae;

         string entryRange = "";
         if(entryScore < 20.0)       entryRange = "Below 20";
         else if(entryScore < 30.0)  entryRange = "20-29";
         else if(entryScore < 40.0)  entryRange = "30-39";
         else if(entryScore < 50.0)  entryRange = "40-49";
         else if(entryScore < 60.0)  entryRange = "50-59";
         else if(entryScore < 70.0)  entryRange = "60-69";
         else if(entryScore < 80.0)  entryRange = "70-79";
         else if(entryScore < 90.0)  entryRange = "80-89";
         else                        entryRange = "90+";

         string hourStr = StringFormat("Hour %02d", hour);

         AccumulateX001Group(tradeTypeStats,  actualTradeType, profit, holdingSec, mfe, mae);
         AccumulateX001Group(entryScoreStats, entryRange,      profit, holdingSec, mfe, mae);
         AccumulateX001Group(sessionStats,    session,         profit, holdingSec, mfe, mae);
         AccumulateX001Group(hourStats,       hourStr,         profit, holdingSec, mfe, mae);
         AccumulateX001Group(contextStats,    context,         profit, holdingSec, mfe, mae);
      }

      double avgEntryScore = (m_totalOpportunities > 0) ? m_entryScoreSum / m_totalOpportunities : 0.0;
      double avgHoldTime   = (closedTradesCount > 0) ? totalHoldTime / closedTradesCount : 0.0;
      double avgMFE        = (closedTradesCount > 0) ? totalMFE / closedTradesCount : 0.0;
      double avgMAE        = (closedTradesCount > 0) ? totalMAE / closedTradesCount : 0.0;

      X001GroupStats bestScoreRange  = {}; bestScoreRange.NetProfit  = -99999.0;
      X001GroupStats worstScoreRange = {}; worstScoreRange.NetProfit =  99999.0;
      int countScores = ArraySize(entryScoreStats);
      for(int i = 0; i < countScores; i++)
      {
         if(entryScoreStats[i].NetProfit > bestScoreRange.NetProfit)  bestScoreRange  = entryScoreStats[i];
         if(entryScoreStats[i].NetProfit < worstScoreRange.NetProfit) worstScoreRange = entryScoreStats[i];
      }

      X001GroupStats bestMode  = {}; bestMode.NetProfit  = -99999.0;
      X001GroupStats worstMode = {}; worstMode.NetProfit =  99999.0;
      int countModes = ArraySize(tradeTypeStats);
      for(int i = 0; i < countModes; i++)
      {
         if(tradeTypeStats[i].NetProfit > bestMode.NetProfit)  bestMode  = tradeTypeStats[i];
         if(tradeTypeStats[i].NetProfit < worstMode.NetProfit) worstMode = tradeTypeStats[i];
      }

      X001GroupStats bestContext  = {}; bestContext.NetProfit  = -99999.0;
      X001GroupStats worstContext = {}; worstContext.NetProfit =  99999.0;
      int countContexts = ArraySize(contextStats);
      for(int i = 0; i < countContexts; i++)
      {
         if(contextStats[i].NetProfit > bestContext.NetProfit)  bestContext  = contextStats[i];
         if(contextStats[i].NetProfit < worstContext.NetProfit) worstContext = contextStats[i];
      }

      m_logger.Info("==================================================");
      m_logger.Info("   CX001_OpportunityScalp - RESEARCH MODE REPORT");
      m_logger.Info("   V4.4 - Adaptive Opportunity Consumer");
      m_logger.Info("==================================================");
      m_logger.Info(StringFormat(" Total Opportunities Detected: %d", m_totalOpportunities));
      m_logger.Info(StringFormat(" Total Trades Taken:           %d", m_totalTradesTaken));
      m_logger.Info(StringFormat(" Opportunities Rejected:       %d", m_opportunitiesRejected));
      m_logger.Info(StringFormat(" Average Composite Score:      %.1f", avgEntryScore));
      m_logger.Info(StringFormat(" Aggressiveness Bonus Applied: %.1f pts", m_aggressivenessBonus));
      m_logger.Info(StringFormat(" Min Score Threshold:          %.1f", m_researchMode ? m_researchMinScore : m_minEntryScore));
      m_logger.Info(StringFormat(" Average Holding Time:         %.0f sec", avgHoldTime));
      m_logger.Info(StringFormat(" Average MFE:                  %.1f pts", avgMFE));
      m_logger.Info(StringFormat(" Average MAE:                  %.1f pts", avgMAE));

      m_logger.Info("--------------------------------------------------");
      m_logger.Info(" Rejection Reasons Breakdown:");
      m_logger.Info("--------------------------------------------------");
      for(int k = 0; k < m_rejectionCount; k++)
      {
         m_logger.Info(StringFormat("  %s: %d", m_rejections[k].Reason, m_rejections[k].Count));
      }

      PrintX001GroupReport("TRADE TYPES",           tradeTypeStats);
      PrintX001GroupReport("ENTRY SCORE RANGES",    entryScoreStats);
      PrintX001GroupReport("SESSIONS",              sessionStats);
      PrintX001GroupReport("HOURS OF THE DAY",      hourStats);
      PrintX001GroupReport("MARKET CONTEXT REGIMES",contextStats);

      m_logger.Info("--------------------------------------------------");
      m_logger.Info(" RESEARCH MODE INSIGHTS");
      m_logger.Info("--------------------------------------------------");
      if(bestScoreRange.Name  != "") m_logger.Info(StringFormat(" Best Entry Score Range:  %s (Profit: %.2f)", bestScoreRange.Name,  bestScoreRange.NetProfit));
      if(worstScoreRange.Name != "") m_logger.Info(StringFormat(" Worst Entry Score Range: %s (Profit: %.2f)", worstScoreRange.Name, worstScoreRange.NetProfit));
      if(bestMode.Name  != "")       m_logger.Info(StringFormat(" Best Trade Type:         %s (Profit: %.2f)", bestMode.Name,  bestMode.NetProfit));
      if(worstMode.Name != "")       m_logger.Info(StringFormat(" Worst Trade Type:        %s (Profit: %.2f)", worstMode.Name, worstMode.NetProfit));
      if(bestContext.Name  != "")    m_logger.Info(StringFormat(" Best Conditions:         %s (Profit: %.2f)", bestContext.Name,  bestContext.NetProfit));
      if(worstContext.Name != "")    m_logger.Info(StringFormat(" Worst Conditions:        %s (Profit: %.2f)", worstContext.Name, worstContext.NetProfit));
      m_logger.Info("==================================================");
   }

public:
   /**
    * @brief Constructor.
    */
   CX001_OpportunityScalp(CLogger* logger, CConfig* config)
      : m_enabled(false),
        m_name("X001"),
        m_logger(logger),
        m_config(config),
        m_opportunity(NULL),
        m_movement(NULL),
        m_intent(NULL),
        m_planner(NULL),
        m_trendEngine(NULL),
        m_volatilityEngine(NULL),
        m_volumeEngine(NULL),
        m_marketContext(NULL),
        m_sessionEngine(NULL),
        m_snapshotCount(0),
        m_lastEntryScore(0.0),
        m_lastEntryReason(""),
        m_lastTradeType(""),
        m_lastPillarMV(0.0),
        m_lastPillarOPP(0.0),
        m_lastPillarINT(0.0),
        m_lastPillarCTX(0.0),
        m_lastPillarVOL(0.0),
        m_rejectionCount(0),
        m_totalOpportunities(0),
        m_totalTradesTaken(0),
        m_opportunitiesRejected(0),
        m_entryScoreSum(0.0),
        m_tradeMemory(NULL),
        m_useModeOverride(false),
        m_modeOverride(MODE_SCALP)
   {
      m_trade.SetExpertMagicNumber(m_config.GetMagicNumber());
      m_trade.SetDeviationInPoints(m_config.GetSlippagePoints());

      // Initialize overrides from compilation inputs
      m_researchMode          = InpX001ResearchMode;
      m_researchMinScore      = InpX001ResearchMinScore;
      m_minEntryScore         = InpX001MinEntryScore;
      m_aggressivenessBonus   = InpX001AggressivenessBonus;
      m_maxBuyPositions       = InpX001MaxBuyPositions;
      m_maxSellPositions      = InpX001MaxSellPositions;
      m_minSpacingPoints      = InpX001MinSpacingPoints;
      m_maxTotalExposure      = InpX001MaxTotalExposure;
      m_maxTradesPerHour      = InpX001MaxTradesPerHour;
      m_maxTradesPerSession   = InpX001MaxTradesPerSession;
      m_momentumExitThreshold = InpX001MomentumExitThreshold;
      m_minExitHoldSeconds     = InpX001MinExitHoldSeconds; // V5.5
      
      
      m_probeTPPoints         = InpX001ProbeTPPoints;
      m_probeSLPoints         = InpX001ProbeSLPoints;
      m_scalpTPPoints         = InpX001ScalpTPPoints;
      m_scalpSLPoints         = InpX001ScalpSLPoints;
      m_momentumTPPoints      = InpX001MomentumTPPoints;
      m_momentumSLPoints      = InpX001MomentumSLPoints;
      m_runnerTrailPoints     = InpX001RunnerTrailPoints;
      m_runnerActivationPts   = InpX001RunnerActivationPts;
      m_sidewaysTPPoints      = InpX001SidewaysTPPoints;
      m_trendTPPoints         = InpX001TrendTPPoints;
   }

   /**
    * @brief Destructor — prints cumulative research report on termination.
    */
   ~CX001_OpportunityScalp()
   {
      PrintCumulativeBacktestMetrics();
   }

   /**
    * @brief Initializes strategy bindings.
    */
   virtual bool Initialize(const QuantEnginesContainer &engines) override
   {
      m_opportunity      = engines.Opportunity;
      m_movement         = engines.Movement;
      m_intent           = engines.Intent;
      m_planner          = engines.Planner;
      m_trendEngine      = engines.Trend;
      m_volatilityEngine = engines.Volatility;
      m_volumeEngine     = engines.Volume;
      m_marketContext    = engines.MarketContext;
      m_sessionEngine    = engines.Session;

      if(m_opportunity == NULL || m_movement == NULL || m_intent == NULL || m_planner == NULL ||
         m_trendEngine == NULL || m_volatilityEngine == NULL || m_volumeEngine == NULL ||
         m_marketContext == NULL || m_sessionEngine == NULL)
      {
         m_logger.Error("X001 Strategy: Failed to initialize. Missing engine references.");
         return false;
      }

      m_logger.Info("X001 Strategy: OpportunityScalp Plug-in initialized successfully. [V4.4 - Adaptive Opportunity Consumer]");
      return true;
   }

   /**
    * @brief Gets Strategy Name.
    */
   virtual string GetName() const override { return m_name; }

   /**
    * @brief Strategy enablement control.
    */
   virtual void SetEnabled(bool enabled) override { m_enabled = enabled; }
   virtual bool IsEnabled() const override { return m_enabled; }

   // --- Control Center Interface Getters
   int      GetTotalOpportunities() const { return m_totalOpportunities; }
   int      GetTotalTradesTaken() const { return m_totalTradesTaken; }
   int      GetOpportunitiesRejected() const { return m_opportunitiesRejected; }
   double   GetAverageEntryScore() const { return m_totalOpportunities > 0 ? (m_entryScoreSum / m_totalOpportunities) : 0.0; }

   double GetMinEntryScore() const { return m_minEntryScore; }
   void SetMinEntryScore(double val) { m_minEntryScore = val; }
   void SetResearchMode(bool enabled) { m_researchMode = enabled; }

   virtual void SetTradeMemory(CTradeMemory* memory) { m_tradeMemory = memory; } // V5.5
   
   void SetModeOverride(bool useOverride, ENUM_EXECUTION_MODE overrideMode) // V5.5
   {
      m_useModeOverride = useOverride;
      m_modeOverride = overrideMode;
   }
   bool GetModeOverride(ENUM_EXECUTION_MODE &outMode) const // V5.5
   {
      outMode = m_modeOverride;
      return m_useModeOverride;
   }

   void OverrideConfig(const X001RuntimeConfig &cfg)
   {
      m_researchMode          = cfg.ResearchMode;
      m_researchMinScore      = cfg.ResearchMinScore;
      m_minEntryScore         = cfg.MinEntryScore;
      m_aggressivenessBonus   = cfg.AggressivenessBonus;
      m_maxBuyPositions       = cfg.MaxBuyPositions;
      m_maxSellPositions      = cfg.MaxSellPositions;
      m_minSpacingPoints      = cfg.MinSpacingPoints;
      m_maxTotalExposure      = cfg.MaxTotalExposure;
      m_maxTradesPerHour      = cfg.MaxTradesPerHour;
      m_maxTradesPerSession   = cfg.MaxTradesPerSession;
      m_momentumExitThreshold = cfg.MomentumExitThreshold;
      m_minExitHoldSeconds     = cfg.MinExitHoldSeconds; // V5.5

      m_probeTPPoints         = cfg.ProbeTPPoints;
      m_probeSLPoints         = cfg.ProbeSLPoints;
      m_scalpTPPoints         = cfg.ScalpTPPoints;
      m_scalpSLPoints         = cfg.ScalpSLPoints;
      m_momentumTPPoints      = cfg.MomentumTPPoints;
      m_momentumSLPoints      = cfg.MomentumSLPoints;
      m_runnerTrailPoints     = cfg.RunnerTrailPoints;
      m_runnerActivationPts   = cfg.RunnerActivationPts;
      m_sidewaysTPPoints      = cfg.SidewaysTPPoints;
      m_trendTPPoints         = cfg.TrendTPPoints;

      m_logger.Info("X001 Strategy: Applied runtime config overrides from Control Center.");
   }

   /**
    * @brief V4.4 — Evaluates scalping entry and exit signals on completed bars.
    *
    * Entry Decision Model:
    *   1. Resolve direction via 3-layer fallback (Planner → TrendRegime → Candle).
    *   2. Compute 5-Pillar Additive Composite Score (max 100 pts).
    *   3. Apply aggressiveness bonus and clamp.
    *   4. Compare against min threshold (Research Mode: InpX001ResearchMinScore).
    *   5. Select adaptive TP/SL based on regime (trending vs sideways).
    *   6. Apply hard resource guards (positions, spacing, exposure, rate limits).
    *   7. Log full 5-pillar breakdown for every evaluation.
    */
   virtual StrategyResponse Evaluate(const string symbol) override
   {
      StrategyResponse response;
      response.Signal        = GEV2_SIGNAL_NONE;
      response.EntryPrice    = 0.0;
      response.StopLoss      = 0.0;
      response.TakeProfit    = 0.0;
      response.Confidence    = 0.0;
      response.StrategyScore = 0.0;
      response.TradeGrade    = "D";
      response.Reason        = "No Trade";
      response.StrategyName  = m_name;

      if(!m_enabled)
      {
         response.Reason = "Strategy Disabled";
         return response;
      }

      // Manage dynamic exits on active positions
      CheckAndManageExits(symbol);

      // --- Extract engine context snapshots
      OpportunityContext  oppCtx    = m_opportunity.GetOpportunityContext();
      MovementContext     movCtx    = m_movement.GetMovementContext();
      MarketIntentContext intentCtx = m_intent.GetMarketIntentContext();
      TradePlanContext    planCtx   = m_planner.GetTradePlanContext();
      MarketContext       marketCtx = m_marketContext.GetContext();

      // --- Step 1: 3-Layer Direction Resolution
      ENUM_TRADE_DIRECTION_REC direction = ResolveDirection(symbol, planCtx, marketCtx);

      // --- Step 2: 5-Pillar Additive Composite Score
      double pillarMV = 0.0, pillarOPP = 0.0, pillarINT = 0.0, pillarCTX = 0.0, pillarVOL = 0.0;
      double entryScore = ComputeCompositeScore(movCtx, oppCtx, intentCtx, marketCtx, direction,
                                                pillarMV, pillarOPP, pillarINT, pillarCTX, pillarVOL);

      // V5.5: Apply Trade Memory modifiers for adaptive degradation
      double memMod = 0.0;
      if(m_tradeMemory != NULL)
      {
         if(direction == REC_DIR_BUY)       memMod = m_tradeMemory.GetBuyModifier();
         else if(direction == REC_DIR_SELL) memMod = m_tradeMemory.GetSellModifier();
      }
      entryScore = MathMax(0.0, entryScore + memMod);

      // --- Step 3: Determine effective min score and resource limits
      double minRequiredScore   = m_researchMode ? m_researchMinScore : m_minEntryScore;
      int    maxBuyPositions    = m_researchMode ? 20    : m_maxBuyPositions;
      int    maxSellPositions   = m_researchMode ? 20    : m_maxSellPositions;
      double minSpacingPoints   = m_researchMode ?  5.0  : (double)m_minSpacingPoints;
      int    maxTradesPerHour   = m_researchMode ? 1000  : m_maxTradesPerHour;
      int    maxTradesPerSession = m_researchMode ? 5000  : m_maxTradesPerSession;

      // --- Step 4: Count open positions and measure spacing
      int    openBuyCount      = 0;
      int    openSellCount     = 0;
      double closestBuyDiff    = 999999.0;
      double closestSellDiff   = 999999.0;
      double ask               = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double bid               = SymbolInfoDouble(symbol, SYMBOL_BID);
      ulong  magic             = m_config.GetMagicNumber();

      for(int p = 0; p < PositionsTotal(); p++)
      {
         if(PositionGetSymbol(p) == symbol && PositionGetInteger(POSITION_MAGIC) == magic)
         {
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            if(type == POSITION_TYPE_BUY)
            {
               openBuyCount++;
               double diff = MathAbs(ask - openPrice);
               if(diff < closestBuyDiff) closestBuyDiff = diff;
            }
            else if(type == POSITION_TYPE_SELL)
            {
               openSellCount++;
               double diff = MathAbs(bid - openPrice);
               if(diff < closestSellDiff) closestSellDiff = diff;
            }
         }
      }

      // --- Step 5: Evaluate hard resource guards
      bool   limitsOk    = true;
      string limitsReason = "Ok";
      if(direction == REC_DIR_BUY  && openBuyCount  >= maxBuyPositions)
      { limitsOk = false; limitsReason = "Max BUY positions limit reached";  }
      if(direction == REC_DIR_SELL && openSellCount >= maxSellPositions)
      { limitsOk = false; limitsReason = "Max SELL positions limit reached"; }

      double spacingPips = minSpacingPoints * SymbolInfoDouble(symbol, SYMBOL_POINT);
      bool   spacingOk   = true;
      if(direction == REC_DIR_BUY  && openBuyCount  > 0 && closestBuyDiff  < spacingPips) spacingOk = false;
      if(direction == REC_DIR_SELL && openSellCount > 0 && closestSellDiff < spacingPips) spacingOk = false;

      double totalLots   = 0.0;
      for(int p = 0; p < PositionsTotal(); p++)
      {
         if(PositionGetSymbol(p) == symbol && PositionGetInteger(POSITION_MAGIC) == magic)
            totalLots += PositionGetDouble(POSITION_VOLUME);
      }
      bool exposureOk     = true;
      double nextLotSize  = m_config.GetFixedLotSize();
      if(totalLots + nextLotSize > m_maxTotalExposure) exposureOk = false;

      int      tradesLastHour = 0;
      int      tradesSession  = 0;
      datetime nowTime        = TimeCurrent();
      datetime oneHourAgo     = nowTime - 3600;
      datetime sessionStart   = nowTime - 86400;

      if(HistorySelect(sessionStart, nowTime))
      {
         int deals = HistoryDealsTotal();
         for(int d = 0; d < deals; d++)
         {
            ulong deal = HistoryDealGetTicket(d);
            if(HistoryDealGetInteger(deal, DEAL_MAGIC) == magic &&
               HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_IN)
            {
               datetime dealTime = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
               if(dealTime >= oneHourAgo) tradesLastHour++;
               tradesSession++;
            }
         }
      }
      bool freqOk = (tradesLastHour < maxTradesPerHour && tradesSession < maxTradesPerSession);

      // --- Step 6: Opportunity Metrics Tracking
      m_totalOpportunities++;
      m_entryScoreSum += entryScore;

      // --- Step 7: Determine rejection reason (resource caps only — score is soft)
      string rejectionReason = "";
      if(entryScore < minRequiredScore)
         rejectionReason = StringFormat("Composite Score %.1f below min %.1f", entryScore, minRequiredScore);
      else if(!limitsOk)
         rejectionReason = limitsReason;
      else if(!spacingOk)
         rejectionReason = "Grid spacing constraint violation";
      else if(!exposureOk)
         rejectionReason = "Total strategy exposure lot cap reached";
      else if(!freqOk)
         rejectionReason = "Hourly/session trade rate limits exceeded";

      bool tradeTaken = (entryScore >= minRequiredScore && spacingOk && exposureOk && freqOk && limitsOk);

      if(tradeTaken)
         m_totalTradesTaken++;
      else
         RecordRejection(rejectionReason);

      // --- Step 8: V4.4 Audit log — full 5-pillar breakdown on every evaluation
      string rText = tradeTaken ? "YES" : "NO | Reason: " + rejectionReason;
      string dirLabel = (direction == REC_DIR_NONE) ? "None(-10)" : DirectionToString(direction);
      m_logger.Info(StringFormat(
         "[X001 Score] MV:%.0f | OPP:%.0f | INT:%.0f | CTX:%.0f | VOL:%.0f | TOTAL:%.1f | Dir:%s | Regime:%s | Taken:%s",
         pillarMV, pillarOPP, pillarINT, pillarCTX, pillarVOL, entryScore,
         dirLabel, GetMarketRegimeString(marketCtx.MarketRegime), rText));

      if(!tradeTaken)
      {
         response.Reason = StringFormat(
            "No entry: CS=%.1f (min %.1f) | Limits=%s | Spacing=%s | Exposure=%s | Freq=%s",
            entryScore, minRequiredScore,
            limitsOk   ? "Ok" : "Exceeded",
            spacingOk  ? "Ok" : "Tight",
            exposureOk ? "Ok" : "Full",
            freqOk     ? "Ok" : "Max");
         return response;
      }

      // --- Step 9: Adaptive TP/SL selection based on regime + composite score
      ENUM_EXECUTION_MODE mode = planCtx.ExecutionMode;
      if(m_useModeOverride) mode = m_modeOverride; // V5.5: Apply GUI dashboard override
      if(mode == MODE_AVOID) mode = MODE_PROBE; // Fallback

      double tpPoints = 0.0;
      double slPoints = 0.0;
      string typeName = "X001_Probe";
      string grade    = "C";

      // Base TP/SL from execution mode
      if(mode == MODE_PROBE)
      {
         tpPoints = m_probeTPPoints;
         slPoints = m_probeSLPoints;
         typeName = "X001_Probe";
         grade    = "C";
      }
      else if(mode == MODE_SCALP)
      {
         tpPoints = m_scalpTPPoints;
         slPoints = m_scalpSLPoints;
         typeName = "X001_Scalp";
         grade    = "B";
      }
      else if(mode == MODE_MOMENTUM)
      {
         tpPoints = m_momentumTPPoints;
         slPoints = m_momentumSLPoints;
         typeName = "X001_Momentum";
         grade    = "A";
      }
      else if(mode == MODE_RUNNER)
      {
         tpPoints = m_scalpTPPoints * 2.0;
         slPoints = m_scalpSLPoints;
         typeName = "X001_Runner";
         grade    = "A+";
      }

      // V4.4 Adaptive TP override based on regime
      ENUM_MARKET_REGIME regime = marketCtx.MarketRegime;
      if(IsSidewaysRegime(regime))
      {
         // Ranging/Compression — take profit fast, do not hold
         tpPoints = m_sidewaysTPPoints;
      }
      else if(IsTrendingRegime(regime) && entryScore >= 60.0)
      {
         // Strong trending regime with high composite score — extend target
         tpPoints = m_trendTPPoints;
         if(grade == "C") grade = "B"; // Upgrade grade in strong trending conditions
      }

      // --- Step 10: Calculate entry, SL, TP prices
      double entryPrice = (direction == REC_DIR_BUY) ? ask : bid;
      double tickSize   = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tickSize <= 0.0) tickSize = SymbolInfoDouble(symbol, SYMBOL_POINT);

      double slPrice = 0.0;
      double tpPrice = 0.0;
      if(direction == REC_DIR_BUY)
      {
         slPrice = entryPrice - slPoints * SymbolInfoDouble(symbol, SYMBOL_POINT);
         tpPrice = entryPrice + tpPoints * SymbolInfoDouble(symbol, SYMBOL_POINT);
      }
      else
      {
         slPrice = entryPrice + slPoints * SymbolInfoDouble(symbol, SYMBOL_POINT);
         tpPrice = entryPrice - tpPoints * SymbolInfoDouble(symbol, SYMBOL_POINT);
      }

      slPrice = NormalizeDouble(MathRound(slPrice / tickSize) * tickSize, _Digits);
      tpPrice = NormalizeDouble(MathRound(tpPrice / tickSize) * tickSize, _Digits);

      // --- Store state for snapshot caching
      m_lastEntryScore  = entryScore;
      m_lastEntryReason = StringFormat("CS=%.1f | MV:%.0f OPP:%.0f INT:%.0f CTX:%.0f VOL:%.0f | Mode:%s | Regime:%s | OpenPos=%d/%d",
         entryScore, pillarMV, pillarOPP, pillarINT, pillarCTX, pillarVOL,
         ModeToString(mode), GetMarketRegimeString(regime), openBuyCount, openSellCount);
      m_lastTradeType   = typeName;
      m_lastPillarMV    = pillarMV;
      m_lastPillarOPP   = pillarOPP;
      m_lastPillarINT   = pillarINT;
      m_lastPillarCTX   = pillarCTX;
      m_lastPillarVOL   = pillarVOL;

      // --- Populate response
      if(direction == REC_DIR_BUY)       response.Signal = GEV2_SIGNAL_BUY;
      else if(direction == REC_DIR_SELL) response.Signal = GEV2_SIGNAL_SELL;
      else                              response.Signal = GEV2_SIGNAL_NONE;
      response.EntryPrice    = entryPrice;
      response.StopLoss      = slPrice;
      response.TakeProfit    = tpPrice;
      response.Confidence    = entryScore / 100.0;
      response.StrategyScore = entryScore;
      response.RawStrategyScore = entryScore; // V5.5: Unified Decision Engine fix
      response.CompositeScore   = entryScore; // V5.5: Unified Decision Engine fix
      response.PenaltyScore     = 0.0;
      response.TradeGrade    = grade;
      response.StrategyName  = typeName;
      response.Reason        = m_lastEntryReason;

      return response;
   }
};

#endif // GOLDENGINEV2_X001_OPPORTUNITY_SCALP_MQH
