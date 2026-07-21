//+------------------------------------------------------------------+
//|                                                       Config.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_CONFIG_MQH
#define GOLDENGINEV2_CONFIG_MQH

//+------------------------------------------------------------------+
//| Configuration storage and validation class                       |
//+------------------------------------------------------------------+
class CConfig
{
private:
   // General Settings
   ulong             m_magicNumber;
   string            m_logsFilePrefix;
   bool              m_autoTradingEnabled;
   
   // Risk Settings (General)
   double            m_riskPercent;
   bool              m_useFixedLot;
   double            m_fixedLotSize;
   bool              m_useCompoundingLot;   // V5.5
   bool              m_enableCapitalLock;   // V5.5
   double            m_capitalLockTrigger;  // V5.5
   double            m_capitalLockFloor;    // V5.5
   bool              m_compoundOnTotalBalance; // Option A compounding
   bool              m_enableHealthLock;       // Trade Health Profit Lock toggle
   double            m_healthLockMinPoints;    // Minimum profit points to trigger health lock
   double            m_maxLossPer001Lot;       // Max monetary loss limit per 0.01 lot
   int               m_maxSpreadPoints;
   int               m_maxDailyTrades;
   
   // Session Filter Settings
   string            m_allowedTradingHours; // Format "HH:MM-HH:MM"
   
   // Execution Settings
   int               m_slippagePoints;

   // Production Risk Guardian Settings (V2.3 additions)
   bool              m_enableRiskGuardian;
   double            m_maxDailyLossPercent;
   double            m_maxWeeklyLossPercent;
   double            m_maxDrawdownPercent;
   int               m_maxConsecutiveLosses;
   int               m_pauseMinutes;
   double            m_maximumExposurePercent;
   int               m_maximumOpenPositions;
   int               m_maximumSpreadPoints;
   bool              m_enableSessionFilter;
   bool              m_enableCooldown;
   int               m_cooldownMinutes;
   bool              m_emergencyStop;

   // Advanced Quant Engine Configuration Settings (V2.4 additions)
   int               m_rsiPeriod;
   int               m_volumePeriod;
   double            m_volumeSpikeRatio;
   int               m_equalThresholdPoints;
   
   // Market Quality composite weights
   double            m_trendWeight;
   double            m_momentumWeight;
   double            m_volatilityWeight;
   double            m_volumeWeight;
   double            m_structureWeight;
   double            m_liquidityWeight;
   double            m_sessionWeight;

   // Strategy S-002 Configuration Settings (V2.5 additions)
   double            m_s002_MinScore;
   double            m_s002_WeightTrend;
   double            m_s002_WeightMomentum;
   double            m_s002_WeightVolume;
   double            m_s002_WeightVolatility;
   double            m_s002_WeightStructure;
   double            m_s002_WeightLiquidity;
   double            m_s002_WeightSession;
   double            m_s002_WeightQuality;
   
   int               m_s002_ExitModel; // 0=Risk Reward, 1=ATR Target, 2=EMA Exit, 3=Trailing, 4=Break-even, 5=Time Exit
   double            m_s002_RRRatio;
   double            m_s002_AtrMultiplier;
   int               m_s002_EmaExitPeriod;
   int               m_s002_TrailingStopPoints;
   int               m_s002_BreakEvenPoints;
   int               m_s002_TimeExitMinutes;

   // Strategy Validation & Explainability (V2.6 additions)
   bool              m_enableExplainability;
   string            m_csvExportFileName;

   // S-002 Production Rules Filter Modes and Thresholds (V2.7.1 additions)
   ENUM_FILTER_MODE  m_s002_ModeTrend;
   ENUM_FILTER_MODE  m_s002_ModeMomentum;
   ENUM_FILTER_MODE  m_s002_ModeVolume;
   ENUM_FILTER_MODE  m_s002_ModeVolatility;
   ENUM_FILTER_MODE  m_s002_ModeStructure;
   ENUM_FILTER_MODE  m_s002_ModeLiquidity;
   ENUM_FILTER_MODE  m_s002_ModeSession;
   ENUM_FILTER_MODE  m_s002_ModeQuality;
   
   double            m_s002_MinTrendStrength;
   double            m_s002_MinRvol;
   double            m_s002_MinMqScore;

   // Strategy S-003 Configuration Settings
   double            m_s003_MaxAtrMultiplier;
   double            m_s003_MinAtrMultiplier;
   double            m_s003_MaxSpreadPoints;
   bool              m_s003_FilterRanging;
   double            m_s003_MinEnvironmentScore;
   bool              m_s003_NewsOpportunityMode;
   bool              m_s003_SessionOpenOpportunity;
   bool              m_s003_EnableEarlyMTFEntry;
   bool              m_autoCapitalLock;
   double            m_lockStepUSD;
   double            m_riskProfitPercent;
   bool              m_s003_EnableADXFilter;             // Phase 1
   double            m_s003_MinADXThreshold;             // Phase 1
   double            m_s003_BreakoutBufferPoints;        // Phase 1
   double            m_s003_BreakoutExtensionPoints;     // Phase 1
   double            m_s003b_RRRatio;                    // Phase 1

   // GITS V3.4 additions
   bool              m_enableCalendarNewsFilter;

   // GITS Trade Manager V1 Settings (V4.6 additions)
   bool              m_enableTradeManager;
   bool              m_enableBreakEven;
   double            m_breakEvenTrigger;
   double            m_breakEvenOffset;
   double            m_stage2Trigger;
   double            m_stage2Offset;
   double            m_stage3Trigger;
   double            m_stage3Offset;
   bool              m_enableTrailing;
   int               m_trailingMode;
   double            m_tmAtrMultiplier;
   double            m_minTrailDistance;
   double            m_maxTrailDistance;
   bool              m_enableProfitLock;
   double            m_profitLockStep;
   double            m_minLockedProfit;

   // Trading Profile (V5.1 addition)
   ENUM_TRADING_PROFILE m_tradingProfile;  // Active trading profile (Research or Production)

