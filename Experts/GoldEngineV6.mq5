//+------------------------------------------------------------------+
//|                                               GoldEngineV6.mq5   |
//|                                  Copyright 2026, GoldEngine V6   |
//|        https://github.com/rpvp007-dev/GoldEngineV6-Quantitative-Master |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, GoldEngine V6"
#property link      "https://github.com/rpvp007-dev/GoldEngineV6-Quantitative-Master"
#property version   "6.00"
#property description "GoldEngine V6: Quantitative Multi-Regime Master Architecture"

//--- Include core enums first to allow inputs declarations
#include "../Include/GoldEngineV4/Core/CoreDefines.mqh"
#include "../Include/GoldEngineV4/QuantEngine/TradeManagerDefines.mqh"
#include "../Include/GoldEngineV4/QuantEngine/MarketRegimeEngine.mqh"
#include "../Include/GoldEngineV4/QuantEngine/DynamicTargetEngine.mqh"
#include "../Include/GoldEngineV4/QuantEngine/LiquidityMatrixEngine.mqh"

//--- Input Group: Trading Profile
input group "--- Trading Profile ---"
input ENUM_TRADING_PROFILE InpTradingProfile = PROFILE_RESEARCH; // Trading Profile (Research = No Restrictions)

//--- Input Group: General Configuration
input group "--- General Settings ---"
input ulong    InpMagicNumber       = 999123;         // Magic Number
input string   InpLogsFileName      = "GITS_V7";      // Logs File Prefix
input bool     InpAutoTrading       = true;           // Enable Auto Trading
input bool     InpDebugMode         = true;           // Enable Quant & Risk Debug Prints

//--- Input Group: === 💰 CORE RISK & CAPITAL LOCK SETTINGS ===
input group "=== 💰 CORE RISK & CAPITAL LOCK SETTINGS ==="
input double   InpRiskPercent            = 1.0;            // [RISK] Risk Percent per Trade
input double   InpGrowthMultiplier       = 1.0;            // [RISK] Dynamic Lot Growth Multiplier (1.0x Safe, 1.5x Fast, 2.0x Turbo)
input bool     InpUseFixedLot            = false;          // [RISK] Use Fixed Lot Sizing
input double   InpFixedLotSize           = 0.1;            // [RISK] Fixed Lot Size
input bool     InpUseCompoundingLot      = false;          // [RISK] Enable $50 Compounding Lot Sizing (Disabled for Capital Preservation)
input bool     InpCompoundOnTotalBalance = true;           // [RISK] Compound on Total Balance (vs Unlocked Buffer)
input int      InpSlippagePoints         = 30;             // [RISK] Slippage (Points)
input bool     InpEnableCapitalLock      = false;          // [RISK] Enable Trailing Capital Lock (Off by default for small accounts)
input double   InpCapitalLockTrigger     = 150.0;          // [RISK] Capital Lock Trigger Balance ($) (V5.5)
input double   InpCapitalLockFloor       = 20.0;           // [RISK] Protected Capital Floor ($) (Lowered to $20.00)
input bool     InpAutoCapitalLock        = false;          // [RISK] Enable Auto-Trailing Capital Lock (Off by default)
input double   InpLockStepUSD            = 50.0;           // [RISK] Profit Step to Lock Next Level (USD)
input double   InpRiskProfitPercent      = 50.0;           // [RISK] Percentage of Profit to Risk (0-100%)

//--- Input Group: === 🏆 BESPOKE GOLD STRATEGIES (G-001 to G-005) ===
input group "=== 🏆 BESPOKE GOLD STRATEGIES (G-001 to G-005) ==="
input bool     InpEnableG001             = true;           // [ENTRY] Enable G-001 Asian Range Sweep & London Expansion
input bool     InpEnableG002             = true;           // [ENTRY] Enable G-002 NY Session Order Block & FVG Retracement
input bool     InpEnableG003             = true;           // [ENTRY] Enable G-003 M5 VWAP & EMA 9/21 Micro-Scalper
input bool     InpEnableG004             = true;           // [ENTRY] Enable G-004 Post-News Institutional Imbalance Expansion
input bool     InpEnableG005             = true;           // [ENTRY] Enable G-005 Daily Key Level (PDH/PDL) Sweep & Reversal

//--- Input Group: === 🛡️ TRADE MANAGER (EXITS) ===
input group "=== 🛡️ TRADE MANAGER (EXITS) ==="
input bool     InpEnableTradeManager     = true;           // [EXIT] Enable GITS Trade Manager V1
input bool     InpEnableBreakEven        = true;           // [EXIT] Enable Smart BreakEven
input double   InpBreakEvenTrigger       = 250.0;          // [EXIT] BreakEven Trigger (Points) (25.0 Pips - Unchoked Breathing Room)
input double   InpBreakEvenOffset        = 50.0;           // [EXIT] BreakEven Offset (Points) (5.0 Pips Locked)
input double   InpStage2Trigger          = 400.0;          // [EXIT] Stage 2 Trigger (Points) (40.0 Pips)
input double   InpStage2Offset           = 250.0;          // [EXIT] Stage 2 Offset (Points) (25.0 Pips Locked)
input double   InpStage3Trigger          = 600.0;          // [EXIT] Stage 3 Trigger (Points) (60.0 Pips)
input double   InpStage3Offset           = 400.0;          // [EXIT] Stage 3 Offset (Points) (40.0 Pips Locked)
input bool     InpEnableTrailing         = false;          // [EXIT] Enable Dynamic Trailing Stop
input ENUM_TRAILING_MODE InpTrailingMode = TRAILING_MODE_FIXED; // [EXIT] Trailing Mode (Fixed/ATR)
input double   InpTmAtrMultiplier        = 2.0;            // [EXIT] ATR Multiplier for Trailing
input double   InpMinTrailDistance       = 50.0;           // [EXIT] Minimum Trail Distance (Points)
input double   InpMaxTrailDistance       = 250.0;          // [EXIT] Maximum Trail Distance (Points)
input bool     InpEnableProfitLock       = true;           // [EXIT] Enable Progressive Profit Lock
input double   InpProfitLockStep         = 250.0;          // [EXIT] Custom Profit Lock Step (Points) (25.0 Pips)
input double   InpMinLockedProfit        = 100.0;          // [EXIT] Custom Min Locked Profit (Points) (10.0 Pips)
input bool     InpEnableHealthLock       = false;          // [EXIT] Enable Trade Health Profit Lock
input double   InpHealthLockMinPoints    = 300.0;          // [EXIT] Health Lock Min Profit (Points)
input double   InpMaxLossPer001Lot       = 4.0;            // [EXIT] Failsafe Max Loss Per 0.01 Lot (USD)

//--- Input Group: === ⚙️ [ADVANCED] ENGINE INDICATORS (KEEP DEFAULTS) ===
input group "=== ⚙️ [ADVANCED] ENGINE INDICATORS (KEEP DEFAULTS) ==="
input int      InpRSIPeriod              = 14;             // [ADVANCED] RSI Period
input int      InpVolumePeriod           = 20;             // [ADVANCED] Volume MA Period
input double   InpVolumeSpikeRatio       = 2.0;            // [ADVANCED] Volume Spike Ratio
input int      InpEqualThresholdPoints   = 15;             // [ADVANCED] Equal High/Low Threshold (Points)
input double   InpTrendWeight            = 15.0;           // [ADVANCED] Trend weight
input double   InpMomentumWeight         = 15.0;           // [ADVANCED] Momentum weight
input double   InpVolatilityWeight       = 15.0;           // [ADVANCED] Volatility weight
input double   InpVolumeWeight           = 15.0;           // [ADVANCED] Volume weight
input double   InpStructureWeight        = 15.0;           // [ADVANCED] Structure weight
input double   InpLiquidityWeight        = 15.0;           // [ADVANCED] Liquidity weight
input double   InpSessionWeight          = 10.0;           // [ADVANCED] Session weight
input bool     InpEnableExplainability   = true;           // [ADVANCED] Enable Explainability Framework
input string   InpCSVExportFileName      = "GITS_Explainability_Log.csv"; // [ADVANCED] CSV Export File Name

//--- Input Group: === 🤖 [ADVANCED] AI EXIT & PULLBACK ENGINES (KEEP DEFAULTS) ===
input group "=== 🤖 [ADVANCED] AI EXIT & PULLBACK ENGINES (KEEP DEFAULTS) ==="
input bool     InpEnablePullbackEngine   = true;           // [ADVANCED] Enable Pullback Engine
input double   InpMinContinuationProb    = 60.0;           // [ADVANCED] Min Continuation Prob (%)
input double   InpMinReversalProb        = 60.0;           // [ADVANCED] Min Reversal Prob (%)
input double   InpBreakoutThreshold      = 70.0;           // [ADVANCED] Breakout Threshold (0-100)
input double   InpFakeBreakoutThreshold  = 65.0;           // [ADVANCED] Fake Breakout Threshold (0-100)
input int      InpEmaLength              = 20;             // [ADVANCED] EMA Period
input int      InpAtrLength              = 14;             // [ADVANCED] ATR Period
input double   InpWeightVolume           = 25.0;           // [ADVANCED] Volume weight (0-100)
input double   InpWeightMovement         = 25.0;           // [ADVANCED] Movement weight (0-100)
input double   InpWeightIntent           = 25.0;           // [ADVANCED] Intent weight (0-100)
input double   InpWeightTradeHealth      = 25.0;           // [ADVANCED] Trade Health weight (0-100)
input bool     InpEnableNarratives       = true;           // [ADVANCED] Enable Narratives
input bool     InpEnableAdaptiveExitAI   = true;           // [ADVANCED] Enable AI Exit Engine
input double   InpHoldThreshold          = 60.0;           // [ADVANCED] Hold Threshold (0-100)
input double   InpExitThreshold          = 60.0;           // [ADVANCED] Exit Threshold (0-100)
input double   InpRunnerThreshold        = 75.0;           // [ADVANCED] Runner Threshold (0-100)
input double   InpTrailThreshold         = 50.0;           // [ADVANCED] Trail Threshold (0-100)
input double   InpConfidenceThreshold    = 60.0;           // [ADVANCED] Confidence Threshold (0-100)

