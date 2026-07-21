//+------------------------------------------------------------------+
//|                                     TradeOptimizationEngine.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_TRADE_OPTIMIZATION_ENGINE_MQH
#define GOLDENGINEV2_TRADE_OPTIMIZATION_ENGINE_MQH

#include "ITradeOptimizationEngine.mqh"
#include "ITradeManager.mqh"
#include "ITradeHealthEngine.mqh"

//--- Helper structure for tracking open trade snapshots
struct OpenTradeSnapshot
{
   ulong    Ticket;
   datetime EntryTime;
   double   EntryScore;
   double   EntryHealth;
   double   MovementScore;
   double   OpportunityScore;
   double   BuyerIntent;
   double   SellerIntent;
   string   MarketRegime;
   string   TrendPhase;
   double   LiquidityStrength;
   double   VolatilityScore;
   double   RelativeVolume;
   string   Session;
   string   TradeClass;
};

//--- Concrete implementation of Trade Optimization Engine
class CTradeOptimizationEngine : public ITradeOptimizationEngine
{
private:
   ITrendEngine*              m_trend;
   IMomentumEngine*           m_momentum;
   IVolatilityEngine*         m_volatility;
   IVolumeEngine*             m_volume;
   ILiquidityEngine*          m_liquidity;
   ISessionEngine*            m_session;
   IMarketStructureEngine*    m_structure;
   IOpportunityEngine*        m_opportunity;
   IMovementEngine*           m_movement;
   IMarketIntentEngine*       m_intent;
   IMarketContextEngine*      m_context;
   ITradeManager*             m_tradeManager;
   ITradeHealthEngine*        m_tradeHealth;

   CConfig*                   m_config;
   bool                       m_isInitialized;

   // Trade databases
   OpenTradeSnapshot          m_openTrades[];
   int                        m_openTradesCount;

   CompletedTradeRecord       m_completedTrades[];
   int                        m_completedTradesCount;

   // Dynamic observations list
   string                     m_observations[];
   int                        m_observationsCount;

   // Performance stats cache
   GITSPerformanceStats       m_stats;

   // Internal calculation helpers
   void                       ScanOpenTrades(const string symbol);
   void                       ProcessTradeClose(ulong ticket, const string symbol);
   void                       CalculateStats();
   void                       DiscoverPatterns();
   string                     EscapeString(string text);

public:
   CTradeOptimizationEngine();
   virtual ~CTradeOptimizationEngine();