   // S-004 Donchian Breakout Settings
   bool              m_enableS004;
   ENUM_TIMEFRAMES   m_s004Timeframe;
   int               m_s004ChannelLength;
   int               m_s004EmaPeriod;
   int               m_s004AtrPeriod;
   double            m_s004AtrMultiplier;
   double            m_s004TargetMult;
   double            m_s004MinSLPoints;
   double            m_s004MaxSLPoints;

   // S-005 Volume Breakout Settings
   bool              m_enableS005;
   ENUM_TIMEFRAMES   m_s005Timeframe;
   int               m_s005ChannelLength;
   int               m_s005EmaPeriod;
   int               m_s005VolSmaPeriod;
   double            m_s005VolMultiplier;
   int               m_s005AtrPeriod;
   double            m_s005AtrMultiplier;
   double            m_s005TargetMult;
   double            m_s005MinSLPoints;
   double            m_s005MaxSLPoints;

   // S-006 Scalp Momentum Settings
   bool              m_enableS006;
   ENUM_TIMEFRAMES   m_s006Timeframe;
   int               m_s006Ema9Period;
   int               m_s006Ema200Period;
   int               m_s006VolSmaPeriod;
   double            m_s006VolMultiplier;
   int               m_s006RsiPeriod;
   double            m_s006RsiMinBuy;
   double            m_s006RsiMaxBuy;
   double            m_s006RsiMinSell;
   double            m_s006RsiMaxSell;
   int               m_s006AtrPeriod;
   double            m_s006AtrMultiplier;
   double            m_s006TargetMult;
   double            m_s006MinSLPoints;
   double            m_s006MaxSLPoints;

public:
   /**
    * @brief Constructor with default values.
    */
   CConfig()
   {
      m_magicNumber              = 999123;
      m_logsFilePrefix           = "GoldEngineV4";
      m_autoTradingEnabled       = true;
      m_riskPercent              = 1.0;
      m_useFixedLot              = false;
      m_fixedLotSize             = 0.1;
      m_useCompoundingLot        = false; // V5.5
      m_enableCapitalLock        = false; // V5.5: Off by default for small accounts
      m_capitalLockTrigger       = 150.0; // V5.5
      m_capitalLockFloor         = 20.0;  // V5.5: Lowered floor to $20.00 so small accounts can trade down to $20
      m_compoundOnTotalBalance   = true;  // Option A compounding
      m_enableHealthLock         = false; // Default false (off by default to prevent choking wiggles)
      m_healthLockMinPoints      = 300.0; // Minimum 3.0 pips profit before locking
      m_maxLossPer001Lot         = 4.0;   // Default $4.00 loss limit per 0.01 lot (40 pips)
      m_enableS004               = true;  // Enabled by default in V3
      m_s004Timeframe            = PERIOD_M5;
      m_s004ChannelLength        = 20;
      m_s004EmaPeriod            = 200;
      m_s004AtrPeriod            = 14;
      m_s004AtrMultiplier        = 2.0;
      m_s004TargetMult           = 1.5;
      m_s004MinSLPoints          = 150.0;
      m_s004MaxSLPoints          = 800.0;

      // S-005 Defaults
      m_enableS005               = true;
      m_s005Timeframe            = PERIOD_M5;
      m_s005ChannelLength        = 20;
      m_s005EmaPeriod            = 200;
      m_s005VolSmaPeriod         = 10;
      m_s005VolMultiplier        = 1.8;
      m_s005AtrPeriod            = 14;
      m_s005AtrMultiplier        = 2.0;
      m_s005TargetMult           = 2.0; // 1:2 Risk-to-Reward
      m_s005MinSLPoints          = 150.0;
      m_s005MaxSLPoints          = 800.0;

      // S-006 Defaults
      m_enableS006               = true;
      m_s006Timeframe            = PERIOD_M5;
      m_s006Ema9Period           = 9;
      m_s006Ema200Period         = 200;
      m_s006VolSmaPeriod         = 20;
      m_s006VolMultiplier        = 1.2;
      m_s006RsiPeriod            = 14;
      m_s006RsiMinBuy            = 45.0;
      m_s006RsiMaxBuy            = 65.0;
      m_s006RsiMinSell           = 35.0;
      m_s006RsiMaxSell           = 55.0;
      m_s006AtrPeriod            = 14;
      m_s006AtrMultiplier        = 2.0;
      m_s006TargetMult           = 1.5; // 1:1.5 Risk-to-Reward
      m_s006MinSLPoints          = 150.0;
      m_s006MaxSLPoints          = 800.0;
      m_maxSpreadPoints          = 40;
      m_maxDailyTrades           = 5;
      m_allowedTradingHours      = "08:00-21:00";
      m_slippagePoints           = 30;

      // Risk Guardian defaults
      m_enableRiskGuardian       = true;
      m_maxDailyLossPercent      = 2.0;
      m_maxWeeklyLossPercent     = 5.0;
      m_maxDrawdownPercent       = 4.0;
      m_maxConsecutiveLosses     = 3;
      m_pauseMinutes             = 60;
      m_maximumExposurePercent   = 10.0;
      m_maximumOpenPositions     = 5;
      m_maximumSpreadPoints      = 35;
      m_enableSessionFilter      = true;
      m_enableCooldown           = true;
      m_cooldownMinutes          = 15;
      m_emergencyStop            = false;

      // Quant Engine Defaults
      m_rsiPeriod                = 14;
      m_volumePeriod             = 20;
      m_volumeSpikeRatio         = 2.0;
      m_equalThresholdPoints     = 15;

      // Market Quality Weights Defaults
      m_trendWeight              = 15.0;
      m_momentumWeight           = 15.0;
      m_volatilityWeight         = 15.0;
      m_volumeWeight             = 15.0;
      m_structureWeight          = 15.0;
      m_liquidityWeight          = 15.0;
      m_sessionWeight            = 10.0;

      // S-002 Strategy Defaults
      m_s002_MinScore            = 80.0;
      m_s002_WeightTrend         = 10.0;
      m_s002_WeightMomentum      = 20.0;
      m_s002_WeightVolume        = 15.0;
      m_s002_WeightVolatility    = 10.0;
      m_s002_WeightStructure     = 15.0;
      m_s002_WeightLiquidity     = 15.0;
      m_s002_WeightSession       = 5.0;
      m_s002_WeightQuality       = 10.0;

      m_s002_ExitModel           = 0;
      m_s002_RRRatio             = 2.0;
      m_s002_AtrMultiplier       = 2.0;
      m_s002_EmaExitPeriod       = 20;
      m_s002_TrailingStopPoints  = 200;
      m_s002_BreakEvenPoints     = 150;
      m_s002_TimeExitMinutes     = 240;

      // Explainability Defaults
      m_enableExplainability     = true;
      m_csvExportFileName        = "GITS_Explainability_Log.csv";

      // S-002 Production Rules Defaults (Default is FILTER_MODE_HARD for all)
      m_s002_ModeTrend           = FILTER_MODE_HARD;
      m_s002_ModeMomentum        = FILTER_MODE_HARD;
      m_s002_ModeVolume          = FILTER_MODE_HARD;
      m_s002_ModeVolatility      = FILTER_MODE_HARD;
      m_s002_ModeStructure       = FILTER_MODE_HARD;
      m_s002_ModeLiquidity       = FILTER_MODE_HARD;
      m_s002_ModeSession         = FILTER_MODE_HARD;
      m_s002_ModeQuality         = FILTER_MODE_HARD;
      
      m_s002_MinTrendStrength    = 40.0;
      m_s002_MinRvol             = 0.8;
      m_s002_MinMqScore          = 70.0;

      // Strategy S-003 Defaults
      m_s003_MaxAtrMultiplier    = 3.0;
      m_s003_MinAtrMultiplier    = 0.3;
      m_s003_MaxSpreadPoints     = 50.0;
      m_s003_FilterRanging       = true;
      m_s003_MinEnvironmentScore = 40.0;
      m_s003_NewsOpportunityMode    = true;
      m_s003_SessionOpenOpportunity = true;
      m_s003_EnableEarlyMTFEntry    = true;
      m_autoCapitalLock             = false;
      m_lockStepUSD                 = 50.0;
      m_riskProfitPercent           = 50.0;
      m_s003_EnableADXFilter        = true;
      m_s003_MinADXThreshold        = 22.0;
      m_s003_BreakoutBufferPoints   = 30.0;
      m_s003_BreakoutExtensionPoints = 100.0;
      m_s003b_RRRatio               = 2.0;

      // GITS V3.4 Defaults
      m_enableCalendarNewsFilter = true;

      // Trade Manager V1 defaults
      m_enableTradeManager       = true;
      m_enableBreakEven          = true;
      m_breakEvenTrigger         = 250.0; // 25.0 Pips unchoked trigger
      m_breakEvenOffset          = 50.0;  // 5.0 Pips locked
      m_stage2Trigger            = 400.0; // 40.0 Pips
      m_stage2Offset             = 250.0; // 25.0 Pips locked
      m_stage3Trigger            = 600.0; // 60.0 Pips
      m_stage3Offset             = 400.0; // 40.0 Pips locked
      m_enableTrailing           = false;
      m_trailingMode             = 0; // Fixed
      m_tmAtrMultiplier          = 2.0;
      m_minTrailDistance         = 50.0;
      m_maxTrailDistance         = 250.0;
      m_enableProfitLock         = true;
      m_profitLockStep           = 250.0; // 25.0 Pips step
      m_minLockedProfit          = 100.0; // 10.0 Pips min lock

      // Trading Profile — default to Research for Strategy Tester / Demo safety
      m_tradingProfile           = PROFILE_RESEARCH;
   }
   