//--- Input Group: === 🏛️ [ADVANCED] INSTITUTIONAL EXECUTION & RISK (KEEP DEFAULTS) ===
input group "=== 🏛️ [ADVANCED] INSTITUTIONAL EXECUTION & RISK (KEEP DEFAULTS) ==="
input bool     InpEnableRiskGuardian     = false;          // [ADVANCED] Enable Risk Guardian (V5.5: Disabled by default to remove trade limits)
input bool     InpEnableCalendarNewsFilter = true;          // [ADVANCED] RG: Enable MQL5 Calendar News Filter
input double   InpMaxDailyLossPercent    = 95.0;           // [ADVANCED] Max Daily Loss (%) (V5.5: Raised to 95% to remove limits)
input double   InpMaxWeeklyLossPercent   = 95.0;           // [ADVANCED] Max Weekly Loss (%) (V5.5: Raised to 95% to remove limits)
input double   InpMaxDrawdownPercent     = 95.0;           // [ADVANCED] Max Drawdown (%) (V5.5: Raised to 95% to remove limits)
input int      InpMaxConsecutiveLosses   = 100;            // [ADVANCED] Max Consecutive Losses (V5.5: Raised to 100 to remove limits)
input int      InpPauseMinutes           = 60;             // [ADVANCED] Trading Pause (Minutes)
input double   InpMaximumExposurePercent = 100.0;          // [ADVANCED] Max Portfolio Exposure (%) (V5.5: Raised to 100% to remove limits)
input int      InpMaximumOpenPositions   = 100;            // [ADVANCED] Max Open Positions (V5.5: Raised to 100 to remove limits)
input int      InpMaximumSpreadPoints    = 35;             // [ADVANCED] Max Spread (Points)
input bool     InpEnableSessionFilter    = true;           // [ADVANCED] Enable Session Filter
input bool     InpEnableCooldown         = true;           // [ADVANCED] Enable Cooldown
input int      InpCooldownMinutes        = 15;             // [ADVANCED] Cooldown (Minutes)
input bool     InpEmergencyStop          = false;          // [ADVANCED] Emergency Stop Switch
input bool     InpEnableInstExecution    = true;           // [ADVANCED] Enable Institutional Execution
input bool     InpEnableMultiPosition    = true;           // [ADVANCED] Enable Multi Position
input int      InpMaxConcurrentPositions = 5;              // [ADVANCED] Maximum Concurrent Positions
input int      InpMaxBuyPositions        = 3;              // [ADVANCED] Maximum Buy Positions
input int      InpMaxSellPositions       = 3;              // [ADVANCED] Maximum Sell Positions
input double   InpMaxExposureLots        = 5.0;            // [ADVANCED] Maximum Exposure Lots
input double   InpMaxRiskPercent         = 2.0;            // [ADVANCED] Maximum Risk %
input bool     InpEnableScaleIn          = true;           // [ADVANCED] Enable Scale-In
input double   InpScaleInThreshold       = 70.0;           // [ADVANCED] Scale-In Threshold (0-100)
input bool     InpEnableScaleOut         = true;           // [ADVANCED] Enable Scale-Out
input string   InpPartialExitLevels      = "5,10,20";      // [ADVANCED] Partial Exit Levels (points)
input double   InpRunnerPromotionThresh  = 75.0;           // [ADVANCED] Runner Promotion Threshold (0-100)
input bool     InpEnableDynamicAllocation= true;           // [ADVANCED] Enable Dynamic Allocation
input double   InpFixedLotMode           = 0.1;            // [ADVANCED] Fixed Lot Mode (lots)
input double   InpPriorityThreshold      = 60.0;           // [ADVANCED] Position Priority Threshold (0-100)
input double   InpPortfolioHealthThresh  = 50.0;           // [ADVANCED] Portfolio Health Threshold (0-100)
input string   InpTradingHours           = "08:00-21:00";  // [ADVANCED] Allowed Session hours (unused legacy config)

//--- Include core helpers
#include "../Include/GoldEngineV4/Core/CoreDefines.mqh"
#include "../Include/GoldEngineV4/Core/Version.mqh"
#include "../Include/GoldEngineV4/Core/Config.mqh"
#include "../Include/GoldEngineV4/Core/Logger.mqh"
#include "../Include/GoldEngineV4/Core/Utils.mqh"
#include "../Include/GoldEngineV4/Core/Lifecycle.mqh"

//--- Include the 9 independent Quant Engines
#include "../Include/GoldEngineV4/QuantEngine/TrendEngine.mqh"
#include "../Include/GoldEngineV4/QuantEngine/MomentumEngine.mqh"
#include "../Include/GoldEngineV4/QuantEngine/VolatilityEngine.mqh"
#include "../Include/GoldEngineV4/QuantEngine/VolumeEngine.mqh"
#include "../Include/GoldEngineV4/QuantEngine/VwapEngine.mqh"
#include "../Include/GoldEngineV4/QuantEngine/LiquidityEngine.mqh"
#include "../Include/GoldEngineV4/QuantEngine/PatternEngine.mqh"
#include "../Include/GoldEngineV4/QuantEngine/SessionEngine.mqh"
#include "../Include/GoldEngineV4/QuantEngine/MarketStructureEngine.mqh"

//--- Include Market Quality Score Calculator
#include "../Include/GoldEngineV4/QuantEngine/MarketQuality.mqh"

//--- Include the Market Classifier
#include "../Include/GoldEngineV4/Classifier/MarketClassifier.mqh"

//--- Include the Market Context Engine
#include "../Include/GoldEngineV4/Core/MarketContext/MarketContextEngine.mqh"

//--- Include the Decision Engine
#include "../Include/GoldEngineV4/Core/DecisionEngine/DecisionEngine.mqh"

#include "../Include/GoldEngineV4/QuantEngine/MovementEngine.mqh"
#include "../Include/GoldEngineV4/QuantEngine/MarketIntentEngine.mqh"
#include "../Include/GoldEngineV4/QuantEngine/OpportunityEngine.mqh"
#include "../Include/GoldEngineV4/QuantEngine/TradePlannerEngine.mqh"

//--- Include Strategy and Portfolio Managers
#include "../Include/GoldEngineV4/Strategy/StrategyManager.mqh"
#include "../Include/GoldEngineV4/Portfolio/PortfolioManager.mqh"

//--- Include Bespoke Gold Strategy Headers (GoldEngine V5)
#include "../Include/GoldEngineV4/Strategy/Strategies/Gold/G001_AsianRangeSweep.mqh"
#include "../Include/GoldEngineV4/Strategy/Strategies/Gold/G002_NYOrderBlockFVG.mqh"
#include "../Include/GoldEngineV4/Strategy/Strategies/Gold/G003_M5VwapScalper.mqh"
#include "../Include/GoldEngineV4/Strategy/Strategies/Gold/G004_PostNewsImbalance.mqh"
#include "../Include/GoldEngineV4/Strategy/Strategies/Gold/G005_DailyKeyLevelSweep.mqh"
#include "../Include/GoldEngineV4/Strategy/Strategies/Gold/G008_MomentumExpansion.mqh"


//--- Include Risk and Execution
#include "../Include/GoldEngineV4/Risk/RiskGuardian.mqh"
#include "../Include/GoldEngineV4/Execution/ExecutionEngine.mqh"

//--- Include Strategy Validation & Explainability Framework concrete header
#include "../Include/GoldEngineV4/Explainability/ExplainabilityFramework.mqh"

//--- Include the 5 Analytics components
#include "../Include/GoldEngineV4/Analytics/TradeStatistics.mqh"
#include "../Include/GoldEngineV4/Analytics/PerformanceTracker.mqh"
#include "../Include/GoldEngineV4/Analytics/StrategyRanking.mqh"
#include "../Include/GoldEngineV4/Analytics/BacktestComparison.mqh"
#include "../Include/GoldEngineV4/Analytics/OptimizationDatabase.mqh"
#include "../Include/GoldEngineV4/Analytics/ResearchFramework.mqh"
#include "../Include/GoldEngineV4/Analytics/TradeMemory.mqh"
#include "../Include/GoldEngineV4/QuantEngine/EntryQualityEngine.mqh"

//--- Include Dashboard HUD
#include "../Include/GoldEngineV4/Dashboard/Dashboard.mqh"

//--- Include GITS Control Center Bridge
#include "../Include/GoldEngineV4/Bridge/GITSBridge.mqh"

//--- Include GITS Trade Manager V1
#include "../Include/GoldEngineV4/QuantEngine/TradeManager.mqh"
#include "../Include/GoldEngineV4/QuantEngine/TradeHealthEngine.mqh"
#include "../Include/GoldEngineV4/QuantEngine/TradeOptimizationEngine.mqh"
#include "../Include/GoldEngineV4/QuantEngine/PullbackReversalEngine.mqh"
#include "../Include/GoldEngineV4/QuantEngine/AdaptiveExitAIEngine.mqh"
#include "../Include/GoldEngineV4/QuantEngine/InstitutionalExecutionManager.mqh"


//+------------------------------------------------------------------+
//| GITS Global Coordinator Class                                    |
//+------------------------------------------------------------------+
class CMainEA
{
private:
   // Core
   CConfig*                   m_config;
   CLogger*                   m_logger;
   CLifecycle*                m_lifecycle;

   // 9 Quant Engines
   CTrendEngine*              m_trendEngine;
   CMomentumEngine*           m_momentumEngine;
   CVolatilityEngine*         m_volatilityEngine;
   CVolumeEngine*             m_volumeEngine;
   CVwapEngine*               m_vwapEngine;
   CLiquidityEngine*          m_liquidityEngine;
   CPatternEngine*            m_patternEngine;
   CSessionEngine*            m_sessionEngine;
   CMarketStructureEngine*    m_structureEngine;

   // Market Quality composite calculator
   CMarketQuality*            m_marketQuality;

   // Classifier
   CMarketClassifier*         m_marketClassifier;

   // Market Context Engine
   CMarketContextEngine*      m_marketContextEngine;

   // Decision Engine
   CDecisionEngine*           m_decisionEngine;

   // GITS-X Opportunity Engine
   COpportunityEngine*        m_opportunityEngine;

