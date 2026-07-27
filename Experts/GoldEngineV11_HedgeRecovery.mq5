//+------------------------------------------------------------------+
//|                                                GoldEngineV10.mq5 |
//|                                  Copyright 2026, GoldEngine V10  |
//|                    Adaptive Multi-Timeframe Hybrid EA (Pro)      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, GoldEngine V10"
#property link      "https://github.com/rpvp007-dev"
#property version   "20.00"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Subclass CTrade to implement automatic order retries and updates  |
//+------------------------------------------------------------------+
class CTradeSafe : public CTrade
{
public:
   bool Buy(double volume, const string symbol=NULL, double price=0, double sl=0, double tp=0, const string comment="")
   {
      int maxRetries = 3;
      for(int r = 0; r < maxRetries; r++)
      {
         if(CTrade::Buy(volume, symbol, price, sl, tp, comment))
         {
            uint retcode = ResultRetcode();
            if(retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_PLACED) return true;
         }
         PrintFormat("[Trade Retry] Buy failed (Retcode: %d). Retrying %d/%d in 200ms...", ResultRetcode(), r+1, maxRetries);
         Sleep(200);
         price = SymbolInfoDouble(symbol == NULL ? _Symbol : symbol, SYMBOL_ASK);
      }
      return false;
   }
   
   bool Sell(double volume, const string symbol=NULL, double price=0, double sl=0, double tp=0, const string comment="")
   {
      int maxRetries = 3;
      for(int r = 0; r < maxRetries; r++)
      {
         if(CTrade::Sell(volume, symbol, price, sl, tp, comment))
         {
            uint retcode = ResultRetcode();
            if(retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_PLACED) return true;
         }
         PrintFormat("[Trade Retry] Sell failed (Retcode: %d). Retrying %d/%d in 200ms...", ResultRetcode(), r+1, maxRetries);
         Sleep(200);
         price = SymbolInfoDouble(symbol == NULL ? _Symbol : symbol, SYMBOL_BID);
      }
      return false;
   }
   
   bool BuyLimit(double volume, double price, const string symbol=NULL, double sl=0, double tp=0, ENUM_ORDER_TYPE_TIME type=ORDER_TIME_GTC, datetime expiration=0, const string comment="")
   {
      int maxRetries = 3;
      for(int r = 0; r < maxRetries; r++)
      {
         if(CTrade::BuyLimit(volume, price, symbol, sl, tp, type, expiration, comment))
         {
            uint retcode = ResultRetcode();
            if(retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_PLACED) return true;
         }
         PrintFormat("[Trade Retry] BuyLimit failed (Retcode: %d). Retrying %d/%d in 200ms...", ResultRetcode(), r+1, maxRetries);
         Sleep(200);
      }
      return false;
   }
   
   bool SellLimit(double volume, double price, const string symbol=NULL, double sl=0, double tp=0, ENUM_ORDER_TYPE_TIME type=ORDER_TIME_GTC, datetime expiration=0, const string comment="")
   {
      int maxRetries = 3;
      for(int r = 0; r < maxRetries; r++)
      {
         if(CTrade::SellLimit(volume, price, symbol, sl, tp, type, expiration, comment))
         {
            uint retcode = ResultRetcode();
            if(retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_PLACED) return true;
         }
         PrintFormat("[Trade Retry] SellLimit failed (Retcode: %d). Retrying %d/%d in 200ms...", ResultRetcode(), r+1, maxRetries);
         Sleep(200);
      }
      return false;
   }
   
   bool BuyStop(double volume, double price, const string symbol=NULL, double sl=0, double tp=0, ENUM_ORDER_TYPE_TIME type=ORDER_TIME_GTC, datetime expiration=0, const string comment="")
   {
      int maxRetries = 3;
      for(int r = 0; r < maxRetries; r++)
      {
         if(CTrade::BuyStop(volume, price, symbol, sl, tp, type, expiration, comment))
         {
            uint retcode = ResultRetcode();
            if(retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_PLACED) return true;
         }
         PrintFormat("[Trade Retry] BuyStop failed (Retcode: %d). Retrying %d/%d in 200ms...", ResultRetcode(), r+1, maxRetries);
         Sleep(200);
      }
      return false;
   }
   
   bool SellStop(double volume, double price, const string symbol=NULL, double sl=0, double tp=0, ENUM_ORDER_TYPE_TIME type=ORDER_TIME_GTC, datetime expiration=0, const string comment="")
   {
      int maxRetries = 3;
      for(int r = 0; r < maxRetries; r++)
      {
         if(CTrade::SellStop(volume, price, symbol, sl, tp, type, expiration, comment))
         {
            uint retcode = ResultRetcode();
            if(retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_PLACED) return true;
         }
         PrintFormat("[Trade Retry] SellStop failed (Retcode: %d). Retrying %d/%d in 200ms...", ResultRetcode(), r+1, maxRetries);
         Sleep(200);
      }
      return false;
   }
};

//--- Timeframe Mode Enum
enum ENUM_TF_MODE {
   TF_AUTO,     // Auto-Detect Chart Timeframe (Default)
   TF_M1,       // M1 (1-Minute) Presets
   TF_M5,       // M5 (5-Minute) Presets
   TF_M15,      // M15 (15-Minute) Presets
   TF_H1,       // H1 (1-Hour) Presets
   TF_CUSTOM    // Custom Settings (Use manual inputs below)
};

enum ENUM_AI_ENGINE {
   AI_GROQ,            // Groq Llama-3.1 (Recommended: Fast & High Quotas)
   AI_GEMINI,          // Gemini Flash
   AI_OPENROUTER,      // OpenRouter
   AI_BOTH_FAILOVER    // OpenRouter first, failover to Groq
};

//--- Input Parameters
input group "--- Target Timeframe Selection ---"
input ENUM_TF_MODE InpTimeframeMode = TF_AUTO;    // Target Chart Timeframe Mode

input group "--- AI Engine Settings ---"
input string   InpGeminiAPIKey       = ""; // Gemini API Key (aistudio.google.com)
input string   InpGroqAPIKey         = ""; // Groq API Key (console.groq.com)
input string   InpOpenRouterAPIKey   = ""; // OpenRouter API Key (openrouter.ai)
input string   InpOpenRouterModel    = "google/gemma-4-31b-it"; // OpenRouter Model Name
input bool     InpUseAIEngines       = true;    // Enable AI Brain Integration
input bool     InpUseAIVision        = false;   // Enable AI Multimodal Vision (Requires OpenRouter Vision Model)

input ENUM_AI_ENGINE InpAIEngineSelection = AI_BOTH_FAILOVER; // AI Engine Selection
input int      InpMinConviction      = 1;      // Minimum AI Conviction to trade (0-100)

enum ENUM_DB_POSITION
{
   DB_POS_TOP_LEFT,      // Top Left
   DB_POS_TOP_RIGHT,     // Top Right
   DB_POS_BOTTOM_LEFT,   // Bottom Left
   DB_POS_BOTTOM_RIGHT,  // Bottom Right
   DB_POS_CENTER,        // Center
   DB_POS_FREE_MOVE      // Free Move (Drag panel to move)
};

input group "--- Dashboard UI Settings ---"
input bool             InpShowDashboard      = true;               // Show Dashboard Panel
input ENUM_DB_POSITION InpDashboardPosition  = DB_POS_TOP_LEFT;     // Dashboard Position Mode
input int              InpDashboardX         = 20;                 // Custom X Offset (Or corner offset)
input int              InpDashboardY         = 60;                 // Custom Y Offset (Or corner offset)

input group "--- Core Risk Settings ---"
input double   InpLotSize          = 0.10;     // Fixed Lot Size (If Compounding is disabled)
input double   InpTargetRiskUSD    = 25.00;    // Target dollar risk per trade ($)
input ulong    InpMagicNumber      = 123456;   // Magic Number
input int      InpMaxConcurrentTrades = 2;       // Max Concurrent Trades (Allows dip buying)
input int      InpPendingOrderExpiryBars = 5;    // Pending Order Expiry (in Bars)

input group "--- Compounding Settings ---"
input bool     InpEnableCompounding = true;    // Enable Lot Compounding (scales target risk)
input double   InpLotsPerStep       = 0.10;    // (Legacy reference lot size)
input double   InpBalanceStep       = 100.00;  // Per how much account balance ($) to scale risk

input group "--- Sideways Hybrid Mode Settings ---"
input bool     InpEnableHybridMode   = true;   // Enable Breakout/Reversion Switch
input bool     InpUseLocalDonchianBreakout = true; // Use Donchian Breakout for local trending breakouts
input double   InpMinADX             = 20.0;   // Custom Mode ONLY: ADX Threshold (Sideways < 20)
input double   InpLimitOffset        = 0.05;   // Front-running offset for limit orders (points)
input double   InpPriceRoundStep     = 0.05;   // Rounding step for limit orders (0.0 to disable)

input group "--- Session Momentum Hours ---"
input bool     InpUseSessionHours    = true;   // Breakouts allowed ONLY during Momentum Hours
input int      InpLondonStartHour    = 7;      // London Open Hour (Server time)
input int      InpLondonEndHour      = 10;     // London End Hour (Server time)
input int      InpNYStartHour        = 13;     // NY Open Hour (Server time)
input int      InpNYStartMin         = 30;     // NY Open Minute (Server time)
input int      InpNYEndHour          = 16;     // NY End Hour (Server time)
input int      InpNYEndMin           = 30;     // NY End Minute (Server time)

input group "--- Precision & Volume Filters (BREAKOUT ONLY) ---"
input bool     InpUseVolumeFilter    = false;   // Tick Volume Filter (confirm breakout volume)
input bool     InpUseMTFTrendFilter  = false;   // Dual-Timeframe Trend Alignment (Macro direction)
input bool     InpUseEMAFilter       = false;   // Filter entries by 50 EMA Trend (Local direction)
input bool     InpUseRSIFilter       = false;   // Filter out Trend Exhaustion (RSI 70/30)
input bool     InpUseATRFilter       = false;   // Block trading if ATR Volatility is low

input group "--- Volatility-Adjusted Entry Offset ---"
input bool     InpUseATROffset       = false;   // Dynamic Entry Offset based on ATR
input double   InpATROffsetMultiplier = 0.15;  // Custom Mode ONLY: ATR Multiplier for Entry Offset

input group "--- Volatility-Adjusted Stop Loss ---"
input bool     InpUseATRStopLoss     = true;   // Stop Loss dynamic based on ATR
input double   InpATRMultiplier      = 1.5;    // Custom Mode ONLY: ATR Multiplier for Stop Loss distance

input group "--- Strategy 1: Donchian Breakout Settings ---"
input int      InpChannelLength   = 20;       // Donchian Channel Period
input int      InpEMAPeriod       = 200;      // Trend Filter EMA Period
input double   InpDonchianATRMult = 2.0;      // ATR Multiplier for Stop Loss
input double   InpTargetMult      = 1.5;      // Take Profit Multiplier (1.5x SL)
input double   InpMinSLPct        = 1.0;      // Default Min SL as % of price
input double   InpMaxSLPct        = 3.0;      // Default Max SL as % of price

input group "--- Strategy 2: Crypto Volume Breakout Settings ---"
input double   InpVolumeMult1     = 1.8;      // Vol Breakout Multiplier
input double   InpVolumeBreakTPMult = 2.0;    // Vol Breakout TP Multiplier (2.0x SL)
input bool     InpUseLocalVolBreakout = true;  // Use Volume Breakout for local breakouts

input group "--- Strategy 3: Crypto Scalp Momentum Settings ---"
input double   InpVolumeMult2     = 1.2;      // Scalp Momentum Multiplier
input int      InpEMA9Length      = 9;        // Pullback EMA Length
input double   InpScalpTPMult     = 1.5;      // Scalp TP Multiplier (1.5x SL)
input bool     InpUseLocalVWAPPullback = true; // Use VWAP Pullback for local setups


input group "--- Profit Management Settings ---"
input bool     InpEnablePartialClose = true;   // Close 50% lot at Break-Even Stage

input group "--- Active Loss-Cutting Settings ---"
input bool     InpEnableCandleTrail   = true;  // Trail SL by Candle Lows/Highs
input double   InpCandleTrailBuffer   = 0.10;  // Custom Mode ONLY: Buffer below Low / above High ($)
input bool     InpEnableRejectionExit = true;  // Close trade if candle closes opposite

input group "--- CUSTOM MODE ONLY: Entry & Stop Distances ---"
input double   InpPriceOffset      = 0.30;     // Custom Entry Offset from High/Low ($)
input double   InpStopLossDist     = 1.30;     // Custom Stop Loss Distance ($)
input double   InpTakeProfitDist   = 0.00;     // Custom Take Profit Distance ($) [0 = Unlimited]

input group "--- CUSTOM MODE ONLY: Stage 1 Break-Even ---"
input bool     InpEnableBE         = true;     // Custom Enable Initial Break-Even
input double   InpBETrigger        = 1.00;     // Custom Break-Even Trigger ($ profit)
input double   InpBEOffset         = 0.10;     // Custom Break-Even Lock Offset ($)

input group "--- CUSTOM MODE ONLY: Stage 2 Wide Trailing ---"
input bool     InpEnableStage1     = true;     // Custom Enable Stage 1 (Wide Trail)
input double   InpStage1Trigger    = 1.50;     // Custom Stage 1 Trigger ($ profit)
input double   InpStage1Distance   = 1.50;     // Custom Stage 1 Trail Distance ($)

input group "--- CUSTOM MODE ONLY: Stage 3 Tight Trailing ---"
input bool     InpEnableStage2     = true;     // Custom Enable Stage 2 (Tight Trail)
input double   InpStage2Trigger    = 2.50;     // Custom Stage 2 Trigger ($ profit)
input double   InpStage2Distance   = 0.60;     // Custom Stage 2 Trail Distance ($)

input group "--- CUSTOM MODE ONLY: Time-Decay Settings ---"
input bool     InpEnableTimeDecay  = true;     // Custom Enable Time-Decay Exit
input int      InpMaxHoldMinutes   = 45;       // Custom Maximum Hold Time (Minutes)
input double   InpMinATR           = 0.50;     // Custom Minimum ATR (Volatility Limit)

input group "--- AI HEDGING RECOVERY SETTINGS ---"
input bool     InpEnableHedgeRecovery      = true;     // Enable AI Hedging Recovery
input double   InpHedgeDrawdownThreshold   = 6.0;      // Points of drawdown to trigger Hedge
input double   InpRecoveryLotMultiplier    = 1.5;      // Lot multiplier for Recovery trade
input double   InpMinBasketProfit          = 1.0;      // Combined net profit ($ USD) to close basket

//--- Global Variables / Presets Map
CTradeSafe     trade;
datetime       g_lastBarTime;
datetime       g_lastOrderPlacedBarTime = 0; // Tracks if order was placed successfully for this candle
int            g_lastDay = 0;                // Tracks day changes for Daily Bias calculation

int            g_emaHandle;         // Local EMA handle
int            g_emaHigherHandle;   // Higher timeframe EMA handle
int            g_atrHandle;         // ATR handle
int            g_rsiHandle;         // RSI handle
int            g_adxHandle;         // ADX handle
int            g_ema200Handle;      // EMA 200 Trend Filter handle
int            g_ema9Handle;        // EMA 9 handle

// Spread smoothing buffers
double         g_spreadBuffer[10];
int            g_spreadCount;

// Dynamic preset outputs
double         g_lotSize;
double         g_priceOffset;
double         g_stopLossDist;
double         g_takeProfitDist;

int            g_ema200M15Handle = INVALID_HANDLE;
int            g_ema200H1Handle = INVALID_HANDLE;
int            g_ema200H4Handle = INVALID_HANDLE;

// Mid-Candle AI Call Cooldowns
int            g_dbX = -1;
int            g_dbY = -1;
bool           g_midCandleQueried = false;
datetime       g_lastAICallTime = 0;

// Hedge Recovery State Tracking
bool           g_hedgeActive = false;
ulong          g_hedgeTicket = 0;
bool           g_recoveryActive = false;
ulong          g_recoveryTicket = 0;
bool           g_enableBE;
double         g_beTrigger;
double         g_beOffset;
bool           g_enableStage1;
double         g_stage1Trigger;
double         g_stage1Distance;
bool           g_enableStage2;
double         g_stage2Trigger;
double         g_stage2Distance;
bool           g_enableTimeDecay;
int            g_maxHoldMinutes;
double         g_minATR;

// Timeframe-adapted settings
double         g_minADX;
double         g_atrSLMultiplier;
double         g_atrOffsetMultiplier;
double         g_candleTrailBuffer;

// UI controls
bool           g_eaRunning = true;  // Button state toggle

// AI Conviction & Bias Outputs
string         g_dailySentiment = "BI_DIRECTIONAL";
string         g_dailySentimentReason = "Analyzing macro...";
string         g_aiDecision = "WAITING";
int            g_aiConviction = 0;
string         g_aiReason = "Awaiting setup...";
string         g_aiStrategy = "NONE";
string         g_tradeHorizon = "SHORT_TERM"; // SHORT_TERM or LONG_TERM holding time horizon
string         g_aiRegime = "BREAKOUT";     // Holds current active AI regime
string         g_upcomingNews = "None"; // Holds parsed news for the current day
string         g_h1MacroBias = "NEUTRAL";
string         g_h1MacroReason = "Analyzing macro H1...";
datetime       g_lastH1BarTime = 0;
string         g_lastAIResponseText = "";
string         g_openRouterAPIKey = "";
string         g_groqAPIKey = "";
datetime       g_lastCalendarFetchTime = 0; // Tracks when we last fetched calendar

//+------------------------------------------------------------------+
//| Determine higher timeframe for trend alignment                  |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetHigherTimeframe()
{
   ENUM_TIMEFRAMES period = _Period;
   if(period == PERIOD_M1)  return PERIOD_M15;
   if(period == PERIOD_M5)  return PERIOD_H1;
   if(period == PERIOD_M15) return PERIOD_H4;
   if(period == PERIOD_H1)  return PERIOD_D1;
   return PERIOD_H4; // fallback
}

bool CalculateReversionMode(double adxVal, bool isMomHour, bool isVolSpike, bool aiAct, string rawReg)
{
   if(aiAct)
   {
      return (rawReg == "REVERSION");
   }
   if(!InpEnableHybridMode) return false;
   
   // Global Trend Guard: if ADX shows a very strong trend, NEVER reversion trade range limits
   if(adxVal > 25.0) return false;
   
   if(adxVal < g_minADX) return true;
   
   if(InpUseSessionHours && !isMomHour)
   {
      if(isVolSpike) return false;
      return true;
   }
   
   if(aiAct)
   {
      return (rawReg == "REVERSION");
   }
   
   return false;
}

double RoundToStep(double value, double step)
{
   if(step <= 0.0) return value;
   return NormalizeDouble(MathRound(value / step) * step, _Digits);
}

string GetCandlePattern(int index)
{
   double openPrice  = iOpen(_Symbol, _Period, index);
   double highPrice  = iHigh(_Symbol, _Period, index);
   double lowPrice   = iLow(_Symbol, _Period, index);
   double closePrice = iClose(_Symbol, _Period, index);
   
   double range = highPrice - lowPrice;
   if(range <= 0.0) return "Normal";
   
   double body = MathAbs(closePrice - openPrice);
   double upperWick = highPrice - MathMax(openPrice, closePrice);
   double lowerWick = MathMin(openPrice, closePrice) - lowPrice;
   
   // Doji check
   if(body / range < 0.1) return "Doji (Indecision)";
   
   // Hammer / Pin Bar check (Bullish Rejection)
   if(lowerWick / range > 0.6 && upperWick / range < 0.2)
      return "Hammer (Bullish Rejection)";
      
   // Shooting Star check (Bearish Rejection)
   if(upperWick / range > 0.6 && lowerWick / range < 0.2)
      return "Shooting Star (Bearish Rejection)";
      
   // Engulfing check (requires index + 1)
   double prevOpen  = iOpen(_Symbol, _Period, index + 1);
   double prevClose = iClose(_Symbol, _Period, index + 1);
   double prevBody  = MathAbs(prevClose - prevOpen);
   
   if(closePrice > openPrice && prevClose < prevOpen && body > prevBody && openPrice <= prevClose && closePrice >= prevOpen)
      return "Bullish Engulfing";
      
   if(closePrice < openPrice && prevClose > prevOpen && body > prevBody && openPrice >= prevClose && closePrice <= prevOpen)
      return "Bearish Engulfing";
      
   return (closePrice > openPrice) ? "Bullish Candle" : "Bearish Candle";
}

//+------------------------------------------------------------------+
//| Update running spread buffer on every single tick                |
//+------------------------------------------------------------------+
void UpdateSpreadBuffer()
{
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentSpread = currentAsk - currentBid;
   
   // Shift buffer
   for(int j = 9; j > 0; j--)
   {
      g_spreadBuffer[j] = g_spreadBuffer[j-1];
   }
   g_spreadBuffer[0] = currentSpread;
   if(g_spreadCount < 10) g_spreadCount++;
}

//+------------------------------------------------------------------+
//| Fetch averaged (smoothed) spread from buffer                     |
//+------------------------------------------------------------------+
double GetSmoothedSpread()
{
   if(g_spreadCount == 0)
   {
      return SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
   }
   
   double sum = 0.0;
   for(int j = 0; j < g_spreadCount; j++)
   {
      sum += g_spreadBuffer[j];
   }
   return NormalizeDouble(sum / g_spreadCount, _Digits);
}

//+------------------------------------------------------------------+
//| Verify chart timeframe matches input settings                    |
//+------------------------------------------------------------------+
bool VerifyTimeframeMismatch()
{
   if(InpTimeframeMode == TF_AUTO || InpTimeframeMode == TF_CUSTOM)
      return false; // Auto and Custom modes have no mismatch
      
   ENUM_TIMEFRAMES currentPeriod = _Period;
   bool tfMismatch = false;
   string targetTfStr = "";
   
   if(InpTimeframeMode == TF_M1 && currentPeriod != PERIOD_M1) { tfMismatch = true; targetTfStr = "M1 (1-Minute)"; }
   else if(InpTimeframeMode == TF_M5 && currentPeriod != PERIOD_M5) { tfMismatch = true; targetTfStr = "M5 (5-Minute)"; }
   else if(InpTimeframeMode == TF_M15 && currentPeriod != PERIOD_M15) { tfMismatch = true; targetTfStr = "M15 (15-Minute)"; }
   else if(InpTimeframeMode == TF_H1 && currentPeriod != PERIOD_H1) { tfMismatch = true; targetTfStr = "H1 (1-Hour)"; }
   
   if(tfMismatch)
   {
      string msg = "WARNING: Timeframe mismatch! Please change chart period to: " + targetTfStr;
      Comment(msg);
      
      static datetime lastAlertTime = 0;
      if(TimeCurrent() - lastAlertTime > 60) // Alert at most once per minute
      {
         lastAlertTime = TimeCurrent();
         Alert(msg);
      }
      return true; // Mismatch exists
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Helper to create label text elements                             |
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text, int fontSize, color clr, string font="Segoe UI")
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Helper to create background panel rectangle                      |
//+------------------------------------------------------------------+
void CreatePanelBg(string name, int x, int y, int width, int height, color bgColor, color borderColor)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_COLOR, borderColor);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Update layout/color of the button                                |
//+------------------------------------------------------------------+
void UpdateButtonState()
{
   string name = "BtnEAToggle";
   if(ObjectFind(0, name) >= 0)
   {
      if(g_eaRunning)
      {
         ObjectSetString(0, name, OBJPROP_TEXT, "EA STATUS: ACTIVE");
         ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C'46,125,50'); // Dark Green
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
      }
      else
      {
         ObjectSetString(0, name, OBJPROP_TEXT, "EA STATUS: PAUSED");
         ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C'198,40,40'); // Dark Red
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
      }
   }
}