   /**
    * @brief Destructor.
    */
   ~CConfig() {}

   //--- Setters for inputs
   void SetMagicNumber(ulong value) { m_magicNumber = value; }
   void SetLogsFilePrefix(string value) { m_logsFilePrefix = value; }
   void SetAutoTradingEnabled(bool value) { m_autoTradingEnabled = value; }
   void SetRiskPercent(double value) { m_riskPercent = value; }
   void SetUseFixedLot(bool value) { m_useFixedLot = value; }
   void SetFixedLotSize(double value) { m_fixedLotSize = value; }
   void SetUseCompoundingLot(bool value) { m_useCompoundingLot = value; } // V5.5
   void SetEnableCapitalLock(bool value) { m_enableCapitalLock = value; } // V5.5
   void SetCapitalLockTrigger(double value) { m_capitalLockTrigger = value; } // V5.5
   void SetCapitalLockFloor(double value) { m_capitalLockFloor = value; } // V5.5
   void SetCompoundOnTotalBalance(bool value) { m_compoundOnTotalBalance = value; } // Option A compounding
   void SetEnableHealthLock(bool value) { m_enableHealthLock = value; }
   void SetHealthLockMinPoints(double value) { m_healthLockMinPoints = value; }
   void SetMaxLossPer001Lot(double value) { m_maxLossPer001Lot = value; }
   void SetMaxSpreadPoints(int value) { m_maxSpreadPoints = value; }
   void SetMaxDailyTrades(int value) { m_maxDailyTrades = value; }
   void SetAllowedTradingHours(string value) { m_allowedTradingHours = value; }
   void SetSlippagePoints(int value) { m_slippagePoints = value; }

