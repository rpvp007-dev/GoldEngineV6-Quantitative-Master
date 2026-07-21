//+------------------------------------------------------------------+
//|                                         MarketStructureEngine.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_MARKET_STRUCTURE_ENGINE_MQH
#define GOLDENGINEV2_MARKET_STRUCTURE_ENGINE_MQH

#include "IMarketStructureEngine.mqh"

//+------------------------------------------------------------------+
//| Market Structure Engine Implementation (GITS V2.4)               |
//+------------------------------------------------------------------+
class CMarketStructureEngine : public IMarketStructureEngine
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_tf;
   bool              m_isInitialized;

   // Cache structure prices
   double            m_swingHigh0; // Most recent Swing High
   double            m_swingHigh1; // Previous Swing High
   double            m_swingLow0;  // Most recent Swing Low
   double            m_swingLow1;  // Previous Swing Low
   
   bool              m_bosDetected;
   string            m_bosType;
   bool              m_chochDetected;
   
   string            m_structureDesc;
   string            m_structureState;

public:
   /**
    * @brief Constructor.
    */
   CMarketStructureEngine()
      : m_symbol(""),
        m_tf(PERIOD_CURRENT),
        m_isInitialized(false),
        m_swingHigh0(0.0),
        m_swingHigh1(0.0),
        m_swingLow0(0.0),
        m_swingLow1(0.0),
        m_bosDetected(false),
        m_bosType("NONE"),
        m_chochDetected(false),
        m_structureDesc("Neutral"),
        m_structureState("Range")
   {}

   /**
    * @brief Destructor.
    */
   ~CMarketStructureEngine() {}

   /**
    * @brief Initialize engine.
    */
   virtual bool InitializeEngine(const string symbol, ENUM_TIMEFRAMES tf) override
   {
      m_symbol = symbol;
      m_tf = tf;
      m_isInitialized = true;
      
      Update();
      return true;
   }

   virtual double GetLastSwingHighPrice() override { return m_swingHigh0; }
   virtual double GetLastSwingLowPrice() override { return m_swingLow0; }
   virtual string GetStructureDesc() override { return m_structureDesc; }
   virtual string GetStructureState() override { return m_structureState; }

   virtual double GetSupportLevel(const string symbol, ENUM_TIMEFRAMES tf, int index) override { return m_swingLow0; }
   virtual double GetResistanceLevel(const string symbol, ENUM_TIMEFRAMES tf, int index) override { return m_swingHigh0; }
   
   virtual bool DetectBOS(const string symbol, ENUM_TIMEFRAMES tf, string &outType) override
   {
      outType = m_bosType;
      return m_bosDetected;
   }

   virtual bool DetectCHoCH(const string symbol, ENUM_TIMEFRAMES tf) override
   {
      return m_chochDetected;
   }

   virtual bool HasEqualHighs(int pointsThreshold) override
   {
      if(m_swingHigh0 <= 0.0 || m_swingHigh1 <= 0.0) return false;
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      if(point <= 0.0) return false;
      return (MathAbs(m_swingHigh0 - m_swingHigh1) / point <= pointsThreshold);
   }

   virtual bool HasEqualLows(int pointsThreshold) override
   {
      if(m_swingLow0 <= 0.0 || m_swingLow1 <= 0.0) return false;
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      if(point <= 0.0) return false;
      return (MathAbs(m_swingLow0 - m_swingLow1) / point <= pointsThreshold);
   }

   /**
    * @brief Scans candles to parse swings, BOS, CHoCH, and overall structure states.
    */
   virtual void Update() override
   {
      if(!m_isInitialized) return;

      MqlRates rates[];
      int copied = CopyRates(m_symbol, m_tf, 0, 100, rates);
      if(copied < 10) return;

      // Set series representation: rates[0] is current live, rates[1] is closed bar
      ArraySetAsSeries(rates, true);

      double shPrice0 = 0.0, shPrice1 = 0.0;
      double slPrice0 = 0.0, slPrice1 = 0.0;
      
      int shCount = 0, slCount = 0;

      // Scan starting at shift=2 (excluding boundaries)
      for(int i = 2; i < copied - 2; i++)
      {
         // 1. Swing High Detection (5-bar extreme)
         if(rates[i].high > rates[i-1].high && rates[i].high > rates[i-2].high &&
            rates[i].high > rates[i+1].high && rates[i].high > rates[i+2].high)
         {
            if(shCount == 0)
            {
               shPrice0 = rates[i].high;
               shCount++;
            }
            else if(shCount == 1)
            {
               shPrice1 = rates[i].high;
               shCount++;
            }
         }

         // 2. Swing Low Detection
         if(rates[i].low < rates[i-1].low && rates[i].low < rates[i-2].low &&
            rates[i].low < rates[i+1].low && rates[i].low < rates[i+2].low)
         {
            if(slCount == 0)
            {
               slPrice0 = rates[i].low;
               slCount++;
            }
            else if(slCount == 1)
            {
               slPrice1 = rates[i].low;
               slCount++;
            }
         }

         if(shCount >= 2 && slCount >= 2) break;
      }

      m_swingHigh0 = shPrice0;
      m_swingHigh1 = shPrice1;
      m_swingLow0 = slPrice0;
      m_swingLow1 = slPrice1;

      // Detect BOS & CHoCH (relative to last closed candle close)
      m_bosDetected = false;
      m_bosType = "NONE";
      m_chochDetected = false;

      double close1 = rates[1].close;

      // A Bullish BOS occurs when price closes above previous Swing High
      if(m_swingHigh0 > 0.0 && close1 > m_swingHigh0)
      {
         m_bosDetected = true;
         m_bosType = "BULLISH";
      }
      else if(m_swingLow0 > 0.0 && close1 < m_swingLow0)
      {
         m_bosDetected = true;
         m_bosType = "BEARISH";
      }

      // CHoCH is triggered when there is an aggressive break of the opposite swing structural level
      bool isBullishBias = (m_swingHigh0 > m_swingHigh1 && m_swingLow0 > m_swingLow1);
      bool isBearishBias = (m_swingHigh0 < m_swingHigh1 && m_swingLow0 < m_swingLow1);

      if(isBullishBias && m_swingLow0 > 0.0 && close1 < m_swingLow0)
      {
         m_chochDetected = true; // Trend shifts Bullish . Bearish
      }
      else if(isBearishBias && m_swingHigh0 > 0.0 && close1 > m_swingHigh0)
      {
         m_chochDetected = true; // Trend shifts Bearish . Bullish
      }

      // Build text description
      string highDesc = "Mixed Highs";
      string lowDesc = "Mixed Lows";

      if(m_swingHigh0 > 0.0 && m_swingHigh1 > 0.0)
      {
         if(m_swingHigh0 > m_swingHigh1) highDesc = "HH (Higher High)";
         else if(m_swingHigh0 < m_swingHigh1) highDesc = "LH (Lower High)";
      }

      if(m_swingLow0 > 0.0 && m_swingLow1 > 0.0)
      {
         if(m_swingLow0 > m_swingLow1) lowDesc = "HL (Higher Low)";
         else if(m_swingLow0 < m_swingLow1) lowDesc = "LL (Lower Low)";
      }

      m_structureDesc = highDesc + " | " + lowDesc;

      // Determine structural state
      if(m_bosDetected || m_chochDetected)
      {
         m_structureState = "Transition";
      }
      else if(HasEqualHighs(15) || HasEqualLows(15))
      {
         m_structureState = "Range";
      }
      else if(isBullishBias)
      {
         m_structureState = "Bullish";
      }
      else if(isBearishBias)
      {
         m_structureState = "Bearish";
      }
      else
      {
         m_structureState = "Range";
      }
   }

   virtual bool IsValidInstitutionalEntry(const string symbol, int signalType, double ask, double bid, string &outReason) override
   {
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(point <= 0.0) point = 0.01;

      // 1. Support & Resistance Proximity Guard
      if(signalType == 1) // GEV2_SIGNAL_BUY
      {
         if(m_swingHigh0 > 0.0 && MathAbs(ask - m_swingHigh0) < 50.0 * point)
         {
            outReason = StringFormat("Market Structure Blocked BUY: Price (%.2f) is too close to Resistance Level (%.2f)", ask, m_swingHigh0);
            return false;
         }
      }
      else if(signalType == -1) // GEV2_SIGNAL_SELL
      {
         if(m_swingLow0 > 0.0 && MathAbs(bid - m_swingLow0) < 50.0 * point)
         {
            outReason = StringFormat("Market Structure Blocked SELL: Price (%.2f) is too close to Support Level (%.2f)", bid, m_swingLow0);
            return false;
         }
      }

      // 2. Anti-Counter-Spike Guard
      MqlRates rates[];
      if(CopyRates(symbol, _Period, 0, 4, rates) >= 4)
      {
         ArraySetAsSeries(rates, true);
         for(int i = 1; i <= 3; i++)
         {
            double body = MathAbs(rates[i].close - rates[i].open);
            // If recent candle has a violent 350+ point spike
            if(body >= 350.0 * point)
            {
               if(signalType == 1 && rates[i].close < rates[i].open)
               {
                  outReason = StringFormat("Market Structure Blocked BUY: Fighting recent violent Bearish Spike (%.1f pips)", body / (point * 10.0));
                  return false;
               }
               else if(signalType == -1 && rates[i].close > rates[i].open)
               {
                  outReason = StringFormat("Market Structure Blocked SELL: Fighting recent violent Bullish Spike (%.1f pips)", body / (point * 10.0));
                  return false;
               }
            }
         }
      }

      return true;
   }
};

#endif // GOLDENGINEV2_MARKET_STRUCTURE_ENGINE_MQH
