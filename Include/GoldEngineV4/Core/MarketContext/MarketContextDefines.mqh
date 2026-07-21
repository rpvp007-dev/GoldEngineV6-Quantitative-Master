//+------------------------------------------------------------------+
//|                                         MarketContextDefines.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_MARKET_CONTEXT_DEFINES_MQH
#define GOLDENGINEV2_MARKET_CONTEXT_DEFINES_MQH

//--- Market Regime Classification
enum ENUM_MARKET_REGIME
{
   REGIME_TRENDING,
   REGIME_RANGING,
   REGIME_BREAKOUT,
   REGIME_REVERSAL,
   REGIME_COMPRESSION,
   REGIME_EXPANSION,
   REGIME_TRANSITION
};

//--- Trend Phase Classification
enum ENUM_TREND_PHASE
{
   PHASE_EARLY_TREND,
   PHASE_MATURE_TREND,
   PHASE_EXHAUSTION,
   PHASE_PULLBACK,
   PHASE_CONTINUATION,
   PHASE_NONE
};

//--- Volatility State Classification
enum ENUM_VOLATILITY_STATE
{
   VOL_STATE_LOW,
   VOL_STATE_NORMAL,
   VOL_STATE_HIGH,
   VOL_STATE_EXPLODING
};

//--- Liquidity State Classification
enum ENUM_LIQUIDITY_STATE
{
   LIQ_STATE_NO_LIQUIDITY,
   LIQ_STATE_BUILDING,
   LIQ_STATE_TARGETING,
   LIQ_STATE_SWEEPING,
   LIQ_STATE_POST_SWEEP
};

//--- Market Structure Classification
enum ENUM_STRUCTURE_STATE
{
   STRUCT_STATE_BULLISH,
   STRUCT_STATE_BEARISH,
   STRUCT_STATE_RANGE,
   STRUCT_STATE_BOS,
   STRUCT_STATE_CHOCH,
   STRUCT_STATE_TRANSITION
};

//--- Momentum State Classification
enum ENUM_MOMENTUM_STATE
{
   MOM_STATE_NEUTRAL,
   MOM_STATE_ACCELERATING_BULLISH,
   MOM_STATE_ACCELERATING_BEARISH,
   MOM_STATE_DECELERATING
};

//--- Institutional Market Context structure definition
struct MarketContext
{
   int                      TrendRegime;       // 1 = Bullish, -1 = Bearish, 0 = Neutral
   ENUM_MARKET_REGIME       MarketRegime;      // TRENDING, RANGING, BREAKOUT, REVERSAL, COMPRESSION, EXPANSION, TRANSITION
   ENUM_TREND_PHASE         TrendPhase;        // EARLY TREND, MATURE TREND, EXHAUSTION, PULLBACK, CONTINUATION
   ENUM_VOLATILITY_STATE    VolatilityRegime;  // LOW, NORMAL, HIGH, EXPLODING
   ENUM_LIQUIDITY_STATE     LiquidityState;    // NO LIQUIDITY, BUILDING, TARGETING, SWEEPING, POST SWEEP
   ENUM_STRUCTURE_STATE     StructureState;    // BULLISH, BEARISH, RANGE, BOS, CHOCH, TRANSITION
   ENUM_MOMENTUM_STATE      MomentumState;     // NEUTRAL, ACCELERATING_BULLISH, ACCELERATING_BEARISH, DECELERATING
   string                   SessionState;      // Active Session name or status
   string                   MarketQuality;     // Poor, Average, Good, Excellent
   double                   ContextConfidence; // Overall Context Confidence (0-100)
   double                   TradeEnvScore;     // Trade Environment Score (0-100)
   string                   TradeEnvironment;  // Avoid, Poor, Average, Good, Excellent
   string                   Narrative;         // Explanatory text narrative
};

#endif // GOLDENGINEV2_MARKET_CONTEXT_DEFINES_MQH