   // Risk Guardian Setters
   void SetEnableRiskGuardian(bool value) { m_enableRiskGuardian = value; }
   void SetMaxDailyLossPercent(double value) { m_maxDailyLossPercent = value; }
   void SetMaxWeeklyLossPercent(double value) { m_maxWeeklyLossPercent = value; }
   void SetMaxDrawdownPercent(double value) { m_maxDrawdownPercent = value; }
   void SetMaxConsecutiveLosses(int value) { m_maxConsecutiveLosses = value; }
   void SetPauseMinutes(int value) { m_pauseMinutes = value; }
   void SetMaximumExposurePercent(double value) { m_maximumExposurePercent = value; }
   void SetMaximumOpenPositions(int value) { m_maximumOpenPositions = value; }
   void SetMaximumSpreadPoints(int value) { m_maximumSpreadPoints = value; }
   void SetEnableSessionFilter(bool value) { m_enableSessionFilter = value; }
   void SetEnableCooldown(bool value) { m_enableCooldown = value; }
   void SetCooldownMinutes(int value) { m_cooldownMinutes = value; }
   void SetEmergencyStop(bool value) { m_emergencyStop = value; }

   // Quant Engine Setters
   void SetRSIPeriod(int value) { m_rsiPeriod = value; }
   void SetVolumePeriod(int value) { m_volumePeriod = value; }
   void SetVolumeSpikeRatio(double value) { m_volumeSpikeRatio = value; }
   void SetEqualThresholdPoints(int value) { m_equalThresholdPoints = value; }
   void SetTrendWeight(double value) { m_trendWeight = value; }
   void SetMomentumWeight(double value) { m_momentumWeight = value; }
   void SetVolatilityWeight(double value) { m_volatilityWeight = value; }
   void SetVolumeWeight(double value) { m_volumeWeight = value; }
   void SetStructureWeight(double value) { m_structureWeight = value; }
   void SetLiquidityWeight(double value) { m_liquidityWeight = value; }
   void SetSessionWeight(double value) { m_sessionWeight = value; }

   // Strategy S-002 Setters
   void SetS002_MinScore(double value) { m_s002_MinScore = value; }
   void SetS002_WeightTrend(double value) { m_s002_WeightTrend = value; }
   void SetS002_WeightMomentum(double value) { m_s002_WeightMomentum = value; }
   void SetS002_WeightVolume(double value) { m_s002_WeightVolume = value; }
   void SetS002_WeightVolatility(double value) { m_s002_WeightVolatility = value; }
   void SetS002_WeightStructure(double value) { m_s002_WeightStructure = value; }
   void SetS002_WeightLiquidity(double value) { m_s002_WeightLiquidity = value; }
   void SetS002_WeightSession(double value) { m_s002_WeightSession = value; }
   void SetS002_WeightQuality(double value) { m_s002_WeightQuality = value; }
   void SetS002_ExitModel(int value) { m_s002_ExitModel = value; }
   void SetS002_RRRatio(double value) { m_s002_RRRatio = value; }
   void SetS002_AtrMultiplier(double value) { m_s002_AtrMultiplier = value; }
   void SetS002_EmaExitPeriod(int value) { m_s002_EmaExitPeriod = value; }
   void SetS002_TrailingStopPoints(int value) { m_s002_TrailingStopPoints = value; }
   void SetS002_BreakEvenPoints(int value) { m_s002_BreakEvenPoints = value; }
   void SetS002_TimeExitMinutes(int value) { m_s002_TimeExitMinutes = value; }

    // Strategy S-003 Setters
    void SetS003_MaxAtrMultiplier(double value) { m_s003_MaxAtrMultiplier = value; }
    void SetS003_MinAtrMultiplier(double value) { m_s003_MinAtrMultiplier = value; }
    void SetS003_MaxSpreadPoints(double value) { m_s003_MaxSpreadPoints = value; }
    void SetS003_FilterRanging(bool value) { m_s003_FilterRanging = value; }
    void SetS003_MinEnvironmentScore(double value) { m_s003_MinEnvironmentScore = value; }
    void SetS003_NewsOpportunityMode(bool value) { m_s003_NewsOpportunityMode = value; }
    void SetS003_SessionOpenOpportunity(bool value) { m_s003_SessionOpenOpportunity = value; }
    void SetS003_EnableEarlyMTFEntry(bool value) { m_s003_EnableEarlyMTFEntry = value; }
    void SetAutoCapitalLock(bool value) { m_autoCapitalLock = value; }
    void SetLockStepUSD(double value) { m_lockStepUSD = value; }
    void SetRiskProfitPercent(double value) { m_riskProfitPercent = value; }
    void SetS003_EnableADXFilter(bool value) { m_s003_EnableADXFilter = value; }
    void SetS003_MinADXThreshold(double value) { m_s003_MinADXThreshold = value; }
    void SetS003_BreakoutBufferPoints(double value) { m_s003_BreakoutBufferPoints = value; }
    void SetS003_BreakoutExtensionPoints(double value) { m_s003_BreakoutExtensionPoints = value; }
    void SetS003b_RRRatio(double value) { m_s003b_RRRatio = value; }
    void SetEnableS004(bool value) { m_enableS004 = value; }
    void SetS004Timeframe(ENUM_TIMEFRAMES value) { m_s004Timeframe = value; }
    void SetS004ChannelLength(int value) { m_s004ChannelLength = value; }
    void SetS004EmaPeriod(int value) { m_s004EmaPeriod = value; }
    void SetS004AtrPeriod(int value) { m_s004AtrPeriod = value; }
    void SetS004AtrMultiplier(double value) { m_s004AtrMultiplier = value; }
    void SetS004TargetMult(double value) { m_s004TargetMult = value; }
    void SetS004MinSLPoints(double value) { m_s004MinSLPoints = value; }
    void SetS004MaxSLPoints(double value) { m_s004MaxSLPoints = value; }
    void SetEnableS005(bool value) { m_enableS005 = value; }
    void SetS005Timeframe(ENUM_TIMEFRAMES value) { m_s005Timeframe = value; }
    void SetS005ChannelLength(int value) { m_s005ChannelLength = value; }
    void SetS005EmaPeriod(int value) { m_s005EmaPeriod = value; }
    void SetS005VolSmaPeriod(int value) { m_s005VolSmaPeriod = value; }
    void SetS005VolMultiplier(double value) { m_s005VolMultiplier = value; }
    void SetS005AtrPeriod(int value) { m_s005AtrPeriod = value; }
    void SetS005AtrMultiplier(double value) { m_s005AtrMultiplier = value; }
    void SetS005TargetMult(double value) { m_s005TargetMult = value; }
    void SetS005MinSLPoints(double value) { m_s005MinSLPoints = value; }
    void SetS005MaxSLPoints(double value) { m_s005MaxSLPoints = value; }