   // GITS-X Movement Engine
   CMovementEngine*           m_movementEngine;

   // GITS-X Market Intent Engine
   CMarketIntentEngine*       m_marketIntentEngine;

   // GITS-X Trade Planner Engine
   CTradePlannerEngine*       m_tradePlannerEngine;

   // Strategy & Portfolio
   CStrategyManager*          m_strategyManager;
   CPortfolioManager*         m_portfolioManager;

   // Risk & Execution
   CRiskGuardian*             m_riskGuardian;
   CExecutionEngine*          m_executionEngine;

   // Explainability Framework
   CExplainabilityFramework*  m_explainability;

   // 5 Analytics components
   CTradeStatistics*          m_tradeStatistics;
   CPerformanceTracker*       m_performanceTracker;
   CStrategyRanking*          m_strategyRanking;
   CBacktestComparison*       m_backtestComparison;
   COptimizationDatabase*     m_optimizationDb;
   CResearchFramework*        m_researchFramework;
   CTradeMemory*              m_tradeMemory; // GITS V5.2.1 Trade Memory

   // HUD Dashboard
   CDashboard*                m_dashboard;

    // GITS Trade Manager V1, Trade Health Engine, & Optimization Engine
    CTradeManager*             m_tradeManager;
    CTradeHealthEngine*        m_tradeHealthEngine;
    CTradeOptimizationEngine*  m_tradeOptEngine;
    CPullbackReversalEngine*   m_pullbackEngine;
    CAdaptiveExitAIEngine*     m_adaptiveExitEngine;
    CInstitutionalExecutionManager* m_instExecution;
 
    // Control Center Bridge (V4.4)
    CGITSBridge*               m_bridge;

    // GITS V5.2.2 Execution Stabilization state
    datetime                   m_lastExecutedTime;
    double                     m_lastExecutedPrice;
    string                     m_lastExecutedStructure;
    bool                       m_lastStopHuntActive;
    double                     m_lastMomentumScore;
    ENUM_GEV2_SIGNAL_TYPE      m_lastExecutedDirection;
    string                     m_lastPullbackRec;

   bool                       m_isInitSuccessful;
   datetime                   m_lastBarTime;
   datetime                   m_lastBarTimeM5;
   datetime                   m_lastBarTimeM15;

   /**
    * @brief Helper to detect new bar opens.
    */
   bool IsNewBar()
   {
      datetime currentBarTime = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
      if(currentBarTime != m_lastBarTime)
      {
         m_lastBarTime = currentBarTime;
         return true;
      }
      return false;
   }

   bool IsNewBarM5()
   {
      datetime currentBarTime = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
      if(currentBarTime != m_lastBarTimeM5)
      {
         m_lastBarTimeM5 = currentBarTime;
         return true;
      }
      return false;
   }

   bool IsNewBarM15()
   {
      datetime currentBarTime = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
      if(currentBarTime != m_lastBarTimeM15)
      {
         m_lastBarTimeM15 = currentBarTime;
         return true;
      }
      return false;
   }

   /**
    * @brief Prints a formatted quant report to the MT5 Journal.
    */
   void PrintBarDebugReport()
   {
      double ema9 = m_trendEngine.GetEmaValue(_Symbol, _Period, 9, 1);
      double ema20 = m_trendEngine.GetEmaValue(_Symbol, _Period, 20, 1);
      double ema50 = m_trendEngine.GetEmaValue(_Symbol, _Period, 50, 1);
      double ema200 = m_trendEngine.GetEmaValue(_Symbol, _Period, 200, 1);
      int trendDir = m_trendEngine.GetTrendDirection(_Symbol, _Period);
      double trendStrength = m_trendEngine.GetTrendStrength(_Symbol, _Period);
      double alignmentConf = m_trendEngine.GetEmaAlignmentConfidence(_Symbol, _Period);
      
      double rsiVal = m_momentumEngine.GetRSIValue(1);
      double rocVal = m_momentumEngine.GetROCValue(1);
      double momentumScore = m_momentumEngine.GetMomentumScore();
      string momentumDir = m_momentumEngine.GetMomentumDirectionDesc();

      double atr = m_volatilityEngine.GetATR(_Symbol, _Period, 14, 1);
      double atrPercentile = m_volatilityEngine.GetATRPercentile(_Symbol, _Period, 14);
      double volatilityScore = m_volatilityEngine.GetVolatilityScore(_Symbol, _Period);
      string volatilityRegime = m_volatilityEngine.GetVolatilityRegime(_Symbol, _Period);
      
      long volumeVal = m_volumeEngine.GetTicksVolume(_Symbol, _Period, 1);
      double rvol = m_volumeEngine.GetRelativeVolume();
      double volumeScore = m_volumeEngine.GetVolumeStrengthScore();

      string marketStruct = m_structureEngine.GetStructureDesc();
      string structState = m_structureEngine.GetStructureState();

      bool buySweep = false, sellSweep = false;
      m_liquidityEngine.IsLiquiditySweep(buySweep, sellSweep);
      string sweepText = "None";
      if(m_liquidityEngine.IsStopHuntActive()) sweepText = "ACTIVE STOP HUNT";
      else if(buySweep && sellSweep) sweepText = "Both Swept";
      else if(buySweep) sweepText = "Buy Side Swept";
      else if(sellSweep) sweepText = "Sell Side Swept";

      string session = m_sessionEngine.GetCurrentSession();
      double progress = m_sessionEngine.GetSessionProgress(session);

      double mqScore = m_marketQuality.CalculateMarketQualityScore();
      string mqInterpret = m_marketQuality.GetMarketQualityInterpretation();

      string trendText = "NEUTRAL";
      if(trendDir > 0) trendText = "BULLISH";
      else if(trendDir < 0) trendText = "BEARISH";

      m_logger.Info("================== GITS ADVANCED QUANT CORE REPORT ==================");
      m_logger.Info(StringFormat("Time: %s | Bar Open Time: %s", TimeToString(TimeCurrent()), TimeToString(m_lastBarTime)));
      m_logger.Info(StringFormat("Trend:      %s (Score: %.1f/100, Alignment Conf: %.1f%%)", trendText, trendStrength, alignmentConf));
      m_logger.Info(StringFormat("EMA Values: 9=%.2f, 20=%.2f, 50=%.2f, 200=%.2f", ema9, ema20, ema50, ema200));
      m_logger.Info(StringFormat("Momentum:   %s (Score: %.1f/100, RSI: %.1f, ROC: %.2f%%)", momentumDir, momentumScore, rsiVal, rocVal));
      m_logger.Info(StringFormat("Volatility: %s Regime (Score: %.1f/100, ATR: %.2f, Percentile: %.1f%%)", volatilityRegime, volatilityScore, atr, atrPercentile));
      m_logger.Info(StringFormat("Volume:     Val: %d (Score: %.1f/100, RVOL: %.2f)", volumeVal, volumeScore, rvol));
      m_logger.Info(StringFormat("Structure:  %s | State: %s", marketStruct, structState));
      m_logger.Info(StringFormat("Liquidity:  Sweeps: %s | Direction: %s", sweepText, m_liquidityEngine.GetLiquidityDirection()));
      m_logger.Info(StringFormat("Session:    %s (Progress: %.1f%%)", session, progress));
      m_logger.Info(StringFormat("Market Quality Score: %.1f/100.0 (%s)", mqScore, mqInterpret));
      m_logger.Info("=====================================================================");
   }

   /**
    * @brief Logs GITS strategy Trade Journal when a trade signal occurs.
    */
   void LogTradeJournal(const StrategyResponse &response)
   {
      double trendScore = m_trendEngine.GetTrendStrength(_Symbol, _Period);
      double momentumScore = m_momentumEngine.GetMomentumScore();
      double volumeScore = m_volumeEngine.GetVolumeStrengthScore();
      double volatilityScore = m_volatilityEngine.GetVolatilityScore(_Symbol, _Period);
      
      string structState = m_structureEngine.GetStructureState();
      double liquidityScore = m_liquidityEngine.GetLiquidityStrength();
      string session = m_sessionEngine.GetCurrentSession();
      double mqScore = m_marketQuality.CalculateMarketQualityScore();

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double currentPrice = (response.Signal == GEV2_SIGNAL_BUY) ? ask : bid;

      m_logger.Info("================== [TRADE JOURNAL] SIGNAL GENERATED ==================");
      m_logger.Info("Strategy Name:   " + response.StrategyName);
      m_logger.Info("Timestamp:       " + TimeToString(TimeCurrent()));
      m_logger.Info(StringFormat("Market Snapshot: Price=%.2f | Bid=%.2f | Ask=%.2f", currentPrice, bid, ask));
      m_logger.Info(StringFormat("Quant Scores:    Trend=%.1f | Momentum=%.1f | Volume=%.1f | Volatility=%.1f",
         trendScore, momentumScore, volumeScore, volatilityScore));
      m_logger.Info(StringFormat("                 Structure=%s | Liquidity=%.1f | Session=%s",
         structState, liquidityScore, session));
      m_logger.Info(StringFormat("                 Market Quality Composite = %.1f/100.0", mqScore));
      m_logger.Info(StringFormat("Strategy Score:  %.1f/100.0", response.Confidence * 100.0));
      m_logger.Info(StringFormat("Signal Decision: %s (Confidence: %.2f)", 
         (response.Signal == GEV2_SIGNAL_BUY) ? "BUY" : "SELL", response.Confidence));
      m_logger.Info(StringFormat("Levels Set:      EntryPrice=%.2f | StopLoss=%.2f | TakeProfit=%.2f",
         response.EntryPrice, response.StopLoss, response.TakeProfit));
      m_logger.Info("Reason Details:  " + response.Reason);
      m_logger.Info("=======================================================================");
   }

