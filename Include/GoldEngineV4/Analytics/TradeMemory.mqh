#ifndef GOLDENGINEV2_TRADE_MEMORY_MQH
#define GOLDENGINEV2_TRADE_MEMORY_MQH

#include "../Strategy/StrategyDefines.mqh"

struct TradeMemoryEntry
{
   ENUM_GEV2_SIGNAL_TYPE Direction;
   string               Session;
   int                  MarketRegime;
   string               Structure;
   int                  Trend;
   double               OpportunityScore;
   double               EntryPrice;
   double               MomentumScore;
   bool                 IsWin;
   int                  HoldTimeSec;
   double               ProfitLoss;
};

class CTradeMemory
{
private:
   TradeMemoryEntry     m_entries[];
   int                  m_count;
   int                  m_maxEntries;
   
   double               m_buyModifier;
   double               m_sellModifier;
   double               m_adaptiveThreshold;
   double               m_baseThreshold;
   int                  m_globalConsecLosses; // V5.5: Global consecutive losses regardless of direction

public:
   CTradeMemory(double baseThreshold = 60.0)
      : m_count(0),
        m_maxEntries(20),
        m_buyModifier(0.0),
        m_sellModifier(0.0),
        m_baseThreshold(baseThreshold),
        m_adaptiveThreshold(baseThreshold),
        m_globalConsecLosses(0)
   {
      ArrayResize(m_entries, 0);
   }
   
   ~CTradeMemory()
   {
      ArrayResize(m_entries, 0);
   }

   double GetBaseThreshold() const { return m_baseThreshold; }
   double GetAdaptiveThreshold() const { return m_adaptiveThreshold; }
   double GetBuyModifier() const { return m_buyModifier; }
   double GetSellModifier() const { return m_sellModifier; }
   int    GetCount() const { return m_count; }
   int    GetGlobalConsecLosses() const { return m_globalConsecLosses; } // V5.5

   double GetWinRate() const
   {
      if(m_count == 0) return 0.0;
      int wins = 0;
      for(int i = 0; i < m_count; i++)
      {
         if(m_entries[i].IsWin) wins++;
      }
      return ((double)wins / m_count) * 100.0;
   }

   void RecordCompletedTrade(const TradeMemoryEntry &entry)
   {
      // Roll array if full
      if(m_count >= m_maxEntries)
      {
         for(int i = 0; i < m_maxEntries - 1; i++)
         {
            m_entries[i] = m_entries[i + 1];
         }
         m_entries[m_maxEntries - 1] = entry;
      }
      else
      {
         m_count++;
         ArrayResize(m_entries, m_count);
         m_entries[m_count - 1] = entry;
      }

      // Update Adaptive Entry Threshold
      if(entry.IsWin)
      {
         m_adaptiveThreshold -= 1.5;
         if(m_adaptiveThreshold < m_baseThreshold - 10.0) m_adaptiveThreshold = m_baseThreshold - 10.0;
         m_globalConsecLosses = 0; // V5.5: reset global streak on any win
      }
      else
      {
         m_adaptiveThreshold += 2.5;
         if(m_adaptiveThreshold > m_baseThreshold + 20.0) m_adaptiveThreshold = m_baseThreshold + 20.0;
         m_globalConsecLosses++; // V5.5: increment global consecutive loss counter
      }

      // Update Adaptive Confidence Modifiers
      UpdateModifiers();
   }

   void UpdateModifiers()
   {
      int buyLosses = 0;
      int sellLosses = 0;
      
      for(int i = m_count - 1; i >= 0; i--)
      {
         if(m_entries[i].Direction == GEV2_SIGNAL_BUY)
         {
            if(!m_entries[i].IsWin) buyLosses++;
            else break;
         }
      }
      
      for(int i = m_count - 1; i >= 0; i--)
      {
         if(m_entries[i].Direction == GEV2_SIGNAL_SELL)
         {
            if(!m_entries[i].IsWin) sellLosses++;
            else break;
         }
      }

      // Calculate directional BUY Modifier
      if(buyLosses >= 5)       m_buyModifier = -30.0;
      else if(buyLosses >= 3)  m_buyModifier = -15.0;
      else                     m_buyModifier = 0.0;

      // Calculate directional SELL Modifier
      if(sellLosses >= 5)      m_sellModifier = -30.0;
      else if(sellLosses >= 3) m_sellModifier = -15.0;
      else                     m_sellModifier = 0.0;

      // V5.5: Additional global consecutive loss penalty (applied to both directions)
      // This handles the 86-streak scenario where directional modifiers alone are insufficient
      double globalPenalty = 0.0;
      if(m_globalConsecLosses >= 20)     globalPenalty = -20.0;
      else if(m_globalConsecLosses >= 10) globalPenalty = -10.0;

      // Apply global penalty on top of directional modifiers (cap at -50 total)
      m_buyModifier  = MathMax(-50.0, m_buyModifier  + globalPenalty);
      m_sellModifier = MathMax(-50.0, m_sellModifier + globalPenalty);
   }

   // Duplicate Setup Detection
   bool DetectDuplicateSetup(ENUM_GEV2_SIGNAL_TYPE dir, double price, int regime, string structure, double momentum, double point) const
   {
      if(m_count == 0) return false;

      int scanCount = MathMin(5, m_count);
      for(int i = m_count - 1; i >= m_count - scanCount; i--)
      {
         if(m_entries[i].Direction == dir &&
            m_entries[i].MarketRegime == regime &&
            m_entries[i].Structure == structure)
         {
            // Similar price zone check (within 200 points)
            double priceDiff = MathAbs(m_entries[i].EntryPrice - price) / point;
            // Similar momentum check (within 15.0 points)
            double momDiff = MathAbs(m_entries[i].MomentumScore - momentum);
            
            if(priceDiff <= 200.0 && momDiff <= 15.0)
            {
               return true;
            }
         }
      }
      return false;
   }
};

#endif // GOLDENGINEV2_TRADE_MEMORY_MQH