    void SetEnableS006(bool value) { m_enableS006 = value; }
    void SetS006Timeframe(ENUM_TIMEFRAMES value) { m_s006Timeframe = value; }
    void SetS006Ema9Period(int value) { m_s006Ema9Period = value; }
    void SetS006Ema200Period(int value) { m_s006Ema200Period = value; }
    void SetS006VolSmaPeriod(int value) { m_s006VolSmaPeriod = value; }
    void SetS006VolMultiplier(double value) { m_s006VolMultiplier = value; }
    void SetS006RsiPeriod(int value) { m_s006RsiPeriod = value; }
    void SetS006RsiMinBuy(double value) { m_s006RsiMinBuy = value; }
    void SetS006RsiMaxBuy(double value) { m_s006RsiMaxBuy = value; }
    void SetS006RsiMinSell(double value) { m_s006RsiMinSell = value; }
    void SetS006RsiMaxSell(double value) { m_s006RsiMaxSell = value; }
    void SetS006AtrPeriod(int value) { m_s006AtrPeriod = value; }
    void SetS006AtrMultiplier(double value) { m_s006AtrMultiplier = value; }
    void SetS006TargetMult(double value) { m_s006TargetMult = value; }
    void SetS006MinSLPoints(double value) { m_s006MinSLPoints = value; }
    void SetS006MaxSLPoints(double value) { m_s006MaxSLPoints = value; }

    // GITS V3.4 Setters
    void SetEnableCalendarNewsFilter(bool value) { m_enableCalendarNewsFilter = value; }

   // Explainability Setters
   void SetEnableExplainability(bool value) { m_enableExplainability = value; }
   void SetCSVExportFileName(string value) { m_csvExportFileName = value; }

   // Trade Manager V1 Setters
   void SetEnableTradeManager(bool value) { m_enableTradeManager = value; }
   void SetEnableBreakEven(bool value) { m_enableBreakEven = value; }
   void SetBreakEvenTrigger(double value) { m_breakEvenTrigger = value; }
   void SetBreakEvenOffset(double value) { m_breakEvenOffset = value; }
   void SetStage2Trigger(double value) { m_stage2Trigger = value; }
   void SetStage2Offset(double value) { m_stage2Offset = value; }
   void SetStage3Trigger(double value) { m_stage3Trigger = value; }
   void SetStage3Offset(double value) { m_stage3Offset = value; }
   void SetEnableTrailing(bool value) { m_enableTrailing = value; }
   void SetTrailingMode(int value) { m_trailingMode = value; }
   void SetTmAtrMultiplier(double value) { m_tmAtrMultiplier = value; }
   void SetMinTrailDistance(double value) { m_minTrailDistance = value; }
   void SetMaxTrailDistance(double value) { m_maxTrailDistance = value; }
   void SetEnableProfitLock(bool value) { m_enableProfitLock = value; }
   void SetProfitLockStep(double value) { m_profitLockStep = value; }
   void SetMinLockedProfit(double value) { m_minLockedProfit = value; }

   // Trading Profile Setter (V5.1)
   void SetTradingProfile(ENUM_TRADING_PROFILE value) { m_tradingProfile = value; }

   // S-002 Production Rules Setters
   void SetS002_ModeTrend(ENUM_FILTER_MODE value) { m_s002_ModeTrend = value; }
   void SetS002_ModeMomentum(ENUM_FILTER_MODE value) { m_s002_ModeMomentum = value; }
   void SetS002_ModeVolume(ENUM_FILTER_MODE value) { m_s002_ModeVolume = value; }
   void SetS002_ModeVolatility(ENUM_FILTER_MODE value) { m_s002_ModeVolatility = value; }
   void SetS002_ModeStructure(ENUM_FILTER_MODE value) { m_s002_ModeStructure = value; }
   void SetS002_ModeLiquidity(ENUM_FILTER_MODE value) { m_s002_ModeLiquidity = value; }
   void SetS002_ModeSession(ENUM_FILTER_MODE value) { m_s002_ModeSession = value; }
   void SetS002_ModeQuality(ENUM_FILTER_MODE value) { m_s002_ModeQuality = value; }
   
   void SetS002_MinTrendStrength(double value) { m_s002_MinTrendStrength = value; }
   void SetS002_MinRvol(double value) { m_s002_MinRvol = value; }
   void SetS002_MinMqScore(double value) { m_s002_MinMqScore = value; }

   //--- Getters
   ulong GetMagicNumber() const { return m_magicNumber; }
   string GetLogsFilePrefix() const { return m_logsFilePrefix; }
   bool IsAutoTradingEnabled() const { return m_autoTradingEnabled; }
   double GetRiskPercent() const { return m_riskPercent; }
   bool IsUsingFixedLot() const { return m_useFixedLot; }
   double GetFixedLotSize() const { return m_fixedLotSize; }
   bool IsUsingCompoundingLot() const { return m_useCompoundingLot; } // V5.5
   bool IsCapitalLockEnabled() const { return m_enableCapitalLock; } // V5.5
   double GetCapitalLockTrigger() const { return m_capitalLockTrigger; } // V5.5
   double GetCapitalLockFloor() const { return m_capitalLockFloor; } // V5.5
   bool IsCompoundingOnTotalBalance() const { return m_compoundOnTotalBalance; } // Option A compounding
   bool IsHealthLockEnabled() const { return m_enableHealthLock; }
   double GetHealthLockMinPoints() const { return m_healthLockMinPoints; }
   double GetMaxLossPer001Lot() const { return m_maxLossPer001Lot; }
   int GetMaxSpreadPoints() const { return m_maxSpreadPoints; }
   int GetMaxDailyTrades() const { return m_maxDailyTrades; }
   string GetAllowedTradingHours() const { return m_allowedTradingHours; }
   int GetSlippagePoints() const { return m_slippagePoints; }

