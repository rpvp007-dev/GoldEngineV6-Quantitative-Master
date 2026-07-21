//+------------------------------------------------------------------+
//|                                     ExplainabilityFramework.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_EXPLAINABILITY_FRAMEWORK_MQH
#define GOLDENGINEV2_EXPLAINABILITY_FRAMEWORK_MQH

#include "IExplainabilityFramework.mqh"
#include <Files/File.mqh>
#include "../QuantEngine/IOpportunityEngine.mqh"
#include "../QuantEngine/IMovementEngine.mqh"
#include "../QuantEngine/IMarketIntentEngine.mqh"
#include "../QuantEngine/ITradePlannerEngine.mqh"
#include "../QuantEngine/ITradeManager.mqh"
#include "../QuantEngine/IPullbackReversalEngine.mqh"
#include "../QuantEngine/IAdaptiveExitAIEngine.mqh"
#include "../QuantEngine/IInstitutionalExecutionManager.mqh"

// Structure mapping ticket to score for history correlation
struct TAcceptedTradeScoreMap
{
   ulong  Ticket;
   double Score;
   double Profit;
   bool   Closed;
};

//+------------------------------------------------------------------+
//| Concrete Explainability Framework Implementation (V2.7.1)        |
//+------------------------------------------------------------------+
class CExplainabilityFramework : public IExplainabilityFramework
{
private:
   CConfig*                   m_config;
   
   // Engine references
   ITrendEngine*              m_trend;
   IMomentumEngine*           m_momentum;
   IVolatilityEngine*         m_volatility;
   IVolumeEngine*             m_volume;
   IVwapEngine*               m_vwap;
   ILiquidityEngine*          m_liquidity;
   IPatternEngine*            m_pattern;
   ISessionEngine*            m_session;
   IMarketStructureEngine*    m_structure;
   CMarketQuality*            m_mq;
   IOpportunityEngine*        m_opportunity;
   IMovementEngine*           m_movementEngine;
   IMarketIntentEngine*       m_intentEngine;
   ITradePlannerEngine*       m_plannerEngine;
   ITradeManager*             m_tradeManager;
   IPullbackReversalEngine*   m_pullback;
   IAdaptiveExitAIEngine*     m_adaptiveExit;
   IInstitutionalExecutionManager* m_instExecution;

   // Stat counters
   int                        m_evaluatedCount;
   int                        m_acceptedCount;
   int                        m_rejectedCount;

   // V2.7.2 Decision Trace counters
   int                        m_buySignals;
   int                        m_sellSignals;
   int                        m_noTradeSignals;
   double                     m_sumMqScore;

   // Rejection reasons counters (Feature 3 additions)
   int                        m_rejRiskGuardian;
   int                        m_rejTrend;
   int                        m_rejMomentum;
   int                        m_rejVolume;
   int                        m_rejVolatility;
   int                        m_rejStructure;
   int                        m_rejLiquidity;
   int                        m_rejSession;
   int                        m_rejQuality;
   int                        m_rejStrategyScore;

   // Score Distributions counters (Feature 4 additions)
   int                        m_dist90_100;
   int                        m_dist80_89;
   int                        m_dist70_79;
   int                        m_dist60_69;
   int                        m_dist50_59;
   int                        m_distBelow50;

   // Acceptance Grade Distributions counters (Feature 5 & 7 additions)
   int                        m_gradeAPlus;
   int                        m_gradeA;
   int                        m_gradeB;
   int                        m_gradeC;
   int                        m_gradeD;

   double                     m_highestScore;
   double                     m_lowestScore;

   // Scores accumulators
   double                     m_sumStrategyScore;

   // Dynamic cache of accepted signals for win/loss mapping
   TAcceptedTradeScoreMap     m_acceptedCache[];
   int                        m_acceptedCacheSize;

   bool                       m_isInitialized;

   /**
    * @brief Helper to convert Opportunity Class to string.
    */
   string OpportunityClassToString(ENUM_OPPORTUNITY_CLASS cls)
   {
      switch(cls)
      {
         case OPPORTUNITY_CLASS_VERY_LOW: return "Very Low";
         case OPPORTUNITY_CLASS_LOW:      return "Low";
         case OPPORTUNITY_CLASS_MEDIUM:   return "Medium";
         case OPPORTUNITY_CLASS_HIGH:     return "High";
         case OPPORTUNITY_CLASS_EXTREME:  return "Extreme";
         default:                         return "None";
      }
   }