//+------------------------------------------------------------------+
//| Create the interactive toggle button and panel on chart          |
//+------------------------------------------------------------------+
void CreateInterface()
{
   if(!InpShowDashboard)
   {
      ObjectDelete(0, "DbPanelBg");
      ObjectDelete(0, "DbTitle");
      ObjectDelete(0, "DbTimeframe");
      ObjectDelete(0, "DbLotSize");
      ObjectDelete(0, "DbADX");
      ObjectDelete(0, "DbATR");
      ObjectDelete(0, "DbMode");
      ObjectDelete(0, "DbSL");
      ObjectDelete(0, "DbBias");
      ObjectDelete(0, "DbDecision");
      ObjectDelete(0, "DbConviction");
      ObjectDelete(0, "DbReason");
      ObjectDelete(0, "BtnEAToggle");
      ChartRedraw();
      return;
   }

   int panelWidth  = 550;
   int panelHeight = 360;
   int margin      = 25;
   
   int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   
   int baseX = InpDashboardX;
   int baseY = InpDashboardY;
   
   if(g_dbX >= 0 || g_dbY >= 0)
   {
      baseX = g_dbX;
      baseY = g_dbY;
   }
   else
   {
      switch(InpDashboardPosition)
      {
         case DB_POS_TOP_LEFT:
            baseX = InpDashboardX;
            baseY = InpDashboardY;
            break;
         case DB_POS_TOP_RIGHT:
            baseX = chartWidth - panelWidth - InpDashboardX;
            baseY = InpDashboardY;
            break;
         case DB_POS_BOTTOM_LEFT:
            baseX = InpDashboardX;
            baseY = chartHeight - panelHeight - InpDashboardY - 40;
            break;
         case DB_POS_BOTTOM_RIGHT:
            baseX = chartWidth - panelWidth - InpDashboardX;
            baseY = chartHeight - panelHeight - InpDashboardY - 40;
            break;
         case DB_POS_CENTER:
            baseX = (chartWidth - panelWidth) / 2;
            baseY = (chartHeight - panelHeight) / 2;
            break;
         case DB_POS_FREE_MOVE:
            baseX = InpDashboardX;
            baseY = InpDashboardY;
            break;
      }
      g_dbX = baseX;
      g_dbY = baseY;
   }
   
   int textX = baseX + margin;
   int fontSize = 8;
   
   // 1. Create Background Shield
   CreatePanelBg("DbPanelBg", baseX, baseY, panelWidth, panelHeight, C'20,20,20', C'70,70,70');
   ObjectSetInteger(0, "DbPanelBg", OBJPROP_SELECTABLE, true);
   
   // 2. Create Header
   CreateLabel("DbTitle", textX, baseY + 15, "GOLD ENGINE V10 - HYBRID PRO", 10, C'255,179,0', "Segoe UI Semibold");
   
   // 3. Create Rows (Relative to baseY)
   CreateLabel("DbTimeframe", textX, baseY + 40, "Chart Timeframe : ", fontSize, clrWhite);
   CreateLabel("DbLotSize",   textX, baseY + 62, "Dynamic Lot Size: ", fontSize, clrWhite);
   CreateLabel("DbADX",       textX, baseY + 84, "Current ADX     : ", fontSize, clrWhite);
   CreateLabel("DbATR",       textX, baseY + 106, "Current ATR     : ", fontSize, clrWhite);
   CreateLabel("DbMode",      textX, baseY + 128, "Active Mode     : ", fontSize, clrWhite);
   CreateLabel("DbSL",        textX, baseY + 150, "Stop Loss (ATR) : ", fontSize, clrWhite);
   
   // AI Dashboard Rows
   CreateLabel("DbBias",      textX, baseY + 172, "AI Daily Bias   : ", fontSize, clrWhite);
   CreateLabel("DbDecision",  textX, baseY + 194, "AI Decision     : ", fontSize, clrWhite);
   CreateLabel("DbConviction",textX, baseY + 216, "AI Conviction   : ", fontSize, clrWhite);
   CreateLabel("DbReason",    textX, baseY + 238, "AI Reason       : ", fontSize, clrWhite);
   
   // 4. Create Button
   string btnName = "BtnEAToggle";
   if(ObjectFind(0, btnName) < 0)
   {
      ObjectCreate(0, btnName, OBJ_BUTTON, 0, 0, 0);
   }
   ObjectSetInteger(0, btnName, OBJPROP_XDISTANCE, textX);
   ObjectSetInteger(0, btnName, OBJPROP_YDISTANCE, baseY + 305);
   ObjectSetInteger(0, btnName, OBJPROP_XSIZE, panelWidth - (margin * 2));
   ObjectSetInteger(0, btnName, OBJPROP_YSIZE, 32);
   ObjectSetInteger(0, btnName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, btnName, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, btnName, OBJPROP_TEXT, "EA STATUS: ACTIVE");
   ObjectSetString(0, btnName, OBJPROP_FONT, "Segoe UI Semibold");
   ObjectSetInteger(0, btnName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, btnName, OBJPROP_HIDDEN, true);
   
   UpdateButtonState();
   ChartSetInteger(0, CHART_FOREGROUND, false);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Display active status information on the dashboard               |
//+------------------------------------------------------------------+
void DrawChartStatus(double currentADX, double currentATR, bool reversionModeActive)
{
   if(!InpShowDashboard) return;
   if(ObjectFind(0, "DbPanelBg") < 0)
   {
      CreateInterface();
   }
   
   if(!g_eaRunning)
   {
      ObjectSetString(0, "DbTimeframe", OBJPROP_TEXT, "         SYSTEM PAUSED         ");
      ObjectSetInteger(0, "DbTimeframe", OBJPROP_COLOR, C'239,83,80'); 
      
      ObjectSetString(0, "DbLotSize",   OBJPROP_TEXT, "No new trades allowed.");
      ObjectSetString(0, "DbADX",       OBJPROP_TEXT, "Active positions will");
      ObjectSetString(0, "DbATR",       OBJPROP_TEXT, "still be managed safely.");
      ObjectSetString(0, "DbMode",      OBJPROP_TEXT, "");
      ObjectSetString(0, "DbSL",        OBJPROP_TEXT, "");
      ObjectSetString(0, "DbBias",      OBJPROP_TEXT, "");
      ObjectSetString(0, "DbDecision",  OBJPROP_TEXT, "");
      ObjectSetString(0, "DbConviction",OBJPROP_TEXT, "");
      ObjectSetString(0, "DbReason",    OBJPROP_TEXT, "");
      ChartRedraw();
      return;
   }
   
   string tfName = "UNKNOWN";
   ENUM_TIMEFRAMES period = _Period;
   if(period == PERIOD_M1) tfName = "M1 (1-Minute)";
   else if(period == PERIOD_M5) tfName = "M5 (5-Minute)";
   else if(period == PERIOD_M15) tfName = "M15 (15-Minute)";
   else if(period == PERIOD_H1) tfName = "H1 (1-Hour)";
   
   string modeStr = reversionModeActive ? "SIDEWAYS" : "TRENDING";
   string shortStrategy = g_aiStrategy;
   if(shortStrategy == "MEAN_REVERSION") shortStrategy = "Mean Rev";
   else if(shortStrategy == "VOLUME_BREAKOUT") shortStrategy = "Vol Break";
   else if(shortStrategy == "DONCHIAN_BREAKOUT") shortStrategy = "Donchian";
   else if(shortStrategy == "VWAP_PULLBACK") shortStrategy = "VWAP Pull";
   else if(shortStrategy == "PULLBACK") shortStrategy = "Pullback";
   else if(shortStrategy == "STRADDLE") shortStrategy = "Straddle";
   else if(shortStrategy == "SCALPING") shortStrategy = "Scalp";
   else if(shortStrategy == "BREAKOUT") shortStrategy = "Breakout";
   
   if(shortStrategy != "NONE" && shortStrategy != "")
   {
      modeStr += " (" + shortStrategy + ")";
   }
   if(InpUseAIEngines && g_tradeHorizon != "")
   {
      string shortHorizon = (g_tradeHorizon == "LONG_TERM") ? "LONG" : "SHORT";
      modeStr += " [" + shortHorizon + "]";
   }
   
   if(g_hedgeActive)
   {
      modeStr = "HEDGE RECOVERY (Active)";
   }
   
   ObjectSetString(0, "DbTimeframe", OBJPROP_TEXT, "Chart Timeframe : " + tfName);
   ObjectSetInteger(0, "DbTimeframe", OBJPROP_COLOR, clrWhite);
   
   ObjectSetString(0, "DbLotSize",   OBJPROP_TEXT, StringFormat("Dynamic Lot Size: %.2f lots", g_lotSize));
   ObjectSetString(0, "DbADX",       OBJPROP_TEXT, StringFormat("Current ADX     : %.2f (Min: %.1f)", currentADX, g_minADX));
   ObjectSetString(0, "DbATR",       OBJPROP_TEXT, StringFormat("Current ATR     : %.2f (Min: %.2f)", currentATR, g_minATR));
   ObjectSetString(0, "DbMode",      OBJPROP_TEXT, "Active Mode     : " + modeStr);
   ObjectSetString(0, "DbSL",        OBJPROP_TEXT, StringFormat("Stop Loss (ATR) : %.2f $", g_stopLossDist));
   
   // AI Daily Bias
   ObjectSetString(0, "DbBias",      OBJPROP_TEXT, "AI Daily Bias   : " + g_dailySentiment);
   if(g_dailySentiment == "BUY_ONLY")
      ObjectSetInteger(0, "DbBias", OBJPROP_COLOR, C'76,175,80');  // Green
   else if(g_dailySentiment == "SELL_ONLY")
      ObjectSetInteger(0, "DbBias", OBJPROP_COLOR, C'239,83,80'); // Red
   else
      ObjectSetInteger(0, "DbBias", OBJPROP_COLOR, C'255,179,0'); // Yellow
   
   // AI Decision
   string displayDecision = g_aiDecision;
   if(CountActiveTrades() > 0)
   {
      if(g_hedgeActive && g_recoveryActive)
      {
         displayDecision = "RECOVERY BASKET";
      }
      else if(g_hedgeActive)
      {
         displayDecision = "HEDGED POSITION";
      }
      else
      {
         for(int idx = 0; idx < PositionsTotal(); idx++)
         {
            if(PositionGetSymbol(idx) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            {
               ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
               displayDecision = (posType == POSITION_TYPE_BUY) ? "HOLDING BUY" : "HOLDING SELL";
               break;
            }
         }
      }
   }
   
   ObjectSetString(0, "DbDecision",  OBJPROP_TEXT, "AI Decision     : " + displayDecision);
   if(StringFind(displayDecision, "BUY") >= 0)
      ObjectSetInteger(0, "DbDecision", OBJPROP_COLOR, C'76,175,80');  // Green
   else if(StringFind(displayDecision, "SELL") >= 0)
      ObjectSetInteger(0, "DbDecision", OBJPROP_COLOR, C'239,83,80'); // Red
   else if(StringFind(displayDecision, "HEDGE") >= 0 || StringFind(displayDecision, "RECOVERY") >= 0)
      ObjectSetInteger(0, "DbDecision", OBJPROP_COLOR, C'239,83,80'); // Red
   else if(StringFind(displayDecision, "HOLD") >= 0)
      ObjectSetInteger(0, "DbDecision", OBJPROP_COLOR, C'255,179,0'); // Yellow
   else
      ObjectSetInteger(0, "DbDecision", OBJPROP_COLOR, clrWhite);
   
   // AI Conviction
   string convictionStr = (g_aiDecision == "LOCAL RULES" || g_aiDecision == "WAITING") ? "N/A" : StringFormat("%d%%", g_aiConviction);
   if(g_aiConviction >= 80) convictionStr += " (HIGH CONFIDENCE)";
   else if(g_aiConviction >= 50) convictionStr += " (MEDIUM CONFIDENCE)";
   else if(g_aiConviction > 0) convictionStr += " (LOW CONFIDENCE - BLOCKED)";
   ObjectSetString(0, "DbConviction", OBJPROP_TEXT, "AI Conviction   : " + convictionStr);
   
   if(g_aiDecision == "LOCAL RULES" || g_aiDecision == "WAITING")
      ObjectSetInteger(0, "DbConviction", OBJPROP_COLOR, clrWhite);
   else if(g_aiConviction >= 80)
      ObjectSetInteger(0, "DbConviction", OBJPROP_COLOR, C'76,175,80'); // Green
   else if(g_aiConviction >= 50)
      ObjectSetInteger(0, "DbConviction", OBJPROP_COLOR, C'255,179,0'); // Yellow
   else
      ObjectSetInteger(0, "DbConviction", OBJPROP_COLOR, C'239,83,80'); // Red
   
   // AI Reason (truncated at 60 chars to fit panel nicely)
   string cleanReason = g_aiReason;
   if(StringLen(cleanReason) > 60)
   {
      cleanReason = StringSubstr(cleanReason, 0, 57) + "...";
   }
   ObjectSetString(0, "DbReason",    OBJPROP_TEXT, "AI Reason       : " + cleanReason);
   
    // Highlight Active Mode Color
    if(g_hedgeActive)
       ObjectSetInteger(0, "DbMode", OBJPROP_COLOR, C'239,83,80'); // Red
    else if(reversionModeActive)
       ObjectSetInteger(0, "DbMode", OBJPROP_COLOR, C'255,179,0'); // Yellow
    else
       ObjectSetInteger(0, "DbMode", OBJPROP_COLOR, C'76,175,80'); // Green
       
   double nearestHighs[];
   double nearestLows[];
   string tempStr = "";
   GetUntestedMagnets(nearestHighs, nearestLows, tempStr);
   
       // Preserve broken lines before updating
    for(int i = 1; i <= 3; i++)
    {
       string oldHighName = "MagnetHighLine_" + (string)i;
       string oldLowName = "MagnetLowLine_" + (string)i;
       
       if(ObjectFind(0, oldHighName) >= 0)
       {
          double oldPrice = ObjectGetDouble(0, oldHighName, OBJPROP_PRICE);
          bool stillActive = false;
          for(int j = 0; j < ArraySize(nearestHighs); j++)
          {
             if(MathAbs(nearestHighs[j] - oldPrice) < 0.01) { stillActive = true; break; }
          }
          if(!stillActive && oldPrice > 0.0)
          {
             string brokenName = "BrokenHigh_" + (string)TimeCurrent() + "_" + DoubleToString(oldPrice, 2);
             ObjectCreate(0, brokenName, OBJ_HLINE, 0, 0, oldPrice);
             ObjectSetInteger(0, brokenName, OBJPROP_STYLE, STYLE_DOT);
             ObjectSetInteger(0, brokenName, OBJPROP_COLOR, clrDimGray);
             ObjectSetInteger(0, brokenName, OBJPROP_SELECTABLE, false);
             
             ObjectDelete(0, oldHighName);
          }
       }
       
       if(ObjectFind(0, oldLowName) >= 0)
       {
          double oldPrice = ObjectGetDouble(0, oldLowName, OBJPROP_PRICE);
          bool stillActive = false;
          for(int j = 0; j < ArraySize(nearestLows); j++)
          {
             if(MathAbs(nearestLows[j] - oldPrice) < 0.01) { stillActive = true; break; }
          }
          if(!stillActive && oldPrice > 0.0)
          {
             string brokenName = "BrokenLow_" + (string)TimeCurrent() + "_" + DoubleToString(oldPrice, 2);
             ObjectCreate(0, brokenName, OBJ_HLINE, 0, 0, oldPrice);
             ObjectSetInteger(0, brokenName, OBJPROP_STYLE, STYLE_DOT);
             ObjectSetInteger(0, brokenName, OBJPROP_COLOR, clrDimGray);
             ObjectSetInteger(0, brokenName, OBJPROP_SELECTABLE, false);
             
             ObjectDelete(0, oldLowName);
          }
       }
    }
    
    // Clean up broken lines older than 30 minutes
     int totalObjects = ObjectsTotal(0, 0, OBJ_HLINE);
     for(int k = totalObjects - 1; k >= 0; k--)
     {
        string objName = ObjectName(0, k, 0, OBJ_HLINE);
        if(StringFind(objName, "BrokenHigh_") == 0 || StringFind(objName, "BrokenLow_") == 0)
        {
           int firstUnderscore = StringFind(objName, "_");
           if(firstUnderscore >= 0)
           {
              int secondUnderscore = StringFind(objName, "_", firstUnderscore + 1);
              if(secondUnderscore > firstUnderscore)
              {
                 string timeStr = StringSubstr(objName, firstUnderscore + 1, secondUnderscore - firstUnderscore - 1);
                 datetime brokenTime = (datetime)StringToInteger(timeStr);
                 if(TimeCurrent() - brokenTime > 1800) // 30 minutes
                 {
                    ObjectDelete(0, objName);
                 }
              }
           }
        }
     }
   
   // Draw High Magnets (closest to furthest)
   color goldColors[3] = { C'255,215,0', C'218,165,32', C'184,134,11' }; // Gold, Goldenrod, Dark Goldenrod
   int highCount = ArraySize(nearestHighs);
   for(int i = 0; i < highCount; i++)
   {
      DrawMagnetLine("MagnetHighLine_" + (string)(i+1), nearestHighs[i], goldColors[i]);
   }
   
   // Draw Low Magnets (closest to furthest)
   color aquaColors[3] = { C'0,255,255', C'72,209,204', C'32,178,170' }; // Aqua, Medium Turquoise, Light Sea Green
   int lowCount = ArraySize(nearestLows);
   for(int i = 0; i < lowCount; i++)
   {
      DrawMagnetLine("MagnetLowLine_" + (string)(i+1), nearestLows[i], aquaColors[i]);
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Count active trades and pending orders for safety                |
//+------------------------------------------------------------------+
int CountActiveTrades()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         count++;
      }
   }
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0)
      {
         if(OrderGetString(ORDER_SYMBOL) == _Symbol && OrderGetInteger(ORDER_MAGIC) == InpMagicNumber)
         {
            count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Calculate dynamic SL distance, Entry Offset and Lot Size         |
//+------------------------------------------------------------------+
void CalculateDynamicSLAndLots()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0.0) balance = AccountInfoDouble(ACCOUNT_EQUITY);
   
   double atrVal[];
   ArraySetAsSeries(atrVal, true);
   double currentATR = 0.80; 
   if(g_atrHandle != INVALID_HANDLE && CopyBuffer(g_atrHandle, 0, 1, 1, atrVal) > 0)
   {
      currentATR = atrVal[0];
   }
   
   if(InpUseATROffset)
   {
      g_priceOffset = NormalizeDouble(g_atrOffsetMultiplier * currentATR, _Digits);
      double minSafeOffset = (InpTimeframeMode == TF_M1 || (InpTimeframeMode == TF_AUTO && _Period == PERIOD_M1)) ? 0.10 : 0.20;
      if(g_priceOffset < minSafeOffset) g_priceOffset = minSafeOffset;
   }
   
   if(InpUseATRStopLoss)
   {
      g_stopLossDist = NormalizeDouble(g_atrSLMultiplier * currentATR, _Digits);
      double minSafeSL = (InpTimeframeMode == TF_M1 || (InpTimeframeMode == TF_AUTO && _Period == PERIOD_M1)) ? 0.80 : 1.30;
      if(g_stopLossDist < minSafeSL) g_stopLossDist = minSafeSL;
   }
   else
   {
      ENUM_TIMEFRAMES period = _Period;
      if(period == PERIOD_M1)       g_stopLossDist = 1.30;
      else if(period == PERIOD_M5)  g_stopLossDist = 2.00;
      else if(period == PERIOD_M15) g_stopLossDist = 3.50;
      else if(period == PERIOD_H1)  g_stopLossDist = 8.00;
      else                          g_stopLossDist = InpStopLossDist;
   }
   
   double dollarRisk = InpTargetRiskUSD;
   if(InpEnableCompounding)
   {
      dollarRisk = (balance / InpBalanceStep) * InpTargetRiskUSD;
   }
   
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   
   if(tickSize > 0.0 && tickValue > 0.0 && g_stopLossDist > 0.0)
   {
      g_lotSize = dollarRisk / ((g_stopLossDist / tickSize) * tickValue);
   }
   else
   {
      g_lotSize = InpLotSize; 
   }
   
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   g_lotSize = MathFloor(g_lotSize / lotStep) * lotStep;
   if(g_lotSize < minLot) g_lotSize = minLot;
   if(g_lotSize > maxLot) g_lotSize = maxLot;
}

//+------------------------------------------------------------------+
//| Load dynamic presets based on the timeframe mode                 |
//+------------------------------------------------------------------+
void LoadTimeframePresets()
{
   ENUM_TF_MODE activeMode = InpTimeframeMode;
   if(InpTimeframeMode == TF_AUTO)
   {
      ENUM_TIMEFRAMES period = _Period;
      if(period == PERIOD_M1)       activeMode = TF_M1;
      else if(period == PERIOD_M5)  activeMode = TF_M5;
      else if(period == PERIOD_M15) activeMode = TF_M15;
      else if(period == PERIOD_H1)  activeMode = TF_H1;
      else                          activeMode = TF_M1; 
   }

   if(activeMode == TF_M1)
   {
      g_minADX             = 22.0; 
      g_atrSLMultiplier    = 1.6;  
      g_atrOffsetMultiplier = 0.20;
      g_candleTrailBuffer  = 0.05;
   }
   else if(activeMode == TF_M5)
   {
      g_minADX             = 20.0;
      g_atrSLMultiplier    = 1.5;
      g_atrOffsetMultiplier = 0.15;
      g_candleTrailBuffer  = 0.10;
   }
   else if(activeMode == TF_M15)
   {
      g_minADX             = 20.0;
      g_atrSLMultiplier    = 1.5;
      g_atrOffsetMultiplier = 0.15;
      g_candleTrailBuffer  = 0.20;
   }
   else if(activeMode == TF_H1)
   {
      g_minADX             = 18.0; 
      g_atrSLMultiplier    = 1.4;
      g_atrOffsetMultiplier = 0.12;
      g_candleTrailBuffer  = 0.50;
   }
   else 
   {
      g_minADX             = InpMinADX;
      g_atrSLMultiplier    = InpATRMultiplier;
      g_atrOffsetMultiplier = InpATROffsetMultiplier;
      g_candleTrailBuffer  = InpCandleTrailBuffer;
   }

   CalculateDynamicSLAndLots();
   
   if(activeMode == TF_M1)
   {
      if(!InpUseATROffset) g_priceOffset = 0.25;
      g_takeProfitDist   = 0.00;
      g_enableBE         = true;
      g_beTrigger        = 0.60;
      g_beOffset         = 0.05;
      g_enableStage1     = true;
      g_stage1Trigger    = 1.00;
      g_stage1Distance   = 0.80;
      g_enableStage2     = true;
      g_stage2Trigger    = 1.60;
      g_stage2Distance   = 0.40;
      g_enableTimeDecay  = true;
      g_maxHoldMinutes   = 2;
      g_minATR           = 0.35; 
   }
   else if(activeMode == TF_M5)
   {
      if(!InpUseATROffset) g_priceOffset = 0.30;
      g_takeProfitDist   = 0.00;
      g_enableBE         = true;
      g_beTrigger        = 1.20;
      g_beOffset         = 0.10;
      g_enableStage1     = true;
      g_stage1Trigger    = 2.00;
      g_stage1Distance   = 1.50;
      g_enableStage2     = true;
      g_stage2Trigger    = 3.00;
      g_stage2Distance   = 0.80;
      g_enableTimeDecay  = true;
      g_maxHoldMinutes   = 15;
      g_minATR           = 0.60;
   }
   else if(activeMode == TF_M15)
   {
      if(!InpUseATROffset) g_priceOffset = 0.40;
      g_takeProfitDist   = 0.00;
      g_enableBE         = true;
      g_beTrigger        = 2.50;
      g_beOffset         = 0.20;
      g_enableStage1     = true;
      g_stage1Trigger    = 3.50;
      g_stage1Distance   = 2.50;
      g_enableStage2     = true;
      g_stage2Trigger    = 5.00;
      g_stage2Distance   = 1.20;
      g_enableTimeDecay  = true;
      g_maxHoldMinutes   = 45;
      g_minATR           = 1.20;
   }
   else if(activeMode == TF_H1)
   {
      if(!InpUseATROffset) g_priceOffset = 0.80;
      g_takeProfitDist   = 0.00;
      g_enableBE         = true;
      g_beTrigger        = 6.00;
      g_beOffset         = 0.50;
      g_enableStage1     = true;
      g_stage1Trigger    = 8.00;
      g_stage1Distance   = 6.00;
      g_enableStage2     = true;
      g_stage2Trigger    = 12.00;
      g_stage2Distance   = 2.50;
      g_enableTimeDecay  = true;
      g_maxHoldMinutes   = 180;
      g_minATR           = 3.00;
   }
   else 
   {
      g_takeProfitDist   = InpTakeProfitDist;
      g_enableBE         = InpEnableBE;
      g_beTrigger        = InpBETrigger;
      g_beOffset         = InpBEOffset;
      g_enableStage1     = InpEnableStage1;
      g_stage1Trigger    = InpStage1Trigger;
      g_stage1Distance   = InpStage1Distance;
      g_enableStage2     = InpEnableStage2;
      g_stage2Trigger    = InpStage2Trigger;
      g_stage2Distance   = InpStage2Distance;
      g_enableTimeDecay  = InpEnableTimeDecay;
      g_maxHoldMinutes   = InpMaxHoldMinutes;
      g_minATR           = InpMinATR;
      
      if(!InpUseATROffset)  g_priceOffset = InpPriceOffset;
      if(!InpUseATRStopLoss) g_stopLossDist = InpStopLossDist;
   }
}

//+------------------------------------------------------------------+
//| Function to delete unexecuted pending orders                     |
//+------------------------------------------------------------------+
void CancelPendingOrdersEx(bool cancelLimits)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0)
      {
         if(OrderGetString(ORDER_SYMBOL) == _Symbol && OrderGetInteger(ORDER_MAGIC) == InpMagicNumber)
         {
            datetime setupTime = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
            int barsPassed = iBarShift(_Symbol, _Period, setupTime);
            if(barsPassed >= InpPendingOrderExpiryBars)
            {
               ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
               if(type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP)
               {
                  trade.OrderDelete(ticket);
               }
               else if(cancelLimits && (type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_SELL_LIMIT))
               {
                  trade.OrderDelete(ticket);
               }
            }
         }
      }
   }
}

void VerifyAndSyncSidewaysLimits(double targetBuyPrice, double targetSellPrice)
{
   bool buyLimitExists = false;
   bool sellLimitExists = false;
   double currentBuyLimitPrice = 0.0;
   double currentSellLimitPrice = 0.0;
   ulong buyTicket = 0;
   ulong sellTicket = 0;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0)
      {
         if(OrderGetString(ORDER_SYMBOL) == _Symbol && OrderGetInteger(ORDER_MAGIC) == InpMagicNumber)
         {
            ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            if(type == ORDER_TYPE_BUY_LIMIT)
            {
               buyLimitExists = true;
               currentBuyLimitPrice = OrderGetDouble(ORDER_PRICE_OPEN);
               buyTicket = ticket;
            }
            else if(type == ORDER_TYPE_SELL_LIMIT)
            {
               sellLimitExists = true;
               currentSellLimitPrice = OrderGetDouble(ORDER_PRICE_OPEN);
               sellTicket = ticket;
            }
         }
      }
   }
   
   // If target price shifted, cancel the misaligned order
   if(buyLimitExists && targetBuyPrice > 0.0 && MathAbs(currentBuyLimitPrice - targetBuyPrice) > 0.05)
   {
      trade.OrderDelete(buyTicket);
      g_lastOrderPlacedBarTime = 0; // force re-evaluation
   }
   if(sellLimitExists && targetSellPrice > 0.0 && MathAbs(currentSellLimitPrice - targetSellPrice) > 0.05)
   {
      trade.OrderDelete(sellTicket);
      g_lastOrderPlacedBarTime = 0; // force re-evaluation
   }
}