   // Risk Guardian Getters
   bool IsRiskGuardianEnabled() const { return m_enableRiskGuardian; }
   double GetMaxDailyLossPercent() const { return m_maxDailyLossPercent; }
   double GetMaxWeeklyLossPercent() const { return m_maxWeeklyLossPercent; }
   double GetMaxDrawdownPercent() const { return m_maxDrawdownPercent; }
   int GetMaxConsecutiveLosses() const { return m_maxConsecutiveLosses; }
   int GetPauseMinutes() const { return m_pauseMinutes; }
   double GetMaximumExposurePercent() const { return m_maximumExposurePercent; }
   int GetMaximumOpenPositions() const { return m_maximumOpenPositions; }
   int GetMaximumSpreadPoints() const { return m_maximumSpreadPoints; }
   bool IsSessionFilterEnabled() const { return m_enableSessionFilter; }
   bool IsCooldownEnabled() const { return m_enableCooldown; }
   int GetCooldownMinutes() const { return m_cooldownMinutes; }
   bool IsEmergencyStopActive() const { return m_emergencyStop; }

   // Quant Engine Getters
   int GetRSIPeriod() const { return m_rsiPeriod; }
   int GetVolumePeriod() const { return m_volumePeriod; }
   double GetVolumeSpikeRatio() const { return m_volumeSpikeRatio; }
   int GetEqualThresholdPoints() const { return m_equalThresholdPoints; }
   double GetTrendWeight() const { return m_trendWeight; }
   double GetMomentumWeight() const { return m_momentumWeight; }
   double GetVolatilityWeight() const { return m_volatilityWeight; }
   double GetVolumeWeight() const { return m_volumeWeight; }
   double GetStructureWeight() const { return m_structureWeight; }
   double GetLiquidityWeight() const { return m_liquidityWeight; }
   double GetSessionWeight() const { return m_sessionWeight; }

   // Strategy S-002 Getters
   double GetS002_MinScore() const { return m_s002_MinScore; }
   double GetS002_WeightTrend() const { return m_s002_WeightTrend; }
   double GetS002_WeightMomentum() const { return m_s002_WeightMomentum; }
   double GetS002_WeightVolume() const { return m_s002_WeightVolume; }
   double GetS002_WeightVolatility() const { return m_s002_WeightVolatility; }
   double GetS002_WeightStructure() const { return m_s002_WeightStructure; }
   double GetS002_WeightLiquidity() const { return m_s002_WeightLiquidity; }
   double GetS002_WeightSession() const { return m_s002_WeightSession; }
   double GetS002_WeightQuality() const { return m_s002_WeightQuality; }
   int GetS002_ExitModel() const { return m_s002_ExitModel; }
   double GetS002_RRRatio() const { return m_s002_RRRatio; }
   double GetS002_AtrMultiplier() const { return m_s002_AtrMultiplier; }
   int GetS002_EmaExitPeriod() const { return m_s002_EmaExitPeriod; }
   int GetS002_TrailingStopPoints() const { return m_s002_TrailingStopPoints; }
   int GetS002_BreakEvenPoints() const { return m_s002_BreakEvenPoints; }
   int GetS002_TimeExitMinutes() const { return m_s002_TimeExitMinutes; }

    // Strategy S-003 Getters
    double GetS003_MaxAtrMultiplier() const { return m_s003_MaxAtrMultiplier; }
    double GetS003_MinAtrMultiplier() const { return m_s003_MinAtrMultiplier; }
    double GetS003_MaxSpreadPoints() const { return m_s003_MaxSpreadPoints; }
    bool IsS003_FilterRanging() const { return m_s003_FilterRanging; }
    double GetS003_MinEnvironmentScore() const { return m_s003_MinEnvironmentScore; }
    bool GetS003_NewsOpportunityMode() const { return m_s003_NewsOpportunityMode; }
    bool GetS003_SessionOpenOpportunity() const { return m_s003_SessionOpenOpportunity; }
    bool GetS003_EnableEarlyMTFEntry() const { return m_s003_EnableEarlyMTFEntry; }
    bool IsAutoCapitalLock() const { return m_autoCapitalLock; }
    double GetLockStepUSD() const { return m_lockStepUSD; }
    double GetRiskProfitPercent() const { return m_riskProfitPercent; }
    bool IsS003_EnableADXFilter() const { return m_s003_EnableADXFilter; }
    double GetS003_MinADXThreshold() const { return m_s003_MinADXThreshold; }
    double GetS003_BreakoutBufferPoints() const { return m_s003_BreakoutBufferPoints; }
    double GetS003_BreakoutExtensionPoints() const { return m_s003_BreakoutExtensionPoints; }
    double GetS003b_RRRatio() const { return m_s003b_RRRatio; }
    bool IsS004Enabled() const { return m_enableS004; }
    ENUM_TIMEFRAMES GetS004Timeframe() const { return m_s004Timeframe; }
    int GetS004ChannelLength() const { return m_s004ChannelLength; }
    int GetS004EmaPeriod() const { return m_s004EmaPeriod; }
    int GetS004AtrPeriod() const { return m_s004AtrPeriod; }
    double GetS004AtrMultiplier() const { return m_s004AtrMultiplier; }
    double GetS004TargetMult() const { return m_s004TargetMult; }
    double GetS004MinSLPoints() const { return m_s004MinSLPoints; }
    double GetS004MaxSLPoints() const { return m_s004MaxSLPoints; }
    bool IsS005Enabled() const { return m_enableS005; }
    ENUM_TIMEFRAMES GetS005Timeframe() const { return m_s005Timeframe; }
    int GetS005ChannelLength() const { return m_s005ChannelLength; }
    int GetS005EmaPeriod() const { return m_s005EmaPeriod; }
    int GetS005VolSmaPeriod() const { return m_s005VolSmaPeriod; }
    double GetS005VolMultiplier() const { return m_s005VolMultiplier; }
    int GetS005AtrPeriod() const { return m_s005AtrPeriod; }
    double GetS005AtrMultiplier() const { return m_s005AtrMultiplier; }
    double GetS005TargetMult() const { return m_s005TargetMult; }
    double GetS005MinSLPoints() const { return m_s005MinSLPoints; }
    double GetS005MaxSLPoints() const { return m_s005MaxSLPoints; }