   virtual bool Initialize(const QuantEnginesContainer &engines, CConfig* config) override;
   virtual void Update(const string symbol) override;
   virtual GITSPerformanceStats GetPerformanceStats() const override { return m_stats; }
   virtual int GetObservationsCount() const override { return m_observationsCount; }
   virtual string GetObservation(int index) const override;
   virtual void ExportToCSV() override;
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTradeOptimizationEngine::CTradeOptimizationEngine()
   : m_trend(NULL), m_momentum(NULL), m_volatility(NULL), m_volume(NULL),
     m_liquidity(NULL), m_session(NULL), m_structure(NULL), m_opportunity(NULL),
     m_movement(NULL), m_intent(NULL), m_context(NULL), m_tradeManager(NULL),
     m_tradeHealth(NULL), m_config(NULL), m_isInitialized(false),
     m_openTradesCount(0), m_completedTradesCount(0), m_observationsCount(0)
{
   ArrayResize(m_openTrades, 0);
   ArrayResize(m_completedTrades, 0);
   ArrayResize(m_observations, 0);
   ZeroMemory(m_stats);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTradeOptimizationEngine::~CTradeOptimizationEngine()
{
   ArrayResize(m_openTrades, 0);
   ArrayResize(m_completedTrades, 0);
   ArrayResize(m_observations, 0);
}

//+------------------------------------------------------------------+
//| Initializer                                                      |
//+------------------------------------------------------------------+
bool CTradeOptimizationEngine::Initialize(const QuantEnginesContainer &engines, CConfig* config)
{
   m_config       = config;
   m_trend        = engines.Trend;
   m_momentum     = engines.Momentum;
   m_volatility   = engines.Volatility;
   m_volume       = engines.Volume;
   m_liquidity    = engines.Liquidity;
   m_session      = engines.Session;
   m_structure    = engines.MarketStructure;
   m_opportunity  = engines.Opportunity;
   m_movement     = engines.Movement;
   m_intent       = engines.Intent;
   m_context      = engines.MarketContext;
   m_tradeManager = engines.TradeManager;
   m_tradeHealth  = engines.TradeHealth;

   m_isInitialized = (m_config != NULL && m_volatility != NULL && m_volume != NULL && m_session != NULL);
   
   // Set default observations
   ArrayResize(m_observations, 1);
   m_observations[0] = "Awaiting optimization dataset. Need more completed trades.";
   m_observationsCount = 1;

   return m_isInitialized;
}

//+------------------------------------------------------------------+
//| Update tick updates                                              |
//+------------------------------------------------------------------+
void CTradeOptimizationEngine::Update(const string symbol)
{
   if(!m_isInitialized) return;

   // 1. Scan active terminal positions and record new entries
   ScanOpenTrades(symbol);

   // 2. Scan open database and find closed ones
   for(int i = m_openTradesCount - 1; i >= 0; i--)
   {
      ulong ticket = m_openTrades[i].Ticket;
      bool isOpen = false;
      
      int totalPos = PositionsTotal();
      for(int k = 0; k < totalPos; k++)
      {
         if(PositionGetSymbol(k) == symbol && PositionGetInteger(POSITION_TICKET) == (long)ticket)
         {
            isOpen = true;
            break;
         }
      }

      if(!isOpen)
      {
         ProcessTradeClose(ticket, symbol);
         // Remove from open list
         for(int j = i; j < m_openTradesCount - 1; j++)
         {
            m_openTrades[j] = m_openTrades[j + 1];
         }
         m_openTradesCount--;
         ArrayResize(m_openTrades, m_openTradesCount);
      }
   }
}

//+------------------------------------------------------------------+
//| Scans open trades and registers new entries                      |
//+------------------------------------------------------------------+
void CTradeOptimizationEngine::ScanOpenTrades(const string symbol)
{
   int totalPos = PositionsTotal();
   for(int i = 0; i < totalPos; i++)
   {
      if(PositionGetSymbol(i) == symbol && PositionGetInteger(POSITION_MAGIC) == m_config.GetMagicNumber())
      {
         ulong ticket = PositionGetInteger(POSITION_TICKET);
         
         // Check if already tracked
         bool tracked = false;
         for(int k = 0; k < m_openTradesCount; k++)
         {
            if(m_openTrades[k].Ticket == ticket)
            {
               tracked = true;
               break;
            }
         }

         if(!tracked)
         {
            m_openTradesCount++;
            ArrayResize(m_openTrades, m_openTradesCount);
            
            OpenTradeSnapshot snap;
            snap.Ticket = ticket;
            snap.EntryTime = (datetime)PositionGetInteger(POSITION_TIME);
            
            // Query engines for current parameters
            snap.EntryScore = (m_opportunity != NULL) ? m_opportunity.GetOpportunityContext().OpportunityScore : 50.0;
            snap.MovementScore = (m_movement != NULL) ? m_movement.GetMovementContext().MovementScore : 50.0;
            snap.OpportunityScore = snap.EntryScore;
            
            if(m_intent != NULL)
            {
               snap.BuyerIntent = m_intent.GetMarketIntentContext().BuyerIntent;
               snap.SellerIntent = m_intent.GetMarketIntentContext().SellerIntent;
            }
            else
            {
               snap.BuyerIntent = 50.0;
               snap.SellerIntent = 50.0;
            }

            string regimeStr = "TRENDING";
            string phaseStr = "NONE";
            if(m_context != NULL)
            {
               MarketContext ctxVal = m_context.GetContext();
               switch(ctxVal.MarketRegime)
               {
                  case REGIME_TRENDING:    regimeStr = "TRENDING"; break;
                  case REGIME_RANGING:     regimeStr = "RANGING"; break;
                  case REGIME_BREAKOUT:    regimeStr = "BREAKOUT"; break;
                  case REGIME_REVERSAL:    regimeStr = "REVERSAL"; break;
                  case REGIME_COMPRESSION: regimeStr = "COMPRESSION"; break;
                  case REGIME_EXPANSION:   regimeStr = "EXPANSION"; break;
                  case REGIME_TRANSITION:  regimeStr = "TRANSITION"; break;
                  default:                 regimeStr = "UNKNOWN"; break;
               }
               
               switch(ctxVal.TrendPhase)
               {
                  case PHASE_EARLY_TREND:  phaseStr = "EARLY TREND"; break;
                  case PHASE_MATURE_TREND: phaseStr = "MATURE TREND"; break;
                  case PHASE_EXHAUSTION:   phaseStr = "EXHAUSTION"; break;
                  case PHASE_PULLBACK:     phaseStr = "PULLBACK"; break;
                  case PHASE_CONTINUATION: phaseStr = "CONTINUATION"; break;
                  case PHASE_NONE:
                  default:                 phaseStr = "NONE"; break;
               }
            }
            snap.MarketRegime = regimeStr;
            snap.TrendPhase = phaseStr;
            snap.LiquidityStrength = (m_liquidity != NULL) ? m_liquidity.GetLiquidityStrength() : 50.0;
            snap.VolatilityScore = (m_volatility != NULL) ? m_volatility.GetVolatilityScore(symbol, Period()) : 50.0;
            snap.RelativeVolume = (m_volume != NULL) ? m_volume.GetRelativeVolume() : 1.0;
            snap.Session = (m_session != NULL) ? m_session.GetCurrentSession() : "London";
            
            string comment = PositionGetString(POSITION_COMMENT);
            snap.TradeClass = "Scalp";
            if(StringFind(comment, "Probe") >= 0) snap.TradeClass = "Probe";
            else if(StringFind(comment, "Mom") >= 0) snap.TradeClass = "Momentum";
            else if(StringFind(comment, "Runner") >= 0) snap.TradeClass = "Runner";

            snap.EntryHealth = 50.0;
            if(m_tradeManager != NULL)
            {
               for(int j = 0; j < m_tradeManager.GetActiveTrackingCount(); j++)
               {
                  TradeTrackingState tm;
                  if(m_tradeManager.GetTrackingState(j, tm) && tm.Ticket == ticket)
                  {
                     snap.EntryHealth = tm.HealthScore;
                     break;
                  }
               }
            }

            m_openTrades[m_openTradesCount - 1] = snap;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Processes trade close and queries MT5 deal history               |
//+------------------------------------------------------------------+
void CTradeOptimizationEngine::ProcessTradeClose(ulong ticket, const string symbol)
{
   // Find corresponding snapshot
   int idx = -1;
   for(int i = 0; i < m_openTradesCount; i++)
   {
      if(m_openTrades[i].Ticket == ticket)
      {
         idx = i;
         break;
      }
   }
   if(idx < 0) return;

   OpenTradeSnapshot snap = m_openTrades[idx];

   // Query Deals History
   datetime from = snap.EntryTime - 5;
   datetime to = TimeCurrent() + 5;
   
   double profit = 0.0;
   double mfe = 0.0, mae = 0.0;
   string exitReason = "Manual";
   datetime exitTime = TimeCurrent();

   // Pull excursions from Trade Manager before position details are cleared
   if(m_tradeManager != NULL)
   {
      int tmCount = m_tradeManager.GetActiveTrackingCount();
      for(int j = 0; j < tmCount; j++)
      {
         TradeTrackingState tm;
         if(m_tradeManager.GetTrackingState(j, tm) && tm.Ticket == ticket)
         {
            mfe = tm.MaxProfitReachedPoints;
            mae = tm.MaxLossReachedPoints;
            break;
         }
      }
   }

   if(HistorySelect(from, to))
   {
      int deals = HistoryDealsTotal();
      for(int k = 0; k < deals; k++)
      {
         ulong dealTicket = HistoryDealGetTicket(k);
         if(HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID) == (long)ticket)
         {
            long entryType = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
            if(entryType == DEAL_ENTRY_OUT)
            {
               profit += HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
               exitTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
               string dealComment = HistoryDealGetString(dealTicket, DEAL_COMMENT);
               
               if(StringFind(dealComment, "sl") >= 0 || StringFind(dealComment, "s/l") >= 0) exitReason = "SL";
               else if(StringFind(dealComment, "tp") >= 0 || StringFind(dealComment, "t/p") >= 0) exitReason = "TP";
               else exitReason = "Strategy";
            }
         }
      }
   }

   m_completedTradesCount++;
   ArrayResize(m_completedTrades, m_completedTradesCount);

   CompletedTradeRecord rec;
   rec.Ticket = ticket;
   rec.EntryTime = snap.EntryTime;
   rec.ExitTime = exitTime;
   rec.DurationSec = (int)(exitTime - snap.EntryTime);
   rec.EntryScore = snap.EntryScore;
   rec.EntryHealth = snap.EntryHealth;
   rec.MovementScore = snap.MovementScore;
   rec.OpportunityScore = snap.OpportunityScore;
   rec.BuyerIntent = snap.BuyerIntent;
   rec.SellerIntent = snap.SellerIntent;
   rec.MarketRegime = snap.MarketRegime;
   rec.TrendPhase = snap.TrendPhase;
   rec.LiquidityStrength = snap.LiquidityStrength;
   rec.VolatilityScore = snap.VolatilityScore;
   rec.RelativeVolume = snap.RelativeVolume;
   rec.Session = snap.Session;
   rec.TradeClass = snap.TradeClass;
   rec.Profit = (profit >= 0) ? profit : 0.0;
   rec.Loss = (profit < 0) ? -profit : 0.0;
   rec.NetProfit = profit;
   rec.MaxFavorableExcursion = mfe;
   rec.MaxAdverseExcursion = mae;
   rec.ExitReason = exitReason;

   m_completedTrades[m_completedTradesCount - 1] = rec;

   // Run calculations
   CalculateStats();
   DiscoverPatterns();
   ExportToCSV();

   // Log to journal every 100 closed trades
   if(m_completedTradesCount % 100 == 0)
   {
      Print(StringFormat("=== GITS SELF LEARNING OPTIMIZATION SUMMARY (Completed Trades: %d) ===", m_completedTradesCount));
      Print(StringFormat("  Win Rate:       %.1f%%", m_stats.WinRate));
      Print(StringFormat("  Net Profit:     $%.2f", m_stats.NetProfit));
      Print(StringFormat("  Profit Factor:  %.2f", m_stats.ProfitFactor));
      Print(StringFormat("  Expectancy:     %.1f pts", m_stats.Expectancy));
      Print(StringFormat("  Best Session:   %s | Worst Session: %s", m_stats.BestSession, m_stats.WorstSession));
      Print(StringFormat("  Best Regime:    %s | Worst Regime:  %s", m_stats.BestRegime, m_stats.WorstRegime));
      Print("=======================================================================");
   }
}

//+------------------------------------------------------------------+
//| Calculates aggregate statistics                                  |
//+------------------------------------------------------------------+
void CTradeOptimizationEngine::CalculateStats()
{
   if(m_completedTradesCount <= 0) return;

   int wins = 0, losses = 0;
   double totProfit = 0.0, totLoss = 0.0, netProfit = 0.0;
   double sumHoldTime = 0.0;

   // Segment helpers
   string sessions[] = {"LONDON SESSION", "NEW YORK SESSION", "ASIAN SESSION"};
   double sessPnL[3] = {0,0,0};
   int sessTrades[3] = {0,0,0};

   string regimes[] = {"TRENDING", "RANGING", "COMPRESSION"};
   double regPnL[3] = {0,0,0};
   int regTrades[3] = {0,0,0};

   string scoreRanges[] = {"< 30", "30-50", "50-70", "> 70"};
   double scorePnL[4] = {0,0,0,0};
   int scoreTrades[4] = {0,0,0,0};

   string classes[] = {"Scalp", "Probe", "Momentum", "Runner"};
   double classPnL[4] = {0,0,0,0};
   int classTrades[4] = {0,0,0,0};

   string methods[] = {"TP", "SL", "Strategy", "Manual"};
   double methodPnL[4] = {0,0,0,0};
   int methodTrades[4] = {0,0,0,0};

   for(int i = 0; i < m_completedTradesCount; i++)
   {
      CompletedTradeRecord rec = m_completedTrades[i];
      if(rec.NetProfit >= 0)
      {
         wins++;
         totProfit += rec.NetProfit;
      }
      else
      {
         losses++;
         totLoss += rec.Loss;
      }
      netProfit += rec.NetProfit;
      sumHoldTime += rec.DurationSec;

      // Segment Session
      string s = rec.Session;
      if(StringFind(s, "LONDON") >= 0) { sessPnL[0] += rec.NetProfit; sessTrades[0]++; }
      else if(StringFind(s, "NEW YORK") >= 0 || StringFind(s, "NEWYORK") >= 0) { sessPnL[1] += rec.NetProfit; sessTrades[1]++; }
      else { sessPnL[2] += rec.NetProfit; sessTrades[2]++; }

      // Segment Regime
      string r = rec.MarketRegime;
      if(StringFind(r, "TRENDING") >= 0) { regPnL[0] += rec.NetProfit; regTrades[0]++; }
      else if(StringFind(r, "RANGING") >= 0) { regPnL[1] += rec.NetProfit; regTrades[1]++; }
      else { regPnL[2] += rec.NetProfit; regTrades[2]++; }

      // Segment Score
      double sc = rec.EntryScore;
      if(sc < 30.0) { scorePnL[0] += rec.NetProfit; scoreTrades[0]++; }
      else if(sc < 50.0) { scorePnL[1] += rec.NetProfit; scoreTrades[1]++; }
      else if(sc < 70.0) { scorePnL[2] += rec.NetProfit; scoreTrades[2]++; }
      else { scorePnL[3] += rec.NetProfit; scoreTrades[3]++; }

      // Segment Class
      string c = rec.TradeClass;
      if(c == "Scalp") { classPnL[0] += rec.NetProfit; classTrades[0]++; }
      else if(c == "Probe") { classPnL[1] += rec.NetProfit; classTrades[1]++; }
      else if(c == "Momentum") { classPnL[2] += rec.NetProfit; classTrades[2]++; }
      else if(c == "Runner") { classPnL[3] += rec.NetProfit; classTrades[3]++; }

      // Segment Exit Method
      string m = rec.ExitReason;
      if(m == "TP") { methodPnL[0] += rec.NetProfit; methodTrades[0]++; }
      else if(m == "SL") { methodPnL[1] += rec.NetProfit; methodTrades[1]++; }
      else if(m == "Strategy") { methodPnL[2] += rec.NetProfit; methodTrades[2]++; }
      else { methodPnL[3] += rec.NetProfit; methodTrades[3]++; }
   }

   m_stats.TotalTrades = m_completedTradesCount;
   m_stats.WinTrades = wins;
   m_stats.LossTrades = losses;
   m_stats.WinRate = (double)wins / m_completedTradesCount * 100.0;
   m_stats.TotalProfit = totProfit;
   m_stats.TotalLoss = totLoss;
   m_stats.NetProfit = netProfit;
   m_stats.ProfitFactor = (totLoss > 0) ? (totProfit / totLoss) : 99.9;
   m_stats.Expectancy = netProfit / m_completedTradesCount;
   m_stats.AverageHoldTime = sumHoldTime / m_completedTradesCount;

   // Sharpe Ratio Approximation (Net profit vs variance)
   double avgPnL = netProfit / m_completedTradesCount;
   double sumSqDiff = 0.0;
   for(int i = 0; i < m_completedTradesCount; i++)
   {
      sumSqDiff += MathPow(m_completedTrades[i].NetProfit - avgPnL, 2);
   }
   double stdDev = MathSqrt(sumSqDiff / m_completedTradesCount);
   m_stats.SharpeRatio = (stdDev > 0) ? (avgPnL / stdDev) : 0.0;

   // Find Best/Worst Sessions
   m_stats.BestSession = "None"; m_stats.WorstSession = "None";
   double bestSess = -999999.0, worstSess = 999999.0;
   for(int j = 0; j < 3; j++)
   {
      if(sessTrades[j] > 0)
      {
         if(sessPnL[j] > bestSess) { bestSess = sessPnL[j]; m_stats.BestSession = sessions[j]; }
         if(sessPnL[j] < worstSess) { worstSess = sessPnL[j]; m_stats.WorstSession = sessions[j]; }
      }
   }

   // Find Best/Worst Regimes
   m_stats.BestRegime = "None"; m_stats.WorstRegime = "None";
   double bestReg = -999999.0, worstReg = 999999.0;
   for(int j = 0; j < 3; j++)
   {
      if(regTrades[j] > 0)
      {
         if(regPnL[j] > bestReg) { bestReg = regPnL[j]; m_stats.BestRegime = regimes[j]; }
         if(regPnL[j] < worstReg) { worstReg = regPnL[j]; m_stats.WorstRegime = regimes[j]; }
      }
   }

   // Find Best/Worst Entry Score Ranges
   m_stats.BestScoreRange = "None"; m_stats.WorstScoreRange = "None";
   double bestScr = -999999.0, worstScr = 999999.0;
   for(int j = 0; j < 4; j++)
   {
      if(scoreTrades[j] > 0)
      {
         if(scorePnL[j] > bestScr) { bestScr = scorePnL[j]; m_stats.BestScoreRange = scoreRanges[j]; }
         if(scorePnL[j] < worstScr) { worstScr = scorePnL[j]; m_stats.WorstScoreRange = scoreRanges[j]; }
      }
   }

   // Find Best/Worst Trade Classes
   m_stats.BestTradeClass = "None"; m_stats.WorstTradeClass = "None";
   double bestCl = -999999.0, worstCl = 999999.0;
   for(int j = 0; j < 4; j++)
   {
      if(classTrades[j] > 0)
      {
         if(classPnL[j] > bestCl) { bestCl = classPnL[j]; m_stats.BestTradeClass = classes[j]; }
         if(classPnL[j] < worstCl) { worstCl = classPnL[j]; m_stats.WorstTradeClass = classes[j]; }
      }
   }

   // Find Best/Worst Exits
   m_stats.BestExitMethod = "None"; m_stats.WorstExitMethod = "None";
   double bestEx = -999999.0, worstEx = 999999.0;
   for(int j = 0; j < 4; j++)
   {
      if(methodTrades[j] > 0)
      {
         if(methodPnL[j] > bestEx) { bestEx = methodPnL[j]; m_stats.BestExitMethod = methods[j]; }
         if(methodPnL[j] < worstEx) { worstEx = methodPnL[j]; m_stats.WorstExitMethod = methods[j]; }
      }
   }
}

//+------------------------------------------------------------------+
//| Dynamic Pattern Discovery Engine                                 |
//+------------------------------------------------------------------+
void CTradeOptimizationEngine::DiscoverPatterns()
{
   if(m_completedTradesCount < 5) return; // need a baseline dataset

   int count = 0;
   ArrayResize(m_observations, 0);

   // Pattern 1: Entry Score Threshold check
   double pnlHigh = 0.0, pnlLow = 0.0;
   int cntHigh = 0, cntLow = 0;
   for(int i = 0; i < m_completedTradesCount; i++)
   {
      if(m_completedTrades[i].EntryScore >= 70.0) { pnlHigh += m_completedTrades[i].NetProfit; cntHigh++; }
      else if(m_completedTrades[i].EntryScore <= 50.0) { pnlLow += m_completedTrades[i].NetProfit; cntLow++; }
   }
   double expHigh = (cntHigh > 0) ? (pnlHigh / cntHigh) : 0;
   double expLow = (cntLow > 0) ? (pnlLow / cntLow) : 0;
   if(expHigh > expLow + 10.0 && cntHigh > 0)
   {
      count++;
      ArrayResize(m_observations, count);
      m_observations[count-1] = "Trades with Entry Score above 70 produce highest expectancy.";
   }

   // Pattern 2: London vs Asian Session comparison
   double pnlLondon = 0.0, pnlAsian = 0.0;
   int cntLondon = 0, cntAsian = 0;
   for(int i = 0; i < m_completedTradesCount; i++)
   {
      if(StringFind(m_completedTrades[i].Session, "LONDON") >= 0) { pnlLondon += m_completedTrades[i].NetProfit; cntLondon++; }
      else if(StringFind(m_completedTrades[i].Session, "ASIA") >= 0) { pnlAsian += m_completedTrades[i].NetProfit; cntAsian++; }
   }
   if(pnlLondon > pnlAsian && cntLondon > 0 && cntAsian > 0)
   {
      count++;
      ArrayResize(m_observations, count);
      m_observations[count-1] = "London session outperforms Asian session.";
   }

   // Pattern 3: Ranging/Compression markets performance check
   double pnlRanging = 0.0;
   int cntRanging = 0;
   for(int i = 0; i < m_completedTradesCount; i++)
   {
      if(StringFind(m_completedTrades[i].MarketRegime, "RANGING") >= 0 || StringFind(m_completedTrades[i].MarketRegime, "COMPRESSION") >= 0)
      {
         pnlRanging += m_completedTrades[i].NetProfit;
         cntRanging++;
      }
   }
   if(cntRanging > 0 && pnlRanging < 0)
   {
      count++;
      ArrayResize(m_observations, count);
      m_observations[count-1] = "Compression markets have poor performance.";
   }

   // Pattern 4: Runner trades profit average check
   double pnlRunner = 0.0, pnlScalp = 0.0;
   int cntRunner = 0, cntScalp = 0;
   for(int i = 0; i < m_completedTradesCount; i++)
   {
      if(m_completedTrades[i].TradeClass == "Runner") { pnlRunner += m_completedTrades[i].NetProfit; cntRunner++; }
      else if(m_completedTrades[i].TradeClass == "Scalp") { pnlScalp += m_completedTrades[i].NetProfit; cntScalp++; }
   }
   double avgRunner = (cntRunner > 0) ? (pnlRunner / cntRunner) : 0;
   double avgScalp = (cntScalp > 0) ? (pnlScalp / cntScalp) : 0;
   if(avgRunner > avgScalp && cntRunner > 0)
   {
      count++;
      ArrayResize(m_observations, count);
      m_observations[count-1] = "Runner trades have highest average profit.";
   }

   // Default fallback if no patterns found
   if(count == 0)
   {
      count = 1;
      ArrayResize(m_observations, 1);
      m_observations[0] = "Processing dataset. Current market variables are stable.";
   }

   m_observationsCount = count;
}

//+------------------------------------------------------------------+
//| Retrieves specific discovered pattern description                 |
//+------------------------------------------------------------------+
string CTradeOptimizationEngine::GetObservation(int index) const
{
   if(index < 0 || index >= m_observationsCount) return "";
   return m_observations[index];
}

//+------------------------------------------------------------------+
//| Exports dataset to CSV                                           |
//+------------------------------------------------------------------+
void CTradeOptimizationEngine::ExportToCSV()
{
   string fileName = "GITS_Bridge\\GITS_Optimization_Dataset.csv";
   int handle = FileOpen(fileName, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   if(handle != INVALID_HANDLE)
   {
      // Headers
      FileWrite(handle,
         "Ticket", "EntryTime", "ExitTime", "DurationSec", "EntryScore",
         "EntryHealth", "MovementScore", "OpportunityScore", "BuyerIntent", "SellerIntent",
         "MarketRegime", "TrendPhase", "LiquidityStrength", "VolatilityScore", "RelativeVolume",
         "Session", "TradeClass", "Profit", "Loss", "NetProfit", "MFE", "MAE", "ExitReason"
      );

      // Rows
      for(int i = 0; i < m_completedTradesCount; i++)
      {
         CompletedTradeRecord rec = m_completedTrades[i];
         FileWrite(handle,
            (string)rec.Ticket,
            TimeToString(rec.EntryTime),
            TimeToString(rec.ExitTime),
            (string)rec.DurationSec,
            DoubleToString(rec.EntryScore, 1),
            DoubleToString(rec.EntryHealth, 1),
            DoubleToString(rec.MovementScore, 1),
            DoubleToString(rec.OpportunityScore, 1),
            DoubleToString(rec.BuyerIntent, 1),
            DoubleToString(rec.SellerIntent, 1),
            rec.MarketRegime,
            rec.TrendPhase,
            DoubleToString(rec.LiquidityStrength, 1),
            DoubleToString(rec.VolatilityScore, 1),
            DoubleToString(rec.RelativeVolume, 2),
            rec.Session,
            rec.TradeClass,
            DoubleToString(rec.Profit, 2),
            DoubleToString(rec.Loss, 2),
            DoubleToString(rec.NetProfit, 2),
            DoubleToString(rec.MaxFavorableExcursion, 1),
            DoubleToString(rec.MaxAdverseExcursion, 1),
            rec.ExitReason
         );
      }
      FileClose(handle);
   }
}

//+------------------------------------------------------------------+
//| Helper to escape double quotes for CSV safety                    |
//+------------------------------------------------------------------+
string CTradeOptimizationEngine::EscapeString(string text)
{
   string out = text;
   StringReplace(out, "\"", "\"\"");
   return out;
}

#endif // GOLDENGINEV2_TRADE_OPTIMIZATION_ENGINE_MQH