   /**
    * @brief GITS V5.3: Calculates dynamic take profit and adaptive stop loss levels.
    */
   void CalculateAdaptiveStopLossAndTakeProfit(const string symbol, ENUM_GEV2_SIGNAL_TYPE signalDir, double entryPrice, double &outSL, double &outTP)
   {
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double atr = m_volatilityEngine.GetATR(symbol, _Period, 14, 1);
      double volatility = m_volatilityEngine.GetVolatilityScore(symbol, _Period);
      double momentum = m_momentumEngine.GetMomentumScore();
      int regime = (m_marketContextEngine != NULL) ? m_marketContextEngine.GetContext().MarketRegime : 0;
      double spread = (double)SymbolInfoInteger(symbol, SYMBOL_SPREAD) * point;

      // 1. Adaptive Stop Loss
      // Base SL is 2.0 * ATR
      double slDistance = atr * 2.0;
      // Adjust with Volatility (wider stops for higher volatility)
      slDistance *= (1.0 + (volatility - 50.0) * 0.005);
      // Add spread
      slDistance += spread;
      
      // Swing High/Low adjustment: scan last 15 bars
      double swingPrice = 0.0;
      if(signalDir == GEV2_SIGNAL_BUY)
      {
         int lowestBar = iLowest(symbol, _Period, MODE_LOW, 15, 1);
         if(lowestBar >= 0) swingPrice = iLow(symbol, _Period, lowestBar);
         if(swingPrice > 0.0)
         {
            double swingDistance = entryPrice - swingPrice;
            slDistance = MathMax(slDistance, swingDistance);
         }
         outSL = entryPrice - slDistance;
      }
      else
      {
         int highestBar = iHighest(symbol, _Period, MODE_HIGH, 15, 1);
         if(highestBar >= 0) swingPrice = iHigh(symbol, _Period, highestBar);
         if(swingPrice > 0.0)
         {
            double swingDistance = swingPrice - entryPrice;
            slDistance = MathMax(slDistance, swingDistance);
         }
         outSL = entryPrice + slDistance;
      }

      // 2. Dynamic Take Profit
      // Base RR ratio is 2.0
      double rrRatio = 2.0;
      // Adjust RR based on Market Regime: trending regime gets higher target, range gets smaller
      if(regime == 1) // REGIME_TRENDING
         rrRatio = 2.5;
      else if(regime == 2) // REGIME_RANGING
         rrRatio = 1.5;
      
      // Adjust based on Momentum (stronger momentum -> larger target)
      rrRatio *= (1.0 + (momentum - 50.0) * 0.004);

      double tpDistance = slDistance * rrRatio;
      
      if(signalDir == GEV2_SIGNAL_BUY)
         outTP = entryPrice + tpDistance;
      else
         outTP = entryPrice - tpDistance;
         
      // Normalize
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      outSL = NormalizeDouble(outSL, digits);
      outTP = NormalizeDouble(outTP, digits);
   }

   /**
    * @brief Prints Risk Guardian evaluation details in Debug Mode.
    */
   void PrintRiskDebugReport(const StrategyResponse &signal, const RiskAuditResponse &response)
   {
      m_logger.Info("================== Risk Guardian Evaluation ==================");
      m_logger.Info("Strategy:       " + signal.StrategyName);
      m_logger.Info("Signal:         " + (string)signal.Signal);
      m_logger.Info(StringFormat("Exposure:       %.2f%% (Limit: %.2f%%)", response.CurrentExposure, m_config.GetMaximumExposurePercent()));
      m_logger.Info(StringFormat("Drawdown:       %.2f%% (Limit: %.2f%%)", response.CurrentDrawdown, m_config.GetMaxDrawdownPercent()));
      m_logger.Info(StringFormat("Rem. Daily:     %.2f", response.RemainingDailyLoss));
      m_logger.Info(StringFormat("Rem. Weekly:    %.2f", response.RemainingWeeklyLoss));
      m_logger.Info("Decision:       " + (response.Approved ? "APPROVED" : "REJECTED"));
      if(!response.Approved)
      {
         m_logger.Info("Reject Reason:  " + response.Reason);
      }
      m_logger.Info("==============================================================");
   }

   /**
    * @brief V2.7.2 Decision Trace Diagnostic: Prints complete per-candle evaluation.
    */
   void PrintDecisionTrace(const StrategyResponse &response)
   {
      // Gather all 8 filter metrics from Quant Engines
      double trendScore = m_trendEngine.GetTrendStrength(_Symbol, _Period);
      int trendDir = m_trendEngine.GetTrendDirection(_Symbol, _Period);
      string trendText = "NEUTRAL";
      if(trendDir > 0) trendText = "BULLISH";
      else if(trendDir < 0) trendText = "BEARISH";

      double momentumScore = m_momentumEngine.GetMomentumScore();
      double rsi = m_momentumEngine.GetRSIValue(1);
      string momDir = m_momentumEngine.GetMomentumDirectionDesc();

      double volumeScore = m_volumeEngine.GetVolumeStrengthScore();
      double rvol = m_volumeEngine.GetRelativeVolume();

      double volatilityScore = m_volatilityEngine.GetVolatilityScore(_Symbol, _Period);
      string volRegime = m_volatilityEngine.GetVolatilityRegime(_Symbol, _Period);

      string structState = m_structureEngine.GetStructureState();

      double liqStrength = m_liquidityEngine.GetLiquidityStrength();
      bool buySw = false, sellSw = false;
      m_liquidityEngine.IsLiquiditySweep(buySw, sellSw);
      string liqText = "None";
      if(m_liquidityEngine.IsStopHuntActive()) liqText = "StopHunt";
      else if(buySw || sellSw) liqText = "Sweep";
      else if(m_liquidityEngine.IsLiquidityPresent()) liqText = "Present";

      string session = m_sessionEngine.GetCurrentSession();
      double mqScore = m_marketQuality.CalculateMarketQualityScore();

      string signalStr = "NO TRADE";
      if(response.Signal == GEV2_SIGNAL_BUY)  signalStr = "BUY";
      if(response.Signal == GEV2_SIGNAL_SELL) signalStr = "SELL";

      double minScore = m_config.GetS002_MinScore();

      Print("--- DECISION TRACE ---");
      Print(StringFormat("Trend:           %s (Score: %.1f)", trendText, trendScore));
      Print(StringFormat("Momentum:        %s (Score: %.1f, RSI: %.1f)", momDir, momentumScore, rsi));
      Print(StringFormat("Volume:          Score: %.1f (RVOL: %.2f)", volumeScore, rvol));
      Print(StringFormat("Volatility:      %s (Score: %.1f)", volRegime, volatilityScore));
      Print(StringFormat("Structure:       %s", structState));
      Print(StringFormat("Liquidity:       %s (Strength: %.1f)", liqText, liqStrength));
      Print(StringFormat("Session:         %s", session));
      Print(StringFormat("Market Quality:  %.1f", mqScore));
      Print(StringFormat("Strategy Score:  %.1f", response.StrategyScore));
      Print(StringFormat("Minimum Required:%.1f", minScore));
      Print(StringFormat("Decision:        %s", signalStr));
      Print(StringFormat("Reason:          %s", response.Reason));
      Print("----------------------");
   }

public:
   /**
    * @brief Constructor.
    */
   CMainEA()
      : m_config(NULL), m_logger(NULL), m_lifecycle(NULL),
        m_trendEngine(NULL), m_momentumEngine(NULL), m_volatilityEngine(NULL),
        m_volumeEngine(NULL), m_vwapEngine(NULL), m_liquidityEngine(NULL),
        m_patternEngine(NULL), m_sessionEngine(NULL), m_structureEngine(NULL),
        m_marketQuality(NULL), m_marketContextEngine(NULL), m_decisionEngine(NULL),
        m_marketClassifier(NULL), m_strategyManager(NULL), m_portfolioManager(NULL),
        m_riskGuardian(NULL), m_executionEngine(NULL),
        m_explainability(NULL),
        m_tradeStatistics(NULL), m_performanceTracker(NULL), m_strategyRanking(NULL),
        m_backtestComparison(NULL), m_optimizationDb(NULL), m_dashboard(NULL),
        m_bridge(NULL), m_tradeManager(NULL),
        m_tradeMemory(NULL),
        m_lastExecutedTime(0),
        m_lastExecutedPrice(0.0),
        m_lastExecutedStructure("None"),
        m_lastStopHuntActive(false),
        m_lastMomentumScore(50.0),
        m_lastExecutedDirection(GEV2_SIGNAL_NONE),
        m_lastPullbackRec("N/A"),
        m_isInitSuccessful(false), m_lastBarTime(0), m_lastBarTimeM5(0), m_lastBarTimeM15(0)
   {}