    bool IsS006Enabled() const { return m_enableS006; }
    ENUM_TIMEFRAMES GetS006Timeframe() const { return m_s006Timeframe; }
    int GetS006Ema9Period() const { return m_s006Ema9Period; }
    int GetS006Ema200Period() const { return m_s006Ema200Period; }
    int GetS006VolSmaPeriod() const { return m_s006VolSmaPeriod; }
    double GetS006VolMultiplier() const { return m_s006VolMultiplier; }
    int GetS006RsiPeriod() const { return m_s006RsiPeriod; }
    double GetS006RsiMinBuy() const { return m_s006RsiMinBuy; }
    double GetS006RsiMaxBuy() const { return m_s006RsiMaxBuy; }
    double GetS006RsiMinSell() const { return m_s006RsiMinSell; }
    double GetS006RsiMaxSell() const { return m_s006RsiMaxSell; }
    int GetS006AtrPeriod() const { return m_s006AtrPeriod; }
    double GetS006AtrMultiplier() const { return m_s006AtrMultiplier; }
    double GetS006TargetMult() const { return m_s006TargetMult; }
    double GetS006MinSLPoints() const { return m_s006MinSLPoints; }
    double GetS006MaxSLPoints() const { return m_s006MaxSLPoints; }

    // GITS V3.4 Getters
    bool IsCalendarNewsFilterEnabled() const { return m_enableCalendarNewsFilter; }

   // Explainability Getters
   bool IsExplainabilityEnabled() const { return m_enableExplainability; }
   string GetCSVExportFileName() const { return m_csvExportFileName; }

   // Trade Manager V1 Getters
   bool IsTradeManagerEnabled() const { return m_enableTradeManager; }
   bool IsBreakEvenEnabled() const { return m_enableBreakEven; }
   double GetBreakEvenTrigger() const { return m_breakEvenTrigger; }
   double GetBreakEvenOffset() const { return m_breakEvenOffset; }
   double GetStage2Trigger() const { return m_stage2Trigger; }
   double GetStage2Offset() const { return m_stage2Offset; }
   double GetStage3Trigger() const { return m_stage3Trigger; }
   double GetStage3Offset() const { return m_stage3Offset; }
   bool IsTrailingEnabled() const { return m_enableTrailing; }
   int GetTrailingMode() const { return m_trailingMode; }
   double GetTmAtrMultiplier() const { return m_tmAtrMultiplier; }
   double GetMinTrailDistance() const { return m_minTrailDistance; }
   double GetMaxTrailDistance() const { return m_maxTrailDistance; }
   bool IsProfitLockEnabled() const { return m_enableProfitLock; }
   double GetProfitLockStep() const { return m_profitLockStep; }
   double GetMinLockedProfit() const { return m_minLockedProfit; }

   // Trading Profile Getters (V5.1)
   ENUM_TRADING_PROFILE GetTradingProfile() const { return m_tradingProfile; }
   bool IsResearchMode() const { return m_tradingProfile == PROFILE_RESEARCH; }

   // S-002 Production Rules Getters
   bool IsS002_FilterTrendEnabled() const { return m_s002_ModeTrend != FILTER_MODE_DISABLED; }
   bool IsS002_FilterMomentumEnabled() const { return m_s002_ModeMomentum != FILTER_MODE_DISABLED; }
   bool IsS002_FilterVolumeEnabled() const { return m_s002_ModeVolume != FILTER_MODE_DISABLED; }
   bool IsS002_FilterVolatilityEnabled() const { return m_s002_ModeVolatility != FILTER_MODE_DISABLED; }
   bool IsS002_FilterStructureEnabled() const { return m_s002_ModeStructure != FILTER_MODE_DISABLED; }
   bool IsS002_FilterLiquidityEnabled() const { return m_s002_ModeLiquidity != FILTER_MODE_DISABLED; }
   bool IsS002_FilterSessionEnabled() const { return m_s002_ModeSession != FILTER_MODE_DISABLED; }
   bool IsS002_FilterQualityEnabled() const { return m_s002_ModeQuality != FILTER_MODE_DISABLED; }

   ENUM_FILTER_MODE GetS002_ModeTrend() const { return m_s002_ModeTrend; }
   ENUM_FILTER_MODE GetS002_ModeMomentum() const { return m_s002_ModeMomentum; }
   ENUM_FILTER_MODE GetS002_ModeVolume() const { return m_s002_ModeVolume; }
   ENUM_FILTER_MODE GetS002_ModeVolatility() const { return m_s002_ModeVolatility; }
   ENUM_FILTER_MODE GetS002_ModeStructure() const { return m_s002_ModeStructure; }
   ENUM_FILTER_MODE GetS002_ModeLiquidity() const { return m_s002_ModeLiquidity; }
   ENUM_FILTER_MODE GetS002_ModeSession() const { return m_s002_ModeSession; }
   ENUM_FILTER_MODE GetS002_ModeQuality() const { return m_s002_ModeQuality; }
   
   double GetS002_MinTrendStrength() const { return m_s002_MinTrendStrength; }
   double GetS002_MinRvol() const { return m_s002_MinRvol; }
   double GetS002_MinMqScore() const { return m_s002_MinMqScore; }