   /**
    * @brief Helper to convert Movement State to string.
    */
   string MovementStateToString(ENUM_MOVEMENT_STATE state)
   {
      switch(state)
      {
         case MOVEMENT_STATE_DEAD:      return "Dead";
         case MOVEMENT_STATE_SLOW:      return "Slow";
         case MOVEMENT_STATE_HEALTHY:   return "Healthy";
         case MOVEMENT_STATE_FAST:      return "Fast";
         case MOVEMENT_STATE_EXPLOSIVE: return "Explosive";
         default:                       return "None";
      }
   }

   /**
    * @brief Helper to convert Planner Direction to string.
    */
   string PlannerDirToString(ENUM_TRADE_DIRECTION_REC dir)
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
    * @brief Helper to convert Execution Mode to string.
    */
   string ExecutionModeToString(ENUM_EXECUTION_MODE mode)
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
    * @brief Helper to write CSV header if file is empty.
    */
   void CheckAndWriteCSVHeader()
   {
      string fileName = m_config.GetCSVExportFileName();
      int handle = FileOpen(fileName, FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ, ',');
      if(handle != INVALID_HANDLE)
      {
         ulong size = FileSize(handle);
         FileClose(handle);
         
         if(size > 0) return; // Header already exists
      }

      // Write Header with V2.7.1 columns (Feature 8) + TM V1 columns
      handle = FileOpen(fileName, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
      if(handle != INVALID_HANDLE)
      {
         string hdr = "Timestamp,Strategy,Signal,Confidence,Price,"
                     + "TrendDirection,TrendScore,EmaAlignmentConfidence,"
                     + "RSIValue,ROCValue,MomentumScore,MomentumDir,"
                     + "ATR,ATRPercentile,VolatilityScore,VolatilityRegime,"
                     + "VolumeVal,RVOL,VolumeScore,StructureState,"
                     + "LiquidityState,SessionName,MarketQualityScore,"
                     + "StrategyScore,MinRequiredScore,Decision,Reason,Entry,SL,TP,"
                     + "FilterModes,TradeGrade,AcceptanceReason,RejectionReason,"
                     + "OpportunityScore,OpportunityClass,MovementScore,MovementState,"
                     + "BuyerIntent,SellerIntent,ContinuationProb,ReversalProb,"
                     + "PlannerDirection,ExecutionMode,ExpectedRR,TradeConfidence,"
                     + "TM_TrackingCount,TM_BreakEvenActive,TM_TrailingActive,TM_LockedProfit,"
                     + "TM_HealthScore,TM_HealthState,TM_HealthNarrative,"
                     + "PB_State,PB_ContinuationProb,PB_ReversalProb,PB_BreakoutAuth,PB_Recommendation,PB_Narrative,PB_Confidence,"
                     + "AE_Recommendation,AE_Confidence,AE_Narrative,AE_HoldScore,AE_ExitScore,AE_RunnerScore,AE_RiskLevel,AE_ExpectedRemainingMove,AE_RecommendedStop,AE_RecommendedTrail,"
                     + "IE_Recommendation,IE_PortfolioHealth,IE_TotalExposure,IE_LongExposure,IE_ShortExposure,IE_NetExposure,IE_ActiveScouts,IE_ActiveScalps,IE_ActiveMomentums,IE_ActiveRunners,IE_CapitalAllocation,IE_PriorityScore";
         FileWriteString(handle, hdr + "\n");

         FileClose(handle);
      }
   }

public:
   /**
    * @brief Constructor.
    */
   CExplainabilityFramework()
      : m_config(NULL),
        m_trend(NULL), m_momentum(NULL), m_volatility(NULL), m_volume(NULL),
        m_vwap(NULL), m_liquidity(NULL), m_pattern(NULL), m_session(NULL),
        m_structure(NULL), m_mq(NULL), m_opportunity(NULL), m_movementEngine(NULL), m_intentEngine(NULL), m_plannerEngine(NULL),
        m_tradeManager(NULL),
        m_evaluatedCount(0), m_acceptedCount(0), m_rejectedCount(0),
        m_buySignals(0), m_sellSignals(0), m_noTradeSignals(0), m_sumMqScore(0.0),
        m_rejRiskGuardian(0),
        m_rejTrend(0), m_rejMomentum(0), m_rejVolume(0), m_rejVolatility(0),
        m_rejStructure(0), m_rejLiquidity(0), m_rejSession(0), m_rejQuality(0), m_rejStrategyScore(0),
        m_dist90_100(0), m_dist80_89(0), m_dist70_79(0), m_dist60_69(0), m_dist50_59(0), m_distBelow50(0),
        m_gradeAPlus(0), m_gradeA(0), m_gradeB(0), m_gradeC(0), m_gradeD(0),
        m_highestScore(0.0), m_lowestScore(100.0),
        m_sumStrategyScore(0.0), m_acceptedCacheSize(0),
        m_isInitialized(false)
   {
      ArrayResize(m_acceptedCache, 0);
   }

   /**
    * @brief Destructor.
    */
   ~CExplainabilityFramework() {}

   /**
    * @brief Initializer.
    */
   virtual bool Initialize(
      CConfig*                config,
      const QuantEnginesContainer &engines,
      CMarketQuality*         mq) override
   {
      m_config     = config;
      m_trend      = engines.Trend;
      m_momentum   = engines.Momentum;
      m_volatility = engines.Volatility;
      m_volume     = engines.Volume;
      m_vwap       = engines.Vwap;
      m_liquidity  = engines.Liquidity;
      m_pattern    = engines.Pattern;
      m_session    = engines.Session;
      m_structure  = engines.MarketStructure;
      m_mq         = mq;
      m_opportunity= engines.Opportunity;
      m_movementEngine = engines.Movement;
      m_intentEngine = engines.Intent;
      m_plannerEngine = engines.Planner;
      m_tradeManager = engines.TradeManager;
      m_pullback = engines.PullbackReversal;
      m_adaptiveExit = engines.AdaptiveExit;
      m_instExecution = engines.InstitutionalExecution;

      if(m_config == NULL || m_trend == NULL || m_momentum == NULL || m_volatility == NULL ||
         m_volume == NULL || m_liquidity == NULL || m_session == NULL || m_structure == NULL || m_mq == NULL)
      {
         m_isInitialized = false;
         return false;
      }

      m_isInitialized = true;
      CheckAndWriteCSVHeader();
      return true;
   }

   /**
    * @brief Registers and correlates an accepted trade ticket with its strategy score.
    */
   void RecordAcceptedTradeTicket(ulong ticket, double score)
   {
      m_acceptedCacheSize++;
      ArrayResize(m_acceptedCache, m_acceptedCacheSize);
      m_acceptedCache[m_acceptedCacheSize - 1].Ticket = ticket;
      m_acceptedCache[m_acceptedCacheSize - 1].Score = score;
      m_acceptedCache[m_acceptedCacheSize - 1].Profit = 0.0;
      m_acceptedCache[m_acceptedCacheSize - 1].Closed = false;
   }

   /**
    * @brief Dynamic audit: logs the decision metrics.
    */
   virtual void LogDecision(
      const StrategyResponse  &response,
      const RiskAuditResponse &riskResponse,
      bool                    riskPassed) override
   {
      if(!m_isInitialized || !m_config.IsExplainabilityEnabled()) return;

      m_evaluatedCount++;

      // V2.7.2: Track signal type counters
      if(response.Signal == GEV2_SIGNAL_BUY)       m_buySignals++;
      else if(response.Signal == GEV2_SIGNAL_SELL)  m_sellSignals++;
      else                                          m_noTradeSignals++;

      // 1. Gather all Quant Metrics
      double trendScore = m_trend.GetTrendStrength(_Symbol, _Period);
      int trendDir = m_trend.GetTrendDirection(_Symbol, _Period);
      double alignmentConf = m_trend.GetEmaAlignmentConfidence(_Symbol, _Period);
      
      double rsiVal = m_momentum.GetRSIValue(1);
      double rocVal = m_momentum.GetROCValue(1);
      double momentumScore = m_momentum.GetMomentumScore();
      string momentumDir = m_momentum.GetMomentumDirectionDesc();

      double atr = m_volatility.GetATR(_Symbol, _Period, 14, 1);
      double atrPercentile = m_volatility.GetATRPercentile(_Symbol, _Period, 14);
      double volatilityScore = m_volatility.GetVolatilityScore(_Symbol, _Period);
      string volatilityRegime = m_volatility.GetVolatilityRegime(_Symbol, _Period);
      
      long volumeVal = m_volume.GetTicksVolume(_Symbol, _Period, 1);
      double rvol = m_volume.GetRelativeVolume();
      double volumeScore = m_volume.GetVolumeStrengthScore();

      string structState = m_structure.GetStructureState();

      bool buySweep = false, sellSweep = false;
      m_liquidity.IsLiquiditySweep(buySweep, sellSweep);
      string liquidityText = "Normal";
      if(m_liquidity.IsStopHuntActive()) liquidityText = "StopHunt";
      else if(buySweep || sellSweep) liquidityText = "Sweep";

      string session = m_session.GetCurrentSession();
      double mqScore = m_mq.CalculateMarketQualityScore();
      m_sumMqScore += mqScore;

      double strategyScore = response.StrategyScore;
      m_sumStrategyScore += strategyScore;

      // Track high/low scores
      if(strategyScore > m_highestScore) m_highestScore = strategyScore;
      if(strategyScore < m_lowestScore)  m_lowestScore = strategyScore;

      // Update Score Distributions (Feature 4)
      if(strategyScore >= 90.0)      m_dist90_100++;
      else if(strategyScore >= 80.0) m_dist80_89++;
      else if(strategyScore >= 70.0) m_dist70_79++;
      else if(strategyScore >= 60.0) m_dist60_69++;
      else if(strategyScore >= 50.0) m_dist50_59++;
      else                           m_distBelow50++;

      bool decision = (response.Signal != GEV2_SIGNAL_NONE && riskPassed);
      string finalReason = response.Reason;
      if(response.Signal != GEV2_SIGNAL_NONE && !riskPassed)
      {
         finalReason = "Risk Guardian Blocked: " + riskResponse.Reason;
      }

      // Feature 6: Trade Grade Assignment
      string grade = response.TradeGrade;
      if(grade == "")
      {
         grade = "D";
         if(strategyScore >= 95.0)      grade = "A+";
         else if(strategyScore >= 90.0) grade = "A";
         else if(strategyScore >= 80.0) grade = "B";
         else if(strategyScore >= 70.0) grade = "C";
      }

      // 2. Increment counters based on decision outcomes (Feature 3 & 5)
      if(decision)
      {
         m_acceptedCount++;
         
         // Track Accepted Grades (Feature 7)
         if(grade == "A+")      m_gradeAPlus++;
         else if(grade == "A")  m_gradeA++;
         else if(grade == "B")  m_gradeB++;
         else if(grade == "C")  m_gradeC++;
         else                   m_gradeD++;
      }
      else
      {
         m_rejectedCount++;

         // Check if rejected by Risk Guardian
         if(response.Signal != GEV2_SIGNAL_NONE && !riskPassed)
         {
            m_rejRiskGuardian++;
         }
         else // Rejected by strategy filters
         {
            // Evaluate each active filter block independently to count rejections (Feature 3)
            // Trend
            if(m_config.GetS002_ModeTrend() != FILTER_MODE_DISABLED)
            {
               bool trendPassed = (trendDir != 0 && trendScore >= m_config.GetS002_MinTrendStrength());
               if(!trendPassed) m_rejTrend++;
            }
            // Momentum
            if(m_config.GetS002_ModeMomentum() != FILTER_MODE_DISABLED)
            {
               bool momentumPassed = false;
               if(trendDir > 0 && rsiVal > 50.0) momentumPassed = true;
               else if(trendDir < 0 && rsiVal < 50.0) momentumPassed = true;
               if(!momentumPassed) m_rejMomentum++;
            }
            // Volume
            if(m_config.GetS002_ModeVolume() != FILTER_MODE_DISABLED)
            {
               bool volumePassed = (rvol >= m_config.GetS002_MinRvol());
               if(!volumePassed) m_rejVolume++;
            }
            // Volatility
            if(m_config.GetS002_ModeVolatility() != FILTER_MODE_DISABLED)
            {
               bool volatilityPassed = (volatilityRegime == "Normal" || volatilityRegime == "High");
               if(!volatilityPassed) m_rejVolatility++;
            }
            // Structure
            if(m_config.GetS002_ModeStructure() != FILTER_MODE_DISABLED)
            {
               bool structurePassed = false;
               if(trendDir > 0 && structState == "Bullish") structurePassed = true;
               else if(trendDir < 0 && structState == "Bearish") structurePassed = true;
               if(!structurePassed) m_rejStructure++;
            }
            // Liquidity
            if(m_config.GetS002_ModeLiquidity() != FILTER_MODE_DISABLED)
            {
               bool liquidityPassed = (m_liquidity.IsStopHuntActive() || buySweep || sellSweep || m_liquidity.IsLiquidityPresent());
               if(!liquidityPassed) m_rejLiquidity++;
            }
            // Session
            if(m_config.GetS002_ModeSession() != FILTER_MODE_DISABLED)
            {
               bool sessionPassed = (session == "LONDON SESSION" || session == "NEW YORK SESSION" || session == "LONDON/NEWYORK OVERLAP");
               if(!sessionPassed) m_rejSession++;
            }
            // Quality
            if(m_config.GetS002_ModeQuality() != FILTER_MODE_DISABLED)
            {
               bool qualityPassed = (mqScore >= m_config.GetS002_MinMqScore());
               if(!qualityPassed) m_rejQuality++;
            }

            // Check if score threshold itself failed
            if(strategyScore < m_config.GetS002_MinScore())
            {
               m_rejStrategyScore++;
            }
         }
      }

      // Feature 8: Columns appending
      string modesStr = StringFormat("Trend=%d;Mom=%d;Volm=%d;Volt=%d;Stru=%d;Liqd=%d;Sess=%d;Qual=%d",
         m_config.GetS002_ModeTrend(),
         m_config.GetS002_ModeMomentum(),
         m_config.GetS002_ModeVolume(),
         m_config.GetS002_ModeVolatility(),
         m_config.GetS002_ModeStructure(),
         m_config.GetS002_ModeLiquidity(),
         m_config.GetS002_ModeSession(),
         m_config.GetS002_ModeQuality()
      );

      // Extract Trade Manager Data
      int tmCount = 0;
      bool tmBE = false;
      bool tmTrail = false;
      double tmLocked = 0.0;
      double tmHealthScore = 0.0;
      string tmHealthState = "Stable";
      string tmHealthNarrative = "No active trade.";
      if(m_tradeManager != NULL)
      {
         tmCount = m_tradeManager.GetActiveTrackingCount();
         if(tmCount > 0)
         {
            TradeTrackingState tmState;
            if(m_tradeManager.GetTrackingState(0, tmState))
            {
               tmBE = tmState.BreakEvenActive;
               tmTrail = tmState.TrailingActive;
               tmLocked = tmState.LockedProfitPoints;
               tmHealthScore = tmState.HealthScore;
               tmHealthState = tmState.HealthStateStr;
               tmHealthNarrative = tmState.HealthNarrative;
            }
         }
      }

      // Extract Pullback vs Reversal details
      string pbState = "None";
      double pbCont = 0.0;
      double pbRev = 0.0;
      double pbBreakoutAuth = 0.0;
      string pbRec = "WAIT";
      string pbNarrative = "None";
      double pbConf = 0.0;
      if(m_pullback != NULL)
      {
         PullbackReversalContext pbCtx = m_pullback.GetEvaluationContext();
         pbState = PullbackStateToString(pbCtx.State);
         pbCont = pbCtx.ContinuationProb;
         pbRev = pbCtx.ReversalProb;
         pbBreakoutAuth = pbCtx.BreakoutAuthenticity;
         pbRec = PullbackRecToString(pbCtx.Recommendation);
         pbNarrative = pbCtx.Narrative;
         pbConf = pbCtx.Confidence;
      }

      // Extract Adaptive Exit AI details
      string aeRec = "WAIT";
      double aeConf = 0.0;
      string aeNarrative = "None";
      double aeHold = 0.0;
      double aeExitVal = 0.0;
      double aeRunner = 0.0;
      string aeRisk = "Low";
      double aeExpectedMove = 0.0;
      double aeRecStop = 0.0;
      double aeRecTrail = 0.0;
      if(m_adaptiveExit != NULL)
      {
         AdaptiveExitContext aeCtx = m_adaptiveExit.GetExitContext();
         aeRec = AdaptiveExitActionToString(aeCtx.Recommendation);
         aeConf = aeCtx.Confidence;
         aeNarrative = aeCtx.Narrative;
         aeHold = aeCtx.HoldScore;
         aeExitVal = aeCtx.ExitScore;
         aeRunner = aeCtx.RunnerScore;
         aeRisk = aeCtx.RiskLevel;
         aeExpectedMove = aeCtx.ExpectedRemainingMove;
         aeRecStop = aeCtx.RecommendedStop;
         aeRecTrail = aeCtx.RecommendedTrail;
      }

      // Extract Institutional Execution details
      string ieRec = "WAIT";
      double ieHealth = 100.0;
      double ieExposure = 0.0;
      double ieLong = 0.0;
      double ieShort = 0.0;
      double ieNet = 0.0;
      int ieScouts = 0;
      int ieScalps = 0;
      int ieMomentums = 0;
      int ieRunners = 0;
      double ieAlloc = 0.0;
      double iePriority = 0.0;
      if(m_instExecution != NULL)
      {
         InstitutionalExecutionContext ieCtx = m_instExecution.GetExecutionContext();
         ieRec = InstitutionalExecActionToString(ieCtx.Recommendation);
         ieHealth = ieCtx.PortfolioHealth;
         ieExposure = ieCtx.TotalExposure;
         ieLong = ieCtx.LongExposure;
         ieShort = ieCtx.ShortExposure;
         ieNet = ieCtx.NetExposure;
         ieScouts = ieCtx.ActiveScouts;
         ieScalps = ieCtx.ActiveScalps;
         ieMomentums = ieCtx.ActiveMomentums;
         ieRunners = ieCtx.ActiveRunners;
         ieAlloc = ieCtx.CapitalAllocation;
         iePriority = ieCtx.PriorityScore;
      }

      // 3. Export record to CSV
      string fileName = m_config.GetCSVExportFileName();
      int handle = FileOpen(fileName, FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_SHARE_READ, ',');
      if(handle != INVALID_HANDLE)
      {
         FileSeek(handle, 0, SEEK_END);
         string oppScore   = (m_opportunity    != NULL) ? DoubleToString(m_opportunity.GetOpportunityContext().OpportunityScore, 1) : "0.0";
         string oppClass   = (m_opportunity    != NULL) ? OpportunityClassToString(m_opportunity.GetOpportunityContext().OpportunityClass) : "None";
         string mvScore    = (m_movementEngine != NULL) ? DoubleToString(m_movementEngine.GetMovementContext().MovementScore, 1) : "0.0";
         string mvStatStr  = (m_movementEngine != NULL) ? MovementStateToString(m_movementEngine.GetMovementContext().MovementState) : "None";
         string buyInt     = (m_intentEngine   != NULL) ? DoubleToString(m_intentEngine.GetMarketIntentContext().BuyerIntent, 1) : "0.0";
         string sellInt    = (m_intentEngine   != NULL) ? DoubleToString(m_intentEngine.GetMarketIntentContext().SellerIntent, 1) : "0.0";
         string contProb   = (m_intentEngine   != NULL) ? DoubleToString(m_intentEngine.GetMarketIntentContext().ContinuationProb, 1) : "0.0";
         string revProb    = (m_intentEngine   != NULL) ? DoubleToString(m_intentEngine.GetMarketIntentContext().ReversalProb, 1) : "0.0";
         string planDir    = (m_plannerEngine  != NULL) ? PlannerDirToString(m_plannerEngine.GetTradePlanContext().DirectionRec) : "None";
         string planMode   = (m_plannerEngine  != NULL) ? ExecutionModeToString(m_plannerEngine.GetTradePlanContext().ExecutionMode) : "Avoid";
         string planRR     = (m_plannerEngine  != NULL) ? DoubleToString(m_plannerEngine.GetTradePlanContext().ExpectedRR, 2) : "1.0";
         string planConf   = (m_plannerEngine  != NULL) ? DoubleToString(m_plannerEngine.GetTradePlanContext().TradeConfidence, 1) : "0.0";

         string row = TimeToString(TimeCurrent()) + ","
            + response.StrategyName + ","
            + ((response.Signal == GEV2_SIGNAL_BUY) ? "BUY" : ((response.Signal == GEV2_SIGNAL_SELL) ? "SELL" : "NONE")) + ","
            + DoubleToString(response.Confidence, 2) + ","
            + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), 2) + ","
            + (string)trendDir + ","
            + DoubleToString(trendScore, 1) + ","
            + DoubleToString(alignmentConf, 1) + ","
            + DoubleToString(rsiVal, 1) + ","
            + DoubleToString(rocVal, 2) + ","
            + DoubleToString(momentumScore, 1) + ","
            + momentumDir + ","
            + DoubleToString(atr, 2) + ","
            + DoubleToString(atrPercentile, 1) + ","
            + DoubleToString(volatilityScore, 1) + ","
            + volatilityRegime + ","
            + (string)volumeVal + ","
            + DoubleToString(rvol, 2) + ","
            + DoubleToString(volumeScore, 1) + ","
            + structState + ","
            + liquidityText + ","
            + session + ","
            + DoubleToString(mqScore, 1) + ","
            + DoubleToString(strategyScore, 1) + ","
            + DoubleToString(m_config.GetS002_MinScore(), 1) + ","
            + (decision ? "ACCEPTED" : "REJECTED") + ","
            + finalReason + ","
            + DoubleToString(response.EntryPrice, 2) + ","
            + DoubleToString(response.StopLoss, 2) + ","
            + DoubleToString(response.TakeProfit, 2) + ","
            + modesStr + ","
            + grade + ","
            + (decision ? finalReason : "") + ","
            + (decision ? "" : finalReason) + ","
            + oppScore + "," + oppClass + ","
            + mvScore + "," + mvStatStr + ","
            + buyInt + "," + sellInt + ","
            + contProb + "," + revProb + ","
            + planDir + "," + planMode + ","
            + planRR + "," + planConf + ","
            + (string)tmCount + ","
            + (tmBE    ? "True" : "False") + ","
            + (tmTrail ? "True" : "False") + ","
            + DoubleToString(tmLocked, 1) + ","
            + DoubleToString(tmHealthScore, 1) + ","
            + tmHealthState + ","
            + tmHealthNarrative + ","
            + pbState + ","
            + DoubleToString(pbCont, 1) + ","
            + DoubleToString(pbRev, 1) + ","
            + DoubleToString(pbBreakoutAuth, 1) + ","
            + pbRec + ","
            + pbNarrative + ","
            + DoubleToString(pbConf, 1) + ","
            + aeRec + ","
            + DoubleToString(aeConf, 1) + ","
            + aeNarrative + ","
            + DoubleToString(aeHold, 1) + ","
            + DoubleToString(aeExitVal, 1) + ","
            + DoubleToString(aeRunner, 1) + ","
            + aeRisk + ","
            + DoubleToString(aeExpectedMove, 1) + ","
            + DoubleToString(aeRecStop, 2) + ","
            + DoubleToString(aeRecTrail, 1) + ","
            + ieRec + ","
            + DoubleToString(ieHealth, 1) + ","
            + DoubleToString(ieExposure, 2) + ","
            + DoubleToString(ieLong, 2) + ","
            + DoubleToString(ieShort, 2) + ","
            + DoubleToString(ieNet, 2) + ","
            + (string)ieScouts + ","
            + (string)ieScalps + ","
            + (string)ieMomentums + ","
            + (string)ieRunners + ","
            + DoubleToString(ieAlloc, 2) + ","
            + DoubleToString(iePriority, 1);
         FileWriteString(handle, row + "\n");

         FileClose(handle);
      }
   }

   /**
    * @brief Compiles deals history to output wins/losses score averages.
    */
   void ParseDealsHistory(double &outWinAvgScore, double &outLossAvgScore)
   {
      outWinAvgScore = 0.0;
      outLossAvgScore = 0.0;

      if(m_acceptedCacheSize <= 0) return;

      if(HistorySelect(0, TimeCurrent()))
      {
         int dealCount = HistoryDealsTotal();
         for(int i = 0; i < dealCount; i++)
         {
            ulong dealTicket = HistoryDealGetTicket(i);
            long magic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
            
            if(magic != m_config.GetMagicNumber()) continue;

            long positionID = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
            double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);

            for(int j = 0; j < m_acceptedCacheSize; j++)
            {
               if(m_acceptedCache[j].Ticket == (ulong)positionID || m_acceptedCache[j].Ticket == dealTicket)
               {
                  m_acceptedCache[j].Profit += profit;
                  m_acceptedCache[j].Closed = true;
               }
            }
         }
      }

      double winSum = 0.0, lossSum = 0.0;
      int winCount = 0, lossCount = 0;

      for(int i = 0; i < m_acceptedCacheSize; i++)
      {
         if(m_acceptedCache[i].Closed)
         {
            if(m_acceptedCache[i].Profit > 0.0)
            {
               winSum += m_acceptedCache[i].Score;
               winCount++;
            }
            else
            {
               lossSum += m_acceptedCache[i].Score;
               lossCount++;
            }
         }
      }

      if(winCount > 0)  outWinAvgScore = winSum / winCount;
      if(lossCount > 0) outLossAvgScore = lossSum / lossCount;
   }

   /**
    * @brief Generates backtest summary (Research Dashboard / Backtest Research Report) to the journal.
    */
   virtual void GenerateDashboardSummary() override
   {
      if(!m_isInitialized) return;

      double winAvg = 0.0, lossAvg = 0.0;
      ParseDealsHistory(winAvg, lossAvg);

      double acceptanceRate = (m_evaluatedCount > 0) ? ((double)m_acceptedCount / m_evaluatedCount) * 100.0 : 0.0;
      double rejectionRate = (m_evaluatedCount > 0) ? ((double)m_rejectedCount / m_evaluatedCount) * 100.0 : 0.0;
      double avgScore = (m_evaluatedCount > 0) ? m_sumStrategyScore / m_evaluatedCount : 0.0;
      double avgMq = (m_evaluatedCount > 0) ? m_sumMqScore / m_evaluatedCount : 0.0;

      // Find top rejection reason
      string topRejName = "None";
      int topRejCount = 0;
      if(m_rejStrategyScore > topRejCount) { topRejCount = m_rejStrategyScore; topRejName = "Strategy Score < Threshold"; }
      if(m_rejTrend > topRejCount)         { topRejCount = m_rejTrend;         topRejName = "Trend Filter"; }
      if(m_rejMomentum > topRejCount)      { topRejCount = m_rejMomentum;      topRejName = "Momentum Filter"; }
      if(m_rejVolume > topRejCount)        { topRejCount = m_rejVolume;        topRejName = "Volume Filter"; }
      if(m_rejVolatility > topRejCount)    { topRejCount = m_rejVolatility;    topRejName = "Volatility Filter"; }
      if(m_rejStructure > topRejCount)     { topRejCount = m_rejStructure;     topRejName = "Structure Filter"; }
      if(m_rejLiquidity > topRejCount)     { topRejCount = m_rejLiquidity;     topRejName = "Liquidity Filter"; }
      if(m_rejSession > topRejCount)       { topRejCount = m_rejSession;       topRejName = "Session Filter"; }
      if(m_rejQuality > topRejCount)       { topRejCount = m_rejQuality;       topRejName = "Quality Filter"; }
      if(m_rejRiskGuardian > topRejCount)  { topRejCount = m_rejRiskGuardian;  topRejName = "Risk Guardian"; }

      Print("==========================");
      Print("BACKTEST SUMMARY");
      Print("==========================");
      Print(StringFormat("Candles Evaluated:         %d", m_evaluatedCount));
      Print(StringFormat("BUY Signals:               %d", m_buySignals));
      Print(StringFormat("SELL Signals:              %d", m_sellSignals));
      Print(StringFormat("NO_TRADE Signals:          %d", m_noTradeSignals));
      Print(StringFormat("Signals Accepted:          %d (%.2f%%)", m_acceptedCount, acceptanceRate));
      Print(StringFormat("Signals Rejected:          %d (%.2f%%)", m_rejectedCount, rejectionRate));
      Print("--------------------------");
      Print(StringFormat("Top Rejection Reason:      %s (%d)", topRejName, topRejCount));
      Print("--------------------------");
      Print("Filter Rejection Counts:");
      Print(StringFormat("  Trend:                   %d", m_rejTrend));
      Print(StringFormat("  Momentum:                %d", m_rejMomentum));
      Print(StringFormat("  Volume:                  %d", m_rejVolume));
      Print(StringFormat("  Volatility:              %d", m_rejVolatility));
      Print(StringFormat("  Structure:               %d", m_rejStructure));
      Print(StringFormat("  Liquidity:               %d", m_rejLiquidity));
      Print(StringFormat("  Session:                 %d", m_rejSession));
      Print(StringFormat("  Quality:                 %d", m_rejQuality));
      Print(StringFormat("  Score < Threshold:       %d", m_rejStrategyScore));
      Print(StringFormat("  Risk Guardian:           %d", m_rejRiskGuardian));
      Print("--------------------------");
      Print(StringFormat("Average Strategy Score:    %.1f", avgScore));
      Print(StringFormat("Average Market Quality:    %.1f", avgMq));
      Print(StringFormat("Average Winning Score:     %.1f", winAvg));
      Print(StringFormat("Average Losing Score:      %.1f", lossAvg));
      Print(StringFormat("Highest Score Evaluated:   %.1f", m_highestScore));
      Print(StringFormat("Lowest Score Evaluated:    %.1f", m_lowestScore));
      Print("------------------------ SCORE DISTRIBUTION -------------------------");
      Print(StringFormat("  90-100:                  %d", m_dist90_100));
      Print(StringFormat("  80-89:                   %d", m_dist80_89));
      Print(StringFormat("  70-79:                   %d", m_dist70_79));
      Print(StringFormat("  60-69:                   %d", m_dist60_69));
      Print(StringFormat("  50-59:                   %d", m_dist50_59));
      Print(StringFormat("  Below 50:                %d", m_distBelow50));
      Print("--------------------- ACCEPTED GRADE DISTRIBUTION -------------------");
      Print(StringFormat("  A+ (95+):                %d", m_gradeAPlus));
      Print(StringFormat("  A  (90-94):              %d", m_gradeA));
      Print(StringFormat("  B  (80-89):              %d", m_gradeB));
      Print(StringFormat("  C  (70-79):              %d", m_gradeC));
      Print(StringFormat("  D  (Below 70):           %d", m_gradeD));
      Print("==========================");
   }
};

#endif // GOLDENGINEV2_EXPLAINABILITY_FRAMEWORK_MQH