//+------------------------------------------------------------------+
//| Manage active positions on candle close (Active Loss-Cutting)    |
//+------------------------------------------------------------------+
void ManageCandleCloseLossCutting(bool reversionModeActive)
{
   bool isSidewaysRegime = reversionModeActive || IsInsideGNNChannel();
   double stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            if(g_hedgeActive) continue;
            string comment = PositionGetString(POSITION_COMMENT);
             bool isSwingPosition = (comment == "GE_SWING");
            if(comment == "HEDGE_FREEZE" || comment == "RECOVERY_ENTRY" || comment == "GE_SWING") continue;
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double currentSL = PositionGetDouble(POSITION_SL);
            double currentTP = PositionGetDouble(POSITION_TP);
            
            double prevOpen  = iOpen(_Symbol, _Period, 1);
            double prevClose = iClose(_Symbol, _Period, 1);
            double prevHigh  = iHigh(_Symbol, _Period, 1);
            double prevLow   = iLow(_Symbol, _Period, 1);
            
            if(type == POSITION_TYPE_BUY)
            {
               if(InpEnableRejectionExit && prevClose < prevOpen && !isSidewaysRegime && !isSwingPosition)
               {
                  Print(StringFormat("[V10 SOFT STOP] Closing BUY ticket #%I64u due to Bearish Close.", ticket));
                  trade.PositionClose(ticket);
                  continue;
               }
               
               if(InpEnableCandleTrail && !isSidewaysRegime && !isSwingPosition)
               {
                  double targetSL = NormalizeDouble(prevLow - g_candleTrailBuffer, _Digits);
                  if(targetSL > currentSL || currentSL == 0.0)
                  {
                     double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                     if(currentBid - targetSL >= stopsLevel)
                     {
                        if(trade.PositionModify(ticket, targetSL, currentTP))
                        {
                           Print(StringFormat("[V10 CANDLE TRAIL] Trailed BUY SL to candle Low: %.2f", targetSL));
                        }
                     }
                  }
               }
            }
            else if(type == POSITION_TYPE_SELL)
            {
               if(InpEnableRejectionExit && prevClose > prevOpen && !isSidewaysRegime && !isSwingPosition)
               {
                  Print(StringFormat("[V10 SOFT STOP] Closing SELL ticket #%I64u due to Bullish Close.", ticket));
                  trade.PositionClose(ticket);
                  continue;
               }
               
               if(InpEnableCandleTrail && !isSidewaysRegime && !isSwingPosition)
               {
                  double targetSL = NormalizeDouble(prevHigh + g_candleTrailBuffer, _Digits);
                  if(targetSL < currentSL || currentSL == 0.0)
                  {
                     double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                     if(targetSL - currentAsk >= stopsLevel)
                     {
                        if(trade.PositionModify(ticket, targetSL, currentTP))
                        {
                           Print(StringFormat("[V10 CANDLE TRAIL] Trailed SELL SL to candle High: %.2f", targetSL));
                        }
                     }
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Simple string parsing helper to extract value by key from JSON   |
//+------------------------------------------------------------------+
string ExtractJSONValue(string json, string key)
{
   // Try matching escaped quotes first: \"key\"
   string searchKey = "\\\"" + key + "\\\"";
   int startIdx = StringFind(json, searchKey);
   
   // If not found, try matching normal quotes: "key"
   if(startIdx < 0)
   {
      searchKey = "\"" + key + "\"";
      startIdx = StringFind(json, searchKey);
   }
   
   // If still not found, try matching single quotes: 'key'
   if(startIdx < 0)
   {
      searchKey = "'" + key + "'";
      startIdx = StringFind(json, searchKey);
   }
   
   if(startIdx < 0) return "";
   
   int colonIdx = StringFind(json, ":", startIdx + StringLen(searchKey));
   if(colonIdx < 0) return "";
   
   int valStart = colonIdx + 1;
   while(valStart < StringLen(json))
   {
      string charStr = StringSubstr(json, valStart, 1);
      if(charStr == " " || charStr == "\t" || charStr == "\r" || charStr == "\n" || 
         charStr == "\"" || charStr == "'" || charStr == "\\" || charStr == "{")
      {
         valStart++;
      }
      else
      {
         break;
      }
   }
   
   int valEnd = valStart;
   while(valEnd < StringLen(json))
   {
      string charStr = StringSubstr(json, valEnd, 1);
      if(charStr == "\"" || charStr == "'" || charStr == "," || charStr == "}" || 
         charStr == "\\" || charStr == "\r" || charStr == "\n")
      {
         break;
      }
      valEnd++;
   }
   
   if(valEnd > valStart)
   {
      return StringSubstr(json, valStart, valEnd - valStart);
   }
   return "";
}

//+------------------------------------------------------------------+
//| Central AI client caller with user selection & failover          |
//+------------------------------------------------------------------+
bool QueryGeminiDirect(string prompt, string &responseText)
{
   if(InpGeminiAPIKey == "" || InpGeminiAPIKey == "PASTE_YOUR_API_KEY_HERE") return false;
   
   string cleanPrompt = prompt;
   // Replace backslashes first, then replace quotes and control characters to ensure clean JSON
   StringReplace(cleanPrompt, "\\", "\\\\");
   StringReplace(cleanPrompt, "\"", "\\\"");
   StringReplace(cleanPrompt, "\r", " ");
   StringReplace(cleanPrompt, "\n", " ");
   StringReplace(cleanPrompt, "\t", " ");
   
   string requestBody = "{\"contents\":[{\"parts\":[{\"text\":\"" + cleanPrompt + "\"}]}]}";
   string url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=" + InpGeminiAPIKey;
   string headers = "Content-Type: application/json\r\n";
   
   uchar post[];
   uchar result[];
   string responseHeaders = "";
   int bytes = StringToCharArray(requestBody, post, 0, WHOLE_ARRAY, CP_UTF8);
   while(bytes > 0 && post[bytes-1] == 0) { bytes--; }
   ArrayResize(post, bytes);
   
   ResetLastError();
   int res = WebRequest("POST", url, headers, 8000, post, result, responseHeaders);
   if(res == 200)
   {
      responseText = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
      Print("[Gemini Success] Response: ", responseText);
      return true;
   }
   else
   {
      string err = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
      Print("[Gemini Fail] HTTP Status: ", res, ", Error Response: ", err);
   }
   return false;
}

string EscapeJSONString(string text)
{
   string escaped = text;
   StringReplace(escaped, "\\x00", "");
   StringReplace(escaped, "\\", "\\\\");
   StringReplace(escaped, "\"", "\\\"");
   StringReplace(escaped, "\r", "\\r");
   StringReplace(escaped, "\n", "\\n");
   StringReplace(escaped, "\t", "\\t");
   return escaped;
}

bool QueryOpenRouterDirect(string prompt, string &responseText)
{
   if(g_openRouterAPIKey == "" || g_openRouterAPIKey == "PASTE_YOUR_API_KEY_HERE") return false;
   
   string cleanPrompt = EscapeJSONString(prompt);   
   string requestBody = "";
   if(InpUseAIVision)
   {
      string filename = "AIVision.png";
      ResetLastError();
      if(ChartScreenShot(0, filename, 800, 600, ALIGN_RIGHT))
      {
         int handle = FileOpen(filename, FILE_BIN|FILE_READ);
         if(handle != INVALID_HANDLE)
         {
            ulong fileSize = FileSize(handle);
            uchar fileData[];
            ArrayResize(fileData, (int)fileSize);
            FileReadArray(handle, fileData);
            FileClose(handle);
            
            uchar key[];
            uchar base64Data[];
            ResetLastError();
            int encRes = CryptEncode(CRYPT_BASE64, fileData, key, base64Data);
            if(encRes > 0)
            {
               string base64Str = CharArrayToString(base64Data, 0, WHOLE_ARRAY, CP_UTF8);
               StringReplace(base64Str, "\r", "");
               StringReplace(base64Str, "\n", "");
               
               requestBody = "{\"model\":\"" + InpOpenRouterModel + "\",\"messages\":[{\"role\":\"user\",\"content\":[{\"type\":\"text\",\"text\":\"" + cleanPrompt + "\"},{\"type\":\"image_url\",\"image_url\":{\"url\":\"data:image/png;base64," + base64Str + "\"}}]}],\"temperature\":0.2,\"response_format\":{\"type\":\"json_object\"}}";
            }
            else
            {
               Print("[AI Vision] Base64 encoding failed. Error: ", GetLastError());
            }
         }
         else
         {
            Print("[AI Vision] Failed to open screenshot file. Error: ", GetLastError());
         }
      }
      else
      {
         Print("[AI Vision] ChartScreenShot failed. Error: ", GetLastError());
      }
   }
   
   if(requestBody == "")
   {
      requestBody = "{\"model\":\"" + InpOpenRouterModel + "\",\"messages\":[{\"role\":\"user\",\"content\":\"" + cleanPrompt + "\"}],\"temperature\":0.2,\"response_format\":{\"type\":\"json_object\"}}";
   }
   
   string url = "https://openrouter.ai/api/v1/chat/completions";
   string headers = "Content-Type: application/json\r\nAuthorization: Bearer " + InpOpenRouterAPIKey + "\r\nHTTP-Referer: http://localhost\r\nX-Title: GoldEngine\r\n";
   
   uchar post[];
   uchar result[];
   string responseHeaders = "";
   int bytes = StringToCharArray(requestBody, post, 0, WHOLE_ARRAY, CP_UTF8);
   while(bytes > 0 && post[bytes-1] == 0) { bytes--; }
   ArrayResize(post, bytes);
   
   ResetLastError();
   int res = WebRequest("POST", url, headers, 8000, post, result, responseHeaders);
   if(res == 200)
   {
      responseText = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
      Print("[OpenRouter Success] Response: ", responseText);
      return true;
   }
   else
   {
      string err = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
      Print("[OpenRouter Fail] HTTP Status: ", res, ", Error Response: ", err);
   }
   return false;
}


bool QueryGroqDirect(string prompt, string &responseText)
{
   if(g_groqAPIKey == "" || g_groqAPIKey == "PASTE_YOUR_API_KEY_HERE") return false;
   
   string cleanPrompt = EscapeJSONString(prompt);   string requestBody = "{\"model\":\"llama-3.1-8b-instant\",\"messages\":[{\"role\":\"user\",\"content\":\"" + cleanPrompt + "\"}],\"temperature\":0.2,\"response_format\":{\"type\":\"json_object\"}}";
   string url = "https://api.groq.com/openai/v1/chat/completions";
   string headers = "Content-Type: application/json\r\nAuthorization: Bearer " + InpGroqAPIKey + "\r\n";
   
   uchar post[];
   uchar result[];
   string responseHeaders = "";
   int bytes = StringToCharArray(requestBody, post, 0, WHOLE_ARRAY, CP_UTF8);
   while(bytes > 0 && post[bytes-1] == 0) { bytes--; }
   ArrayResize(post, bytes);
   
   ResetLastError();
   int res = WebRequest("POST", url, headers, 8000, post, result, responseHeaders);
   if(res == 200)
   {
      responseText = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
      Print("[Groq Success] Response: ", responseText);
      return true;
   }
   else
   {
      string err = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
      Print("[Groq Fail] HTTP Status: ", res, ", Error Response: ", err);
   }
   return false;
}

string GetNewsCountdownDesc()
{
   if(g_upcomingNews == "None" || g_upcomingNews == "") return "No high-impact news today.";
   
   datetime gmt = TimeGMT();
   MqlDateTime gmtStruct;
   TimeToStruct(gmt, gmtStruct);
   
   int estOffset = -5; // default EST
   // US DST: Second Sunday of March to First Sunday of November
   if(gmtStruct.mon > 3 && gmtStruct.mon < 11) estOffset = -4;
   else if(gmtStruct.mon == 3)
   {
      if(gmtStruct.day - gmtStruct.day_of_week >= 8) estOffset = -4;
   }
   else if(gmtStruct.mon == 11)
   {
      if(gmtStruct.day - gmtStruct.day_of_week < 1) estOffset = -4;
   }
   
   datetime est = gmt + estOffset * 3600;
   MqlDateTime estStruct;
   TimeToStruct(est, estStruct);
   int curMins = estStruct.hour * 60 + estStruct.min;
   
   string desc = "";
   int startPos = 0;
   
   while(startPos < StringLen(g_upcomingNews))
   {
      int atIdx = StringFind(g_upcomingNews, " at ", startPos);
      if(atIdx < 0) break;
      
      int nameStart = startPos;
      while(nameStart < atIdx && (StringSubstr(g_upcomingNews, nameStart, 1) == "," || StringSubstr(g_upcomingNews, nameStart, 1) == " "))
         nameStart++;
      string newsName = StringSubstr(g_upcomingNews, nameStart, atIdx - nameStart);
      
      int timeStart = atIdx + 4;
      int spaceIdx = StringFind(g_upcomingNews, " (", timeStart);
      if(spaceIdx < 0) break;
      
      string timeStr = StringSubstr(g_upcomingNews, timeStart, spaceIdx - timeStart);
      
      int colonIdx = StringFind(timeStr, ":");
      if(colonIdx > 0)
      {
         int hour = (int)StringToInteger(StringSubstr(timeStr, 0, colonIdx));
         int min = (int)StringToInteger(StringSubstr(timeStr, colonIdx + 1, 2));
         bool isPM = (StringFind(timeStr, "pm") >= 0);
         bool isAM = (StringFind(timeStr, "am") >= 0);
         
         if(isPM && hour != 12) hour += 12;
         if(isAM && hour == 12) hour = 0;
         
         int newsMins = hour * 60 + min;
         int diff = newsMins - curMins;
         
         if(desc != "") desc += ", ";
         if(diff > 0)
         {
            desc += StringFormat("%s in %d mins", newsName, diff);
         }
         else if(diff >= -30)
         {
            desc += StringFormat("%s occurred %d mins ago (Active Volatility)", newsName, -diff);
         }
         else
         {
            desc += StringFormat("%s passed", newsName);
         }
      }
      else
      {
         if(desc != "") desc += ", ";
         desc += StringFormat("%s (%s)", newsName, timeStr);
      }
      
      int closeBrack = StringFind(g_upcomingNews, ")", spaceIdx);
      if(closeBrack < 0) break;
      startPos = closeBrack + 1;
   }
   
   if(desc == "") return "No specific timed news today.";
   return desc;
}

void CalculateDailyVolumeProfile(double &poc, double &vah, double &val, double &imbalanceRatio)
{
   poc = 0.0; vah = 0.0; val = 0.0; imbalanceRatio = 1.0;
   datetime startOfDay = iTime(_Symbol, PERIOD_D1, 0);
   if(startOfDay <= 0) return;
   
   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   int copied = CopyRates(_Symbol, PERIOD_M5, startOfDay, TimeCurrent(), rates);
   if(copied <= 0) return;
   
   double minPrice = 999999.0;
   double maxPrice = 0.0;
   for(int i = 0; i < copied; i++)
   {
      if(rates[i].low < minPrice) minPrice = rates[i].low;
      if(rates[i].high > maxPrice) maxPrice = rates[i].high;
   }
   
   int numBuckets = (int)MathCeil(maxPrice - minPrice);
   if(numBuckets <= 0) numBuckets = 1;
   double bucketSize = 1.0;
   if(numBuckets > 100)
   {
      bucketSize = MathCeil((maxPrice - minPrice) / 50.0);
      numBuckets = (int)MathCeil((maxPrice - minPrice) / bucketSize);
      if(numBuckets <= 0) numBuckets = 1;
   }
   
   double volumes[];
   ArrayResize(volumes, numBuckets);
   ArrayInitialize(volumes, 0.0);
   
   double totalVolume = 0.0;
   double totalBullVolume = 0.0;
   double totalBearVolume = 0.0;
   for(int i = 0; i < copied; i++)
   {
      int bucketIdx = (int)((rates[i].close - minPrice) / bucketSize);
      if(bucketIdx >= 0 && bucketIdx < numBuckets)
      {
         volumes[bucketIdx] += (double)rates[i].tick_volume;
         totalVolume += (double)rates[i].tick_volume;
      }
      if(rates[i].close > rates[i].open)
         totalBullVolume += (double)rates[i].tick_volume;
      else if(rates[i].close < rates[i].open)
         totalBearVolume += (double)rates[i].tick_volume;
   }
   
   double maxVol = 0.0;
   int pocIdx = 0;
   for(int i = 0; i < numBuckets; i++)
   {
      if(volumes[i] > maxVol)
      {
         maxVol = volumes[i];
         pocIdx = i;
      }
   }
   poc = minPrice + pocIdx * bucketSize + (bucketSize / 2.0);
   
   double targetVol = totalVolume * 0.70;
   double currentVol = maxVol;
   int lowerIdx = pocIdx;
   int upperIdx = pocIdx;
   
   while(currentVol < targetVol && (lowerIdx > 0 || upperIdx < numBuckets - 1))
   {
      double leftVol = (lowerIdx > 0) ? volumes[lowerIdx - 1] : 0.0;
      double rightVol = (upperIdx < numBuckets - 1) ? volumes[upperIdx + 1] : 0.0;
      
      if(leftVol >= rightVol && lowerIdx > 0)
      {
         lowerIdx--;
         currentVol += leftVol;
      }
      else if(upperIdx < numBuckets - 1)
      {
         upperIdx++;
         currentVol += rightVol;
      }
      else if(lowerIdx > 0)
      {
         lowerIdx--;
         currentVol += leftVol;
      }
      else
      {
         break;
      }
   }
   val = minPrice + lowerIdx * bucketSize;
   vah = minPrice + upperIdx * bucketSize + bucketSize;
   imbalanceRatio = (totalBearVolume > 0.0) ? (totalBullVolume / totalBearVolume) : 1.0;
}

bool QueryAIH1MacroBias()
{
   string h1History = "";
   for(int i = 10; i >= 1; i--)
   {
      h1History += StringFormat("[H1 Bar %d: O=%.2f, H=%.2f, L=%.2f, C=%.2f, V=%I64d] ", 
         i, iOpen(_Symbol, PERIOD_H1, i), iHigh(_Symbol, PERIOD_H1, i), iLow(_Symbol, PERIOD_H1, i), iClose(_Symbol, PERIOD_H1, i), iVolume(_Symbol, PERIOD_H1, i));
   }
   
   double currentEMA200 = 0.0;
   int handleH1EMA200 = iMA(_Symbol, PERIOD_H1, 200, 0, MODE_EMA, PRICE_CLOSE);
   if(handleH1EMA200 != INVALID_HANDLE)
   {
      double emaArr[];
      if(CopyBuffer(handleH1EMA200, 0, 0, 1, emaArr) > 0) currentEMA200 = emaArr[0];
      IndicatorRelease(handleH1EMA200);
   }
   
   double h1Close = iClose(_Symbol, PERIOD_H1, 0);
   string h1Trend = (h1Close > currentEMA200) ? "BULLISH (above EMA200)" : "BEARISH (below EMA200)";
   
   string prompt = StringFormat(
      "Gold (XAUUSD) H1 Macro Strategist Analysis in json format. Current price=%.2f. H1 Trend: %s (H1 EMA200=%.2f). H1 candles history: %s. "+
      "As an Elite Macro Strategist, analyze the higher timeframe structure, volume shift, and major support/resistance. "+
      "Determine the H1 directional bias for the next few hours. "+
      "Respond strictly with a json object containing: 'bias' ('BULLISH', 'BEARISH', or 'NEUTRAL') and 'reason' (short 10 words summary). "+
      "Example: { \"bias\": \"BULLISH\", \"reason\": \"Double bottom rejection on H1 support\" }.",
      SymbolInfoDouble(_Symbol, SYMBOL_BID), h1Trend, currentEMA200, h1History
   );
   
   string responseText = "";
   if(!CallAI(prompt, responseText))
   {
      g_h1MacroBias = "NEUTRAL";
      g_h1MacroReason = "AI Macro offline, neutral fallback.";
      return false;
   }
   
      string bias = ExtractJSONValue(responseText, "bias");
   string reason = ExtractJSONValue(responseText, "reason");
   
   StringToUpper(bias);
   StringTrimLeft(bias);
   StringTrimRight(bias);
   
   if(bias == "BULLISH" || bias == "BEARISH" || bias == "NEUTRAL")
   {
      g_h1MacroBias = bias;
   }
   else
   {
      g_h1MacroBias = "NEUTRAL";
   }
   
   if(reason != "")
   {
      g_h1MacroReason = reason;
      StringTrimLeft(g_h1MacroReason);
      StringTrimRight(g_h1MacroReason);
   }
   
   PrintFormat("[H1 Macro Strategist Success] Bias: %s, Reason: %s", g_h1MacroBias, g_h1MacroReason);
   return true;
}

void SaveReasoningForNewPosition(string responseText)
{
   if(responseText == "") return;
   
   string strategy = ExtractJSONValue(responseText, "strategy");
   string reasoning = ExtractJSONValue(responseText, "reasoning");
   if(strategy == "" && reasoning == "") return;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         ulong positionId = PositionGetInteger(POSITION_IDENTIFIER);
         string fileName = StringFormat("GoldEngine_Reasoning_%I64u.txt", positionId);
         if(!FileIsExist(fileName))
         {
            int fileHandle = FileOpen(fileName, FILE_WRITE|FILE_TXT|FILE_ANSI);
            if(fileHandle != INVALID_HANDLE)
            {
               FileWriteString(fileHandle, StringFormat("%s|%s", strategy, reasoning));
               FileClose(fileHandle);
               PrintFormat("[Post-Mortem Memory] Saved reasoning file for position ID: %I64u", positionId);
            }
            break;
         }
      }
   }
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0)
      {
         if(OrderGetString(ORDER_SYMBOL) == _Symbol && OrderGetInteger(ORDER_MAGIC) == InpMagicNumber)
         {
            string fileName = StringFormat("GoldEngine_Reasoning_Order_%I64u.txt", ticket);
            if(!FileIsExist(fileName))
            {
               int fileHandle = FileOpen(fileName, FILE_WRITE|FILE_TXT|FILE_ANSI);
               if(fileHandle != INVALID_HANDLE)
               {
                  FileWriteString(fileHandle, StringFormat("%s|%s", strategy, reasoning));
                  FileClose(fileHandle);
                  PrintFormat("[Post-Mortem Memory] Saved reasoning file for pending order ticket: %I64u", ticket);
               }
               break;
            }
         }
      }
   }
}

string GetMTFStructureAlignment()
{
   double m5Close = iClose(_Symbol, PERIOD_M5, 0);
   double m5EMA50 = 0.0;
   int hM5_50 = iMA(_Symbol, PERIOD_M5, 50, 0, MODE_EMA, PRICE_CLOSE);
   if(hM5_50 != INVALID_HANDLE)
   {
      double arr[];
      if(CopyBuffer(hM5_50, 0, 0, 1, arr) > 0) m5EMA50 = arr[0];
      IndicatorRelease(hM5_50);
   }
   double m5EMA200 = 0.0;
   int hM5_200 = iMA(_Symbol, PERIOD_M5, 200, 0, MODE_EMA, PRICE_CLOSE);
   if(hM5_200 != INVALID_HANDLE)
   {
      double arr[];
      if(CopyBuffer(hM5_200, 0, 0, 1, arr) > 0) m5EMA200 = arr[0];
      IndicatorRelease(hM5_200);
   }
   string m5Structure = (m5Close > m5EMA50 && m5EMA50 > m5EMA200) ? "BULLISH" :
                        (m5Close < m5EMA50 && m5EMA50 < m5EMA200) ? "BEARISH" : "NEUTRAL";

   double m15Close = iClose(_Symbol, PERIOD_M15, 0);
   double m15EMA50 = 0.0;
   int hM15_50 = iMA(_Symbol, PERIOD_M15, 50, 0, MODE_EMA, PRICE_CLOSE);
   if(hM15_50 != INVALID_HANDLE)
   {
      double arr[];
      if(CopyBuffer(hM15_50, 0, 0, 1, arr) > 0) m15EMA50 = arr[0];
      IndicatorRelease(hM15_50);
   }
   double m15EMA200 = 0.0;
   int hM15_200 = iMA(_Symbol, PERIOD_M15, 200, 0, MODE_EMA, PRICE_CLOSE);
   if(hM15_200 != INVALID_HANDLE)
   {
      double arr[];
      if(CopyBuffer(hM15_200, 0, 0, 1, arr) > 0) m15EMA200 = arr[0];
      IndicatorRelease(hM15_200);
   }
   string m15Structure = (m15Close > m15EMA50 && m15EMA50 > m15EMA200) ? "BULLISH" :
                         (m15Close < m15EMA50 && m15EMA50 < m15EMA200) ? "BEARISH" : "NEUTRAL";

   double h1Close = iClose(_Symbol, PERIOD_H1, 0);
   double h1EMA50 = 0.0;
   int hH1_50 = iMA(_Symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
   if(hH1_50 != INVALID_HANDLE)
   {
      double arr[];
      if(CopyBuffer(hH1_50, 0, 0, 1, arr) > 0) h1EMA50 = arr[0];
      IndicatorRelease(hH1_50);
   }
   double h1EMA200 = 0.0;
   int hH1_200 = iMA(_Symbol, PERIOD_H1, 200, 0, MODE_EMA, PRICE_CLOSE);
   if(hH1_200 != INVALID_HANDLE)
   {
      double arr[];
      if(CopyBuffer(hH1_200, 0, 0, 1, arr) > 0) h1EMA200 = arr[0];
      IndicatorRelease(hH1_200);
   }
   string h1Structure = (h1Close > h1EMA50 && h1EMA50 > h1EMA200) ? "BULLISH" :
                        (h1Close < h1EMA50 && h1EMA50 < h1EMA200) ? "BEARISH" : "NEUTRAL";

   return StringFormat("[M5: %s, M15: %s, H1: %s]", m5Structure, m15Structure, h1Structure);
}

void GetAsianSessionRange(double &asianHigh, double &asianLow)
{
   asianHigh = 0.0;
   asianLow = 999999.0;
   
   datetime currentDayOpen = iTime(_Symbol, PERIOD_D1, 0);
   if(currentDayOpen <= 0) return;
   
   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   int copied = CopyRates(_Symbol, PERIOD_M5, currentDayOpen, TimeCurrent(), rates);
   if(copied <= 0) return;
   
   bool found = false;
   for(int i = 0; i < copied; i++)
   {
      MqlDateTime dt;
      TimeToStruct(rates[i].time, dt);
      if(dt.hour >= 0 && dt.hour < 8)
      {
         if(rates[i].high > asianHigh) asianHigh = rates[i].high;
         if(rates[i].low < asianLow) asianLow = rates[i].low;
         found = true;
      }
   }
   
   if(!found) { asianHigh = 0.0; asianLow = 0.0; }
}

void GetAccountRiskExposure(double &floatingPnL, double &totalRiskUSD)
{
   floatingPnL = 0.0;
   totalRiskUSD = 0.0;
   
   double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(contractSize <= 0.0 || tickSize <= 0.0) return;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         floatingPnL += profit;
         
         double sl = PositionGetDouble(POSITION_SL);
         double entry = PositionGetDouble(POSITION_PRICE_OPEN);
         long type = PositionGetInteger(POSITION_TYPE);
         double volume = PositionGetDouble(POSITION_VOLUME);
         
         if(sl > 0.0)
         {
            double diff = 0.0;
            if(type == POSITION_TYPE_BUY) diff = entry - sl;
            else if(type == POSITION_TYPE_SELL) diff = sl - entry;
            
            if(diff > 0.0)
            {
               double risk = (diff / tickSize) * volume * tickValue;
               totalRiskUSD += risk;
            }
         }
      }
   }
}