   /**
    * @brief Validates config parameters.
    * @param outError String to store validation error message.
    * @return true if valid, false otherwise.
    */
   bool Validate(string &outError)
   {
      if(m_magicNumber <= 0)
      {
         outError = "Magic Number must be greater than 0";
         return false;
      }
      if(m_riskPercent < 0.0 || m_riskPercent > 100.0)
      {
         outError = "Risk Percent must be between 0.0 and 100.0";
         return false;
      }
      if(m_useFixedLot && m_fixedLotSize <= 0.0)
      {
         outError = "Fixed Lot Size must be greater than 0.0 when UseFixedLot is true";
         return false;
      }
      if(m_maxSpreadPoints < 0)
      {
         outError = "Max Spread cannot be negative";
         return false;
      }
      if(m_maxDailyTrades < 0)
      {
         outError = "Max Daily Trades cannot be negative";
         return false;
      }
      if(StringLen(m_allowedTradingHours) > 0)
      {
         // Simple format check (e.g. "HH:MM-HH:MM")
         if(StringLen(m_allowedTradingHours) != 11 || StringSubstr(m_allowedTradingHours, 2, 1) != ":" || 
            StringSubstr(m_allowedTradingHours, 5, 1) != "-" || StringSubstr(m_allowedTradingHours, 8, 1) != ":")
         {
            outError = "Allowed Trading Hours must follow the format 'HH:MM-HH:MM'";
            return false;
         }
      }

      // Risk Guardian Validations
      if(m_maxDailyLossPercent < 0.0 || m_maxDailyLossPercent > 100.0)
      {
         outError = "Max Daily Loss Percent must be between 0.0 and 100.0";
         return false;
      }
      if(m_maxWeeklyLossPercent < 0.0 || m_maxWeeklyLossPercent > 100.0)
      {
         outError = "Max Weekly Loss Percent must be between 0.0 and 100.0";
         return false;
      }
      if(m_maxDrawdownPercent < 0.0 || m_maxDrawdownPercent > 100.0)
      {
         outError = "Max Drawdown Percent must be between 0.0 and 100.0";
         return false;
      }
      if(m_maxConsecutiveLosses < 0)
      {
         outError = "Max Consecutive Losses cannot be negative";
         return false;
      }
      if(m_pauseMinutes < 0)
      {
         outError = "Pause Minutes cannot be negative";
         return false;
      }
      if(m_maximumExposurePercent < 0.0 || m_maximumExposurePercent > 100.0)
      {
         outError = "Maximum Exposure Percent must be between 0.0 and 100.0";
         return false;
      }
      if(m_maximumOpenPositions < 0)
      {
         outError = "Maximum Open Positions cannot be negative";
         return false;
      }
      if(m_maximumSpreadPoints < 0)
      {
         outError = "Maximum Spread Points cannot be negative";
         return false;
      }
      if(m_cooldownMinutes < 0)
      {
         outError = "Cooldown Minutes cannot be negative";
         return false;
      }

      // Quant Engine Validations
      if(m_rsiPeriod <= 0)
      {
         outError = "RSI Period must be positive";
         return false;
      }
      if(m_volumePeriod <= 0)
      {
         outError = "Volume Period must be positive";
         return false;
      }
      if(m_volumeSpikeRatio <= 0.0)
      {
         outError = "Volume Spike Ratio must be positive";
         return false;
      }
      if(m_equalThresholdPoints < 0)
      {
         outError = "Equal Threshold Points cannot be negative";
         return false;
      }

      // S-002 Validations
      if(m_s002_MinScore < 0.0 || m_s002_MinScore > 100.0)
      {
         outError = "S-002 Min Score Required must be between 0.0 and 100.0";
         return false;
      }
      if(m_s002_WeightTrend < 0.0 || m_s002_WeightMomentum < 0.0 || m_s002_WeightVolume < 0.0 ||
         m_s002_WeightVolatility < 0.0 || m_s002_WeightStructure < 0.0 || m_s002_WeightLiquidity < 0.0 ||
         m_s002_WeightSession < 0.0 || m_s002_WeightQuality < 0.0)
      {
         outError = "S-002 individual weights cannot be negative";
         return false;
      }
      if(m_s002_ExitModel < 0 || m_s002_ExitModel > 5)
      {
         outError = "S-002 Exit Model must be between 0 and 5";
         return false;
      }
      if(m_s002_RRRatio <= 0.0)
      {
         outError = "S-002 Risk-Reward Ratio must be positive";
         return false;
      }
      if(m_s002_AtrMultiplier <= 0.0)
      {
         outError = "S-002 ATR Multiplier must be positive";
         return false;
      }
      if(m_s002_EmaExitPeriod <= 0)
      {
         outError = "S-002 EMA Exit Period must be positive";
         return false;
      }
      if(m_s002_TrailingStopPoints < 0 || m_s002_BreakEvenPoints < 0 || m_s002_TimeExitMinutes < 0)
      {
         outError = "S-002 protective points or timers cannot be negative";
         return false;
      }

      // Explainability Validations
      if(StringLen(m_csvExportFileName) <= 0)
      {
         outError = "CSV Export File Name cannot be empty";
         return false;
      }

      // S-002 Production Rules Validations
      if(m_s002_MinTrendStrength < 0.0 || m_s002_MinTrendStrength > 100.0)
      {
         outError = "S-002 Min Trend Strength must be between 0.0 and 100.0";
         return false;
      }
      if(m_s002_MinRvol < 0.0)
      {
         outError = "S-002 Min RVOL cannot be negative";
         return false;
      }
      if(m_s002_MinMqScore < 0.0 || m_s002_MinMqScore > 100.0)
      {
         outError = "S-002 Min Market Quality Score must be between 0.0 and 100.0";
         return false;
      }

      return true;
   }
};

#endif // GOLDENGINEV2_CONFIG_MQH