   /**
    * @brief Destructor. Safe dynamic memory cleanup.
    */
   ~CMainEA()
   {
      if(CheckPointer(m_tradeManager) == POINTER_DYNAMIC) delete m_tradeManager;
      if(CheckPointer(m_dashboard) == POINTER_DYNAMIC) delete m_dashboard;
      if(CheckPointer(m_bridge) == POINTER_DYNAMIC) delete m_bridge;
      
      // Cleanup Analytics
      if(CheckPointer(m_tradeMemory) == POINTER_DYNAMIC) delete m_tradeMemory;
      if(CheckPointer(m_optimizationDb) == POINTER_DYNAMIC) delete m_optimizationDb;
      if(CheckPointer(m_researchFramework) == POINTER_DYNAMIC) delete m_researchFramework;
      if(CheckPointer(m_backtestComparison) == POINTER_DYNAMIC) delete m_backtestComparison;
      if(CheckPointer(m_strategyRanking) == POINTER_DYNAMIC) delete m_strategyRanking;
      if(CheckPointer(m_performanceTracker) == POINTER_DYNAMIC) delete m_performanceTracker;
      if(CheckPointer(m_tradeStatistics) == POINTER_DYNAMIC) delete m_tradeStatistics;

      if(CheckPointer(m_explainability) == POINTER_DYNAMIC) delete m_explainability;
      if(CheckPointer(m_executionEngine) == POINTER_DYNAMIC) delete m_executionEngine;
      if(CheckPointer(m_riskGuardian) == POINTER_DYNAMIC) delete m_riskGuardian;
      if(CheckPointer(m_tradeOptEngine) == POINTER_DYNAMIC) delete m_tradeOptEngine;
      if(CheckPointer(m_pullbackEngine) == POINTER_DYNAMIC) delete m_pullbackEngine;
      if(CheckPointer(m_adaptiveExitEngine) == POINTER_DYNAMIC) delete m_adaptiveExitEngine;
      if(CheckPointer(m_instExecution) == POINTER_DYNAMIC) delete m_instExecution;
      if(CheckPointer(m_tradeHealthEngine) == POINTER_DYNAMIC) delete m_tradeHealthEngine;
      if(CheckPointer(m_portfolioManager) == POINTER_DYNAMIC) delete m_portfolioManager;
      if(CheckPointer(m_strategyManager) == POINTER_DYNAMIC) delete m_strategyManager;
      if(CheckPointer(m_marketClassifier) == POINTER_DYNAMIC) delete m_marketClassifier;
      if(CheckPointer(m_marketContextEngine) == POINTER_DYNAMIC) delete m_marketContextEngine;
      if(CheckPointer(m_decisionEngine) == POINTER_DYNAMIC) delete m_decisionEngine;
      if(CheckPointer(m_opportunityEngine) == POINTER_DYNAMIC) delete m_opportunityEngine;
      if(CheckPointer(m_movementEngine) == POINTER_DYNAMIC) delete m_movementEngine;
      if(CheckPointer(m_marketIntentEngine) == POINTER_DYNAMIC) delete m_marketIntentEngine;
      if(CheckPointer(m_tradePlannerEngine) == POINTER_DYNAMIC) delete m_tradePlannerEngine;
      
      if(CheckPointer(m_marketQuality) == POINTER_DYNAMIC) delete m_marketQuality;

      // Cleanup Quant Engines
      if(CheckPointer(m_structureEngine) == POINTER_DYNAMIC) delete m_structureEngine;
      if(CheckPointer(m_sessionEngine) == POINTER_DYNAMIC) delete m_sessionEngine;
      if(CheckPointer(m_patternEngine) == POINTER_DYNAMIC) delete m_patternEngine;
      if(CheckPointer(m_liquidityEngine) == POINTER_DYNAMIC) delete m_liquidityEngine;
      if(CheckPointer(m_vwapEngine) == POINTER_DYNAMIC) delete m_vwapEngine;
      if(CheckPointer(m_volumeEngine) == POINTER_DYNAMIC) delete m_volumeEngine;
      if(CheckPointer(m_volatilityEngine) == POINTER_DYNAMIC) delete m_volatilityEngine;
      if(CheckPointer(m_momentumEngine) == POINTER_DYNAMIC) delete m_momentumEngine;
      if(CheckPointer(m_trendEngine) == POINTER_DYNAMIC) delete m_trendEngine;

      if(CheckPointer(m_lifecycle) == POINTER_DYNAMIC) delete m_lifecycle;
      if(CheckPointer(m_logger) == POINTER_DYNAMIC) delete m_logger;
      if(CheckPointer(m_config) == POINTER_DYNAMIC) delete m_config;
   }