bool CallAI(string prompt, string &responseText)
{
   // --- Option 1: Groq Only ---
   if(InpAIEngineSelection == AI_GROQ)
   {
      return QueryGroqDirect(prompt, responseText);
   }
   
   // --- Option 2: Gemini Only ---
   if(InpAIEngineSelection == AI_GEMINI)
   {
      return QueryGeminiDirect(prompt, responseText);
   }
   
   // --- Option 3: OpenRouter ---
   if(InpAIEngineSelection == AI_OPENROUTER)
   {
      return QueryOpenRouterDirect(prompt, responseText);
   }
   
   // --- Option 4: OpenRouter first, failover to Groq ---
   if(InpAIEngineSelection == AI_BOTH_FAILOVER)
   {
      if(QueryOpenRouterDirect(prompt, responseText)) return true;
      Print("[AI Failover] OpenRouter API unavailable. Switching to Groq Llama-3.1...");
      return QueryGroqDirect(prompt, responseText);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Query AI for Daily Sentiment Directional Anchor                  |
//+------------------------------------------------------------------+
bool QueryAIDailySentiment()
{
   string dailyHistory = "";
   for(int i = 3; i >= 1; i--)
   {
      dailyHistory += StringFormat("[D1 Bar %d: O=%.2f, H=%.2f, L=%.2f, C=%.2f] ", 
         i, iOpen(_Symbol, PERIOD_D1, i), iHigh(_Symbol, PERIOD_D1, i), iLow(_Symbol, PERIOD_D1, i), iClose(_Symbol, PERIOD_D1, i));
   }
   
   string prompt = StringFormat(
      "Gold (XAUUSD) Daily Bias Analysis in json format. Current price=%.2f. Daily candles history: %s. "+
      "As a professional macro analyst, determine today's directional bias. "+
      "Respond strictly with a json object containing: 'bias' ('BUY_ONLY', 'SELL_ONLY', or 'BI_DIRECTIONAL') and 'reason' (short 10 words). "+
      "Example output format: { \"bias\": \"BUY_ONLY\", \"reason\": \"Strong daily bullish engulfing\" }.",
      SymbolInfoDouble(_Symbol, SYMBOL_BID), dailyHistory
   );
   
   string responseText = "";
   if(!CallAI(prompt, responseText))
   {
      g_dailySentiment = "BI_DIRECTIONAL";
      g_dailySentimentReason = "AI offline, trading both sides.";
      return false;
   }
   
   string rawBias = ExtractJSONValue(responseText, "bias");
   string rawReason = ExtractJSONValue(responseText, "reason");
   
   if(StringFind(rawBias, "BUY_ONLY") >= 0) g_dailySentiment = "BUY_ONLY";
   else if(StringFind(rawBias, "SELL_ONLY") >= 0) g_dailySentiment = "SELL_ONLY";
   else g_dailySentiment = "BI_DIRECTIONAL";
   
   g_dailySentimentReason = (rawReason != "") ? rawReason : "Daily bias analyzed.";
   Print("[AI Bias] Daily Sentiment set to: ", g_dailySentiment, " (Reason: ", g_dailySentimentReason, ")");
   return true;
}

//+------------------------------------------------------------------+
//| Function to manage active positions (BE, Trailing, Time-Decay)   |
//+------------------------------------------------------------------+
void ManageActivePositions()
{
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
          {
             string posComment = PositionGetString(POSITION_COMMENT);
             bool isSwingPosition = (posComment == "GE_SWING");
             ulong ticket = PositionGetInteger(POSITION_TICKET);
             ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentSL = PositionGetDouble(POSITION_SL);
            double currentTP = PositionGetDouble(POSITION_TP);
            double currentVolume = PositionGetDouble(POSITION_VOLUME);
            datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
             
             // --- Boundary Guard Exit (Exit immediately on opposite GNN/Magnet line touch) ---
             double nearestHighs[];
             double nearestLows[];
             string dummy = "";
             GetUntestedMagnets(nearestHighs, nearestLows, dummy);
             
            // --- Live Stop Loss Safety Adjuster (Failsafe Guard Rail) ---
            if(type == POSITION_TYPE_BUY)
            {
               double nearestSupport = 0.0;
               for(int j = 0; j < ArraySize(nearestLows); j++)
               {
                  if(nearestLows[j] > 0.0 && nearestLows[j] < currentBid)
                  {
                     if(j + 1 < ArraySize(nearestLows) && nearestLows[j+1] > 0.0 && (nearestLows[j] - nearestLows[j+1] <= 8.0))
                     {
                        nearestSupport = nearestLows[j+1];
                     }
                     else
                     {
                        nearestSupport = nearestLows[j];
                     }
                     break;
                  }
               }
               
               if(nearestSupport > 0.0)
               {
                  double safeSL = NormalizeDouble(nearestSupport - 4.0, _Digits);
                  if(currentSL == 0.0 || (currentSL > safeSL && currentBid - safeSL >= stopsLevel))
                  {
                     PrintFormat("[SL Safety Adjuster] Modifying BUY trade #%I64u SL from %.2f to safe level %.2f (4.0 USD below support %.2f) to protect it from liquidity sweeps.", 
                        ticket, currentSL, safeSL, nearestSupport);
                     if(trade.PositionModify(ticket, safeSL, currentTP))
                     {
                        currentSL = safeSL;
                      }
                  }
               }
            }
            else if(type == POSITION_TYPE_SELL)
            {
               double nearestResistance = 0.0;
               for(int j = 0; j < ArraySize(nearestHighs); j++)
               {
                  if(nearestHighs[j] > 0.0 && nearestHighs[j] > currentAsk)
                  {
                     if(j + 1 < ArraySize(nearestHighs) && nearestHighs[j+1] > 0.0 && (nearestHighs[j+1] - nearestHighs[j] <= 8.0))
                     {
                        nearestResistance = nearestHighs[j+1];
                     }
                     else
                     {
                        nearestResistance = nearestHighs[j];
                     }
                     break;
                  }
               }
               
               if(nearestResistance > 0.0)
               {
                  double safeSL = NormalizeDouble(nearestResistance + 4.0, _Digits);
                  if(currentSL == 0.0 || (currentSL < safeSL && safeSL - currentAsk >= stopsLevel))
                  {
                     PrintFormat("[SL Safety Adjuster] Modifying SELL trade #%I64u SL from %.2f to safe level %.2f (4.0 USD above resistance %.2f) to protect it from liquidity sweeps.", 
                        ticket, currentSL, safeSL, nearestResistance);
                     if(trade.PositionModify(ticket, safeSL, currentTP))
                     {
                        currentSL = safeSL;
                     }
                  }
               }
            }
             double goldCeiling = (ArraySize(nearestHighs) > 0) ? nearestHighs[0] : 0.0;
             double aquaFloor = (ArraySize(nearestLows) > 0) ? nearestLows[0] : 0.0;
             
             bool isRecoveryTrade = (posComment == "RECOVERY_ENTRY" || posComment == "HEDGE_FREEZE");
            bool isScalpTrade = (StringFind(posComment, "Scalp") >= 0);
            if(isScalpTrade)
            {
               if(type == POSITION_TYPE_BUY && goldCeiling > 0.0 && currentBid >= goldCeiling)
               {
                  PrintFormat("[Boundary Guard Exit] Closing BUY trade #%I64u at %.2f. Hit Golden Line Ceiling: %.2f", ticket, currentBid, goldCeiling);
                  trade.PositionClose(ticket);
                  continue;
               }
               else if(type == POSITION_TYPE_SELL && aquaFloor > 0.0 && currentAsk <= aquaFloor)
               {
                  PrintFormat("[Boundary Guard Exit] Closing SELL trade #%I64u at %.2f. Hit Aqua Line Floor: %.2f", ticket, currentAsk, aquaFloor);
                  trade.PositionClose(ticket);
                  continue;
               }
            }

            
            if(g_enableTimeDecay && !isSwingPosition)
            {
               int durationSec = (int)(TimeCurrent() - openTime);
               if(durationSec >= g_maxHoldMinutes * 60)
               {
                  trade.PositionClose(ticket);
                  continue; 
               }
            }
            
            double mult = isSwingPosition ? 2.5 : 1.0;
            double actBETrigger     = g_beTrigger * mult;
            double actBEOffset      = g_beOffset * mult;
            double actStage1Trigger = g_stage1Trigger * mult;
            double actStage1Dist    = g_stage1Distance * mult;
            double actStage2Trigger = g_stage2Trigger * mult;
            double actStage2Dist    = g_stage2Distance * mult;
            
            if(type == POSITION_TYPE_BUY)
            {
               double currentProfit = currentBid - entryPrice;
               double targetSL = 0.0;
               
               if(g_enableStage2 && currentProfit >= actStage2Trigger)
               {
                  targetSL = NormalizeDouble(currentBid - actStage2Dist, _Digits);
               }
               else if(g_enableStage1 && currentProfit >= actStage1Trigger)
               {
                  targetSL = NormalizeDouble(currentBid - actStage1Dist, _Digits);
               }
               else if(g_enableBE && currentProfit >= actBETrigger)
               {
                  if(InpEnablePartialClose && currentVolume >= g_lotSize)
                  {
                     double closeLots = NormalizeDouble(g_lotSize / 2.0, 2);
                     if(closeLots > 0.0)
                     {
                        trade.PositionClosePartial(ticket, closeLots);
                      }
                   }
                   targetSL = NormalizeDouble(entryPrice + actBEOffset, _Digits);
                }
                
                if(targetSL > 0.0 && (targetSL > currentSL || currentSL == 0.0))
                {
                   if(currentBid - targetSL >= stopsLevel)
                   {
                      trade.PositionModify(ticket, targetSL, currentTP);
                   }
                }
             }
             else if(type == POSITION_TYPE_SELL)
             {
                double currentProfit = entryPrice - currentAsk;
                double targetSL = 0.0;
                
                if(g_enableStage2 && currentProfit >= actStage2Trigger)
                {
                   targetSL = NormalizeDouble(currentAsk + actStage2Dist, _Digits);
                }
                else if(g_enableStage1 && currentProfit >= actStage1Trigger)
                {
                   targetSL = NormalizeDouble(currentAsk + actStage1Dist, _Digits);
                }
                else if(g_enableBE && currentProfit >= actBETrigger)
                {
                   if(InpEnablePartialClose && currentVolume >= g_lotSize)
                   {
                      double closeLots = NormalizeDouble(g_lotSize / 2.0, 2);
                      if(closeLots > 0.0)
                      {
                         trade.PositionClosePartial(ticket, closeLots);
                      }
                   }
                   targetSL = NormalizeDouble(entryPrice - actBEOffset, _Digits);
                }
                
                if(targetSL > 0.0 && (targetSL < currentSL || currentSL == 0.0))
                {
                   if(targetSL - currentAsk >= stopsLevel)
                   {
                      trade.PositionModify(ticket, targetSL, currentTP);
                   }
                }
             }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Query AI for Active Trade Management (Dynamic Trailing Stop)     |
//+------------------------------------------------------------------+
void QueryAIActiveTradeManagement()
{
   if(g_hedgeActive) return;
   double stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         ulong ticket = PositionGetInteger(POSITION_TICKET);
         ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentSL = PositionGetDouble(POSITION_SL);
         double currentTP = PositionGetDouble(POSITION_TP);
         double currentPrice = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double currentProfit = (type == POSITION_TYPE_BUY) ? (currentPrice - entryPrice) : (entryPrice - currentPrice);
         
         // Gather recent 3 bars history for trend context
         string barsHistory = "";
         for(int j = 3; j >= 1; j--)
         {
            barsHistory += StringFormat("[Bar %d: O=%.2f, H=%.2f, L=%.2f, C=%.2f] ", 
               j, iOpen(_Symbol, _Period, j), iHigh(_Symbol, _Period, j), iLow(_Symbol, _Period, j), iClose(_Symbol, _Period, j));
         }
         
         string comment = PositionGetString(POSITION_COMMENT);
         string prompt = StringFormat(
            "Gold (XAUUSD) active position management review. TradeType/Strategy=%s, Type=%s, EntryPrice=%.2f, CurrentPrice=%.2f, CurrentSL=%.2f, CurrentProfit=%.2f. "+
            "Recent 3 closed candles: %s. "+
            "Instructions: "+
            "1. If TradeType/Strategy is 'GE_SWING' (Long-Term Swing trade), you must be highly patient. Do NOT close early or tighten SL for minor pullbacks. Let it breathe through temporary retracements of 3-5 USD in value as long as the macro H1/Daily structure is intact. Only close or tighten if opposite trend structure is confirmed. "+
            "2. If TradeType is 'SCALPING', trail SL closely to lock in small gains quickly. "+
            "3. If TradeType is 'BREAKOUT' or 'MOMENTUM', trail SL tightly behind momentum bars. "+
            "Evaluate position exit/trail. Respond strictly with a JSON object containing: 'action' ('HOLD', 'TIGHTEN', 'WIDEN', or 'CLOSE'), 'stop_distance' (double dollar offset from current price, e.g. 1.50), and 'reason' (short 10 words). "+
            "Example format: { 'action': 'TIGHTEN', 'stop_distance': 0.60, 'reason': 'Bearish trend forming close' }.",
            comment, (type == POSITION_TYPE_BUY ? "BUY" : "SELL"), entryPrice, currentPrice, currentSL, currentProfit, barsHistory
         );
         
         string responseText = "";
         if(CallAI(prompt, responseText))
         {
            string rawAction = ExtractJSONValue(responseText, "action");
            double stopDistance = StringToDouble(ExtractJSONValue(responseText, "stop_distance"));
            string rawReason = ExtractJSONValue(responseText, "reason");
            
            if(rawReason != "") g_aiReason = "Trade Mgmt: " + rawReason;
            
            if(rawAction == "CLOSE")
            {
               Print(StringFormat("[AI Dynamic Exit] Closing trade #%I64u. Reason: %s", ticket, rawReason));
               trade.PositionClose(ticket);
               continue;
            }
            else if((rawAction == "TIGHTEN" || rawAction == "WIDEN") && stopDistance > 0.0)
            {
               double targetSL = 0.0;
               if(type == POSITION_TYPE_BUY)
               {
                  targetSL = NormalizeDouble(currentPrice - stopDistance, _Digits);
                  // Ensure we only move SL in profit direction (trailing stop rules)
                  if(targetSL > currentSL || currentSL == 0.0)
                  {
                     if(currentPrice - targetSL >= stopsLevel)
                     {
                        trade.PositionModify(ticket, targetSL, currentTP);
                        Print(StringFormat("[AI Dynamic SL] Modified BUY #%I64u SL to %.2f (offset %.2f). Reason: %s", ticket, targetSL, stopDistance, rawReason));
                     }
                  }
               }
               else if(type == POSITION_TYPE_SELL)
               {
                  targetSL = NormalizeDouble(currentPrice + stopDistance, _Digits);
                  // Ensure we only move SL in profit direction (trailing stop rules)
                  if(targetSL < currentSL || currentSL == 0.0)
                  {
                     if(targetSL - currentPrice >= stopsLevel)
                     {
                        trade.PositionModify(ticket, targetSL, currentTP);
                        Print(StringFormat("[AI Dynamic SL] Modified SELL #%I64u SL to %.2f (offset %.2f). Reason: %s", ticket, targetSL, stopDistance, rawReason));
                     }
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Extract recent closed trades history under this magic number     |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Get the current active trading session based on broker hour      |
//+------------------------------------------------------------------+
string GetActiveSession()
{
   datetime serverTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(serverTime, dt);
   int hour = dt.hour;
   
   string sessions = "";
   if(hour >= 3 && hour < 12) sessions += "Asian (Tokyo/Sydney)";
   if(hour >= 10 && hour < 19) {
      if(sessions != "") sessions += " overlapping with ";
      sessions += "London";
   }
   if(hour >= 15 || hour < 0) {
      if(sessions != "") sessions += " overlapping with ";
      sessions += "New York";
   }
   if(sessions == "") sessions = "Late US / Pre-Asia quiet hours";
   return sessions;
}

void GetRecentTradesHistory(string &historyStr)
{
   historyStr = "";
   if(!HistorySelect(TimeCurrent() - 7 * 86400, TimeCurrent()))
   {
      historyStr = "No trade history available yet.";
      return;
   }
   
   int totalDeals = HistoryDealsTotal();
   int count = 0;
   int wins = 0;
   int losses = 0;
   double totalWinAmt = 0.0;
   double totalLossAmt = 0.0;
   int consecutiveWins = 0;
   int consecutiveLosses = 0;
   bool streakActive = true;
   
   for(int i = totalDeals - 1; i >= 0 && count < 5; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0)
      {
         string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
         long magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
         long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
         
         if(symbol == _Symbol && magic == InpMagicNumber && (entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY))
         {
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) + HistoryDealGetDouble(ticket, DEAL_COMMISSION) + HistoryDealGetDouble(ticket, DEAL_SWAP);
            if(profit > 0.0)
            {
               wins++;
               totalWinAmt += profit;
               if(streakActive)
               {
                  if(consecutiveLosses > 0) streakActive = false;
                  else consecutiveWins++;
               }
            }
            else if(profit < 0.0)
            {
               losses++;
               totalLossAmt += profit;
               if(streakActive)
               {
                  if(consecutiveWins > 0) streakActive = false;
                  else consecutiveLosses++;
               }
            }
            count++;
         }
      }
   }
   
   double winRate = (count > 0) ? ((double)wins / (double)count * 100.0) : 0.0;
   double avgWin = (wins > 0) ? (totalWinAmt / wins) : 0.0;
   double avgLoss = (losses > 0) ? (totalLossAmt / losses) : 0.0;
   string streakStr = "None";
   if(consecutiveWins > 0) streakStr = StringFormat("%d Wins", consecutiveWins);
   else if(consecutiveLosses > 0) streakStr = StringFormat("%d Losses", consecutiveLosses);
   
   historyStr += StringFormat("[Performance Stats (Last 5 Trades): Win Rate=%.1f%%, Avg Win=%.2f$, Avg Loss=%.2f$, Current Streak=%s] ", 
      winRate, avgWin, avgLoss, streakStr);
      
   count = 0;
   for(int i = totalDeals - 1; i >= 0 && count < 3; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0)
      {
         string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
         long magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
         long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
         
         if(symbol == _Symbol && magic == InpMagicNumber && (entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY))
         {
            long type = HistoryDealGetInteger(ticket, DEAL_TYPE);
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) + HistoryDealGetDouble(ticket, DEAL_COMMISSION) + HistoryDealGetDouble(ticket, DEAL_SWAP);
            double price = HistoryDealGetDouble(ticket, DEAL_PRICE);
            
            double entryPrice = 0.0;
            long entryType = -1;
            ulong positionId = HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
            
            for(int j = 0; j < totalDeals; j++)
            {
               ulong tEntry = HistoryDealGetTicket(j);
               if(HistoryDealGetInteger(tEntry, DEAL_POSITION_ID) == positionId && 
                  (HistoryDealGetInteger(tEntry, DEAL_ENTRY) == DEAL_ENTRY_IN))
               {
                  entryPrice = HistoryDealGetDouble(tEntry, DEAL_PRICE);
                  entryType = HistoryDealGetInteger(tEntry, DEAL_TYPE);
                  break;
               }
            }
            
            string typeStr = (entryType == DEAL_TYPE_BUY) ? "BUY" : "SELL";
            string comment = HistoryDealGetString(ticket, DEAL_COMMENT);
            
            string savedStrategy = "N/A";
            string savedReasoning = "N/A";
            string fileName = StringFormat("GoldEngine_Reasoning_%I64u.txt", positionId);
            string pendingFileName = StringFormat("GoldEngine_Reasoning_Order_%I64u.txt", positionId);
            
            string fileToRead = "";
            if(FileIsExist(fileName)) fileToRead = fileName;
            else if(FileIsExist(pendingFileName)) fileToRead = pendingFileName;
            
            if(fileToRead != "")
            {
               int fileHandle = FileOpen(fileToRead, FILE_READ|FILE_TXT|FILE_ANSI);
               if(fileHandle != INVALID_HANDLE)
               {
                  string savedContent = FileReadString(fileHandle);
                  FileClose(fileHandle);
                  
                  int pipeIdx = StringFind(savedContent, "|");
                  if(pipeIdx >= 0)
                  {
                     savedStrategy = StringSubstr(savedContent, 0, pipeIdx);
                     savedReasoning = StringSubstr(savedContent, pipeIdx + 1);
                  }
               }
            }
            
            historyStr += StringFormat("[Trade %d: %s entry %.2f, exit %.2f, profit=%.2f$, strategy=%s, reasoning='%s', comment='%s'] ", 
               count + 1, typeStr, entryPrice, price, profit, savedStrategy, savedReasoning, comment);
            count++;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Fetch ForexFactory Economic Calendar and parse USD news          |
//+------------------------------------------------------------------+
string GetXMLNodeValue(string xml, string tag)
{
   string startTag = "<" + tag + ">";
   string endTag = "</" + tag + ">";
   
   int startIdx = StringFind(xml, startTag);
   if(startIdx < 0) return "";
   
   int endIdx = StringFind(xml, endTag, startIdx);
   if(endIdx < 0) return "";
   
   int valStart = startIdx + StringLen(startTag);
   return StringSubstr(xml, valStart, endIdx - valStart);
}

void FetchEconomicCalendar()
{
   // Check terminal global variable to see when the last successful fetch occurred
   datetime lastFetch = 0;
   if(GlobalVariableCheck("GoldEngine_LastCalendarFetch"))
   {
      lastFetch = (datetime)GlobalVariableGet("GoldEngine_LastCalendarFetch");
   }
   
   // If last fetch was less than 6 hours ago, read the cached news string from file
   if(lastFetch > 0 && TimeCurrent() - lastFetch < 21600)
   {
      int fileHandle = FileOpen("GoldEngine_Calendar.txt", FILE_READ|FILE_TXT|FILE_ANSI);
      if(fileHandle != INVALID_HANDLE)
      {
         g_upcomingNews = FileReadString(fileHandle);
         FileClose(fileHandle);
         g_lastCalendarFetchTime = lastFetch;
         if(g_upcomingNews != "" && g_upcomingNews != "None")
         {
            Print("[Calendar Cache] Loaded from file: ", g_upcomingNews);
            return;
         }
      }
   }
   
   // If we got rate-limited recently (429 status code), back off for 1 hour to cool down
   datetime lastFail = 0;
   if(GlobalVariableCheck("GoldEngine_LastCalendarFail"))
   {
      lastFail = (datetime)GlobalVariableGet("GoldEngine_LastCalendarFail");
   }
   if(lastFail > 0 && TimeCurrent() - lastFail < 3600)
   {
      // Load fallback cache if available
      int fileHandle = FileOpen("GoldEngine_Calendar.txt", FILE_READ|FILE_TXT|FILE_ANSI);
      if(fileHandle != INVALID_HANDLE)
      {
         g_upcomingNews = FileReadString(fileHandle);
         FileClose(fileHandle);
      }
      if(g_upcomingNews == "") g_upcomingNews = "None";
      Print("[Calendar Cooldown] Backing off after rate limit. Fallback: ", g_upcomingNews);
      return;
   }
   
   string url = "https://nfs.faireconomy.media/ff_calendar_thisweek.xml";
   string headers = "";
   uchar post[];
   uchar result[];
   string responseHeaders = "";
   
   ResetLastError();
   int res = WebRequest("GET", url, headers, 5000, post, result, responseHeaders);
   if(res != 200)
   {
      Print("[Calendar Fail] HTTP Status: ", res, ", Error code: ", GetLastError());
      
      // Store fail timestamp to back off
      GlobalVariableSet("GoldEngine_LastCalendarFail", (double)TimeCurrent());
      
      // Load fallback cache so the EA continues to work
      int fileHandle = FileOpen("GoldEngine_Calendar.txt", FILE_READ|FILE_TXT|FILE_ANSI);
      if(fileHandle != INVALID_HANDLE)
      {
         g_upcomingNews = FileReadString(fileHandle);
         FileClose(fileHandle);
      }
      if(g_upcomingNews == "") g_upcomingNews = "None";
      return;
   }
   
   string xml = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   
   // Get today's date formatted as mm-dd-yyyy (matches ForexFactory XML date format)
   MqlDateTime dt;
   TimeCurrent(dt);
   string todayStr = StringFormat("%02d-%02d-%04d", dt.mon, dt.day, dt.year);
   
   g_upcomingNews = "";
   int pos = 0;
   
   while(true)
   {
      int startEvent = StringFind(xml, "<event>", pos);
      if(startEvent < 0) break;
      int endEvent = StringFind(xml, "</event>", startEvent);
      if(endEvent < 0) break;
      
      string eventXml = StringSubstr(xml, startEvent, endEvent - startEvent);
      pos = endEvent + 8;
      
      // Parse fields
      string title = GetXMLNodeValue(eventXml, "title");
      string country = GetXMLNodeValue(eventXml, "country");
      string date = GetXMLNodeValue(eventXml, "date");
      string time = GetXMLNodeValue(eventXml, "time");
      string impact = GetXMLNodeValue(eventXml, "impact");
      string forecast = GetXMLNodeValue(eventXml, "forecast");
      string previous = GetXMLNodeValue(eventXml, "previous");
      
      // Filter: USD High/Medium impact events for today
      if(country == "USD" && (impact == "High" || impact == "Medium") && date == todayStr)
      {
         if(g_upcomingNews != "") g_upcomingNews += ", ";
         g_upcomingNews += StringFormat("%s at %s (Forecast: %s, Previous: %s)", title, time, forecast, previous);
      }
   }
   
   if(g_upcomingNews == "")
   {
      g_upcomingNews = "None";
   }
   
   // Cache successful result to file and update terminal global variable
   GlobalVariableSet("GoldEngine_LastCalendarFetch", (double)TimeCurrent());
   int fileHandle = FileOpen("GoldEngine_Calendar.txt", FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(fileHandle != INVALID_HANDLE)
   {
      FileWriteString(fileHandle, g_upcomingNews);
      FileClose(fileHandle);
   }
   
   Print("[Calendar Success] USD Today's News: ", g_upcomingNews);
}

//+------------------------------------------------------------------+
//| Get Volume SMA and anchor-free Daily VWAP calculation           |
//+------------------------------------------------------------------+
double GetVolumeSMA(int period)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, _Period, 1, period, rates) > 0)
   {
      double sum = 0.0;
      for(int i = 0; i < period; i++)
      {
         double vol = (double)rates[i].tick_volume;
         if(rates[i].real_volume > 0) vol = (double)rates[i].real_volume;
         sum += vol;
      }
      return sum / period;
   }
   return 0.0;
}

double GetDailyVWAP()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   datetime todayStart = TimeCurrent() - (dt.hour * 3600 + dt.min * 60 + dt.sec);
   
   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   int copied = CopyRates(_Symbol, _Period, todayStart, TimeCurrent(), rates);
   if(copied <= 0) return 0.0;
   
   double sumPV = 0.0;
   double sumV = 0.0;
   for(int i = 0; i < copied; i++)
   {
      double typicalPrice = (rates[i].high + rates[i].low + rates[i].close) / 3.0;
      double vol = (double)rates[i].tick_volume;
      if(rates[i].real_volume > 0) vol = (double)rates[i].real_volume;
      
      sumPV += typicalPrice * vol;
      sumV += vol;
   }
   
   if(sumV > 0.0) return sumPV / sumV;
   return 0.0;
}

//+------------------------------------------------------------------+
//| Get Untested Swing High/Low Magnets and Draw them on chart       |
//+------------------------------------------------------------------+
void GetUntestedMagnets(double &nearestHighs[], double &nearestLows[], string &outputStr)
{
   ArrayResize(nearestHighs, 0);
   ArrayResize(nearestLows, 0);
   outputStr = "";
   
   int lookback = 150;
   double highs[];
   double lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   
   if(CopyHigh(_Symbol, _Period, 1, lookback, highs) <= 0 ||
      CopyLow(_Symbol, _Period, 1, lookback, lows) <= 0)
   {
      outputStr = "Failed to copy high/low series.";
      return;
   }
   
   double currentPrice = iClose(_Symbol, _Period, 1);
   
   double rawHighs[];
   int rawHighAges[];
   double rawLows[];
   int rawLowAges[];
   
   ArrayResize(rawHighs, 0);
   ArrayResize(rawHighAges, 0);
   ArrayResize(rawLows, 0);
   ArrayResize(rawLowAges, 0);
   
   // Find swing highs/lows
   for(int i = 2; i < lookback - 2; i++)
   {
      if(highs[i] > highs[i-1] && highs[i] > highs[i-2] &&
         highs[i] > highs[i+1] && highs[i] > highs[i+2])
      {
         bool tested = false;
         for(int k = 1; k < i; k++)
         {
            if(highs[k] > highs[i]) { tested = true; break; }
         }
         if(!tested && highs[i] > currentPrice)
         {
            int sz = ArraySize(rawHighs);
            ArrayResize(rawHighs, sz + 1);
            ArrayResize(rawHighAges, sz + 1);
            rawHighs[sz] = highs[i];
            rawHighAges[sz] = i + 1;
         }
      }
      
      if(lows[i] < lows[i-1] && lows[i] < lows[i-2] &&
         lows[i] < lows[i+1] && lows[i] < lows[i+2])
      {
         bool tested = false;
         for(int k = 1; k < i; k++)
         {
            if(lows[k] < lows[i]) { tested = true; break; }
         }
         if(!tested && lows[i] < currentPrice)
         {
            int sz = ArraySize(rawLows);
            ArrayResize(rawLows, sz + 1);
            ArrayResize(rawLowAges, sz + 1);
            rawLows[sz] = lows[i];
            rawLowAges[sz] = i + 1;
         }
      }
   }
   
   // Sort rawHighs ascending (bubble sort)
   int numHighs = ArraySize(rawHighs);
   for(int i = 0; i < numHighs - 1; i++)
   {
      for(int j = i + 1; j < numHighs; j++)
      {
         if(rawHighs[i] > rawHighs[j])
         {
            double tempP = rawHighs[i]; rawHighs[i] = rawHighs[j]; rawHighs[j] = tempP;
            int tempA = rawHighAges[i]; rawHighAges[i] = rawHighAges[j]; rawHighAges[j] = tempA;
         }
      }
   }
   
   // Sort rawLows descending
   int numLows = ArraySize(rawLows);
   for(int i = 0; i < numLows - 1; i++)
   {
      for(int j = i + 1; j < numLows; j++)
      {
         if(rawLows[i] < rawLows[j])
         {
            double tempP = rawLows[i]; rawLows[i] = rawLows[j]; rawLows[j] = tempP;
            int tempA = rawLowAges[i]; rawLowAges[i] = rawLowAges[j]; rawLowAges[j] = tempA;
         }
      }
   }
   
   // Copy top 3
   int limitHigh = MathMin(3, numHighs);
   ArrayResize(nearestHighs, limitHigh);
   string highsDesc = "";
   for(int i = 0; i < limitHigh; i++)
   {
      nearestHighs[i] = rawHighs[i];
      highsDesc += StringFormat("[Price=%.2f, Age=%d bars, Dist=%.2f] ", rawHighs[i], rawHighAges[i], rawHighs[i] - currentPrice);
   }
   
   int limitLow = MathMin(3, numLows);
   ArrayResize(nearestLows, limitLow);
   string lowsDesc = "";
   for(int i = 0; i < limitLow; i++)
   {
      nearestLows[i] = rawLows[i];
      lowsDesc += StringFormat("[Price=%.2f, Age=%d bars, Dist=%.2f] ", rawLows[i], rawLowAges[i], currentPrice - rawLows[i]);
   }
   
   if(highsDesc == "") highsDesc = "None";
   if(lowsDesc == "") lowsDesc = "None";
   
   outputStr = "Untested Swing High Price Magnets: " + highsDesc + ". Untested Swing Low Price Magnets: " + lowsDesc;
}

void DrawMagnetLine(string name, double price, color clr)
{
   if(price <= 0.0)
   {
      ObjectDelete(0, name);
      return;
   }
   
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }
   else
   {
      ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   }
}

//+------------------------------------------------------------------+
//| Donchian Channel High/Low and dynamic Stop Loss calculation     |
//+------------------------------------------------------------------+
double GetChannelHigh(int length)
{
   int highest_index = iHighest(_Symbol, _Period, MODE_HIGH, length, 2);
   return iHigh(_Symbol, _Period, highest_index);
}

double GetChannelLow(int length)
{
   int lowest_index = iLowest(_Symbol, _Period, MODE_LOW, length, 2);
   return iLow(_Symbol, _Period, lowest_index);
}

double GetStopLossDistance(string sym, double price, double atr)
{
   double lo = 0.0;
   double hi = 0.0;

   if(sym == "BTCUSD" || sym == "BTCUSDT") 
   {
      lo = 100.0;
      hi = 800.0;
   }
   else if(sym == "ETHUSD" || sym == "ETHUSDT") 
   {
      lo = 5.0;
      hi = 40.0;
   }
   else 
   {
      // Fallback percentage based bands
      lo = price * InpMinSLPct / 100.0;
      hi = price * InpMaxSLPct / 100.0;
   }

   // Clamp the base SL between lo and hi
   double base_sl = InpDonchianATRMult * atr;
   if(base_sl < lo) base_sl = lo;
   if(base_sl > hi) base_sl = hi;

   // Apply noise floor (1.5x ATR)
   double noise_floor = 1.5 * atr;
   return MathMax(base_sl, noise_floor);
}

//+------------------------------------------------------------------+
//| Execute new order placement (Once per candle or on recovery)     |
//+------------------------------------------------------------------+
bool ExecuteNewOrderPlacement(datetime currentBarTime, bool isMidCandle = false)
{
   if(g_hedgeActive) return false;
   double prevHigh = iHigh(_Symbol, _Period, 1);
   double prevLow  = iLow(_Symbol, _Period, 1);
   double prevClose = iClose(_Symbol, _Period, 1);

   if(prevHigh == 0 || prevLow == 0)
      return false;

   double emaVal[];
   double atrVal[];
   double rsiVal[];
   double adxVal[];
   ArraySetAsSeries(emaVal, true);
   ArraySetAsSeries(atrVal, true);
   ArraySetAsSeries(rsiVal, true);
   ArraySetAsSeries(adxVal, true);
   
   if(CopyBuffer(g_emaHandle, 0, 1, 1, emaVal) <= 0 || 
      CopyBuffer(g_atrHandle, 0, 1, 1, atrVal) <= 0 ||
      CopyBuffer(g_rsiHandle, 0, 1, 1, rsiVal) <= 0 ||
      CopyBuffer(g_adxHandle, 0, 1, 1, adxVal) <= 0)
   {
      return false;
   }
   
   double currentEMA = emaVal[0];
   double currentATR = atrVal[0];
   double currentRSI = rsiVal[0];
   double currentADX = adxVal[0];

   double atrSum = 0.0;
   int atrCount = 0;
   for(int j = 2; j <= 11; j++)
   {
      double atrTemp[];
      ArraySetAsSeries(atrTemp, true);
      if(CopyBuffer(g_atrHandle, 0, j, 1, atrTemp) > 0)
      {
         atrSum += atrTemp[0];
         atrCount++;
      }
   }
   double avgATR = (atrCount > 0) ? (atrSum / atrCount) : currentATR;
   bool isVolatilitySpike = (avgATR > 0.0 && currentATR > 1.4 * avgATR);

   double spread = GetSmoothedSpread();

   MqlDateTime dt;
   TimeCurrent(dt);
   bool isMomentumHour = false;
   if(dt.hour >= InpLondonStartHour && dt.hour < InpLondonEndHour)
   {
      isMomentumHour = true;
   }
   int currentMinutesSinceMidnight = dt.hour * 60 + dt.min;
   int nyStartMinutes = InpNYStartHour * 60 + InpNYStartMin;
   int nyEndMinutes = InpNYEndHour * 60 + InpNYEndMin;
   if(currentMinutesSinceMidnight >= nyStartMinutes && currentMinutesSinceMidnight < nyEndMinutes)
   {
      isMomentumHour = true;
   }

   double ema200Val[];
   ArraySetAsSeries(ema200Val, true);
   double currentEMA200 = 0.0;
   if(CopyBuffer(g_ema200Handle, 0, 1, 1, ema200Val) > 0)
   {
      currentEMA200 = ema200Val[0];
   }
   
   double ema9Val[];
   ArraySetAsSeries(ema9Val, true);
   double currentEMA9 = 0.0;
   if(CopyBuffer(g_ema9Handle, 0, 1, 1, ema9Val) > 0)
   {
      currentEMA9 = ema9Val[0];
   }
   
   double currentVWAP = GetDailyVWAP();
   double volSMA10    = GetVolumeSMA(10);
   double volSMA20    = GetVolumeSMA(20);

   // --- Query the AI Conviction Engine ---
   string barsHistory = "";
   for(int i = 10; i >= 1; i--)
   {
      barsHistory += StringFormat("[Bar %d: O=%.2f, H=%.2f, L=%.2f, C=%.2f, V=%I64d] ", 
         i, iOpen(_Symbol, _Period, i), iHigh(_Symbol, _Period, i), iLow(_Symbol, _Period, i), iClose(_Symbol, _Period, i), iVolume(_Symbol, _Period, i));
   }
   
   // Macro timeframe history for trend alignment
   string macroHistory = "";
   ENUM_TIMEFRAMES HTF = GetHigherTimeframe();
   string htfName = (HTF == PERIOD_M15) ? "M15" : ((HTF == PERIOD_H1) ? "H1" : "H4");
   for(int i = 5; i >= 1; i--)
   {
      macroHistory += StringFormat("[%s Bar %d: O=%.2f, H=%.2f, L=%.2f, C=%.2f] ", 
         htfName, i, iOpen(_Symbol, HTF, i), iHigh(_Symbol, HTF, i), iLow(_Symbol, HTF, i), iClose(_Symbol, HTF, i));
   }
   
   // Explicit trend description
   string trendDesc = "Neutral/Rangebound (Price is oscillating)";
   if(prevClose > currentEMA200 && prevClose > currentVWAP)
      trendDesc = "Strong Bullish Trend (Price is above EMA200 and VWAP)";
   else if(prevClose < currentEMA200 && prevClose < currentVWAP)
      trendDesc = "Strong Bearish Trend (Price is below EMA200 and VWAP)";
   
   string candlePatterns = StringFormat("Bar 1: %s, Bar 2: %s, Bar 3: %s", GetCandlePattern(1), GetCandlePattern(2), GetCandlePattern(3));

   string tradeHistory = "";
   GetRecentTradesHistory(tradeHistory);
   
   g_aiStrategy = "NONE";
   
   double fvgLow = 0.0, fvgHigh = 0.0;
   int fvgType = 0;
   GetLatestUnmitigatedFVG(fvgLow, fvgHigh, fvgType);
   
   double bullOB_Low = 0.0, bullOB_High = 0.0;
   double bearOB_Low = 0.0, bearOB_High = 0.0;
   GetNearestOrderBlocks(bullOB_Low, bullOB_High, bearOB_Low, bearOB_High);
   
   string ictDesc = "";
   if(fvgType == 1) ictDesc += StringFormat("Latest unmitigated Bullish FVG (imbalance vacuum) at %.2f-%.2f. ", fvgLow, fvgHigh);
   else if(fvgType == -1) ictDesc += StringFormat("Latest unmitigated Bearish FVG (imbalance vacuum) at %.2f-%.2f. ", fvgLow, fvgHigh);
   else ictDesc += "No active FVG gaps. ";
   
   if(bullOB_Low > 0.0) ictDesc += StringFormat("Nearest Bullish Order Block (Bank Demand Wall) at %.2f-%.2f. ", bullOB_Low, bullOB_High);
   if(bearOB_Low > 0.0) ictDesc += StringFormat("Nearest Bearish Order Block (Bank Supply Wall) at %.2f-%.2f. ", bearOB_Low, bearOB_High);
    
   string magnetDesc = "";
   double nearestHighs[];
   double nearestLows[];
   GetUntestedMagnets(nearestHighs, nearestLows, magnetDesc);

   string activeSession = GetActiveSession();
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);

   double nHighs[];
   double nLows[];
   string mDesc = "";
   GetUntestedMagnets(nHighs, nLows, mDesc);
   double goldCeiling = (ArraySize(nHighs) > 0) ? nHighs[0] : 0.0;
   double aquaFloor = (ArraySize(nLows) > 0) ? nLows[0] : 0.0;
   
   double distanceToCeiling = (goldCeiling > 0.0) ? (goldCeiling - prevClose) : -1.0;
   double distanceToFloor = (aquaFloor > 0.0) ? (prevClose - aquaFloor) : -1.0;
   
   string gnnDistanceDesc = "";
   if(distanceToCeiling >= 0.0) gnnDistanceDesc += StringFormat("Price is %.2f USD below Golden Ceiling (%.2f). ", distanceToCeiling, goldCeiling);
   else gnnDistanceDesc += "No active Golden Ceiling. ";
   if(distanceToFloor >= 0.0) gnnDistanceDesc += StringFormat("Price is %.2f USD above Aqua Floor (%.2f). ", distanceToFloor, aquaFloor);
   else gnnDistanceDesc += "No active Aqua Floor. ";
   
   string maSignal = (prevClose > currentEMA200) ? "ABOVE EMA200 (Macro Bullish)" : "BELOW EMA200 (Macro Bearish)";
   string vwapSignal = (prevClose > currentVWAP) ? "ABOVE VWAP (Intraday Bullish)" : "BELOW VWAP (Intraday Bearish)";
   string rsiSignal = "NEUTRAL";
   if(currentRSI < 30.0) rsiSignal = "OVERSOLD (Reversal Target)";
   else if(currentRSI > 70.0) rsiSignal = "OVERBOUGHT (Reversal Target)";
   
   string spreadSignal = (spread <= 0.40) ? "NORMAL (Low Spread)" : "WIDENED (High Spread Risk)";

   // --- Advanced Data Enrichment: Daily Range, MTF Confluence, and Countdown ---
   MqlRates dailyRates[];
   ArraySetAsSeries(dailyRates, true);
   double dailyHigh = 0.0;
   double dailyLow = 0.0;
   if(CopyRates(_Symbol, PERIOD_D1, 0, 1, dailyRates) > 0)
   {
      dailyHigh = dailyRates[0].high;
      dailyLow = dailyRates[0].low;
   }
   double dailyRange = dailyHigh - dailyLow;
   double dailyPct = (dailyRange > 0.0) ? (((prevClose - dailyLow) / dailyRange) * 100.0) : 0.0;
   string dailyRangeDesc = StringFormat("Daily High: %.2f, Daily Low: %.2f. Price is at %.1f%% of today's total range.", dailyHigh, dailyLow, dailyPct);

   double ema200H1Val[];
   double ema200H4Val[];
   ArraySetAsSeries(ema200H1Val, true);
   ArraySetAsSeries(ema200H4Val, true);
   double h1Ema = 0.0;
   double h4Ema = 0.0;
   if(CopyBuffer(g_ema200H1Handle, 0, 0, 1, ema200H1Val) > 0) h1Ema = ema200H1Val[0];
   if(CopyBuffer(g_ema200H4Handle, 0, 0, 1, ema200H4Val) > 0) h4Ema = ema200H4Val[0];
   string h1Trend = (h1Ema > 0.0) ? ((prevClose > h1Ema) ? "BULLISH" : "BEARISH") : "UNKNOWN";
   string h4Trend = (h4Ema > 0.0) ? ((prevClose > h4Ema) ? "BULLISH" : "BEARISH") : "UNKNOWN";
   string mtfConfluenceDesc = StringFormat("Confluence: H1 EMA200 is %s, H4 EMA200 is %s.", h1Trend, h4Trend);
   
   string macroTrendDesc = "Mixed/Consolidating";
   if(h1Trend == "BULLISH" && h4Trend == "BULLISH")
      macroTrendDesc = "Strong Bullish (Price is above H1 and H4 EMA200)";
   else if(h1Trend == "BEARISH" && h4Trend == "BEARISH")
      macroTrendDesc = "Strong Bearish (Price is below H1 and H4 EMA200)";
   else if(h1Trend == "BULLISH" && h4Trend == "BEARISH")
      macroTrendDesc = "Mixed (Bullish pullback on H1 inside H4 Bearish Macro Trend)";
   else if(h1Trend == "BEARISH" && h4Trend == "BULLISH")
      macroTrendDesc = "Mixed (Bearish pullback on H1 inside H4 Bullish Macro Trend)";

   // --- 1. Calculate Moving Average Slopes & Deviations (Momentum) ---
   double qEma9Val[];
   double qEma50Val[];
   double qEma200Val[];
   ArrayResize(qEma9Val, 2);
   ArrayResize(qEma50Val, 2);
   ArrayResize(qEma200Val, 2);
   ArraySetAsSeries(qEma9Val, true);
   ArraySetAsSeries(qEma50Val, true);
   ArraySetAsSeries(qEma200Val, true);
   
   double e9Cur = 0.0, e9Prev = 0.0, e50Cur = 0.0, e50Prev = 0.0, e200Cur = 0.0, e200Prev = 0.0;
   if(CopyBuffer(g_ema9Handle, 0, 1, 2, qEma9Val) > 0) { e9Cur = qEma9Val[0]; e9Prev = qEma9Val[1]; }
   if(CopyBuffer(g_emaHandle, 0, 1, 2, qEma50Val) > 0) { e50Cur = qEma50Val[0]; e50Prev = qEma50Val[1]; }
   if(CopyBuffer(g_ema200Handle, 0, 1, 2, qEma200Val) > 0) { e200Cur = qEma200Val[0]; e200Prev = qEma200Val[1]; }
   
   double e9Slope = (e9Cur > 0.0 && e9Prev > 0.0) ? (e9Cur - e9Prev) : 0.0;
   double e50Slope = (e50Cur > 0.0 && e50Prev > 0.0) ? (e50Cur - e50Prev) : 0.0;
   double e200Slope = (e200Cur > 0.0 && e200Prev > 0.0) ? (e200Cur - e200Prev) : 0.0;
   
   double e9Dev = (e9Cur > 0.0) ? (prevClose - e9Cur) : 0.0;
   double e50Dev = (e50Cur > 0.0) ? (prevClose - e50Cur) : 0.0;
   double e200Dev = (e200Cur > 0.0) ? (prevClose - e200Cur) : 0.0;

   // --- 2. Calculate Proximity to Key Levels (Boundary Distances) ---
   double tempCeiling = (ArraySize(nearestHighs) > 0) ? nearestHighs[0] : 0.0;
   double tempFloor = (ArraySize(nearestLows) > 0) ? nearestLows[0] : 0.0;
   
   double distToCeiling = (tempCeiling > 0.0) ? (tempCeiling - prevClose) : 999.9;
   double distToFloor = (tempFloor > 0.0) ? (prevClose - tempFloor) : 999.9;
   double distToBullOB = (bullOB_High > 0.0) ? (prevClose - bullOB_High) : 999.9;
   double distToBearOB = (bearOB_Low > 0.0) ? (bearOB_Low - prevClose) : 999.9;
   
   double distToFVG = 999.9;
   if(fvgType == 1 && fvgHigh > 0.0)      distToFVG = prevClose - fvgHigh; 
   else if(fvgType == -1 && fvgLow > 0.0)  distToFVG = fvgLow - prevClose;

   string metricsDesc = StringFormat(
      "EMA9 Slope: %.2f USD/bar, EMA50 Slope: %.2f USD/bar, EMA200 Slope: %.2f USD/bar. "+
      "Price Deviation from EMA9: %.2f USD, EMA50: %.2f USD, EMA200: %.2f USD. "+
      "USD Distance to GNN Golden Ceiling: %.2f, GNN Aqua Floor: %.2f, Nearest Bullish OB: %.2f, Nearest Bearish OB: %.2f, Nearest FVG: %.2f.",
      e9Slope, e50Slope, e200Slope, e9Dev, e50Dev, e200Dev, distToCeiling, distToFloor, distToBullOB, distToBearOB, distToFVG
   );

   datetime curTime = TimeCurrent();
   MqlDateTime sdt;
   TimeToStruct(curTime, sdt);
   int curHour = sdt.hour;
   int curMin = sdt.min;
   int curMinsFromMidnight = curHour * 60 + curMin;
   int londonOpenMins = 11 * 60; // 11:00 Broker Time
   int nyOpenMins = 16 * 60 + 30; // 16:30 Broker Time
   int minsToLondon = (curMinsFromMidnight < londonOpenMins) ? (londonOpenMins - curMinsFromMidnight) : -1;
   int minsToNY = (curMinsFromMidnight < nyOpenMins) ? (nyOpenMins - curMinsFromMidnight) : -1;
   string sessionCountdownDesc = "";
   if(minsToLondon > 0) sessionCountdownDesc += StringFormat("London Open in %d mins. ", minsToLondon);
   else sessionCountdownDesc += "London is open. ";
   if(minsToNY > 0) sessionCountdownDesc += StringFormat("NY Open in %d mins. ", minsToNY);
   else sessionCountdownDesc += "NY is open. ";

   double g_dailyPOC = 0.0;
   double g_dailyVAH = 0.0;
   double g_dailyVAL = 0.0;
   double g_dailyImbalance = 1.0;
   CalculateDailyVolumeProfile(g_dailyPOC, g_dailyVAH, g_dailyVAL, g_dailyImbalance);
   string newsCountdownDesc = GetNewsCountdownDesc();
   
   string mtfStructureMap = GetMTFStructureAlignment();
   
   string volRegimeDesc = "Normal Volatility";
   double currentATRVal = currentATR;
   double atrSMA = 0.0;
   double atrArr[];
   int copiedAtr = CopyBuffer(g_atrHandle, 0, 1, 100, atrArr);
   if(copiedAtr > 0)
   {
      double sum = 0.0;
      for(int k = 0; k < copiedAtr; k++) sum += atrArr[k];
      atrSMA = sum / copiedAtr;
   }
   if(atrSMA > 0.0)
   {
      double ratio = currentATRVal / atrSMA;
      if(ratio < 0.8) volRegimeDesc = StringFormat("Volatility Compression (Ratio=%.2f, ATR=%.2f, SMA=%.2f) - range scalping preferred", ratio, currentATRVal, atrSMA);
      else if(ratio > 1.5) volRegimeDesc = StringFormat("Volatility Expansion (Ratio=%.2f, ATR=%.2f, SMA=%.2f) - high momentum breakouts expected", ratio, currentATRVal, atrSMA);
      else volRegimeDesc = StringFormat("Normal Volatility (Ratio=%.2f, ATR=%.2f, SMA=%.2f)", ratio, currentATRVal, atrSMA);
   }
   
   double asianHigh = 0.0, asianLow = 0.0;
   GetAsianSessionRange(asianHigh, asianLow);
   string asianRangeDesc = StringFormat("High=%.2f, Low=%.2f", asianHigh, asianLow);
   
   MqlDateTime brokerTimeStruct;
   TimeCurrent(brokerTimeStruct);
   string dayNames[] = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"};
   string timeDayDesc = StringFormat("%s at %02d:%02d", dayNames[brokerTimeStruct.day_of_week], brokerTimeStruct.hour, brokerTimeStruct.min);
   
   double floatingPnL = 0.0, totalRiskUSD = 0.0;
   GetAccountRiskExposure(floatingPnL, totalRiskUSD);
   string riskExposureDesc = StringFormat("Floating PnL=%.2f$, Active Risk Exposure to SL=%.2f$", floatingPnL, totalRiskUSD);

            string prompt = StringFormat(
      "Gold (XAUUSD) setup analysis. Current price=%.2f. Active Session: %s (Time: %s). Account Capital: Balance=%.2f, Equity=%.2f, Free Margin=%.2f, Margin Level=%.1f%%. Open Positions Exposure: %s. "+
      "GNN Line Distances: %s. Technical Signals: Intraday Trend (M5) is %s, Macro H1 Bias: %s (Reason: %s), Macro Trend (H1/H4) is %s, Intraday VWAP is %s, RSI Status: %s, Spread Status: %s. "+
      "Daily Range Analysis: %s. Asian Session Range: %s. Volatility Regime State: %s. Multi-Timeframe Trend %s. Multi-Timeframe Structure Map: %s. Volatility opens: %s. "+
      "Momentum & Proximity Metrics: %s. Intraday Volume Profile: POC=%.2f, VAH=%.2f, VAL=%.2f, Imbalance Ratio=%.2f. High-Impact News Countdowns: %s. "+
      "Trend Direction: %s. Indicators: ADX=%.2f, ATR=%.2f, RSI=%.2f, EMA50=%.2f, EMA200=%.2f, EMA9=%.2f, VWAP=%.2f, VolSMA10=%.1f, VolSMA20=%.1f, Spread=%.2f. "+
      "Upcoming High-Impact News today: %s. "+
      "Price History (Active Timeframe): %s. "+
      "Macro Price History (Higher Timeframe): %s. "+
      "Candle Patterns (Last 3 Bars): %s. "+
      "Recent closed trades history: %s. "+
      "Untested Price Magnets (Liquidity Pools): %s. "+"ICT Market Structure (Order Blocks & Fair Value Gaps): %s. "+
      "As a Super Intelligent, Elite Institutional Quant Trader, you must analyze the market context through our 100-Concept Cognitive Framework spanning 5 phases: "+
      "Phase 1 - Basics: 1.Market Structure, 2.S&R, 3.Trend, 4.Candlestick Patterns, 5.Time Frames Interaction (M1-M5-H1-H4-D1), 6.Volume, 7.Liquidity Pools, 8.Fair Value Gap (FVG), 9.Order Blocks (OB), 10.BOS, 11.CHOCH, 12.Supply/Demand Zones, 13.Premium/Discount Range, 14.Imbalance, 15.Equal Highs/Lows, 16.Swing High/Low, 17.Sessions (Asian/London/NY), 18.Risk Management, 19.Risk-to-Reward, 20.Psychology. "+
      "Phase 2 - Intermediate: 21.Multi-Timeframe Analysis, 22.Entry Models, 23.SL Placement, 24.TP Techniques, 25.Trendlines, 26.Channels, 27.Moving Averages, 28.RSI, 29.MACD, 30.VWAP, 31.EMA Strategy, 32.ATR Volatility, 33.Fibonacci Retracement, 34.Fibonacci Extension, 35.Breakout Trading, 36.Retest Entries, 37.Fake Breakouts (Deviations), 38.Consolidation, 39.Range Trading, 40.Volatility metrics. "+
      "Phase 3 - Advanced Price Action: 41.Demand Zones, 42.Supply Zones, 43.Mitigation Blocks, 44.Breaker Blocks, 45.Rejection Blocks, 46.Liquidity Sweeps, 47.Stop Hunts, 48.Inducement (liquidity baits), 49.SMT Divergence, 50.Optimal Trade Entry (OTE), 51.Daily Bias, 52.Weekly Bias, 53.Monthly Bias, 54.Market Structure Shift (MSS), 55.Internal Liquidity, 56.External Liquidity, 57.Institutional Order Flow, 58.Premium/Discount Arrays, 59.Market Maker Models, 60.Advanced Price Action Review. "+
      "Phase 4 - Strategy Building: 61.Scalping, 62.Intraday, 63.Swing, 64.Position Trading, 65.Trend Following, 66.Reversal, 67.Pullback, 68.Breakout, 69.Liquidity Sweep Strategy, 70.FVG Strategy, 71.Order Block Strategy, 72.S&D Strategy, 73.Confluence, 74.Strategy Checklist, 75.Trade Checklist, 76.Journal, 77.Performance Analysis, 78.Backtesting, 79.Forward Testing, 80.Strategy Optimization. "+
      "Phase 5 - Professional Trading: 81.Position Sizing, 82.Compounding, 83.Leverage, 84.Funding Rate, 85.Market Maker Concepts, 86.Retail vs SMC, 87.Common Mistakes, 88.Routine, 89.Daily Review, 90.Weekly Review, 91.Monthly Review, 92.Live Chart Analysis, 93.Professional Rules, 94.Risk Control Framework, 95.Trading Plan, 96.Discipline, 97.Performance Metrics, 98.Psychology Mastery, 99.Revision, 100.Live Market Example. "+
      "IN-DEPTH INSTITUTIONAL COGNITIVE PLAYBOOKS: "+
      "1. EMA FOUNTAIN (TREND FANNING): Understand that when EMA9, EMA20, EMA50, and EMA200 are aligned sequentially (bullish: 9>20>50>200; bearish: 9<20<50<200) and fanned out widely, it represents a strong, healthy institutional trend. Do not enter counter-trend reversion trades during an active EMA fountain phase. If EMAs are tangled, flat, or intersecting frequently, the market is consolidated; execute range-bound scalping strategies at boundaries. "+
      "2. EMA ANGLES (SLOPE STRENGTH): Analyze the angles of the EMA lines. A steep slope (>35 degrees) represents high-speed momentum; prioritize pullback entries to ride the wave. A flattening EMA slope represents momentum deceleration and exhaustion; expect consolidation or a structural shift, and look to buy discount zones or sell premium zones. "+
      "3. FAIR VALUE GAPS (FVG) & IMBALANCE: FVGs represent market structural inefficiencies where price moved so rapidly that buy/sell orders were left unfilled. Price acts like a magnet, eventually pulling back to rebalance these gaps. Analyze the nearest unmitigated FVGs. A retracement to the 50% level (Consequent Encroachment) of an FVG in a discount zone is a prime, high-probability long entry zone; a return to a premium FVG is a prime short entry zone. "+
      "4. ORDER BLOCKS (OB) SUPPLY/DEMAND WALLS: Order Blocks represent price zones where central banks and institutional players built massive positions before launching a structural expansion. Locate the nearest unmitigated OBs. The open price of a bullish OB acts as a strong institutional support floor; the open of a bearish OB acts as a strong supply ceiling. Place limit entries at these levels, placing stop losses strictly 3 to 5 USD beyond the outer boundary of the Order Block. "+
      "5. SYSTEMATIC DATA ANALYSIS: Synthesize all data points systematically. Do not rely on a single indicator. Look for a convergence of: EMA Fountain/Angles (momentum direction) + FVG mitigation (inefficiency fill) + OB retests (institutional wall) + Volume Profile (POC/VAH/VAL coordinates) + Wick Rejections (liquidity sweep confirmations). "+
      "6. INSTITUTIONAL GAP-FILLING & REBALANCING MECHANICS (WHEN & WHY PRICES MOVE): Understand that prices are driven by two institutional mandates: (a) Sweeping liquidity pools (GNN Golden Ceiling/Aqua Floor boundaries, Asian range highs/lows, equal highs/lows, or swing pivots) and (b) Rebalancing market inefficiencies (unfilled Fair Value Gaps and volume imbalances). Reversals to fill gaps are triggered when: "+
      "  - GNN Boundary Wick Rejections: Price tests a GNN Golden Ceiling or Aqua Floor and leaves long wicks (wick rejection). This rejection launchpad drives the price back through the range to fill the nearest unmitigated FVG in the opposite direction. "+
      "  - Asian Range Sweeps (Judas Swings): A stop hunt sweeps the Asian session High or Low at London/NY open to collect liquidity. Once the sweep is confirmed (price pulls back inside the range with long wicks), price will aggressively expand to mitigate the opposite side's imbalances. "+
      "  - EMA Fountain Alignment: Fanned-out EMAs with steep angles push price rapidly to fill gaps in the trend direction on brief pullbacks. Counter-trend FVGs should not be traded until EMA angles flatten out (exhaustion). "+
      "  - Order Block & FVG Convergence: Retests of an institutional OB that align with the 50% consequent encroachment level of an FVG form premium entry zones to catch the next gap-filling expansion wave. "+
      "7. EMA OVER-EXTENSION & MEAN REVERSION (THE EMA GRAVITY GAP): Treat the 200 EMA as the market's long-term fair value equilibrium (gravity line). When price moves rapidly in one direction, leaving a series of candles (e.g. red candles below the 200 EMA) completely isolated without touching the line, it creates a 'Gravity Gap' (liquidity vacuum). The further price stretches away from the 200 EMA, the higher the mathematical probability of a sharp pullback (mean reversion) to fill the gap and touch the 200 EMA. Avoid entering trend-continuation trades (e.g. selling when price is already far below the 200 EMA) to prevent selling the bottom or buying the top. Furthermore, if price pulls back close to the 200 EMA but reverses without touching the line, it indicates extreme trend strength where institutional players are front-running the average. "+
      "8. RUNAWAY TREND-FOLLOWING PULLBACK PREDATOR (MICRO-SCALPING): When the EMA Fountain (9, 20, 50, 200) is widely fanned out with a steep angle (>35 degrees), the market is in a runaway institutional expansion trend. In this high-momentum state, you MUST bypass over-conservative filters: "+
      "  - Ignore RSI Overbought/Oversold Limits: In strong trends, RSI can stay overbought/oversold for hours while price continues to expand. Do not hesitate to buy an overbought uptrend or sell an oversold downtrend. "+
      "  - Ignore GNN Boundary Proximity: Do not sit idle waiting for price to touch a GNN golden ceiling or aqua floor. Open-space trading is highly encouraged during runaway trends. "+
      "  - The Execution Rule (Pullback Scalping): On every red pullback candle in an uptrend that approaches the EMA9 or EMA20, place a BUY order immediately. On every green pullback candle in a downtrend that approaches the EMA9 or EMA20, place a SELL order immediately. Target a quick micro-profit of 1-3 USD (10-30 pips) to compound the account balance. Only use GNN boundary ping-pong scalping when EMA slopes are flat. When EMAs are steeply angled, immediately switch to the Trend-Following Pullback Predator model. "+
      "Instructions: "+
      "0. CHAIN-OF-THOUGHT ANALYSIS: Perform a strict 5-Phase evaluation checklist inside the 'reasoning' key before deciding: "+
      "1. Basics & Market Structure (Phase 1): Map structural direction, identify BOS/CHOCH, locate premium/discount range, scan volume & liquidity pools. "+
      "2. Intermediate Confluences (Phase 2): Check EMA Fountain alignment, EMA Angles/slopes, VWAP deviation, RSI momentum, ATR volatility sizing, and the EMA Gravity Gap (assess if price is over-extended from the 200 EMA and look for mean-reversion pullbacks). "+
      "3. Advanced Price Action & Institutional Flow (Phase 3): Scan for unmitigated FVGs and OBs, identify breaker/mitigation blocks, rejection blocks, and check for liquidity sweeps/stop hunts. Analyze when and why the price will move to fill gaps using GNN line rejections, Asian range sweeps, and EMA fountain momentum alignment. "+
      "4. Strategy Alignment (Phase 4): Choose entry strategy (Scalping, Intraday, Swing, Pullback, Breakout, Reversion, or OB/FVG/SMT). If a runaway trend is active (EMA Fountain widely fanned with steep angles), immediately select the RUNAWAY TREND-FOLLOWING PULLBACK PREDATOR strategy, bypass GNN/RSI safety boundaries, and execute pullback entries on candle color changes (red in uptrend, green in downtrend) to grab micro-profits. "+
      "5. Professional Risk & Position Management (Phase 5): Audit target stop loss (placed at least 3-5 USD beyond GNN/structure boundary or OB/FVG edge) and take profit targets. Perform position sizing and leverage audits. "+
      "Write your detailed reasoning step-by-step first. "+
      "1. INSTITUTIONAL MARKET STRUCTURE: Read the structural phase. Identify the dominant Order Flow. Identify key BOS and CHOCH. Trade in the direction of the dominant institutional flow. Never write generic or placeholders for HOLD decisions; provide clear technical confluences. "+
      "2. CONFLUENCE ENTRY ZONES: Seek convergence. Look for zones where GNN boundaries overlap with local Order Blocks (OB), Breaker Blocks, or Fair Value Gaps (FVG) to form high-conviction entries. "+
      "3. DECISIVE ENTRY & MOMENTUM: Execute immediately when a setup is validated. Do not over-analyze or hesitate. Place the trade and let your Stop Loss protect your capital. "+
      "4. STRATEGIC STOP LOSS PLACEMENT: Never place a Stop Loss right on GNN line or key indicator value. Always place it 3 to 5 USD beyond the structural boundary (below the support floor or above the resistance ceiling) to survive normal market noise. "+
      "5. SIDEWAYS PING-PONG PLAY: When you detect a tight sideways range, execute a SCALPING strategy. Buy ONLY at the lower GNN boundary (discount zone), target the upper boundary, and sell ONLY at the upper GNN boundary (premium zone), targeting the lower boundary. "+
      "6. OBJECTIVE EXECUTION: Focus entirely on the technical setup at hand. Do not let recent closed losses or wins affect your decision-making. "+
      "7. LONG-TERM SWING TRADES: When the daily/higher timeframe shows a clear macro trend, look for pullback entries to ride the trend. Set a 'LONG_TERM' horizon, target major support/resistance targets far away, and use a wider Stop Loss to allow the swing trade room to breathe. "+
      "8. BREAKOUT VALIDATION: Never buy a breakout if ADX is below 20.0 or if RSI is above 70.0 (overbought). Never sell a breakout if ADX is below 20.0 or if RSI is below 30.0 (oversold). In these low-momentum conditions, breakout attempts are highly likely to fail and turn into liquidity sweeps. "+
      "Respond strictly with a JSON object containing: "+
      "'reasoning' (detailed step-by-step analysis of EMAs, wicks, patterns, and liquidity gaps), "+
      "'decision' ('BUY', 'SELL', or 'HOLD'), "+
      "'conviction' (integer 0 to 100), "+
      "'regime' ('BREAKOUT' or 'REVERSION'), "+
      "'strategy' ('BREAKOUT', 'MEAN_REVERSION', 'PULLBACK', 'STRADDLE', 'SCALPING', 'DONCHIAN_BREAKOUT', 'VOLUME_BREAKOUT', or 'VWAP_PULLBACK'), "+
      "'horizon' ('SHORT_TERM' or 'LONG_TERM'), "+
      "'stop_loss_price' (double target stop loss price level, or 0.0 to use default), "+
      "'take_profit_price' (double target take profit price level, or 0.0 to use default), "+
      "'reason' (short 10 words summary).",
      prevClose, activeSession, timeDayDesc, balance, equity, freeMargin, marginLevel, riskExposureDesc, gnnDistanceDesc, maSignal, g_h1MacroBias, g_h1MacroReason, macroTrendDesc, vwapSignal, rsiSignal, spreadSignal, dailyRangeDesc, asianRangeDesc, volRegimeDesc, mtfConfluenceDesc, mtfStructureMap, sessionCountdownDesc,
      metricsDesc, g_dailyPOC, g_dailyVAH, g_dailyVAL, g_dailyImbalance, newsCountdownDesc,
      trendDesc, currentADX, currentATR, currentRSI, currentEMA, currentEMA200, currentEMA9, currentVWAP, volSMA10, volSMA20, spread, g_upcomingNews, barsHistory, macroHistory, candlePatterns, tradeHistory, magnetDesc, ictDesc
   );

   bool aiActive = false;
   string responseText = "";
   string rawRegime = "BREAKOUT"; // default
   
   if(InpUseAIEngines)
   {
      aiActive = CallAI(prompt, responseText);
      if(aiActive)
      {
         g_lastAIResponseText = responseText;
         string rawDecision = ExtractJSONValue(responseText, "decision");
         string rawConviction = ExtractJSONValue(responseText, "conviction");
         string rawReason = ExtractJSONValue(responseText, "reason");
         rawRegime = ExtractJSONValue(responseText, "regime");
          g_aiRegime = rawRegime;
         string rawStrategy = ExtractJSONValue(responseText, "strategy");
         
         // Clean decision
         if(StringFind(rawDecision, "BUY") >= 0) g_aiDecision = "BUY";
         else if(StringFind(rawDecision, "SELL") >= 0) g_aiDecision = "SELL";
         else if(StringFind(rawDecision, "HOLD") >= 0) g_aiDecision = "HOLD";
         else g_aiDecision = "HOLD";
         
         g_aiConviction = (int)StringToInteger(rawConviction);
         if(g_aiConviction < 0) g_aiConviction = 0;
         if(g_aiConviction > 100) g_aiConviction = 100;
         
         g_aiStrategy = (rawStrategy != "") ? rawStrategy : "BREAKOUT";
         string rawHorizon = ExtractJSONValue(responseText, "horizon");
         if(StringFind(rawHorizon, "LONG_TERM") >= 0) g_tradeHorizon = "LONG_TERM";
         else g_tradeHorizon = "SHORT_TERM";
         g_aiReason = (rawReason != "") ? rawReason : "AI analyzed successfully.";
      }
      else
      {
         g_aiDecision = "API ERROR";
         g_aiConviction = 0;
         g_aiReason = "AI services offline.";
      }
   }
   else
   {
      g_aiDecision = "LOCAL RULES";
      g_aiConviction = 0;
      g_aiReason = "AI Engine is disabled.";
   }

   // Lock queries for the current candle to exactly once
   if(!isMidCandle) g_lastOrderPlacedBarTime = currentBarTime;

   bool useReversionMode = CalculateReversionMode(currentADX, isMomentumHour, isVolatilitySpike, aiActive, g_aiRegime);

   // Trend Adaptation: if ADX trend guard blocks reversion, convert range strategy to breakout
   if(!aiActive && !useReversionMode && (g_aiStrategy == "MEAN_REVERSION" || g_aiStrategy == "SCALPING" || g_aiStrategy == "NONE" || g_aiStrategy == ""))
   {
      g_aiStrategy = "VOLUME_BREAKOUT";
      Print("[Trend Adaptation] Converted AI range strategy to VOLUME_BREAKOUT due to high ADX Trend Guard.");
   }

   // Dynamic Risk Scaling factor based on conviction
   double convictionMultiplier = 1.0;
   if(aiActive)
   {
      // --- Context-Aware Over-Extension Entry Guard ---
      double nHighs[];
      double nLows[];
      string mDesc = "";
      GetUntestedMagnets(nHighs, nLows, mDesc);
      double goldCeiling = (ArraySize(nHighs) > 0) ? nHighs[0] : 0.0;
      double aquaFloor = (ArraySize(nLows) > 0) ? nLows[0] : 0.0;
      
             double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
       double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
       
       // Dynamic guard distance based on ATR (minimum 3.0 USD buffer to protect from near-boundary whipsaws)
       double guardDist = MathMax(3.0, 1.5 * currentATR);
       
       if(g_aiDecision == "BUY" && goldCeiling > 0.0 && currentAsk >= goldCeiling - guardDist)
       {
          PrintFormat("[Over-Extension Warning] BUY price %.2f is close to Golden Line Ceiling: %.2f (Guard buffer: %.2f). LLM is proceeding with supreme control.", currentAsk, goldCeiling, guardDist);
       }
       else if(g_aiDecision == "SELL" && aquaFloor > 0.0 && currentBid <= aquaFloor + guardDist)
       {
          PrintFormat("[Over-Extension Warning] SELL price %.2f is close to Aqua Line Floor: %.2f (Guard buffer: %.2f). LLM is proceeding with supreme control.", currentBid, aquaFloor, guardDist);
       }

      // Block trades below the threshold
      if(g_aiConviction < InpMinConviction)
      {
         Print(StringFormat("[Conviction Engine Blocked] Score %d is below the minimum threshold %d. Reason: %s", 
            g_aiConviction, InpMinConviction, g_aiReason));
         g_aiDecision = "BLOCKED";
         DrawChartStatus(currentADX, currentATR, (rawRegime == "REVERSION"));
         return false; 
      }
      
      // Scale position size dynamically based on conviction:
      if(g_aiConviction >= 90)
      {
         convictionMultiplier = 1.00;
      }
      else if(g_aiConviction >= 80)
      {
         convictionMultiplier = 0.80;
      }
      else if(g_aiConviction >= 70)
      {
         convictionMultiplier = 0.50;
      }
      else
      {
         convictionMultiplier = 0.30;
      }
    }

    if(g_aiDecision == "BUY" || g_aiDecision == "SELL")
    {
       if(!CheckTrendConfluence(g_aiDecision))
       {
          return false;
       }
    }
    
    double finalLotSize = NormalizeDouble(g_lotSize * convictionMultiplier, 2);
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    if(finalLotSize < minLot) finalLotSize = minLot;

    // --- Parse AI Suggested Structural Stop Loss and Take Profit ---
    double structuralSL = 0.0;
    double structuralTP = 0.0;
    if(aiActive)
    {
       structuralSL = StringToDouble(ExtractJSONValue(responseText, "stop_loss_price"));
       structuralTP = StringToDouble(ExtractJSONValue(responseText, "take_profit_price"));
    }

        // --- Swing / Long-Term Trade Execution ---
    if(aiActive && g_tradeHorizon == "LONG_TERM")
    {
       double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
       double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
       
       double swingSL = (structuralSL > 0.0) ? structuralSL : 0.0;
       double swingTP = (structuralTP > 0.0) ? structuralTP : 0.0;
       
       if(g_aiDecision == "BUY" )
       {
          if(swingSL <= 0.0 || swingSL >= currentBid) swingSL = NormalizeDouble(currentBid - (2.5 * g_stopLossDist), _Digits);
          if(swingTP <= 0.0 || swingTP <= currentAsk) swingTP = NormalizeDouble(currentBid + (4.0 * g_stopLossDist), _Digits);
          
          double swingLotSize = NormalizeDouble(finalLotSize * 0.30, 2);
          double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
          if(swingLotSize < minLot) swingLotSize = minLot;
          
          PrintFormat("[Swing Engine] Placing LONG_TERM Swing BUY. Lot: %.2f, Entry: %.2f, SL: %.2f, TP: %.2f", 
             swingLotSize, currentAsk, swingSL, swingTP);
          trade.Buy(swingLotSize, _Symbol, currentAsk, swingSL, swingTP, "GE_SWING");
          return true;
       }
       else if(g_aiDecision == "SELL" )
       {
          if(swingSL <= 0.0 || swingSL <= currentAsk) swingSL = NormalizeDouble(currentAsk + (2.5 * g_stopLossDist), _Digits);
          if(swingTP <= 0.0 || swingTP >= currentBid) swingTP = NormalizeDouble(currentAsk - (4.0 * g_stopLossDist), _Digits);
          
          double swingLotSize = NormalizeDouble(finalLotSize * 0.30, 2);
          double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
          if(swingLotSize < minLot) swingLotSize = minLot;
          
          PrintFormat("[Swing Engine] Placing LONG_TERM Swing SELL. Lot: %.2f, Entry: %.2f, SL: %.2f, TP: %.2f", 
             swingLotSize, currentBid, swingSL, swingTP);
          trade.Sell(swingLotSize, _Symbol, currentBid, swingSL, swingTP, "GE_SWING");
          return true;
       }
       return false;
    }

    // --- Execute Specific Strategy if Selected by AI ---
    if(aiActive)
    {
       if(g_aiStrategy == "SCALPING")
       {
          double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
          double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
          
          double scalpingSL = (structuralSL > 0.0 && structuralSL < currentAsk) ? structuralSL : NormalizeDouble(currentBid - 0.60, _Digits);
          double scalpingTP = (structuralTP > 0.0) ? structuralTP : NormalizeDouble(currentBid + 0.80, _Digits);
          
          if(g_aiDecision == "BUY" )
          {
             // Validate and cap Stop Loss
             double maxRiskSL = NormalizeDouble(currentBid - (2.0 * g_stopLossDist), _Digits);
             if(scalpingSL < maxRiskSL) scalpingSL = maxRiskSL; // Safety Cap
             
             trade.Buy(finalLotSize, _Symbol, currentAsk, scalpingSL, scalpingTP, "AI Scalp BUY");
             return true;
          }
          else if(g_aiDecision == "SELL" )
          {
             scalpingSL = (structuralSL > currentBid) ? structuralSL : NormalizeDouble(currentAsk + 0.60, _Digits);
             scalpingTP = (structuralTP > 0.0) ? structuralTP : NormalizeDouble(currentAsk - 0.80, _Digits);
             
             double maxRiskSL = NormalizeDouble(currentAsk + (2.0 * g_stopLossDist), _Digits);
             if(scalpingSL > maxRiskSL) scalpingSL = maxRiskSL; // Safety Cap
             
             trade.Sell(finalLotSize, _Symbol, currentBid, scalpingSL, scalpingTP, "AI Scalp SELL");
             return true;
          }
          return false;
       }
       
       if(g_aiStrategy == "PULLBACK")
       {
          double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
          double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
          
          if(g_aiDecision == "BUY" )
          {
             double limitPrice = (bullOB_High > 0.0) ? bullOB_High : ((fvgType == 1) ? fvgHigh : NormalizeDouble(currentEMA, _Digits));
             double pullbackSL = (structuralSL > 0.0 && structuralSL < limitPrice) ? structuralSL : ((bullOB_Low > 0.0) ? bullOB_Low : NormalizeDouble(limitPrice - 0.80, _Digits));
             double pullbackTP = (structuralTP > 0.0) ? structuralTP : NormalizeDouble(limitPrice + 2.00, _Digits);
             
             // Risk Cap
             double maxRiskSL = NormalizeDouble(limitPrice - (2.0 * g_stopLossDist), _Digits);
             if(pullbackSL < maxRiskSL) pullbackSL = maxRiskSL;
             
             if(MathAbs(currentBid - currentEMA) <= 0.30)
             {
                trade.Buy(finalLotSize, _Symbol, currentAsk, pullbackSL, pullbackTP, "AI Pullback BUY Market");
             }
             else
             {
                if(limitPrice > currentAsk)
                {
                   trade.BuyStop(finalLotSize, limitPrice, _Symbol, pullbackSL, pullbackTP, ORDER_TIME_GTC, 0, "AI Pullback BUY Stop");
                }
                else
                {
                   trade.BuyLimit(finalLotSize, limitPrice, _Symbol, pullbackSL, pullbackTP, ORDER_TIME_GTC, 0, "AI Pullback BUY Limit");
                }
             }
             return true;
          }
          else if(g_aiDecision == "SELL" )
          {
             double limitPrice = (bearOB_Low > 0.0) ? bearOB_Low : ((fvgType == -1) ? fvgLow : NormalizeDouble(currentEMA, _Digits));
             double pullbackSL = (structuralSL > limitPrice) ? structuralSL : ((bearOB_High > 0.0) ? bearOB_High : NormalizeDouble(limitPrice + 0.80, _Digits));
             double pullbackTP = (structuralTP > 0.0) ? structuralTP : NormalizeDouble(limitPrice - 2.00, _Digits);
             
             // Risk Cap
             double maxRiskSL = NormalizeDouble(limitPrice + (2.0 * g_stopLossDist), _Digits);
             if(pullbackSL > maxRiskSL) pullbackSL = maxRiskSL;
             
             if(MathAbs(currentAsk - currentEMA) <= 0.30)
             {
                trade.Sell(finalLotSize, _Symbol, currentBid, pullbackSL, pullbackTP, "AI Pullback SELL Market");
             }
             else
             {
                if(limitPrice < currentBid)
                {
                   trade.SellStop(finalLotSize, limitPrice, _Symbol, pullbackSL, pullbackTP, ORDER_TIME_GTC, 0, "AI Pullback SELL Stop");
                }
                else
                {
                   trade.SellLimit(finalLotSize, limitPrice, _Symbol, pullbackSL, pullbackTP, ORDER_TIME_GTC, 0, "AI Pullback SELL Limit");
                }
             }
             return true;
          }
          return false;
       }
       
        if(g_aiStrategy == "STRADDLE")
        {
           double buyStopPrice  = NormalizeDouble(prevHigh + g_priceOffset + spread, _Digits);
           double buySL         = (structuralSL > 0.0 && structuralSL < buyStopPrice) ? structuralSL : NormalizeDouble(buyStopPrice - g_stopLossDist, _Digits);
           double buyTP         = (structuralTP > 0.0) ? structuralTP : ((g_takeProfitDist > 0.0) ? NormalizeDouble(buyStopPrice + g_takeProfitDist, _Digits) : 0.0);
           
           // Risk Cap
           double maxBuyRiskSL = NormalizeDouble(buyStopPrice - (2.0 * g_stopLossDist), _Digits);
           if(buySL < maxBuyRiskSL) buySL = maxBuyRiskSL;
           
           double sellStopPrice = NormalizeDouble(prevLow - g_priceOffset, _Digits);
           double sellSL        = (structuralSL > sellStopPrice) ? structuralSL : NormalizeDouble(sellStopPrice + g_stopLossDist, _Digits);
           double sellTP        = (structuralTP > 0.0) ? structuralTP : ((g_takeProfitDist > 0.0) ? NormalizeDouble(sellStopPrice - g_takeProfitDist, _Digits) : 0.0);
           
           // Risk Cap
           double maxSellRiskSL = NormalizeDouble(sellStopPrice + (2.0 * g_stopLossDist), _Digits);
           if(sellSL > maxSellRiskSL) sellSL = maxSellRiskSL;
          
          if(true)
          {
             trade.BuyStop(finalLotSize, buyStopPrice, _Symbol, buySL, buyTP, ORDER_TIME_GTC, 0, "AI Straddle BUY");
          }
          if(true)
          {
              trade.SellStop(finalLotSize, sellStopPrice, _Symbol, sellSL, sellTP, ORDER_TIME_GTC, 0, "AI Straddle SELL");
           }
           return true;
        }
        
        if(g_aiStrategy == "DONCHIAN_BREAKOUT")
        {
           double ema200Val[];
           ArraySetAsSeries(ema200Val, true);
           if(CopyBuffer(g_ema200Handle, 0, 1, 1, ema200Val) > 0)
           {
              double curr_ema200 = ema200Val[0];
              double ch_high = GetChannelHigh(InpChannelLength);
              double ch_low = GetChannelLow(InpChannelLength);
              
              double donchianSL = GetStopLossDistance(_Symbol, prevClose, currentATR);
              if(structuralSL > 0.0)
              {
                 double suggestedSLDist = MathAbs(prevClose - structuralSL);
                 double maxCap = 2.0 * g_stopLossDist;
                 if(suggestedSLDist < donchianSL) suggestedSLDist = donchianSL;
                 if(suggestedSLDist > maxCap) suggestedSLDist = maxCap;
                 donchianSL = suggestedSLDist;
              }
              double donchianTP = donchianSL * InpTargetMult;
              if(structuralTP > 0.0)
              {
                 double suggestedTPDist = MathAbs(prevClose - structuralTP);
                 if(suggestedTPDist < donchianSL) suggestedTPDist = donchianSL;
                 donchianTP = suggestedTPDist;
              }
              
              double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
              double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
              
              bool triggerBuy  = aiActive ? true : ((prevClose > ch_high) && (prevClose >= curr_ema200));
              bool triggerSell = aiActive ? true : ((prevClose < ch_low)  && (prevClose < curr_ema200));
              
              if(g_aiDecision == "BUY" )
              {
                 if(!triggerBuy)
                 {
                    Print("[Quant Guard] Blocked AI Donchian BUY: Close (", prevClose, ") is not above Channel High (", ch_high, ") or EMA200 (", curr_ema200, ").");
                    return false;
                 }
                 double buySL = currentAsk - donchianSL;
                 double buyTP = currentAsk + donchianTP;
                 
                 // Risk Cap
                 double maxRiskSL = NormalizeDouble(currentAsk - (2.0 * g_stopLossDist), _Digits);
                 if(buySL < maxRiskSL) buySL = maxRiskSL;
                 
                 trade.Buy(finalLotSize, _Symbol, currentAsk, buySL, buyTP, "AI Donchian BUY");
                 return true;
              }
              else if(g_aiDecision == "SELL" )
              {
                 if(!triggerSell)
                 {
                    Print("[Quant Guard] Blocked AI Donchian SELL: Close (", prevClose, ") is not below Channel Low (", ch_low, ") or EMA200 (", curr_ema200, ").");
                    return false;
                 }
                 double sellSL = currentBid + donchianSL;
                 double sellTP = currentBid - donchianTP;
                 
                 // Risk Cap
                 double maxRiskSL = NormalizeDouble(currentBid + (2.0 * g_stopLossDist), _Digits);
                 if(sellSL > maxRiskSL) sellSL = maxRiskSL;
                 
                 trade.Sell(finalLotSize, _Symbol, currentBid, sellSL, sellTP, "AI Donchian SELL");
                 return true;
              }
           }
           return false;
        }

        if(g_aiStrategy == "VOLUME_BREAKOUT")
        {
           double ema200Val[];
           ArraySetAsSeries(ema200Val, true);
           if(CopyBuffer(g_ema200Handle, 0, 1, 1, ema200Val) > 0)
           {
              double curr_ema200 = ema200Val[0];
              double ch_high = GetChannelHigh(InpChannelLength);
              double ch_low = GetChannelLow(InpChannelLength);
              
              double donchianSL = GetStopLossDistance(_Symbol, prevClose, currentATR);
              if(structuralSL > 0.0)
              {
                 double suggestedSLDist = MathAbs(prevClose - structuralSL);
                 double maxCap = 2.0 * g_stopLossDist;
                 if(suggestedSLDist < donchianSL) suggestedSLDist = donchianSL;
                 if(suggestedSLDist > maxCap) suggestedSLDist = maxCap;
                 donchianSL = suggestedSLDist;
              }
              double donchianTP = donchianSL * InpVolumeBreakTPMult;
              if(structuralTP > 0.0)
              {
                 double suggestedTPDist = MathAbs(prevClose - structuralTP);
                 if(suggestedTPDist < donchianSL) suggestedTPDist = donchianSL;
                 donchianTP = suggestedTPDist;
              }
              
              double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
              double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
              
              double currVol = (double)iVolume(_Symbol, _Period, 1);
              double volSMA10 = GetVolumeSMA(10);
              bool volOk = (currVol >= InpVolumeMult1 * volSMA10);
              
              bool triggerBuy  = aiActive ? true : ((prevClose > ch_high) && (prevClose >= curr_ema200) && volOk);
              bool triggerSell = aiActive ? true : ((prevClose < ch_low)  && (prevClose < curr_ema200)  && volOk);
              
              if(g_aiDecision == "BUY" )
              {
                 if(!triggerBuy)
                 {
                    Print("[Quant Guard] Blocked AI Vol Breakout BUY: Close (", prevClose, ") not above High (", ch_high, ") or Vol (", currVol, ") < 1.8x SMA (", volSMA10, ").");
                    return false;
                 }
                 double buySL = currentAsk - donchianSL;
                 double buyTP = currentAsk + donchianTP;
                 
                 double maxRiskSL = NormalizeDouble(currentAsk - (2.0 * g_stopLossDist), _Digits);
                 if(buySL < maxRiskSL) buySL = maxRiskSL;
                 
                 trade.Buy(finalLotSize, _Symbol, currentAsk, buySL, buyTP, "AI Vol Breakout BUY");
                 return true;
              }
              else if(g_aiDecision == "SELL" )
              {
                 if(!triggerSell)
                 {
                    Print("[Quant Guard] Blocked AI Vol Breakout SELL: Close (", prevClose, ") not below Low (", ch_low, ") or Vol (", currVol, ") < 1.8x SMA (", volSMA10, ").");
                    return false;
                 }
                 double sellSL = currentBid + donchianSL;
                 double sellTP = currentBid - donchianTP;
                 
                 double maxRiskSL = NormalizeDouble(currentBid + (2.0 * g_stopLossDist), _Digits);
                 if(sellSL > maxRiskSL) sellSL = maxRiskSL;
                 
                 trade.Sell(finalLotSize, _Symbol, currentBid, sellSL, sellTP, "AI Vol Breakout SELL");
                 return true;
              }
           }
           return false;
        }
        
        if(g_aiStrategy == "VWAP_PULLBACK")
        {
           double ema200Val[];
           ArraySetAsSeries(ema200Val, true);
           if(CopyBuffer(g_ema200Handle, 0, 1, 1, ema200Val) > 0)
           {
              double curr_ema200 = ema200Val[0];
              double currentVWAP = GetDailyVWAP();
              
              double pullbackSL = GetStopLossDistance(_Symbol, prevClose, currentATR);
              if(structuralSL > 0.0)
              {
                 double suggestedSLDist = MathAbs(prevClose - structuralSL);
                 double maxCap = 2.0 * g_stopLossDist;
                 if(suggestedSLDist < pullbackSL) suggestedSLDist = pullbackSL;
                 if(suggestedSLDist > maxCap) suggestedSLDist = maxCap;
                 pullbackSL = suggestedSLDist;
              }
              double pullbackTP = pullbackSL * InpScalpTPMult;
              if(structuralTP > 0.0)
              {
                 double suggestedTPDist = MathAbs(prevClose - structuralTP);
                 if(suggestedTPDist < pullbackSL) suggestedTPDist = pullbackSL;
                 pullbackTP = suggestedTPDist;
              }
              
              double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
              double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
              
              double ema9Val[];
               ArraySetAsSeries(ema9Val, true);
               if(CopyBuffer(g_ema9Handle, 0, 1, 3, ema9Val) > 0)
               {
                  double close1 = iClose(_Symbol, _Period, 1);
                  double close2 = iClose(_Symbol, _Period, 2);
                  
                  double low1 = iLow(_Symbol, _Period, 1);
                  double low2 = iLow(_Symbol, _Period, 2);
                  double low3 = iLow(_Symbol, _Period, 3);
                  
                  double high1 = iHigh(_Symbol, _Period, 1);
                  double high2 = iHigh(_Symbol, _Period, 2);
                  double high3 = iHigh(_Symbol, _Period, 3);
                  
                  double currRSI = currentRSI;
                  double currVol = (double)iVolume(_Symbol, _Period, 1);
                  double volSMA20 = GetVolumeSMA(20);
                  bool volOk = (currVol >= InpVolumeMult2 * volSMA20);
                  
                  bool pullbackBuy = (low1 <= ema9Val[0] || low2 <= ema9Val[1] || low3 <= ema9Val[2]);
                  bool triggerBuy = (close1 > ema9Val[0] && close2 <= ema9Val[1]);
                  bool rsiBuyOk = (currRSI >= 45.0 && currRSI <= 65.0);
                  bool trendBuyOk = (close1 > curr_ema200 && close1 > currentVWAP);
                  
                  bool pullbackSell = (high1 >= ema9Val[0] || high2 >= ema9Val[1] || high3 >= ema9Val[2]);
                  bool triggerSell = (close1 < ema9Val[0] && close2 >= ema9Val[1]);
                  bool rsiSellOk = (currRSI >= 35.0 && currRSI <= 55.0);
                  bool trendSellOk = (close1 < curr_ema200 && close1 < currentVWAP);
                  
                  if(g_aiDecision == "BUY" )
                  {
                     if(!aiActive && !(trendBuyOk && pullbackBuy && triggerBuy && volOk && rsiBuyOk))
                     {
                        Print("[Quant Guard] Blocked AI VWAP Pullback BUY: Indicators mismatch.");
                        return false;
                     }
                     double buySL = currentAsk - pullbackSL;
                     double buyTP = currentAsk + pullbackTP;
                     
                     double maxRiskSL = NormalizeDouble(currentAsk - (2.0 * g_stopLossDist), _Digits);
                     if(buySL < maxRiskSL) buySL = maxRiskSL;
                     
                     trade.Buy(finalLotSize, _Symbol, currentAsk, buySL, buyTP, "AI VWAP Pullback BUY");
                     return true;
                  }
                  else if(g_aiDecision == "SELL" )
                  {
                     if(!aiActive && !(trendSellOk && pullbackSell && triggerSell && volOk && rsiSellOk))
                     {
                        Print("[Quant Guard] Blocked AI VWAP Pullback SELL: Indicators mismatch.");
                        return false;
                     }
                     double sellSL = currentBid + pullbackSL;
                     double sellTP = currentBid - pullbackTP;
                     
                     double maxRiskSL = NormalizeDouble(currentBid + (2.0 * g_stopLossDist), _Digits);
                     if(sellSL > maxRiskSL) sellSL = maxRiskSL;
                     
                     trade.Sell(finalLotSize, _Symbol, currentBid, sellSL, sellTP, "AI VWAP Pullback SELL");
                     return true;
                  }
               }
              else if(g_aiDecision == "SELL" )
              {
                 double sellSL = currentBid + pullbackSL;
                 double sellTP = currentBid - pullbackTP;
                 
                 double maxRiskSL = NormalizeDouble(currentBid + (2.0 * g_stopLossDist), _Digits);
                 if(sellSL > maxRiskSL) sellSL = maxRiskSL;
                 
                 trade.Sell(finalLotSize, _Symbol, currentBid, sellSL, sellTP, "AI VWAP Pullback SELL");
                 return true;
              }
           }
           return false;
        }
     }



    // Place Orders in accordance with Daily Sentiment Anchor
    if(useReversionMode)
    {
       if(!aiActive && InpUseLocalVWAPPullback)
       {
          double ema200Val[];
          ArraySetAsSeries(ema200Val, true);
          if(CopyBuffer(g_ema200Handle, 0, 1, 1, ema200Val) > 0)
          {
             double curr_ema200 = ema200Val[0];
             double currentVWAP = GetDailyVWAP();
             
             double ema9Val[];
             ArraySetAsSeries(ema9Val, true);
             if(CopyBuffer(g_ema9Handle, 0, 1, 3, ema9Val) > 0)
             {
                double close1 = iClose(_Symbol, _Period, 1);
                double close2 = iClose(_Symbol, _Period, 2);
                
                double low1 = iLow(_Symbol, _Period, 1);
                double low2 = iLow(_Symbol, _Period, 2);
                double low3 = iLow(_Symbol, _Period, 3);
                
                double high1 = iHigh(_Symbol, _Period, 1);
                double high2 = iHigh(_Symbol, _Period, 2);
                double high3 = iHigh(_Symbol, _Period, 3);
                
                double currRSI = currentRSI;
                double currVol = (double)iVolume(_Symbol, _Period, 1);
                double volSMA20 = GetVolumeSMA(20);
                
                bool volOk = (currVol >= InpVolumeMult2 * volSMA20);
                
                bool pullbackBuy = (low1 <= ema9Val[0] || low2 <= ema9Val[1] || low3 <= ema9Val[2]);
                bool triggerBuy = (close1 > ema9Val[0] && close2 <= ema9Val[1]);
                bool rsiBuyOk = (currRSI >= 45.0 && currRSI <= 65.0);
                bool trendBuyOk = (close1 > curr_ema200 && close1 > currentVWAP);
                
                bool pullbackSell = (high1 >= ema9Val[0] || high2 >= ema9Val[1] || high3 >= ema9Val[2]);
                bool triggerSell = (close1 < ema9Val[0] && close2 >= ema9Val[1]);
                bool rsiSellOk = (currRSI >= 35.0 && currRSI <= 55.0);
                bool trendSellOk = (close1 < curr_ema200 && close1 < currentVWAP);
                
                if(trendBuyOk && pullbackBuy && triggerBuy && volOk && rsiBuyOk && (g_dailySentiment != "SELL_ONLY"))
                {
                   double pullbackSL = GetStopLossDistance(_Symbol, prevClose, currentATR);
                   double pullbackTP = pullbackSL * InpScalpTPMult;
                   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                   double buySL = currentAsk - pullbackSL;
                   double buyTP = currentAsk + pullbackTP;
                   
                   double maxRiskSL = NormalizeDouble(currentAsk - (2.0 * g_stopLossDist), _Digits);
                   if(buySL < maxRiskSL) buySL = maxRiskSL;
                   
                   trade.Buy(finalLotSize, _Symbol, currentAsk, buySL, buyTP, "Local VWAP Pullback BUY");
                   return true;
                }
                else if(trendSellOk && pullbackSell && triggerSell && volOk && rsiSellOk && (g_dailySentiment != "BUY_ONLY"))
                {
                   double pullbackSL = GetStopLossDistance(_Symbol, prevClose, currentATR);
                   double pullbackTP = pullbackSL * InpScalpTPMult;
                   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                   double sellSL = currentBid + pullbackSL;
                   double sellTP = currentBid - pullbackTP;
                   
                   double maxRiskSL = NormalizeDouble(currentBid + (2.0 * g_stopLossDist), _Digits);
                   if(sellSL > maxRiskSL) sellSL = maxRiskSL;
                   
                   trade.Sell(finalLotSize, _Symbol, currentBid, sellSL, sellTP, "Local VWAP Pullback SELL");
                   return true;
                }
             }
          }
       }

        // --- SIDEWAYS RANGE MODE (Limit Orders) ---
        double reversionOffset = (InpTimeframeMode == TF_M1 || (InpTimeframeMode == TF_AUTO && _Period == PERIOD_M1)) ? 0.08 : 0.15;
        
        bool placeBuy = (g_dailySentiment != "SELL_ONLY");
        bool placeSell = (g_dailySentiment != "BUY_ONLY");
       
       if(placeBuy)
       {
          double rawBuyPrice = (ArraySize(nearestLows) > 0) ? (nearestLows[0] + InpLimitOffset) : (prevLow - reversionOffset);
          double buyLimitPrice = (InpPriceRoundStep > 0.0) ? RoundToStep(rawBuyPrice, InpPriceRoundStep) : NormalizeDouble(rawBuyPrice, _Digits);
          // Strictly use ATR-based Stop Loss for range limits (ignore tight AI structural stops)
          double buySL          = NormalizeDouble(buyLimitPrice - g_stopLossDist, _Digits);
          
          // Buy TP defaults to the target Sell Limit price (front-run Golden Magnet)
          double rawBuyTPPrice = (ArraySize(nearestHighs) > 0) ? (nearestHighs[0] - InpLimitOffset) : 0.0;
          double buyTP = (rawBuyTPPrice > 0.0) ? ((InpPriceRoundStep > 0.0) ? RoundToStep(rawBuyTPPrice, InpPriceRoundStep) : NormalizeDouble(rawBuyTPPrice, _Digits)) : 
                         ((g_takeProfitDist > 0.0) ? NormalizeDouble(buyLimitPrice + g_takeProfitDist, _Digits) : 0.0);
          
          // Apply safety stops clamping
          double maxRiskSL = NormalizeDouble(buyLimitPrice - (2.0 * g_stopLossDist), _Digits);
          if(buySL < maxRiskSL) buySL = maxRiskSL;
          
          // Force minimum 1:1 risk-to-reward on dynamic target
          if(buyTP > buyLimitPrice && buySL < buyLimitPrice)
          {
             double tpDist = buyTP - buyLimitPrice;
             double slDist = buyLimitPrice - buySL;
             if(tpDist < slDist) buyTP = buyLimitPrice + slDist;
          }
          
          trade.BuyLimit(finalLotSize, buyLimitPrice, _Symbol, buySL, buyTP, ORDER_TIME_GTC, 0, "AI Buy Limit Reversion");
       }
       
       if(placeSell)
       {
          double rawSellPrice = (ArraySize(nearestHighs) > 0) ? (nearestHighs[0] - InpLimitOffset) : (prevHigh + reversionOffset);
          double sellLimitPrice = (InpPriceRoundStep > 0.0) ? RoundToStep(rawSellPrice, InpPriceRoundStep) : NormalizeDouble(rawSellPrice, _Digits);
          // Strictly use ATR-based Stop Loss for range limits (ignore tight AI structural stops)
          double sellSL         = NormalizeDouble(sellLimitPrice + g_stopLossDist, _Digits);
          
          // Sell TP defaults to the target Buy Limit price (front-run Aqua Magnet)
          double rawSellTPPrice = (ArraySize(nearestLows) > 0) ? (nearestLows[0] + InpLimitOffset) : 0.0;
          double sellTP = (rawSellTPPrice > 0.0) ? ((InpPriceRoundStep > 0.0) ? RoundToStep(rawSellTPPrice, InpPriceRoundStep) : NormalizeDouble(rawSellTPPrice, _Digits)) : 
                          ((g_takeProfitDist > 0.0) ? NormalizeDouble(sellLimitPrice - g_takeProfitDist, _Digits) : 0.0);
          
          // Apply safety stops clamping
          double maxRiskSL = NormalizeDouble(sellLimitPrice + (2.0 * g_stopLossDist), _Digits);
          if(sellSL > maxRiskSL) sellSL = maxRiskSL;
          
          // Force minimum 1:1 risk-to-reward on dynamic target
          if(sellTP < sellLimitPrice && sellSL > sellLimitPrice)
          {
             double tpDist = sellLimitPrice - sellTP;
             double slDist = sellSL - sellLimitPrice;
             if(tpDist < slDist) sellTP = sellLimitPrice - slDist;
          }
          
          trade.SellLimit(finalLotSize, sellLimitPrice, _Symbol, sellSL, sellTP, ORDER_TIME_GTC, 0, "AI Sell Limit Reversion");
       }
      
      return true;
   }
   else
   {
      // --- TRENDING BREAKOUT MODE ---
      if(!aiActive && InpUseLocalVolBreakout)
      {
         double ema200Val[];
         ArraySetAsSeries(ema200Val, true);
         if(CopyBuffer(g_ema200Handle, 0, 1, 1, ema200Val) > 0)
         {
            double curr_ema200 = ema200Val[0];
            double ch_high = GetChannelHigh(InpChannelLength);
            double ch_low = GetChannelLow(InpChannelLength);
            
            double currVol = (double)iVolume(_Symbol, _Period, 1);
            double volSMA10 = GetVolumeSMA(10);
            bool volOk = (currVol >= InpVolumeMult1 * volSMA10);
            
            bool triggerBuy  = (prevClose > ch_high) && (prevClose >= curr_ema200) && volOk && (g_dailySentiment != "SELL_ONLY");
            bool triggerSell = (prevClose < ch_low)  && (prevClose < curr_ema200)  && volOk && (g_dailySentiment != "BUY_ONLY");
            
            if(triggerBuy)
            {
               double donchianSL = GetStopLossDistance(_Symbol, prevClose, currentATR);
               double donchianTP = donchianSL * InpVolumeBreakTPMult;
               
               double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               double buySL = currentAsk - donchianSL;
               double buyTP = currentAsk + donchianTP;
               
               double maxRiskSL = NormalizeDouble(currentAsk - (2.0 * g_stopLossDist), _Digits);
               if(buySL < maxRiskSL) buySL = maxRiskSL;
               
               trade.Buy(finalLotSize, _Symbol, currentAsk, buySL, buyTP, "Local Vol Breakout BUY");
               return true;
            }
            else if(triggerSell)
            {
               double donchianSL = GetStopLossDistance(_Symbol, prevClose, currentATR);
               double donchianTP = donchianSL * InpVolumeBreakTPMult;
               
               double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               double sellSL = currentBid + donchianSL;
               double sellTP = currentBid - donchianTP;
               
               double maxRiskSL = NormalizeDouble(currentBid + (2.0 * g_stopLossDist), _Digits);
               if(sellSL > maxRiskSL) sellSL = maxRiskSL;
               
               trade.Sell(finalLotSize, _Symbol, currentBid, sellSL, sellTP, "Local Vol Breakout SELL");
               return true;
            }
         }
         return false;
      }

      if(!aiActive && InpUseLocalDonchianBreakout)
      {
         double ema200Val[];
         ArraySetAsSeries(ema200Val, true);
         if(CopyBuffer(g_ema200Handle, 0, 1, 1, ema200Val) > 0)
         {
            double curr_ema200 = ema200Val[0];
            double ch_high = GetChannelHigh(InpChannelLength);
            double ch_low = GetChannelLow(InpChannelLength);
            
            bool triggerBuy  = (prevClose > ch_high) && (prevClose >= curr_ema200) && (g_dailySentiment != "SELL_ONLY");
            bool triggerSell = (prevClose < ch_low)  && (prevClose < curr_ema200)  && (g_dailySentiment != "BUY_ONLY");
            
            if(triggerBuy)
            {
               double donchianSL = GetStopLossDistance(_Symbol, prevClose, currentATR);
               double donchianTP = donchianSL * InpTargetMult;
               
               double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               double buySL = currentAsk - donchianSL;
               double buyTP = currentAsk + donchianTP;
               
               double maxRiskSL = NormalizeDouble(currentAsk - (2.0 * g_stopLossDist), _Digits);
               if(buySL < maxRiskSL) buySL = maxRiskSL;
               
               trade.Buy(finalLotSize, _Symbol, currentAsk, buySL, buyTP, "Local Donchian BUY");
               return true;
            }
            else if(triggerSell)
            {
               double donchianSL = GetStopLossDistance(_Symbol, prevClose, currentATR);
               double donchianTP = donchianSL * InpTargetMult;
               
               double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               double sellSL = currentBid + donchianSL;
               double sellTP = currentBid - donchianTP;
               
               double maxRiskSL = NormalizeDouble(currentBid + (2.0 * g_stopLossDist), _Digits);
               if(sellSL > maxRiskSL) sellSL = maxRiskSL;
               
               trade.Sell(finalLotSize, _Symbol, currentBid, sellSL, sellTP, "Local Donchian SELL");
               return true;
            }
         }
         return false;
      }

      // --- Fallback: Standard Trending Breakout Mode (Stop Orders) ---
      if(InpUseATRFilter && currentATR < g_minATR) return false;
      
      if(InpUseVolumeFilter)
      {
         long prevVolume = iVolume(_Symbol, _Period, 1);
         long volumeSum = 0;
         for(int j = 2; j <= 11; j++)
         {
            volumeSum += iVolume(_Symbol, _Period, j);
         }
         double avgVolume = volumeSum / 10.0;
         if(prevVolume < avgVolume) return false;
      }

      bool allowBuy = (g_dailySentiment != "SELL_ONLY");
      bool allowSell = (g_dailySentiment != "BUY_ONLY");
      
      if(aiActive)
      {
         allowBuy  = allowBuy && (StringFind(g_aiDecision, "BUY") >= 0);
         allowSell = allowSell && (StringFind(g_aiDecision, "SELL") >= 0);
      }
      else
      {
         if(InpUseEMAFilter)
         {
            allowBuy = allowBuy && (prevClose > currentEMA);
            allowSell = allowSell && (prevClose < currentEMA);
         }
         
         if(InpUseMTFTrendFilter)
         {
            double emaHighVal[];
            ArraySetAsSeries(emaHighVal, true);
            if(CopyBuffer(g_emaHigherHandle, 0, 1, 1, emaHighVal) > 0)
            {
               double higherEMA = emaHighVal[0];
               double higherClose = iClose(_Symbol, GetHigherTimeframe(), 1);
               allowBuy  = allowBuy && (higherClose > higherEMA);
               allowSell = allowSell && (higherClose < higherEMA);
            }
         }

         if(InpUseRSIFilter)
         {
            allowBuy  = allowBuy && (currentRSI < 70.0);
            allowSell = allowSell && (currentRSI > 30.0);
         }
      }

      bool orderPlaced = false;
      if(allowBuy)
      {
         double buyStopPrice  = NormalizeDouble(prevHigh + g_priceOffset + spread, _Digits);
         double buySL         = (structuralSL > 0.0) ? structuralSL : NormalizeDouble(buyStopPrice - g_stopLossDist, _Digits);
         double buyTP         = (structuralTP > 0.0) ? structuralTP : ((g_takeProfitDist > 0.0) ? NormalizeDouble(buyStopPrice + g_takeProfitDist, _Digits) : 0.0);
         
         double maxRiskSL = NormalizeDouble(buyStopPrice - (2.0 * g_stopLossDist), _Digits);
         if(buySL < maxRiskSL) buySL = maxRiskSL;
         
         trade.BuyStop(finalLotSize, buyStopPrice, _Symbol, buySL, buyTP, ORDER_TIME_GTC, 0, "AI Buy Stop Breakout");
         orderPlaced = true;
      }
      
      if(allowSell)
      {
         double sellStopPrice = NormalizeDouble(prevLow - g_priceOffset, _Digits);
         double sellSL        = (structuralSL > 0.0) ? structuralSL : NormalizeDouble(sellStopPrice + g_stopLossDist, _Digits);
         double sellTP        = (structuralTP > 0.0) ? structuralTP : ((g_takeProfitDist > 0.0) ? NormalizeDouble(sellStopPrice - g_takeProfitDist, _Digits) : 0.0);
         
         double maxRiskSL = NormalizeDouble(sellStopPrice + (2.0 * g_stopLossDist), _Digits);
         if(sellSL > maxRiskSL) sellSL = maxRiskSL;
         
         trade.SellStop(finalLotSize, sellStopPrice, _Symbol, sellSL, sellTP, ORDER_TIME_GTC, 0, "AI Sell Stop Breakout");
         orderPlaced = true;
      }
      
      if(orderPlaced)
      {
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Query Google Gemini and Groq APIs to verify keys on startup      |
//+------------------------------------------------------------------+
void TestAIEngines()
{
   bool success = false;
   string name = "";
   
   if(InpAIEngineSelection == AI_GROQ)
   {
      name = "Groq Llama-3.1";
      string resp = "";
      success = QueryGroqDirect("Respond strictly with status OK in json format. Example: {\"status\":\"OK\"}", resp);
   }
   else if(InpAIEngineSelection == AI_GEMINI)
   {
      name = "Gemini Flash";
      string resp = "";
      success = QueryGeminiDirect("Respond strictly with status OK in json format. Example: {\"status\":\"OK\"}", resp);
   }
   else if(InpAIEngineSelection == AI_OPENROUTER)
    {
       name = "OpenRouter";
       string resp = "";
       success = QueryOpenRouterDirect("Respond strictly with status OK in json format. Example: {\"status\":\"OK\"}", resp);
    }
    else if(InpAIEngineSelection == AI_BOTH_FAILOVER)
    {
       name = "OpenRouter & Groq (Failover)";
       string resp = "";
       bool openrouterSuccess = QueryOpenRouterDirect("Respond strictly with status OK in json format. Example: {\"status\":\"OK\"}", resp);
       bool groqSuccess = QueryGroqDirect("Respond strictly with status OK in json format. Example: {\"status\":\"OK\"}", resp);
       success = openrouterSuccess || groqSuccess;
       if(openrouterSuccess) g_aiReason = "OpenRouter API OK";
       else if(groqSuccess) g_aiReason = "Groq API OK (OpenRouter Offline)";
    }
   
   if(success)
   {
      g_aiDecision = "WAITING";
      if(InpAIEngineSelection != AI_BOTH_FAILOVER)
      {
         g_aiReason = name + " OK";
      }
   }
   else
   {
      g_aiDecision = "API ERROR";
      g_aiReason = name + " Offline";
   }
}

//+------------------------------------------------------------------+
//| Expert initialization presets and indicators loading             |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("[GoldEngine] INITIALIZED: Supreme AI Version with EscapeJSONString & uchar buffers.");

   g_openRouterAPIKey = InpOpenRouterAPIKey;
   g_groqAPIKey = InpGroqAPIKey;
   
   if(g_openRouterAPIKey == "" || g_groqAPIKey == "")
   {
      int fileHandle = FileOpen("GoldEngine_API_Keys.txt", FILE_READ|FILE_TXT|FILE_ANSI);
      if(fileHandle != INVALID_HANDLE)
      {
         string fileContent = FileReadString(fileHandle);
         FileClose(fileHandle);
         
         int pipeIdx = StringFind(fileContent, "|");
         if(pipeIdx >= 0)
         {
            if(g_openRouterAPIKey == "") g_openRouterAPIKey = StringSubstr(fileContent, 0, pipeIdx);
            if(g_groqAPIKey == "") g_groqAPIKey = StringSubstr(fileContent, pipeIdx + 1);
            StringTrimLeft(g_openRouterAPIKey); StringTrimRight(g_openRouterAPIKey);
            StringTrimLeft(g_groqAPIKey); StringTrimRight(g_groqAPIKey);
         }
      }
   }
   

   trade.SetExpertMagicNumber(InpMagicNumber);
   g_lastBarTime = 0;
   g_lastOrderPlacedBarTime = 0;
   g_lastDay = 0;
   g_spreadCount = 0;
   ArrayInitialize(g_spreadBuffer, 0.0);
   
   // 1. Initialize Indicators first
   g_emaHandle = iMA(_Symbol, _Period, 50, 0, MODE_EMA, PRICE_CLOSE);
   g_emaHigherHandle = iMA(_Symbol, GetHigherTimeframe(), 50, 0, MODE_EMA, PRICE_CLOSE);
   g_atrHandle = iATR(_Symbol, _Period, 14);
   g_rsiHandle = iRSI(_Symbol, _Period, 14, PRICE_CLOSE);
   g_adxHandle = iADX(_Symbol, _Period, 14);
   g_ema200Handle = iMA(_Symbol, _Period, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_ema9Handle   = iMA(_Symbol, _Period, InpEMA9Length, 0, MODE_EMA, PRICE_CLOSE);
   g_ema200M15Handle = iMA(_Symbol, PERIOD_M15, 200, 0, MODE_EMA, PRICE_CLOSE);
   g_ema200H1Handle = iMA(_Symbol, PERIOD_H1, 200, 0, MODE_EMA, PRICE_CLOSE);
   g_ema200H4Handle = iMA(_Symbol, PERIOD_H4, 200, 0, MODE_EMA, PRICE_CLOSE);
   
   if(g_emaHandle == INVALID_HANDLE || g_emaHigherHandle == INVALID_HANDLE || 
      g_atrHandle == INVALID_HANDLE || g_rsiHandle == INVALID_HANDLE || g_adxHandle == INVALID_HANDLE ||
      g_ema200Handle == INVALID_HANDLE || g_ema9Handle == INVALID_HANDLE)
   {
      Print("[V10 INIT ERROR] Failed to initialize indicators.");
      return(INIT_FAILED);
   }
   
   // 2. Load presets safely
   LoadTimeframePresets();
   
   // 3. Create UI elements (clean up old cached objects to force layout recalculations)
   ObjectsDeleteAll(0, "Db");
   ObjectDelete(0, "BtnEAToggle");
   CreateInterface();
   
   // 4. Test AI Engines connection live on startup
   TestAIEngines();
   
   // 5. Fetch Economic Calendar and establish initial Daily Sentiment Anchor
   FetchEconomicCalendar();
   QueryAIDailySentiment();
   g_lastH1BarTime = iTime(_Symbol, PERIOD_H1, 0);
   QueryAIH1MacroBias();
   
   MqlDateTime dt;
   TimeCurrent(dt);
   g_lastDay = dt.day;
   
   CleanUpVisualBoxes();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   CleanUpVisualBoxes();
   Comment(""); 
   IndicatorRelease(g_emaHandle);
   IndicatorRelease(g_emaHigherHandle);
   IndicatorRelease(g_atrHandle);
   IndicatorRelease(g_rsiHandle);
   IndicatorRelease(g_adxHandle);
   IndicatorRelease(g_ema200Handle);
   IndicatorRelease(g_ema9Handle);
   IndicatorRelease(g_ema200H4Handle);
   
   // Delete UI elements
   ObjectDelete(0, "DbPanelBg");
   ObjectDelete(0, "DbTitle");
   ObjectDelete(0, "DbTimeframe");
   ObjectDelete(0, "DbLotSize");
   ObjectDelete(0, "DbADX");
   ObjectDelete(0, "DbATR");
   ObjectDelete(0, "DbMode");
   ObjectDelete(0, "DbSL");
   ObjectDelete(0, "DbBias");
   ObjectDelete(0, "DbDecision");
   ObjectDelete(0, "DbConviction");
   ObjectDelete(0, "DbReason");
   ObjectDelete(0, "BtnEAToggle");
   
   ObjectDelete(0, "MagnetHighLine");
   ObjectDelete(0, "MagnetLowLine");
}

//+------------------------------------------------------------------+
//| Chart Event Handler                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_DRAG)
   {
      if(sparam == "DbPanelBg")
      {
         g_dbX = (int)ObjectGetInteger(0, "DbPanelBg", OBJPROP_XDISTANCE);
         g_dbY = (int)ObjectGetInteger(0, "DbPanelBg", OBJPROP_YDISTANCE);
         CreateInterface();
         ChartRedraw();
      }
   }
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == "BtnEAToggle")
      {
         g_eaRunning = !g_eaRunning;
         UpdateButtonState();
         ChartRedraw();
      }
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Manage AI-Guided Hedging Recovery Basket                          |
//+------------------------------------------------------------------+
void ManageHedgeRecovery()
{
   if(!InpEnableHedgeRecovery) return;
   
   ulong primaryTicket = 0;
   ulong hedgeTicket = 0;
   ulong recoveryTicket = 0;
   
   double primaryLots = 0.0;
   double primaryProfit = 0.0;
   double primaryEntry = 0.0;
   ENUM_POSITION_TYPE primaryType = POSITION_TYPE_BUY;
   
   double hedgeLots = 0.0;
   double hedgeProfit = 0.0;
   
   double recoveryLots = 0.0;
   double recoveryProfit = 0.0;
   
   int totalPositions = PositionsTotal();
   for(int i = 0; i < totalPositions; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
      {
         string comment = PositionGetString(POSITION_COMMENT);
             bool isSwingPosition = (comment == "GE_SWING");
         if(comment == "HEDGE_FREEZE")
         {
            hedgeTicket = ticket;
            hedgeLots = PositionGetDouble(POSITION_VOLUME);
            hedgeProfit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         }
         else if(comment == "RECOVERY_ENTRY")
         {
            recoveryTicket = ticket;
            recoveryLots = PositionGetDouble(POSITION_VOLUME);
            recoveryProfit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         }
         else
         {
            if(primaryTicket == 0)
            {
               primaryTicket = ticket;
               primaryLots = PositionGetDouble(POSITION_VOLUME);
               primaryProfit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
               primaryEntry = PositionGetDouble(POSITION_PRICE_OPEN);
               primaryType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            }
         }
      }
   }
   
   // Safety Guardian: If primary trade is closed, clean up any remaining hedge/recovery positions
   if(primaryTicket == 0)
   {
      if(hedgeTicket > 0)
      {
         trade.PositionClose(hedgeTicket);
         Print("[Hedge Recovery] Orphaned hedge trade closed.");
      }
      if(recoveryTicket > 0)
      {
         trade.PositionClose(recoveryTicket);
         Print("[Hedge Recovery] Orphaned recovery trade closed.");
      }
      g_hedgeActive = false;
      g_hedgeTicket = 0;
      g_recoveryActive = false;
      g_recoveryTicket = 0;
      return;
   }
   
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   // --- Phase 1: Trigger the Hedge Freeze ---
   if(primaryTicket > 0 && hedgeTicket == 0)
   {
      double drawdownPoints = 0.0;
      if(primaryType == POSITION_TYPE_BUY)
         drawdownPoints = primaryEntry - currentBid;
      else
         drawdownPoints = currentAsk - primaryEntry;
         
      if(drawdownPoints >= InpHedgeDrawdownThreshold)
      {
         PrintFormat("[Hedge Recovery] Primary trade %.2f lots in drawdown: %.2f points. Placing Hedge Freeze...", primaryLots, drawdownPoints);
         
         // Place opposite trade
         if(primaryType == POSITION_TYPE_BUY)
         {
            trade.Sell(primaryLots, _Symbol, currentBid, 0.0, 0.0, "HEDGE_FREEZE");
         }
         else
         {
            trade.Buy(primaryLots, _Symbol, currentAsk, 0.0, 0.0, "HEDGE_FREEZE");
         }
         
         // Remove/Widen SL of primary trade to prevent stop-out
         trade.PositionModify(primaryTicket, 0.0, 0.0);
         g_hedgeActive = true;
         return;
      }
   }
   
   // --- Phase 2: Trigger the Recovery Trade at GNN ceilings/floors ---
   if(primaryTicket > 0 && hedgeTicket > 0 && recoveryTicket == 0)
   {
      g_hedgeActive = true;
      bool triggerRecovery = false;
      
      // AI indicates turn-around in the primary direction
      if(g_aiDecision == (primaryType == POSITION_TYPE_BUY ? "BUY" : "SELL") && g_aiConviction >= 70)
      {
         triggerRecovery = true;
      }
      
      if(triggerRecovery)
      {
         double recoveryVol = NormalizeDouble(primaryLots * InpRecoveryLotMultiplier, 2);
         double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         if(recoveryVol < minVol) recoveryVol = minVol;
         
         PrintFormat("[Hedge Recovery] AI Reversal setup confirmed. Placing Recovery trade %.2f lots...", recoveryVol);
         if(primaryType == POSITION_TYPE_BUY)
         {
            trade.Buy(recoveryVol, _Symbol, currentAsk, 0.0, 0.0, "RECOVERY_ENTRY");
         }
         else
         {
            trade.Sell(recoveryVol, _Symbol, currentBid, 0.0, 0.0, "RECOVERY_ENTRY");
         }
         g_recoveryActive = true;
         return;
      }
   }
   
   // --- Phase 3: Monitor Basket Profit and Close Out ---
   if(primaryTicket > 0 && hedgeTicket > 0 && recoveryTicket > 0)
   {
      g_hedgeActive = true;
      g_recoveryActive = true;
      
      double netBasketProfit = primaryProfit + hedgeProfit + recoveryProfit;
      if(netBasketProfit >= InpMinBasketProfit)
      {
         PrintFormat("[Hedge Recovery] Basket Profit hit targets: $%.2f. Closing all positions...", netBasketProfit);
         trade.PositionClose(primaryTicket);
         trade.PositionClose(hedgeTicket);
         trade.PositionClose(recoveryTicket);
         
         g_hedgeActive = false;
         g_hedgeTicket = 0;
         g_recoveryActive = false;
         g_recoveryTicket = 0;
      }
   }
}



//+------------------------------------------------------------------+
//| Get Latest Unmitigated Fair Value Gap (FVG)                       |
//+------------------------------------------------------------------+
void GetLatestUnmitigatedFVG(double &fvgLow, double &fvgHigh, int &fvgType)
{
   fvgLow = 0.0;
   fvgHigh = 0.0;
   fvgType = 0;
   
   for(int i = 2; i < 30; i++)
   {
      double low1 = iLow(_Symbol, _Period, i);
      double high1 = iHigh(_Symbol, _Period, i);
      
      double low3 = iLow(_Symbol, _Period, i+2);
      double high3 = iHigh(_Symbol, _Period, i+2);
      
      // Check Bullish FVG
      if(low1 > high3)
      {
         bool mitigated = false;
         for(int j = i - 1; j >= 1; j--)
         {
            if(iLow(_Symbol, _Period, j) <= high3)
            {
               mitigated = true;
               break;
            }
         }
         if(!mitigated)
         {
            fvgLow = high3;
            fvgHigh = low1;
            fvgType = 1; // Bullish FVG
            return;
         }
      }
      
      // Check Bearish FVG
      if(high1 < low3)
      {
         bool mitigated = false;
         for(int j = i - 1; j >= 1; j--)
         {
            if(iHigh(_Symbol, _Period, j) >= low3)
            {
               mitigated = true;
               break;
            }
         }
         if(!mitigated)
         {
            fvgLow = high1;
            fvgHigh = low3;
            fvgType = -1; // Bearish FVG
            return;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Get Nearest Unmitigated Institutional Order Blocks (OB)          |
//+------------------------------------------------------------------+
void GetNearestOrderBlocks(double &bullOB_Low, double &bullOB_High, double &bearOB_Low, double &bearOB_High)
{
   bullOB_Low = 0.0;
   bullOB_High = 0.0;
   bearOB_Low = 0.0;
   bearOB_High = 0.0;
   
   double atrVal[];
   ArraySetAsSeries(atrVal, true);
   if(CopyBuffer(g_atrHandle, 0, 1, 1, atrVal) <= 0) return;
   double currentATR = atrVal[0];
   
   for(int i = 2; i < 40; i++)
   {
      double o = iOpen(_Symbol, _Period, i);
      double h = iHigh(_Symbol, _Period, i);
      double l = iLow(_Symbol, _Period, i);
      double c = iClose(_Symbol, _Period, i);
      
      // 1. Check Bullish Order Block (bearish candle followed by strong bullish impulse)
      if(c < o && bullOB_Low == 0.0)
      {
         bool impulseFound = false;
         for(int j = i - 1; j >= MathMax(1, i - 3); j--)
         {
            double jo = iOpen(_Symbol, _Period, j);
            double jc = iClose(_Symbol, _Period, j);
            if(jc > jo && (jc - jo) >= 1.2 * currentATR)
            {
               impulseFound = true;
               break;
            }
         }
         
         if(impulseFound)
         {
            bool mitigated = false;
            for(int k = i - 1; k >= 1; k--)
            {
               if(iLow(_Symbol, _Period, k) < l)
               {
                  mitigated = true;
                  break;
               }
            }
            if(!mitigated)
            {
               bullOB_Low = l;
               bullOB_High = h;
            }
         }
      }
      
      // 2. Check Bearish Order Block (bullish candle followed by strong bearish impulse)
      if(c > o && bearOB_Low == 0.0)
      {
         bool impulseFound = false;
         for(int j = i - 1; j >= MathMax(1, i - 3); j--)
         {
            double jo = iOpen(_Symbol, _Period, j);
            double jc = iClose(_Symbol, _Period, j);
            if(jc < jo && (jo - jc) >= 1.2 * currentATR)
            {
               impulseFound = true;
               break;
            }
         }
         
         if(impulseFound)
         {
            bool mitigated = false;
            for(int k = i - 1; k >= 1; k--)
            {
               if(iHigh(_Symbol, _Period, k) > h)
               {
                  mitigated = true;
                  break;
               }
            }
            if(!mitigated)
            {
               bearOB_Low = l;
               bearOB_High = h;
            }
         }
      }
      
      if(bullOB_Low > 0.0 && bearOB_Low > 0.0) break;
   }
}


//+------------------------------------------------------------------+
//| Check if current price is trapped inside GNN golden/aqua channel |
//+------------------------------------------------------------------+
bool IsInsideGNNChannel()
{
   double nearestHighs[];
   double nearestLows[];
   string dummy = "";
   GetUntestedMagnets(nearestHighs, nearestLows, dummy);
   
   if(ArraySize(nearestHighs) > 0 && ArraySize(nearestLows) > 0)
   {
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(currentPrice >= nearestLows[0] && currentPrice <= nearestHighs[0])
      {
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Manage Sideways Escape (Exit at break-even in rangebound market) |
//+------------------------------------------------------------------+
void ManageSidewaysEscape(bool reversionModeActive)
{
   bool isSidewaysRegime = reversionModeActive || IsInsideGNNChannel();
   if(!isSidewaysRegime) return;
   
   int totalPositions = PositionsTotal();
   for(int i = totalPositions - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
      {
         string comment = PositionGetString(POSITION_COMMENT);
             bool isSwingPosition = (comment == "GE_SWING");
         if(comment == "HEDGE_FREEZE" || comment == "RECOVERY_ENTRY" || comment == "GE_SWING") continue;
         
         datetime posTime = (datetime)PositionGetInteger(POSITION_TIME);
         if(TimeCurrent() - posTime >= PeriodSeconds(_Period))
         {
            double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
            if(profit >= 0.20)
            {
               PrintFormat("[Sideways Escape] Position #%I64u has been open for > 1 bar. Profit: $%.2f. Closing at range center...", ticket, profit);
               trade.PositionClose(ticket);
            }
         }
      }
   }
}


//+------------------------------------------------------------------+
//| Check Mid-Candle Event Triggers for AI Queries                   |
//+------------------------------------------------------------------+
void CheckMidCandleTriggers(datetime currentBarTime)
{
   if(!InpUseAIEngines || !g_eaRunning) return;
   if(CountActiveTrades() >= InpMaxConcurrentTrades) return;
   
   if(g_midCandleQueried || (TimeCurrent() - g_lastAICallTime < 30)) return;
   
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   bool triggerAI = false;
   string triggerReason = "";
   
   double nearestHighs[];
   double nearestLows[];
   string dummy = "";
   GetUntestedMagnets(nearestHighs, nearestLows, dummy);
   
   if(ArraySize(nearestLows) > 0 && MathAbs(currentBid - nearestLows[0]) <= 0.20)
   {
      triggerAI = true;
      triggerReason = StringFormat("GNN Aqua Support Floor Touch at %.2f", nearestLows[0]);
   }
   else if(ArraySize(nearestHighs) > 0 && MathAbs(currentAsk - nearestHighs[0]) <= 0.20)
   {
      triggerAI = true;
      triggerReason = StringFormat("GNN Golden Resistance Ceiling Touch at %.2f", nearestHighs[0]);
   }
   
   if(!triggerAI)
   {
      double bullOB_Low = 0.0, bullOB_High = 0.0;
      double bearOB_Low = 0.0, bearOB_High = 0.0;
      GetNearestOrderBlocks(bullOB_Low, bullOB_High, bearOB_Low, bearOB_High);
      
      if(bullOB_High > 0.0 && currentBid >= bullOB_Low && currentBid <= bullOB_High)
      {
         triggerAI = true;
         triggerReason = StringFormat("Institutional Demand (Bullish OB) Entry at %.2f", currentBid);
      }
      else if(bearOB_Low > 0.0 && currentAsk >= bearOB_Low && currentAsk <= bearOB_High)
      {
         triggerAI = true;
         triggerReason = StringFormat("Institutional Supply (Bearish OB) Entry at %.2f", currentAsk);
      }
   }
   
   if(!triggerAI)
   {
      double fvgLow = 0.0, fvgHigh = 0.0;
      int fvgType = 0;
      GetLatestUnmitigatedFVG(fvgLow, fvgHigh, fvgType);
      
      if(fvgType == 1 && currentBid >= fvgLow && currentBid <= fvgHigh)
      {
         triggerAI = true;
         triggerReason = StringFormat("Bullish FVG Imbalance Entry at %.2f", currentBid);
      }
      else if(fvgType == -1 && currentAsk >= fvgLow && currentAsk <= fvgHigh)
      {
         triggerAI = true;
         triggerReason = StringFormat("Bearish FVG Imbalance Entry at %.2f", currentAsk);
      }
   }
   
   if(triggerAI)
   {
      g_midCandleQueried = true;
      g_lastAICallTime = TimeCurrent();
      PrintFormat("[Mid-Candle Trigger] Event: %s. Querying AI Brain mid-candle...", triggerReason);
      if(ExecuteNewOrderPlacement(currentBarTime, true))
      {
         SaveReasoningForNewPosition(g_lastAIResponseText);
      }
   }
}


//+------------------------------------------------------------------+
//| Check Multi-Timeframe Trend Confluence (Tide Guard)              |
//+------------------------------------------------------------------+
bool CheckTrendConfluence(string decision)
{
   if(!InpUseMTFTrendFilter) return true;
   double ema200Val[];
   if(CopyBuffer(g_ema200Handle, 0, 1, 1, ema200Val) <= 0) return false;
   double prevCloseVal = iClose(_Symbol, _Period, 1);
   int trendCurrent = (prevCloseVal > ema200Val[0]) ? 1 : -1;
   
   double ema200M15Val[];
   if(CopyBuffer(g_ema200M15Handle, 0, 1, 1, ema200M15Val) <= 0) return false;
   double closeM15 = iClose(_Symbol, PERIOD_M15, 1);
   int trendM15 = (closeM15 > ema200M15Val[0]) ? 1 : -1;
   
   double ema200H1Val[];
   if(CopyBuffer(g_ema200H1Handle, 0, 1, 1, ema200H1Val) <= 0) return false;
   double closeH1 = iClose(_Symbol, PERIOD_H1, 1);
   int trendH1 = (closeH1 > ema200H1Val[0]) ? 1 : -1;
   
   int bullishCount = 0;
   if(trendCurrent == 1) bullishCount++;
   if(trendM15 == 1) bullishCount++;
   if(trendH1 == 1) bullishCount++;
   
   if(decision == "BUY" && bullishCount < 2)
   {
      PrintFormat("[Tide Guard Block] BUY rejected. Bullish confluence: %d/3 (Current: %s, M15: %s, H1: %s)", 
         bullishCount, (trendCurrent==1)?"UP":"DN", (trendM15==1)?"UP":"DN", (trendH1==1)?"UP":"DN");
      return false;
   }
   if(decision == "SELL" && bullishCount > 1)
   {
      PrintFormat("[Tide Guard Block] SELL rejected. Bearish confluence: %d/3 (Current: %s, M15: %s, H1: %s)", 
         3-bullishCount, (trendCurrent==-1)?"DN":"UP", (trendM15==-1)?"DN":"UP", (trendH1==-1)?"DN":"UP");
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Draw FVG and OB colored boxes on chart                           |
//+------------------------------------------------------------------+
void DrawICTVisualBoxes()
{
   int total = ObjectsTotal(0, 0, OBJ_RECTANGLE);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, OBJ_RECTANGLE);
      if(StringFind(name, "GE_OB_") == 0 || StringFind(name, "GE_FVG_") == 0)
      {
         ObjectDelete(0, name);
      }
   }
   
   double fvgLow = 0.0, fvgHigh = 0.0;
   int fvgType = 0;
   GetLatestUnmitigatedFVG(fvgLow, fvgHigh, fvgType);
   
   double bullOB_Low = 0.0, bullOB_High = 0.0;
   double bearOB_Low = 0.0, bearOB_High = 0.0;
   GetNearestOrderBlocks(bullOB_Low, bullOB_High, bearOB_Low, bearOB_High);
   
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   datetime extendTime = currentBarTime + PeriodSeconds(_Period) * 8;
   
   if(fvgType != 0)
   {
      string name = StringFormat("GE_FVG_%s", (fvgType == 1)?"BULL":"BEAR");
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, currentBarTime - PeriodSeconds(_Period)*10, fvgLow, extendTime, fvgHigh);
      ObjectSetInteger(0, name, OBJPROP_COLOR, (fvgType == 1) ? C'0x15,0x40,0x80' : C'0x80,0x15,0x40');
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
   }
   
   if(bullOB_High > 0.0)
   {
      string name = "GE_OB_BULL";
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, currentBarTime - PeriodSeconds(_Period)*20, bullOB_Low, extendTime, bullOB_High);
      ObjectSetInteger(0, name, OBJPROP_COLOR, C'0x0C,0x40,0x0C');
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
   }
   
   if(bearOB_High > 0.0)
   {
      string name = "GE_OB_BEAR";
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, currentBarTime - PeriodSeconds(_Period)*20, bearOB_Low, extendTime, bearOB_High);
      ObjectSetInteger(0, name, OBJPROP_COLOR, C'0x40,0x0C,0x0C');
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
   }
}


//+------------------------------------------------------------------+
//| Clean up any leftover visual FVG/OB rectangles from the chart    |
//+------------------------------------------------------------------+
void CleanUpVisualBoxes()
{
   ObjectsDeleteAll(0, "GE_OB_");
   ObjectsDeleteAll(0, "GE_FVG_");
   ObjectsDeleteAll(0, "GE_OB");
   ObjectsDeleteAll(0, "GE_FVG");
   
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, "GE_") >= 0 || StringFind(name, "OB") >= 0 || StringFind(name, "FVG") >= 0)
      {
         ObjectDelete(0, name);
      }
   }
}

void OnTick()
{
   // Process AI Hedging Recovery
   ManageHedgeRecovery();

   UpdateSpreadBuffer();
   LoadTimeframePresets();

   if(VerifyTimeframeMismatch())
   {
      return;
   }

   ManageActivePositions();

   double emaVal[];
   double atrVal[];
   double rsiVal[];
   double adxVal[];
   ArraySetAsSeries(emaVal, true);
   ArraySetAsSeries(atrVal, true);
   ArraySetAsSeries(rsiVal, true);
   ArraySetAsSeries(adxVal, true);
   
   double currentADX = 0.0;
   double currentATR = 0.0;
   bool useReversionMode = false;
   
   if(CopyBuffer(g_emaHandle, 0, 1, 1, emaVal) > 0 && 
      CopyBuffer(g_atrHandle, 0, 1, 1, atrVal) > 0 &&
      CopyBuffer(g_rsiHandle, 0, 1, 1, rsiVal) > 0 &&
      CopyBuffer(g_adxHandle, 0, 1, 1, adxVal) > 0)
   {
      currentADX = adxVal[0];
      currentATR = atrVal[0];
      
      MqlDateTime dt;
      TimeCurrent(dt);
      
      // Update Daily Sentiment Anchor on new calendar day
      if(dt.day != g_lastDay)
      {
         g_lastDay = dt.day;
         FetchEconomicCalendar();
         QueryAIDailySentiment();
         g_lastH1BarTime = iTime(_Symbol, PERIOD_H1, 0);
         QueryAIH1MacroBias();
      }
      
      datetime h1BarTime = iTime(_Symbol, PERIOD_H1, 0);
      if(h1BarTime != g_lastH1BarTime)
      {
         g_lastH1BarTime = h1BarTime;
         QueryAIH1MacroBias();
      }
      
      bool isMomentumHour = false;
      if(dt.hour >= InpLondonStartHour && dt.hour < InpLondonEndHour)
      {
         isMomentumHour = true;
      }
      int currentMinutesSinceMidnight = dt.hour * 60 + dt.min;
      int nyStartMinutes = InpNYStartHour * 60 + InpNYStartMin;
      int nyEndMinutes = InpNYEndHour * 60 + InpNYEndMin;
      if(currentMinutesSinceMidnight >= nyStartMinutes && currentMinutesSinceMidnight < nyEndMinutes)
      {
         isMomentumHour = true;
      }
      
      double atrSum = 0.0;
      int atrCount = 0;
      for(int j = 2; j <= 11; j++)
      {
         double atrTemp[];
         ArraySetAsSeries(atrTemp, true);
         if(CopyBuffer(g_atrHandle, 0, j, 1, atrTemp) > 0)
         {
            atrSum += atrTemp[0];
            atrCount++;
         }
      }
      double avgATR = (atrCount > 0) ? (atrSum / atrCount) : currentATR;
      bool isVolatilitySpike = (avgATR > 0.0 && currentATR > 1.4 * avgATR);
      bool aiActive = (g_dailySentiment != "WAITING");
      useReversionMode = CalculateReversionMode(currentADX, isMomentumHour, isVolatilitySpike, aiActive, g_aiRegime);
   }
   
   // Keep dashboard drawn and updated on every tick
   DrawChartStatus(currentADX, currentATR, useReversionMode);
   
   // Process Sideways Escape
   ManageSidewaysEscape(useReversionMode);

   // Check if EA is paused by the on-chart button
   if(!g_eaRunning)
   {
      CancelPendingOrdersEx(true);
      return;
   }

   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   bool isNewBar = (currentBarTime != g_lastBarTime);
   
   if(isNewBar)
   {

      if(g_lastBarTime != 0)
      {
         ManageCandleCloseLossCutting(useReversionMode);
         
         // Trigger AI active trade management dynamically on candle close
         if(CountActiveTrades() > 0)
         {
            QueryAIActiveTradeManagement();
         }
      }
      
      g_lastBarTime = currentBarTime;
      CancelPendingOrdersEx(!useReversionMode);
      g_midCandleQueried = false; // Reset mid-candle status for the new bar!
   }

   if(g_eaRunning)
   {
      if(useReversionMode)
      {
         double nearestHighs[];
         double nearestLows[];
         string dummy = "";
         GetUntestedMagnets(nearestHighs, nearestLows, dummy);
         
         double rawBuy = (ArraySize(nearestLows) > 0) ? (nearestLows[0] + InpLimitOffset) : 0.0;
         double targetBuy = (rawBuy > 0.0) ? ((InpPriceRoundStep > 0.0) ? RoundToStep(rawBuy, InpPriceRoundStep) : NormalizeDouble(rawBuy, _Digits)) : 0.0;
         
         double rawSell = (ArraySize(nearestHighs) > 0) ? (nearestHighs[0] - InpLimitOffset) : 0.0;
         double targetSell = (rawSell > 0.0) ? ((InpPriceRoundStep > 0.0) ? RoundToStep(rawSell, InpPriceRoundStep) : NormalizeDouble(rawSell, _Digits)) : 0.0;
         
         VerifyAndSyncSidewaysLimits(targetBuy, targetSell);
      }
      else
      {
         // Clean up sideways limits if we transitioned to trending mode
         CancelPendingOrdersEx(true);
      }
   }

   // Place orders if not yet successfully processed for this candle and no open orders exist
   if(g_eaRunning && g_lastOrderPlacedBarTime != currentBarTime)
   {
      if(CountActiveTrades() < InpMaxConcurrentTrades)
      {
         if(ExecuteNewOrderPlacement(currentBarTime))
         {
            SaveReasoningForNewPosition(g_lastAIResponseText);
         }
      }
   }
   
   // Process Mid-Candle Event-Triggered Entries
   CheckMidCandleTriggers(currentBarTime);
}
//+------------------------------------------------------------------+