   /**
    * @brief GITS system initialization.
    */
   bool OnInit()
   {
      // Safety Check: Force M15 Timeframe
      if(_Period != PERIOD_M15)
      {
         Alert("GITS Warning: This Expert Advisor is optimized for the M15 timeframe only. Please switch the chart timeframe to M15.");
         return false;
      }

      m_logger = new CLogger();
      m_logger.SetPrefix("GITS");
      m_logger.SetMinLevel(GEV2_LOG_DEBUG);

      m_logger.Info("==================================================");
      m_logger.Info("Starting GITS V2.7 S-002 Production Trading Rules EA initialization");

      m_config = new CConfig();
      
      // Inject standard inputs into config
      m_config.SetMagicNumber(InpMagicNumber);
      m_config.SetLogsFilePrefix(InpLogsFileName);
      m_config.SetAutoTradingEnabled(InpAutoTrading);
      m_config.SetRiskPercent(InpRiskPercent);
      m_config.SetUseFixedLot(InpUseFixedLot);
      m_config.SetFixedLotSize(InpFixedLotSize);
      m_config.SetUseCompoundingLot(InpUseCompoundingLot); // V5.5
      m_config.SetCompoundOnTotalBalance(InpCompoundOnTotalBalance); // Option A compounding
      m_config.SetMaxSpreadPoints(InpMaximumSpreadPoints);
      m_config.SetMaxDailyTrades(InpMaximumOpenPositions * 3);
      m_config.SetAllowedTradingHours(InpTradingHours);
      m_config.SetSlippagePoints(InpSlippagePoints);

      // Inject Production Risk Guardian inputs
      m_config.SetEnableRiskGuardian(InpEnableRiskGuardian);
      m_config.SetEnableCalendarNewsFilter(InpEnableCalendarNewsFilter);
      m_config.SetMaxDailyLossPercent(InpMaxDailyLossPercent);
      m_config.SetMaxWeeklyLossPercent(InpMaxWeeklyLossPercent);
      m_config.SetMaxDrawdownPercent(InpMaxDrawdownPercent);
      m_config.SetMaxConsecutiveLosses(InpMaxConsecutiveLosses);
      m_config.SetPauseMinutes(InpPauseMinutes);
      m_config.SetMaximumExposurePercent(InpMaximumExposurePercent);
      m_config.SetMaximumOpenPositions(InpMaximumOpenPositions);
      m_config.SetMaximumSpreadPoints(InpMaximumSpreadPoints);
      m_config.SetEnableCapitalLock(InpEnableCapitalLock);   // V5.5
      m_config.SetCapitalLockTrigger(InpCapitalLockTrigger); // V5.5
      m_config.SetCapitalLockFloor(InpCapitalLockFloor);     // V5.5
      m_config.SetEnableSessionFilter(InpEnableSessionFilter);
      m_config.SetEnableCooldown(InpEnableCooldown);
      m_config.SetCooldownMinutes(InpCooldownMinutes);
      m_config.SetEmergencyStop(InpEmergencyStop);

      // Inject Advanced Quant Engine inputs
      m_config.SetRSIPeriod(InpRSIPeriod);
      m_config.SetVolumePeriod(InpVolumePeriod);
      m_config.SetVolumeSpikeRatio(InpVolumeSpikeRatio);
      m_config.SetEqualThresholdPoints(InpEqualThresholdPoints);

      // Inject Market Quality weights
      m_config.SetTrendWeight(InpTrendWeight);
      m_config.SetMomentumWeight(InpMomentumWeight);
      m_config.SetVolatilityWeight(InpVolatilityWeight);
      m_config.SetVolumeWeight(InpVolumeWeight);
      m_config.SetStructureWeight(InpStructureWeight);
      m_config.SetLiquidityWeight(InpLiquidityWeight);
      m_config.SetSessionWeight(InpSessionWeight);

      m_config.SetAutoCapitalLock(InpAutoCapitalLock);
      m_config.SetLockStepUSD(InpLockStepUSD);
      m_config.SetRiskProfitPercent(InpRiskProfitPercent);

      // Inject Explainability inputs
      m_config.SetEnableExplainability(InpEnableExplainability);
      m_config.SetCSVExportFileName(InpCSVExportFileName);

      // Inject GITS Trade Manager V1 inputs
      m_config.SetEnableTradeManager(InpEnableTradeManager);
      m_config.SetEnableBreakEven(InpEnableBreakEven);
      m_config.SetBreakEvenTrigger(InpBreakEvenTrigger);
      m_config.SetBreakEvenOffset(InpBreakEvenOffset);
      m_config.SetStage2Trigger(InpStage2Trigger);
      m_config.SetStage2Offset(InpStage2Offset);
      m_config.SetStage3Trigger(InpStage3Trigger);
      m_config.SetStage3Offset(InpStage3Offset);
      m_config.SetEnableTrailing(InpEnableTrailing);
      m_config.SetTrailingMode((int)InpTrailingMode);
      m_config.SetTmAtrMultiplier(InpTmAtrMultiplier);
      m_config.SetMinTrailDistance(InpMinTrailDistance);
      m_config.SetMaxTrailDistance(InpMaxTrailDistance);
      m_config.SetEnableProfitLock(InpEnableProfitLock);
      m_config.SetProfitLockStep(InpProfitLockStep);
      m_config.SetMinLockedProfit(InpMinLockedProfit);
      m_config.SetEnableHealthLock(InpEnableHealthLock);
      m_config.SetHealthLockMinPoints(InpHealthLockMinPoints);
      m_config.SetMaxLossPer001Lot(InpMaxLossPer001Lot);

      // V5.1 — Inject Trading Profile
      m_config.SetTradingProfile(InpTradingProfile);
      m_logger.Info(StringFormat("[PROFILE] Trading Profile set to: %s",
         (InpTradingProfile == PROFILE_RESEARCH) ? "PROFILE_RESEARCH (Unlimited)" : "PROFILE_PRODUCTION (Restricted)"));

      m_lifecycle = new CLifecycle(m_logger, m_config);
      if(!m_lifecycle.AuditEnvironment(_Symbol))
      {
         m_logger.Critical("GITS Environment Audit Failed.");
         return false;
      }

      // 1. Create the 9 independent Quant Engines
      m_trendEngine = new CTrendEngine();
      m_momentumEngine = new CMomentumEngine();
      m_volatilityEngine = new CVolatilityEngine();
      m_volumeEngine = new CVolumeEngine();
      m_vwapEngine = new CVwapEngine();
      m_liquidityEngine = new CLiquidityEngine();
      m_patternEngine = new CPatternEngine();
      m_sessionEngine = new CSessionEngine();
      m_structureEngine = new CMarketStructureEngine();

      if(!m_trendEngine.InitializeEngine(_Symbol, _Period) ||
         !m_momentumEngine.InitializeEngine(_Symbol, _Period, m_config.GetRSIPeriod()) ||
         !m_volatilityEngine.InitializeEngine(_Symbol, _Period) ||
         !m_volumeEngine.InitializeEngine(_Symbol, _Period) ||
         !m_liquidityEngine.InitializeEngine(_Symbol, _Period) ||
         !m_structureEngine.InitializeEngine(_Symbol, _Period))
      {
         m_logger.Critical("Failed to initialize indicator engine handles.");
         return false;
      }

      // Create Market Quality Score composite calculator
      m_marketQuality = new CMarketQuality();
      if(!m_marketQuality.Initialize(
         m_config, m_trendEngine, m_momentumEngine, m_volatilityEngine, m_volumeEngine,
         m_structureEngine, m_liquidityEngine, m_sessionEngine))
      {
         m_logger.Critical("Failed to initialize Market Quality composite calculator.");
         return false;
      }

      // 2. Create the Market Classifier
      m_marketClassifier = new CMarketClassifier(m_logger);
      if(!m_marketClassifier.Initialize(
         m_trendEngine, m_momentumEngine, m_volatilityEngine, m_volumeEngine,
         m_vwapEngine, m_liquidityEngine, m_patternEngine, m_sessionEngine, m_structureEngine))
      {
         m_logger.Critical("Failed to initialize Market Classifier.");
         return false;
      }

      // 3. Create Strategy Manager and Portfolio Manager
      m_strategyManager = new CStrategyManager(m_logger);
      m_portfolioManager = new CPortfolioManager(m_logger, m_config);

      // Register Bespoke Gold Strategies (GoldEngine V5)
      CG001_AsianRangeSweep* g001 = new CG001_AsianRangeSweep(m_logger, m_config);
      g001.SetEnabled(InpEnableG001);
      m_strategyManager.RegisterStrategy(g001);

      CG002_NYOrderBlockFVG* g002 = new CG002_NYOrderBlockFVG(m_logger, m_config);
      g002.SetEnabled(InpEnableG002);
      m_strategyManager.RegisterStrategy(g002);

      CG003_M5VwapScalper* g003 = new CG003_M5VwapScalper(m_logger, m_config);
      g003.SetEnabled(InpEnableG003);
      m_strategyManager.RegisterStrategy(g003);

      CG004_PostNewsImbalance* g004 = new CG004_PostNewsImbalance(m_logger, m_config);
      g004.SetEnabled(InpEnableG004);
      m_strategyManager.RegisterStrategy(g004);

      CG005_DailyKeyLevelSweep* g005 = new CG005_DailyKeyLevelSweep(m_logger, m_config);
      g005.SetEnabled(InpEnableG005);
      m_strategyManager.RegisterStrategy(g005);

      CG008_MomentumExpansion* g008 = new CG008_MomentumExpansion();
      g008.SetEnabled(true);
      m_strategyManager.RegisterStrategy(g008);

      QuantEnginesContainer container;
      container.Trend = m_trendEngine;
      container.Momentum = m_momentumEngine;
      container.Volatility = m_volatilityEngine;
      container.Volume = m_volumeEngine;
      container.Vwap = m_vwapEngine;
      container.Liquidity = m_liquidityEngine;
      container.Pattern = m_patternEngine;
      container.Session = m_sessionEngine;
      container.MarketStructure = m_structureEngine;
      container.MarketContext = NULL;
      container.Decision = NULL;
      container.Opportunity = NULL;
      container.Movement = NULL;
      container.Intent = NULL;
      container.Planner = NULL;
      container.TradeManager = NULL;

      // Instantiate and Initialize Market Context Engine
      m_marketContextEngine = new CMarketContextEngine();
      if(!m_marketContextEngine.Initialize(container, m_marketQuality))
      {
         m_logger.Critical("Failed to initialize Market Context Engine.");
         return false;
      }
      container.MarketContext = m_marketContextEngine;

      // Instantiate and Initialize Decision Engine
      m_decisionEngine = new CDecisionEngine();
      if(!m_decisionEngine.Initialize(m_marketContextEngine))
      {
         m_logger.Critical("Failed to initialize Decision Engine.");
         return false;
      }
      container.Decision = m_decisionEngine;

      // Instantiate and Initialize GITS-X Movement Engine
      m_movementEngine = new CMovementEngine(m_logger, m_config);
      container.Movement = m_movementEngine;
      if(!m_movementEngine.Initialize(container))
      {
         m_logger.Critical("Failed to initialize GITS-X Movement Engine.");
         return false;
      }

      // Instantiate and Initialize GITS-X Market Intent Engine
      m_marketIntentEngine = new CMarketIntentEngine(m_logger, m_config);
      container.Intent = m_marketIntentEngine;
      if(!m_marketIntentEngine.Initialize(container))
      {
         m_logger.Critical("Failed to initialize GITS-X Market Intent Engine.");
         return false;
      }

      // Instantiate and Initialize GITS-X Opportunity Engine
      m_opportunityEngine = new COpportunityEngine(m_logger, m_config);
      container.Opportunity = m_opportunityEngine;
      if(!m_opportunityEngine.Initialize(container))
      {
         m_logger.Critical("Failed to initialize GITS-X Opportunity Engine.");
         return false;
      }

      // Instantiate and Initialize GITS-X Trade Planner Engine
      m_tradePlannerEngine = new CTradePlannerEngine(m_logger, m_config);
      container.Planner = m_tradePlannerEngine;
      if(!m_tradePlannerEngine.Initialize(container))
      {
         m_logger.Critical("Failed to initialize GITS-X Trade Planner Engine.");
         return false;
      }

      // Instantiate and Initialize GITS Trade Health Engine
      m_tradeHealthEngine = new CTradeHealthEngine();
      container.TradeHealth = m_tradeHealthEngine;
      if(!m_tradeHealthEngine.Initialize(container))
      {
         m_logger.Critical("Failed to initialize GITS Trade Health Engine.");
         return false;
      }
 
      // Instantiate and Initialize GITS Trade Manager V1
      m_tradeManager = new CTradeManager(*m_logger);
      container.TradeManager = m_tradeManager;
      if(!m_tradeManager.Initialize(container, m_config))
      {
         m_logger.Critical("Failed to initialize GITS Trade Manager V1.");
         return false;
      }
 
      // Instantiate and Initialize GITS Trade Optimization Engine
      m_tradeOptEngine = new CTradeOptimizationEngine();
      container.TradeOptimization = m_tradeOptEngine;
      if(!m_tradeOptEngine.Initialize(container, m_config))
      {
         m_logger.Critical("Failed to initialize GITS Trade Optimization Engine.");
         return false;
      }
 
      // Instantiate and Initialize GITS Pullback vs Reversal Intelligence Engine
      m_pullbackEngine = new CPullbackReversalEngine();
      container.PullbackReversal = m_pullbackEngine;
      if(!m_pullbackEngine.Initialize(container,
                                       InpEnablePullbackEngine,
                                       InpMinContinuationProb,
                                       InpMinReversalProb,
                                       InpBreakoutThreshold,
                                       InpFakeBreakoutThreshold,
                                       InpEmaLength,
                                       InpAtrLength,
                                       InpWeightVolume,
                                       InpWeightMovement,
                                       InpWeightIntent,
                                       InpWeightTradeHealth,
                                       InpEnableNarratives))
      {
         m_logger.Critical("Failed to initialize GITS Pullback vs Reversal Engine.");
         return false;
      }

      // Instantiate and Initialize GITS Adaptive Exit AI Engine
      m_adaptiveExitEngine = new CAdaptiveExitAIEngine();
      container.AdaptiveExit = m_adaptiveExitEngine;
      if(!m_adaptiveExitEngine.Initialize(container,
                                           InpEnableAdaptiveExitAI,
                                           InpHoldThreshold,
                                           InpExitThreshold,
                                           InpRunnerThreshold,
                                           InpTrailThreshold,
                                           InpConfidenceThreshold))
      {
         m_logger.Critical("Failed to initialize GITS Adaptive Exit AI Engine.");
         return false;
      }
 
      // Instantiate and Initialize GITS Institutional Execution Coordinator
      m_instExecution = new CInstitutionalExecutionManager();
      container.InstitutionalExecution = m_instExecution;
      if(!m_instExecution.Initialize(container,
                                     InpEnableInstExecution,
                                     InpEnableMultiPosition,
                                     InpMaxConcurrentPositions,
                                     InpMaxBuyPositions,
                                     InpMaxSellPositions,
                                     InpMaxExposureLots,
                                     InpMaxRiskPercent,
                                     InpEnableScaleIn,
                                     InpScaleInThreshold,
                                     InpEnableScaleOut,
                                     InpPartialExitLevels,
                                     InpRunnerPromotionThresh,
                                     InpEnableDynamicAllocation,
                                     InpFixedLotMode,
                                     InpPriorityThreshold,
                                     InpPortfolioHealthThresh))
      {
         m_logger.Critical("Failed to initialize GITS Institutional Execution Coordinator.");
         return false;
      }

      m_strategyManager.LoadStrategies(container);

      // Initialize Strategy Validation & Explainability Framework
      m_explainability = new CExplainabilityFramework();
      if(!m_explainability.Initialize(m_config, container, m_marketQuality))
      {
         m_logger.Critical("Failed to initialize Strategy Validation & Explainability Framework.");
         return false;
      }

      // 4. Create Risk and Execution
      m_riskGuardian = new CRiskGuardian(m_logger, m_config);
      m_riskGuardian.InitializeRiskGuardian(m_sessionEngine);
      
      m_executionEngine = new CExecutionEngine(m_logger, m_config);

      // 5. Create the 5 independent Analytics components
      m_tradeStatistics = new CTradeStatistics(m_logger);
      m_performanceTracker = new CPerformanceTracker(m_logger);
      m_strategyRanking = new CStrategyRanking(m_logger);
      m_backtestComparison = new CBacktestComparison(m_logger);
      m_optimizationDb = new COptimizationDatabase(m_logger);
      m_researchFramework = new CResearchFramework(m_logger, m_config);

      // Create GITS V5.2.1 Trade Memory
      m_tradeMemory = new CTradeMemory(60.0);
      m_tradeManager.SetTradeMemory(m_tradeMemory);

      // 6. Create Dashboard
      m_dashboard = new CDashboard(m_logger, m_config, m_opportunityEngine, m_movementEngine, m_marketIntentEngine,
                                   m_tradePlannerEngine, m_tradeManager, m_pullbackEngine, m_adaptiveExitEngine, m_instExecution);
      m_dashboard.SetProfile(InpTradingProfile);  // V5.1: wire profile into dashboard
      m_dashboard.SetTradeMemory(m_tradeMemory);
      m_dashboard.Render();

      // 7. Create GITS Control Center Bridge Layer (V4.4)
      m_bridge = new CGITSBridge();
      m_bridge.Initialize("GITS_Bridge\\gits_state.json", "GITS_Bridge\\gits_config.json");

      m_lastBarTime = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);

      m_isInitSuccessful = true;
      m_logger.Info("GITS V2.7 initialized successfully with Production Rules.");
      m_logger.Info("==================================================");
      return true;
   }

   /**
    * @brief GITS deinitialization.
    */
   void OnDeinit(const int reason)
   {
      if(m_logger != NULL && CheckPointer(m_logger) != POINTER_INVALID)
      {
         m_logger.Info("GITS shutting down. Reason: " + (string)reason);
      }
      else
      {
         Print("GITS shutting down (logger offline). Reason: ", reason);
      }

      if(m_dashboard != NULL && CheckPointer(m_dashboard) != POINTER_INVALID)
      {
         m_dashboard.DestroyHUD();
      }

      if(m_researchFramework != NULL && CheckPointer(m_researchFramework) != POINTER_INVALID)
      {
         m_researchFramework.AnalyzeAndReport();
      }

      // Generate the backtest statistics summary
      if(m_explainability != NULL && CheckPointer(m_explainability) != POINTER_INVALID)
      {
         m_explainability.GenerateDashboardSummary();
      }
   }

   /**
    * @brief Event handler on every tick.
    */
   void OnTick()
   {
      if(!m_isInitSuccessful || m_lifecycle == NULL || !m_lifecycle.IsOperational())
         return;

      QuantEnginesContainer container;
      container.Trend = m_trendEngine;
      container.Momentum = m_momentumEngine;
      container.Volatility = m_volatilityEngine;
      container.Volume = m_volumeEngine;
      container.Vwap = m_vwapEngine;
      container.Liquidity = m_liquidityEngine;
      container.Pattern = m_patternEngine;
      container.Session = m_sessionEngine;
      container.MarketStructure = m_structureEngine;
      container.MarketContext = m_marketContextEngine;
      container.Decision = m_decisionEngine;
      container.Opportunity = m_opportunityEngine;
      container.Movement = m_movementEngine;
      container.Intent = m_marketIntentEngine;
      container.Planner = m_tradePlannerEngine;
      container.TradeManager = m_tradeManager;

      // 1. Update active Quant Engines
      m_trendEngine.Update();
      m_momentumEngine.Update();
      m_volatilityEngine.Update();
      m_volumeEngine.Update();
      m_vwapEngine.Update();
      m_liquidityEngine.Update();
      m_patternEngine.Update();
      m_sessionEngine.Update();
      m_structureEngine.Update();

      // 1.5 Update Market Context
      m_marketContextEngine.UpdateContext(_Symbol, _Period);

      // 1.6 Evaluate Decisions
      m_decisionEngine.EvaluateDecision(_Symbol, _Period);
 
      // 1.65 Update Movement Engine
      m_movementEngine.UpdateMovement(_Symbol, _Period);

      // 1.66 Update Market Intent Engine
      m_marketIntentEngine.UpdateIntent(_Symbol, _Period);
 
      // 1.7 Update Opportunity Engine
         m_opportunityEngine.UpdateOpportunity(_Symbol, _Period);

      // 1.75 Update Trade Planner Engine
      m_tradePlannerEngine.UpdatePlan(_Symbol, _Period);
 
      // 1.76 Update Self Learning Trade Optimization Engine
      if(m_tradeOptEngine != NULL)
      {
         m_tradeOptEngine.Update(_Symbol);
      }
 
      // 1.765 Update Pullback vs Reversal Intelligence Engine
      if(m_pullbackEngine != NULL)
      {
         m_pullbackEngine.Update(_Symbol);
      }
 
      // 1.766 Update GITS Adaptive Exit AI Engine
      if(m_adaptiveExitEngine != NULL)
      {
         m_adaptiveExitEngine.Update(_Symbol);
      }
 
      // 1.767 Update GITS Institutional Execution Coordinator
      if(m_instExecution != NULL)
      {
         m_instExecution.Update(_Symbol);
      }
 
      // 1.77 Process Trade Manager dynamic exit updates
      if(m_tradeManager != NULL)
      {
         m_tradeManager.ManageActiveTrades(_Symbol);
      }
 
      // 1.8 Update Research Framework Excursion and Closure Trackers
      if(m_researchFramework != NULL)
      {
         m_researchFramework.UpdateOnTick(_Symbol);
         m_researchFramework.CheckClosedTrades(_Symbol, container);
      }
 
      // 2. Process Classifier
      m_marketClassifier.Update(_Symbol);
 
      // 3. New Bar Check: Print report
      if(IsNewBar())
      {
         if(InpDebugMode)
         {
            PrintBarDebugReport();
         }
      }
 
      // 4. Strategy Manager evaluates strategies (S-002 active)
      StrategyResponse rawResponses[];
      int rawCount = m_strategyManager.EvaluateAll(_Symbol, rawResponses);
 
      // CRITICAL ISSUE 8 & 9: Decision Audit & Pipeline Checks
      for(int i = 0; i < rawCount; i++)
      {
         if(rawResponses[i].Signal == GEV2_SIGNAL_NONE) continue;
         
         // V2.7.2: Decision Trace Diagnostic - prints all filter scores for every candle
         PrintDecisionTrace(rawResponses[i]);

         double rawScore = rawResponses[i].RawStrategyScore;
         double compositeScore = rawResponses[i].CompositeScore;
         double stratPenalty = rawResponses[i].PenaltyScore;

         string s002SignalStr = "NO TRADE";
         if(rawResponses[i].Signal == GEV2_SIGNAL_BUY)  s002SignalStr = "BUY";
         if(rawResponses[i].Signal == GEV2_SIGNAL_SELL) s002SignalStr = "SELL";

         string portfolioOutputStr = "NONE";
         string riskGuardianStatus = "NOT REACHED";
         string executionSignalStr = "NONE";
         string orderSentStr = "NO";
         string finalDecisionStr = "NO TRADE";
         
         double totalPenalty = stratPenalty;
         double finalExecutionScore = 0.0;
         string decisionStr = "WAIT";
         string rejectionReason = "";
         string blockReason = "New opportunity confirmed";

         // 1. Risk Guardian Stage (performs Hard checks and calculates Soft penalties)
         RiskAuditResponse riskResponse;
         riskResponse.PenaltyScore = 0.0;
         riskResponse.Approved = false;
         riskResponse.Reason = "None";

         bool riskAllowed = m_riskGuardian.AuditSignal(rawResponses[i], riskResponse);
         totalPenalty += riskResponse.PenaltyScore;

         // Clamp total penalties in research mode to 0 (V5.2.0 requirement 7)
         if(m_config.IsResearchMode())
         {
            totalPenalty = 0.0;
         }

         // Calculate Base Execution Score
         finalExecutionScore = compositeScore - totalPenalty;
          
         // GITS V5.3 Entry Quality and Recovery Probability Calculations
         double entryQuality = 0.0;
         double preRecoveryProb = 0.0;
         double recoveryMod = 0.0;
         double statsMod = 0.0;
          
         if(rawResponses[i].StrategyName != "S-003b" && rawResponses[i].StrategyName != "S-004" && rawResponses[i].StrategyName != "S-005" && rawResponses[i].StrategyName != "S-006")
         {
            entryQuality = CEntryQualityEngine::CalculateEntryQuality(_Symbol, rawResponses[i].Signal, m_trendEngine, m_structureEngine, m_pullbackEngine, m_momentumEngine, m_volumeEngine, m_liquidityEngine, m_volatilityEngine, m_sessionEngine, m_marketIntentEngine, m_opportunityEngine);
            preRecoveryProb = CEntryQualityEngine::CalculateRecoveryProbability(_Symbol, rawResponses[i].Signal, m_trendEngine, m_pullbackEngine, m_marketIntentEngine);
             
            // Apply recovery probability modifier (if < 50%, reduce confidence)
            recoveryMod = (preRecoveryProb < 50.0) ? -15.0 : 0.0;
             
            // Apply recent trade stats modifier
            double buyMod = m_tradeMemory.GetBuyModifier();
            double sellMod = m_tradeMemory.GetSellModifier();
            if(rawResponses[i].Signal == GEV2_SIGNAL_BUY) statsMod += buyMod;
            else if(rawResponses[i].Signal == GEV2_SIGNAL_SELL) statsMod += sellMod;
             
            if(m_tradeMemory.GetCount() >= 5)
            {
               double wr = m_tradeMemory.GetWinRate();
               if(wr >= 65.0) statsMod += 10.0;
               else if(wr < 40.0) statsMod -= 10.0;
            }

            finalExecutionScore = finalExecutionScore + recoveryMod + statsMod;
         }

         finalExecutionScore = MathMax(0.0, MathMin(100.0, finalExecutionScore));
 
         // GITS V5.3: Calculate Adaptive SL and Dynamic TP levels
         if(rawResponses[i].StrategyName != "S-003b" && rawResponses[i].StrategyName != "S-004" && rawResponses[i].StrategyName != "S-005" && rawResponses[i].StrategyName != "S-006")
         {
            CalculateAdaptiveStopLossAndTakeProfit(_Symbol, rawResponses[i].Signal, rawResponses[i].EntryPrice, rawResponses[i].StopLoss, rawResponses[i].TakeProfit);
         }

         double momentumVal = m_momentumEngine.GetMomentumScore();
         string structState = m_structureEngine.GetStructureState();
         int regimeVal = (m_marketContextEngine != NULL) ? m_marketContextEngine.GetContext().MarketRegime : 0;
         double pointVal = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

         bool isApproved = false;
         if(!riskAllowed)
         {
            // Hard Rejection occurred
            decisionStr = "REJECTED (Hard Block)";
            rejectionReason = riskResponse.Reason;
            riskGuardianStatus = "HARD REJECTED: " + riskResponse.Reason;
            blockReason = "Risk Guardian block";
         }
         else
         {
            riskGuardianStatus = (riskResponse.PenaltyScore > 0.0) ? StringFormat("ADVISED (Soft Penalty: %.1f)", riskResponse.PenaltyScore) : "APPROVED";
            isApproved = true;
            decisionStr = "APPROVED";
            blockReason = "Strategy setup confirmed & Risk Guardian approved";
         }

         // Update raw response score for explainability / rank tracking
         rawResponses[i].StrategyScore = finalExecutionScore;

         if(!isApproved)
         {
            portfolioOutputStr = "NONE";
            executionSignalStr = "NONE";
            orderSentStr = "NO";
            finalDecisionStr = "NO TRADE";

            m_explainability.LogDecision(rawResponses[i], riskResponse, false);

            if(m_dashboard != NULL)
               m_dashboard.RecordSignalResult(false, rejectionReason);
         }
         else
         {
            if(rawResponses[i].Signal == GEV2_SIGNAL_BUY)  portfolioOutputStr = "BUY";
            if(rawResponses[i].Signal == GEV2_SIGNAL_SELL) portfolioOutputStr = "SELL";
            executionSignalStr = portfolioOutputStr;

            // 4. Execution Engine stage
            bool executed = m_executionEngine.ExecuteSignal(rawResponses[i], m_config.GetMagicNumber());
            if(executed)
            {
               orderSentStr = "YES";
               finalDecisionStr = portfolioOutputStr;

               m_explainability.LogDecision(rawResponses[i], riskResponse, true);
               ulong dealTicket = m_executionEngine.GetLastDealTicket();
               m_tradeStatistics.RecordTrade(dealTicket, rawResponses[i]);
               m_explainability.RecordAcceptedTradeTicket(dealTicket, rawResponses[i].Confidence * 100.0);

               // Record snapshots for stabilization
               m_lastExecutedTime = TimeCurrent();
               m_lastExecutedPrice = rawResponses[i].EntryPrice;
               m_lastExecutedStructure = structState;
               m_lastStopHuntActive = m_liquidityEngine.IsStopHuntActive();
               m_lastMomentumScore = momentumVal;
               m_lastExecutedDirection = rawResponses[i].Signal;
               if(m_pullbackEngine != NULL)
                  m_lastPullbackRec = PullbackRecToString(m_pullbackEngine.GetEvaluationContext().Recommendation);
               else
                  m_lastPullbackRec = "N/A";

               if(m_researchFramework != NULL)
               {
                  m_researchFramework.OnTradeOpen(dealTicket, rawResponses[i], container);
               }

               if(m_dashboard != NULL)
                  m_dashboard.RecordSignalResult(true, "");
            }
            else
            {
               orderSentStr = "FAILED";
               finalDecisionStr = "NO TRADE";

               string execBlockReason = "Execution Blocked (Broker/Margin/Market)";
               riskResponse.Reason = execBlockReason;
               m_explainability.LogDecision(rawResponses[i], riskResponse, false);

               if(m_dashboard != NULL)
                  m_dashboard.RecordSignalResult(false, execBlockReason);
            }
         }

         // V5.3 Standardized Stable Decision Audit Block
         Print("=========================================");
         Print("Unified Decision Engine Audit (V5.3)");
         Print("=========================================");
         Print(StringFormat("Raw Strategy Score:     %.1f", rawScore));
         Print(StringFormat("Composite Score:        %.1f", compositeScore));
         Print(StringFormat("Penalty Score:          %.1f", totalPenalty));
         Print(StringFormat("Entry Quality Score:    %.1f", entryQuality));
         Print(StringFormat("Recovery Probability:   %.1f", preRecoveryProb));
         Print(StringFormat("Final Execution Score:  %.1f", finalExecutionScore));
         Print(StringFormat("Trade Block Reason:     %s", blockReason));
         Print(StringFormat("Decision:               %s", decisionStr));
         if(!isApproved)
         {
            Print(StringFormat("Rejection Reason:       %s", rejectionReason));
         }
         Print("=========================================");

         // V5.1 ENTRY BLOCK REPORT (only printed if rejected/wait occurs)
         if(!isApproved)
         {
            // Gather intelligence engine data for Entry Block Report
            double   tmHealthScore   = 0.0;
            string   tmHealthState   = "N/A";
            string   aeRecStr        = "N/A";
            string   ieRecStr        = "N/A";
            if(m_tradeManager != NULL && m_tradeManager.GetActiveTrackingCount() > 0)
            {
               TradeTrackingState ts;
               if(m_tradeManager.GetTrackingState(0, ts))
               {
                  tmHealthScore = ts.HealthScore;
                  tmHealthState = ts.HealthStateStr;
               }
            }
            if(m_adaptiveExitEngine != NULL)
            {
               AdaptiveExitContext aeCtx = m_adaptiveExitEngine.GetExitContext();
               aeRecStr = AdaptiveExitActionToString(aeCtx.Recommendation);
            }
            if(m_instExecution != NULL)
            {
               InstitutionalExecutionContext ieCtx = m_instExecution.GetExecutionContext();
               ieRecStr = InstitutionalExecActionToString(ieCtx.Recommendation);
            }

            Print("=========================");
            Print("ENTRY BLOCK REPORT");
            Print(StringFormat("Signal:              %s", s002SignalStr));
            Print(StringFormat("Score:               %.1f", finalExecutionScore));
            Print(StringFormat("Trade Health:        %.1f (%s)", tmHealthScore, tmHealthState));
            Print(StringFormat("Adaptive Exit:       %s", aeRecStr));
            Print(StringFormat("Institutional Mgr:   %s", ieRecStr));
            Print(StringFormat("Margin (Free):       %.2f", AccountInfoDouble(ACCOUNT_MARGIN_FREE)));
            Print(StringFormat("Broker Status:       %s", (bool)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE) ? "OK" : "DISABLED"));
            Print("Result:              REJECTED");
            Print("Reason:              " + (rejectionReason == "" ? riskResponse.Reason : rejectionReason));
            Print("=========================");
         }
      }
 
      // 7. Update Analytics sub-components
      m_performanceTracker.UpdateMetrics();
      m_strategyRanking.EvaluateRankings();
      m_backtestComparison.CompareLiveVsBacktest();
 
      // 8. Update graphical Dashboard overlay
      m_dashboard.UpdateMetrics(m_tradeStatistics, m_performanceTracker);
 
      // 9. Update Risk stats
      m_riskGuardian.UpdateRiskState();
    }
 
    /**
     * @brief Timer updates.
     */
    void OnTimer()
    {
       if(m_dashboard != NULL)
       {
          m_dashboard.UpdateMetrics(m_tradeStatistics, m_performanceTracker);
       }

       // 1. Bridge Configuration check and dynamic application
       if(m_bridge != NULL)
       {
          GITSBridgeConfig cfg;
          if(m_bridge.CheckAndApplyConfig(cfg))
          {
             m_config.SetRiskPercent(cfg.Risk.RiskPercent);
             m_config.SetMaxDailyLossPercent(cfg.Risk.MaxDailyLossPercent);
             m_config.SetMaxWeeklyLossPercent(cfg.Risk.MaxWeeklyLossPercent);
             m_config.SetMaximumOpenPositions(cfg.Risk.MaxPositions);
             m_config.SetMaximumExposurePercent(cfg.Risk.MaxExposurePercent);
             
             // Dynamic Trade Manager overrides
             m_config.SetEnableTradeManager(cfg.TM.EnableTradeManager);
             m_config.SetEnableBreakEven(cfg.TM.EnableBreakEven);
             m_config.SetBreakEvenTrigger(cfg.TM.BreakEvenTrigger);
             m_config.SetBreakEvenOffset(cfg.TM.BreakEvenOffset);
             m_config.SetEnableTrailing(cfg.TM.EnableTrailing);
             m_config.SetTrailingMode(cfg.TM.TrailingMode);
             m_config.SetTmAtrMultiplier(cfg.TM.TmAtrMultiplier);
             m_config.SetMinTrailDistance(cfg.TM.MinTrailDistance);
             m_config.SetMaxTrailDistance(cfg.TM.MaxTrailDistance);
             m_config.SetEnableProfitLock(cfg.TM.EnableProfitLock);
             m_config.SetProfitLockStep(cfg.TM.ProfitLockStep);
             m_config.SetMinLockedProfit(cfg.TM.MinLockedProfit);
          }
       }

       // 2. Export runtime state to GITS Bridge
       if(m_bridge != NULL)
       {
          QuantEnginesContainer container;
          container.Trend           = m_trendEngine;
          container.Momentum        = m_momentumEngine;
          container.Volatility      = m_volatilityEngine;
          container.Volume          = m_volumeEngine;
          container.Vwap            = m_vwapEngine;
          container.Liquidity       = m_liquidityEngine;
          container.Pattern         = m_patternEngine;
          container.Session         = m_sessionEngine;
          container.MarketStructure = m_structureEngine;
          container.MarketContext    = m_marketContextEngine;
          container.Decision        = m_decisionEngine;
          container.Opportunity     = m_opportunityEngine;
          container.Movement        = m_movementEngine;
          container.Intent          = m_marketIntentEngine;
          container.Planner         = m_tradePlannerEngine;

          double currentSpread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
          m_bridge.ExportState(container, m_tradeStatistics, m_performanceTracker, m_riskGuardian, currentSpread);
       }
    }
 
    /**
     * @brief Trade transactions.
     */
    void OnTrade()
    {
       if(m_executionEngine != NULL)
       {
          m_executionEngine.SynchronizeTrades();
       }
    }

   /**
    * @brief Graphic user events.
    */
    void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
    {
       if(m_dashboard != NULL)
       {
          m_dashboard.OnChartEvent(id, lparam, dparam, sparam);
       }
    }
};

//--- Global Instance
CMainEA ExtMainEA;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   if(!ExtMainEA.OnInit())
   {
      return INIT_FAILED;
   }
   EventSetMillisecondTimer(250);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   ExtMainEA.OnDeinit(reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   ExtMainEA.OnTick();
}

//+------------------------------------------------------------------+
//| Expert timer function                                            |
//+------------------------------------------------------------------+
void OnTimer()
{
   ExtMainEA.OnTimer();
}

//+------------------------------------------------------------------+
//| Expert trade function                                            |
//+------------------------------------------------------------------+
void OnTrade()
{
   ExtMainEA.OnTrade();
}

//+------------------------------------------------------------------+
//| Expert chart event function                                      |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   ExtMainEA.OnChartEvent(id, lparam, dparam, sparam);
}
