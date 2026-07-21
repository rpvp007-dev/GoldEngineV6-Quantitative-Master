//+------------------------------------------------------------------+
//|                                                 TradeManager.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_TRADE_MANAGER_MQH
#define GOLDENGINEV2_TRADE_MANAGER_MQH

#include "ITradeManager.mqh"
#include "../Core/Config.mqh"
#include "../Core/Logger.mqh"
#include "IVolatilityEngine.mqh"
#include "ITradeHealthEngine.mqh"
#include "TradeHealthDefines.mqh"
#include "../Strategy/IStrategy.mqh"
#include <Trade/Trade.mqh>

// Quant Engine interfaces for Profit First exits
#include "ITrendEngine.mqh"
#include "IMomentumEngine.mqh"
#include "IPullbackReversalEngine.mqh"
#include "IAdaptiveExitAIEngine.mqh"
#include "IInstitutionalExecutionManager.mqh"
#include "../Analytics/TradeMemory.mqh"
#include "EntryQualityEngine.mqh"


//+------------------------------------------------------------------+
//| Concrete Implementation of GITS Trade Manager V1                |
//+------------------------------------------------------------------+
class CTradeManager : public ITradeManager
{
private:
   CLogger*               m_logger;
   CConfig*               m_config;
   CTrade                 m_trade;
   ITradeHealthEngine*    m_healthEngine;
   bool                   m_isInitialized;
   CTradeMemory*          m_tradeMemory; // GITS V5.2.1 Trade Memory
   
   QuantEnginesContainer  m_engines;
   
   // Tracked positions list
   TradeTrackingState     m_trackedTrades[];
   int                    m_trackedCount;
   double                 m_peakBalance; // V5.5
   
   // Helper methods for cache tracking
   int                    FindTrackedTrade(ulong ticket);
   void                   AddTrackedTrade(ulong ticket, double entryPrice);
   void                   RemoveTrackedTrade(int index);
   void                   UpdateTrackingCache(const string symbol);
   double                 GetATR(const string symbol) const;
   
public:
   CTradeManager(CLogger &logger);
   virtual ~CTradeManager();
   
   virtual void SetTradeMemory(CTradeMemory* memory) override { m_tradeMemory = memory; }
   virtual bool Initialize(const QuantEnginesContainer &engines, CConfig* config) override;
   virtual void ManageActiveTrades(const string symbol) override;
   virtual int  GetActiveTrackingCount() const override { return m_trackedCount; }
   virtual bool GetTrackingState(int index, TradeTrackingState &outState) const override;
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTradeManager::CTradeManager(CLogger &logger)
{
   m_logger = &logger;
   m_config = NULL;
   m_healthEngine = NULL;
   m_isInitialized = false;
   m_tradeMemory = NULL;
   m_trackedCount = 0;
   m_peakBalance = 0.0; // V5.5
   ArrayResize(m_trackedTrades, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTradeManager::~CTradeManager()
{
   ArrayResize(m_trackedTrades, 0);
}

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CTradeManager::Initialize(const QuantEnginesContainer &engines, CConfig* config)
{
   m_config = config;
   m_engines = engines;
   m_healthEngine = engines.TradeHealth;
   
   if(m_config == NULL)
   {
      m_logger.Error("Trade Manager: Configuration reference is NULL.");
      m_isInitialized = false;
      return false;
   }
   
   m_trade.SetExpertMagicNumber(m_config.GetMagicNumber());
   m_isInitialized = true;
   m_logger.Info("Trade Manager V1: Initialized successfully.");
   return true;
}

//+------------------------------------------------------------------+
//| Finds a tracked trade index by ticket                            |
//+------------------------------------------------------------------+
int CTradeManager::FindTrackedTrade(ulong ticket)
{
   for(int i = 0; i < m_trackedCount; i++)
   {
      if(m_trackedTrades[i].Ticket == ticket)
         return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Adds a trade to the tracking cache                               |
//+------------------------------------------------------------------+
void CTradeManager::AddTrackedTrade(ulong ticket, double entryPrice)
{
   if(FindTrackedTrade(ticket) >= 0) return;
   
   m_trackedCount++;
   ArrayResize(m_trackedTrades, m_trackedCount);
   
   TradeTrackingState state;
   state.Ticket = ticket;
   state.EntryPrice = entryPrice;
   state.CurrentProfitPoints = 0.0;
   state.CurrentSL = 0.0;
   state.MaxProfitReachedPoints = 0.0;
   state.MaxLossReachedPoints = 0.0;
   state.LockedProfitPoints = 0.0;
   state.TrailingDistancePoints = 0.0;
   state.BreakEvenActive = false;
   state.TrailingActive = false;
   state.TradeDurationSec = 0;
   state.HealthScore = 50.0;
   state.HealthStateStr = "Stable";
   state.HealthNarrative = "Trade initialized.";
   state.PrevHealthState = -1; // Force log on first update
   state.RecoveryProbability = 50.0;
   state.CurrentExitReason = "None";
   
   // V5.5: Initialize exit stabilization counters
   state.LowRecoveryTickCount = 0;
   state.LowTrendReverseCount = 0;
   state.LastAEExitScore      = 0.0;
   state.LastHealthScore      = 50.0;
   state.TrendDirectionAtEntry = "Neutral";
   state.ScaledOut            = false; // V5.5: Initialize partial exit state
   state.LockStage            = 0;     // V5.6: Initialize multi-stage lock state
   
   m_trackedTrades[m_trackedCount - 1] = state;
   m_logger.Info(StringFormat("Trade Manager: Started tracking position Ticket %d at Entry %.2f", ticket, entryPrice));
}

//+------------------------------------------------------------------+
//| Removes a trade from the tracking cache                          |
//+------------------------------------------------------------------+
void CTradeManager::RemoveTrackedTrade(int index)
{
   if(index < 0 || index >= m_trackedCount) return;
   
   ulong ticket = m_trackedTrades[index].Ticket;
   double mfe = m_trackedTrades[index].MaxProfitReachedPoints;
   double mae = m_trackedTrades[index].MaxLossReachedPoints;
   double locked = m_trackedTrades[index].LockedProfitPoints;
   double trailDist = m_trackedTrades[index].TrailingDistancePoints;
   double recoveryProb = m_trackedTrades[index].RecoveryProbability;
   double finalPL = m_trackedTrades[index].CurrentProfitPoints;
   int duration = m_trackedTrades[index].TradeDurationSec;
   
   string exitReason = m_trackedTrades[index].CurrentExitReason;
   if(exitReason == "None" || exitReason == "")
   {
      exitReason = "Broker SL/TP Hit";
   }
   
   // Journal close log (V5.2 specification)
   m_logger.Info(StringFormat("[EXIT JOURNAL] Ticket %d Closed. Recovery Probability: %.1f%% | Reason for Exit: %s | Profit Locked: %.1f pts | Trailing Distance: %.1f pts | Final Profit/Loss: %.1f pts",
                              ticket, recoveryProb, exitReason, locked, trailDist, finalPL));
   
   // V5.5: Structured loss diagnostic report
   if(finalPL <= 0.0)
   {
      string dirStr   = (m_trackedTrades[index].Direction == GEV2_SIGNAL_BUY) ? "BUY" : "SELL";
      string trendStr = (m_trackedTrades[index].Trend > 0) ? "Bull" : (m_trackedTrades[index].Trend < 0) ? "Bear" : "Neutral";
      string regimeStr = IntegerToString(m_trackedTrades[index].MarketRegime);
      double buyerIntent = (m_engines.Intent != NULL) ? m_engines.Intent.GetMarketIntentContext().BuyerIntent : 0.0;
      double sellerIntent = (m_engines.Intent != NULL) ? m_engines.Intent.GetMarketIntentContext().SellerIntent : 0.0;
      double movScore    = (m_engines.Movement != NULL) ? m_engines.Movement.GetMovementContext().MovementScore : 0.0;
      
      m_logger.Info(StringFormat(
         "[LOSS DIAGNOSTIC] Ticket=%d | Dir=%s | TrendAtEntry=%d(%s) | Regime=%s | Structure=%s | "
         "Movement=%.1f | BuyerIntent=%.1f | SellerIntent=%.1f | "
         "OppScore=%.1f | EntryQuality=%.1f | RecovProb=%.1f%% | "
         "ExitReason=%s | AEScore=%.1f | HealthAtExit=%.1f | Duration=%ds | TrendAlignment=%s",
         ticket, dirStr,
         m_trackedTrades[index].Trend, trendStr,
         regimeStr,
         m_trackedTrades[index].Structure,
         movScore, buyerIntent, sellerIntent,
         m_trackedTrades[index].OpportunityScore,
         m_trackedTrades[index].EntryQualityScore,
         recoveryProb,
         exitReason,
         m_trackedTrades[index].LastAEExitScore,
         m_trackedTrades[index].LastHealthScore,
         duration,
         m_trackedTrades[index].TrendDirectionAtEntry));
   }
   
   // Record to Trade Memory Layer
   if(m_tradeMemory != NULL)
   {
      TradeMemoryEntry entry;
      entry.Direction = m_trackedTrades[index].Direction;
      entry.Session = m_trackedTrades[index].Session;
      entry.MarketRegime = m_trackedTrades[index].MarketRegime;
      entry.Structure = m_trackedTrades[index].Structure;
      entry.Trend = m_trackedTrades[index].Trend;
      entry.OpportunityScore = m_trackedTrades[index].OpportunityScore;
      entry.EntryPrice = m_trackedTrades[index].EntryPrice;
      entry.MomentumScore = m_trackedTrades[index].MomentumScore;
      entry.IsWin = (finalPL > 0.0);
      entry.HoldTimeSec = duration;
      entry.ProfitLoss = finalPL;
      m_tradeMemory.RecordCompletedTrade(entry);
   }

   m_logger.Info(StringFormat("Trade Manager: Position Ticket %d Tracking Finished. Duration: %d sec, MFE: %.1f pts, MAE: %.1f pts",
                              ticket, duration, mfe, mae));
   
   for(int i = index; i < m_trackedCount - 1; i++)
   {
      m_trackedTrades[i] = m_trackedTrades[i + 1];
   }
   
   m_trackedCount--;
   ArrayResize(m_trackedTrades, m_trackedCount);
}

//+------------------------------------------------------------------+
//| Updates MFE, MAE, Duration and cleans up closed trades           |
//+------------------------------------------------------------------+
void CTradeManager::UpdateTrackingCache(const string symbol)
{
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0) return;
   
   // Pass 1: Scan open terminal positions and update/add
   int totalPos = PositionsTotal();
   for(int i = 0; i < totalPos; i++)
   {
      if(PositionGetSymbol(i) == symbol && PositionGetInteger(POSITION_MAGIC) == m_config.GetMagicNumber())
      {
         ulong ticket = PositionGetInteger(POSITION_TICKET);
         double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentSL = PositionGetDouble(POSITION_SL);
         ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         
         int idx = FindTrackedTrade(ticket);
         if(idx < 0)
         {
            AddTrackedTrade(ticket, entryPrice);
            idx = m_trackedCount - 1;
            
            // GITS V5.2.1: Cache trade entry characteristics for memory recording later
            m_trackedTrades[idx].Direction = (type == POSITION_TYPE_BUY) ? GEV2_SIGNAL_BUY : GEV2_SIGNAL_SELL;
            m_trackedTrades[idx].Session = (m_engines.Session != NULL) ? m_engines.Session.GetCurrentSession() : "None";
            m_trackedTrades[idx].MarketRegime = (m_engines.MarketContext != NULL) ? m_engines.MarketContext.GetContext().MarketRegime : 0;
            m_trackedTrades[idx].Structure = (m_engines.MarketStructure != NULL) ? m_engines.MarketStructure.GetStructureState() : "None";
            m_trackedTrades[idx].Trend = (m_engines.Trend != NULL) ? m_engines.Trend.GetTrendDirection(symbol, Period()) : 0;
            m_trackedTrades[idx].OpportunityScore = (m_engines.Opportunity != NULL) ? m_engines.Opportunity.GetOpportunityContext().OpportunityScore : 50.0;
            m_trackedTrades[idx].MomentumScore = (m_engines.Momentum != NULL) ? m_engines.Momentum.GetMomentumScore() : 50.0;
            
            // V5.5: Cache trend direction at entry for diagnostic log
            int entryTrend = m_trackedTrades[idx].Trend;
            bool isBuyEntry = (type == POSITION_TYPE_BUY);
            if((isBuyEntry && entryTrend >= 0) || (!isBuyEntry && entryTrend <= 0))
               m_trackedTrades[idx].TrendDirectionAtEntry = "Aligned";
            else
               m_trackedTrades[idx].TrendDirectionAtEntry = "Counter-Trend";
            
            // GITS V5.3: Calculate Entry Quality Score at the time trade starts tracking
            m_trackedTrades[idx].EntryQualityScore = CEntryQualityEngine::CalculateEntryQuality(symbol, m_trackedTrades[idx].Direction, m_engines.Trend, m_engines.MarketStructure, m_engines.PullbackReversal, m_engines.Momentum, m_engines.Volume, m_engines.Liquidity, m_engines.Volatility, m_engines.Session, m_engines.Intent, m_engines.Opportunity);
         }
         
         // Update state
         double curPrice = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);
         double profitPrice = (type == POSITION_TYPE_BUY) ? (curPrice - entryPrice) : (entryPrice - curPrice);
         double lossPrice = (type == POSITION_TYPE_BUY) ? (entryPrice - curPrice) : (curPrice - entryPrice);
         
         double profitPoints = profitPrice / point;
         double lossPoints = lossPrice / point;
         
         m_trackedTrades[idx].CurrentProfitPoints = profitPoints;
         m_trackedTrades[idx].CurrentSL = currentSL;
         m_trackedTrades[idx].CurrentTP = PositionGetDouble(POSITION_TP);
         m_trackedTrades[idx].TradeDurationSec = (int)(TimeCurrent() - PositionGetInteger(POSITION_TIME));
         
         if(profitPoints > m_trackedTrades[idx].MaxProfitReachedPoints)
            m_trackedTrades[idx].MaxProfitReachedPoints = profitPoints;
            
         if(lossPoints > m_trackedTrades[idx].MaxLossReachedPoints)
            m_trackedTrades[idx].MaxLossReachedPoints = lossPoints;
      }
   }
   
   // Pass 2: Clean up positions that are no longer open
   for(int i = m_trackedCount - 1; i >= 0; i--)
   {
      ulong ticket = m_trackedTrades[i].Ticket;
      bool found = false;
      
      int activeCount = PositionsTotal();
      for(int k = 0; k < activeCount; k++)
      {
         if(PositionGetSymbol(k) == symbol)
         {
            if(PositionGetInteger(POSITION_TICKET) == (long)ticket)
            {
               found = true;
               break;
            }
         }
      }
      
      if(!found)
      {
         RemoveTrackedTrade(i);
      }
   }
}

//+------------------------------------------------------------------+
//| Retrieves ATR price change                                       |
//+------------------------------------------------------------------+
double CTradeManager::GetATR(const string symbol) const
{
   if(m_engines.Volatility != NULL)
   {
      double atr = m_engines.Volatility.GetATR(symbol, Period(), 14, 1);
      if(atr > 0.0) return atr;
   }
   return SymbolInfoDouble(symbol, SYMBOL_POINT) * 100.0; // default $1.00 move
}

//+------------------------------------------------------------------+
//| Core Trade Management Tick Updates                               |
//+------------------------------------------------------------------+
 void CTradeManager::ManageActiveTrades(const string symbol)
 {
    if(!m_isInitialized || !m_config.IsTradeManagerEnabled()) return;
    
    // Update peak balance
    double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    if(m_peakBalance <= 0.0) m_peakBalance = currentBalance;
    if(currentBalance > m_peakBalance) m_peakBalance = currentBalance;
    
    // V5.5: Trailing Capital Lock Active Protection Floor (Hard Stop)
    // If Capital Lock is enabled, and peak balance has reached the trigger (e.g. $250),
    // if live floating equity drops below floor (e.g. $200), instantly close all trades!
    if(m_config.IsCapitalLockEnabled() && m_peakBalance >= m_config.GetCapitalLockTrigger())
    {
       double floor = m_config.GetCapitalLockFloor();
       if(currentEquity <= floor || currentBalance <= floor)
       {
          m_logger.Warning(StringFormat("[CAPITAL LOCK EMERGENCY] Equity %.2f fell below protected floor %.2f! Force closing all positions.", currentEquity, floor));
          // Loop and close all tracked trades
          for(int i = m_trackedCount - 1; i >= 0; i--)
          {
             ulong ticket = m_trackedTrades[i].Ticket;
             if(PositionSelectByTicket(ticket))
             {
                m_trackedTrades[i].CurrentExitReason = "Capital Lock Floor Breach";
                m_trade.PositionClose(ticket);
             }
          }
          return; // Exit out, all trades are closed
       }
    }

    // Sync tracking cache
   UpdateTrackingCache(symbol);
   
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0) return;
   
   double stopLevel = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minStopDistance = MathMax(stopLevel, 10.0) * point;
   
   // Process each tracked trade
   MqlDateTime serverTime;
   TimeToStruct(TimeCurrent(), serverTime);
   bool isWeekendClose = (serverTime.day_of_week == 5 && serverTime.hour >= 21); // Friday after 21:00 server time
   
   for(int i = 0; i < m_trackedCount; i++)
   {
      ulong ticket = m_trackedTrades[i].Ticket;
      if(!PositionSelectByTicket(ticket)) continue;
      
      if(isWeekendClose)
      {
         m_logger.Info(StringFormat("[WEEKEND SHUTDOWN] Friday market closing. Force closing position ticket #%I64u to avoid weekend gaps.", ticket));
         m_trackedTrades[i].CurrentExitReason = "Friday Weekend Shutdown";
         m_trade.PositionClose(ticket);
         continue;
      }
      
      double entryPrice = m_trackedTrades[i].EntryPrice;
      double currentSL = m_trackedTrades[i].CurrentSL;
      double currentTP = PositionGetDouble(POSITION_TP);
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      // Evaluate Trade Health
      TradeHealthContext healthCtx;
      healthCtx.HealthScore = 50.0;
      healthCtx.HealthState = HEALTH_STABLE;
      healthCtx.HealthNarrative = "Trade tracking.";
      if(m_healthEngine != NULL)
      {
         healthCtx = m_healthEngine.EvaluateTradeHealth(
            ticket,
            m_trackedTrades[i].CurrentProfitPoints,
            m_trackedTrades[i].MaxProfitReachedPoints,
            m_trackedTrades[i].MaxLossReachedPoints,
            m_trackedTrades[i].TradeDurationSec
         );
         
         int nextStateEnum = (int)healthCtx.HealthState;
         if(nextStateEnum != m_trackedTrades[i].PrevHealthState)
         {
            string prevStateStr = (m_trackedTrades[i].PrevHealthState == -1) ? "NONE" : TradeHealthStateToString((ENUM_TRADE_HEALTH_STATE)m_trackedTrades[i].PrevHealthState);
            m_logger.Info(StringFormat("Trade Manager: Ticket %d State Transition: %s -> %s (Score: %.1f, Narrative: %s)",
                                       ticket,
                                       prevStateStr,
                                       TradeHealthStateToString(healthCtx.HealthState),
                                       healthCtx.HealthScore,
                                       healthCtx.HealthNarrative));
            m_trackedTrades[i].PrevHealthState = nextStateEnum;
         }
         
         m_trackedTrades[i].HealthScore = healthCtx.HealthScore;
         m_trackedTrades[i].HealthStateStr = TradeHealthStateToString(healthCtx.HealthState);
         m_trackedTrades[i].HealthNarrative = healthCtx.HealthNarrative;
         m_trackedTrades[i].LastHealthScore = healthCtx.HealthScore; // V5.5: cache for diagnostics
      }
      
      // Gather engine parameters for Profit First exit intelligence
      int trendDir = (m_engines.Trend != NULL) ? m_engines.Trend.GetTrendDirection(symbol, Period()) : 0;
      
      PullbackReversalContext pbCtx;
      pbCtx.TrendRecoveryProb = 50.0;
      pbCtx.ReversalProb = 0.0;
      pbCtx.State = PULLBACK_STATE_NONE;
      pbCtx.Recommendation = PULLBACK_REC_WAIT;
      if(m_engines.PullbackReversal != NULL)
      {
         pbCtx = m_engines.PullbackReversal.GetEvaluationContext();
      }
      
      AdaptiveExitContext aeCtx;
      aeCtx.Recommendation = ADAPTIVE_EXIT_WAIT;
      if(m_engines.AdaptiveExit != NULL)
      {
         aeCtx = m_engines.AdaptiveExit.GetExitContext();
         m_trackedTrades[i].LastAEExitScore = aeCtx.ExitScore; // V5.5: cache AE exit score
      }
      
      InstitutionalExecutionContext ieCtx;
      ieCtx.Recommendation = EXEC_ACTION_WAIT;
      if(m_engines.InstitutionalExecution != NULL)
      {
         ieCtx = m_engines.InstitutionalExecution.GetExecutionContext();
      }
      
      // 1. Evaluate Recovery Probability
      double recoveryProb = 50.0;
      if(m_engines.PullbackReversal != NULL)
      {
         recoveryProb = pbCtx.TrendRecoveryProb;
      }
      else
      {
         // Fallback evaluation
         double contFactor = 50.0;
         if(type == POSITION_TYPE_BUY)
         {
            contFactor += ((m_engines.Intent != NULL) ? (m_engines.Intent.GetMarketIntentContext().BuyerIntent - 50.0) * 0.4 : 0.0);
            contFactor += (trendDir > 0) ? 15.0 : -15.0;
         }
         else
         {
            contFactor += ((m_engines.Intent != NULL) ? (m_engines.Intent.GetMarketIntentContext().SellerIntent - 50.0) * 0.4 : 0.0);
            contFactor += (trendDir < 0) ? 15.0 : -15.0;
         }
         contFactor += (m_trackedTrades[i].HealthScore - 50.0) * 0.3;
         recoveryProb = MathMax(0.0, MathMin(100.0, contFactor));
      }
      m_trackedTrades[i].RecoveryProbability = recoveryProb;
      
      // 2. Check low recovery probability exit triggers (controlled loss exit)
      // V5.5: Guards — require 2 consecutive evaluations before firing
      // to prevent exits on single-tick anomalies
      bool trendReversed = (type == POSITION_TYPE_BUY && trendDir < 0) || (type == POSITION_TYPE_SELL && trendDir > 0);
      // V5.5: HEALTH_CRITICAL requires score < 25 (enum value 5) — not DANGER (enum 4)
      bool healthCritical = (healthCtx.HealthState == HEALTH_CRITICAL && healthCtx.HealthScore < 25.0);
      bool aeFullExit = (m_engines.AdaptiveExit != NULL && aeCtx.Recommendation == ADAPTIVE_EXIT_FULL_EXIT);
      bool instRiskReduction = (m_engines.InstitutionalExecution != NULL && (ieCtx.Recommendation == EXEC_ACTION_RISK_REDUCTION || ieCtx.Recommendation == EXEC_ACTION_REDUCE_EXPOSURE));
      
      // V5.5: Increment/reset consecutive counter for trend reversal
      if(trendReversed)
         m_trackedTrades[i].LowTrendReverseCount++;
      else
         m_trackedTrades[i].LowTrendReverseCount = 0;

      // V5.5: Increment/reset consecutive counter for low recovery
      if(recoveryProb < 40.0)
         m_trackedTrades[i].LowRecoveryTickCount++;
      else
         m_trackedTrades[i].LowRecoveryTickCount = 0;

      // Minimum hold time: no strategy exit in first 30 seconds (broker SL still works)
      bool minHoldElapsed = (m_trackedTrades[i].TradeDurationSec >= 30);

      bool lowRecoveryExit = false;
      string exitReasonStr = "None";
      
      // Query position comment to check if this is an S-003b trade
      string posComment = PositionGetString(POSITION_COMMENT);
      bool isDecoupled = (posComment == "G-001" || posComment == "G-002" || posComment == "G-003" || posComment == "S-003b" || posComment == "S-004" || posComment == "S-005" || posComment == "S-006");

      if(!isDecoupled)
      {
         // Health Critical: immediate exit (no consecutive requirement — critical means critical)
         if(healthCritical && minHoldElapsed)
         {
            lowRecoveryExit = true;
            exitReasonStr = "Trade Health Critical";
         }
         // Trend reversed for 2+ consecutive evaluations AND recovery is very low
         else if(m_trackedTrades[i].LowTrendReverseCount >= 2 && recoveryProb < 35.0 && minHoldElapsed)
         {
            lowRecoveryExit = true;
            exitReasonStr = "Trend Reversed (confirmed 2 ticks)";
         }
         // Adaptive Exit AI full exit (after 45s guard in AdaptiveExitAI)
         else if(aeFullExit && minHoldElapsed)
         {
            lowRecoveryExit = true;
            exitReasonStr = "Adaptive Exit AI Full Exit";
         }
         // Institutional risk reduction
         else if(instRiskReduction && minHoldElapsed)
         {
            lowRecoveryExit = true;
            exitReasonStr = "Institutional Execution Risk Reduction";
         }
         // Recovery probability low for 2+ consecutive evaluations
         else if(m_trackedTrades[i].LowRecoveryTickCount >= 2 && minHoldElapsed)
         {
            lowRecoveryExit = true;
            exitReasonStr = "Recovery Probability Low (confirmed 2 ticks)";
         }
      }
      
      if(lowRecoveryExit)
      {
         m_trackedTrades[i].RecoveryProbability = 15.0; // Force low for exit log
         m_trackedTrades[i].CurrentExitReason = exitReasonStr;
         m_trade.PositionClose(ticket);
         continue; // skip further modifications as position is closing
      }
      
      double currentPrice = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);
      double profitPoints = m_trackedTrades[i].CurrentProfitPoints;
      
      // 3. Profitable exit evaluation & checks
      // GITS V5.5.0 Optimization: Disabled this block because it clashed with the Trailing Stop and 
      // Progressive Profit Lock. It was closing winning trades too early on minor M1 momentum fluctuations, 
      // choking profits. We now let the Trailing Stop and Break-Even handle the exit dynamically.
      /*
      if(profitPoints > 0.0 && minHoldElapsed)
      {
         bool momentumWeakened = (m_engines.Momentum != NULL && m_engines.Momentum.GetMomentumScore() < 45.0);
         bool reversalIncreased = (m_engines.PullbackReversal != NULL && (pbCtx.ReversalProb > 50.0 || pbCtx.State == PULLBACK_STATE_REVERSAL || pbCtx.Recommendation == PULLBACK_REC_EXIT));
         
         if(momentumWeakened || reversalIncreased)
         {
            if(momentumWeakened && reversalIncreased) exitReasonStr = "Weak Momentum & Increased Reversal Probability";
            else if(momentumWeakened) exitReasonStr = "Weak Momentum";
            else exitReasonStr = "Increased Reversal Probability";
            
            m_trackedTrades[i].CurrentExitReason = exitReasonStr;
            m_trade.PositionClose(ticket);
            continue;
         }
      }
      */

      
      // --- GITS V5.5: Hard Monetary Stop Loss per 0.01 lots Failsafe (Anti-Big-Loss Protection)
      if(PositionSelectByTicket(ticket))
      {
         double posVolume = PositionGetDouble(POSITION_VOLUME);
         double posProfit = PositionGetDouble(POSITION_PROFIT);
         double maxAllowedLoss = -m_config.GetMaxLossPer001Lot() * (posVolume / 0.01);
         if(posProfit <= maxAllowedLoss)
         {
            m_logger.Warning(StringFormat("[SAFETY LIMIT] Ticket %d reached maximum monetary loss limit ($%.2f for %.2f lots). Force closing position.", ticket, maxAllowedLoss, posVolume));
            m_trackedTrades[i].CurrentExitReason = "Hard Monetary Stop Breach";
            m_trade.PositionClose(ticket);
            continue;
         }
      }

      bool modified = false;
      double nextSL = currentSL;
      double atrVal = GetATR(symbol);
      double atrPoints = atrVal / point;

      // 1. Progressive Profit Protection:
      // +0.50 ATR -> move stop to break-even (BE)
      // +1.00 ATR -> lock small profit (0.2 ATR)
      // +2.00 ATR -> tighten trailing stop
      double beTrigger = m_config.GetBreakEvenTrigger(); // Connected to screen input (Points)
      double lockTrigger = atrPoints * 0.8; // Tightened from 1.0 to lock profit early
      double trailTrigger = atrPoints * 1.5; // Tightened from 2.0 to trail profit early

      // V5.5 Sudden News Spike Protection:
      // If we are in profit and the volatility regime turns to VOL_STATE_EXPLODING,
      // instantly lock in profit by tightening the trailing stop to just 1.0 ATR
      // to secure gains before a sudden news reversal occurs.
      if(m_engines.MarketContext != NULL && m_engines.MarketContext.GetContext().VolatilityRegime == VOL_STATE_EXPLODING)
      {
         trailTrigger = atrPoints * 0.5; // Trigger trailing immediately
         atrPoints = atrPoints * 0.8;    // Tighten the trail distance by 20%
      }

      // GITS V5.6: Multi-Stage Step Locking
      if(m_config.IsBreakEvenEnabled())
      {
         int currentStage = m_trackedTrades[i].LockStage;
         int nextStage = currentStage;
         double targetOffsetPoints = 0.0;
         double triggerPoints = 0.0;

         // Evaluate Stage 1 (Break-Even) - Trigger at +250 points (+25 pips)
         if(profitPoints >= 250.0 && currentStage < 2)
         {
            nextStage = 2;
            triggerPoints = 250.0;
            targetOffsetPoints = 50.0; // Lock +5 pips
         }

         if(nextStage > currentStage)
         {
            double stageSL = (type == POSITION_TYPE_BUY) ? (entryPrice + targetOffsetPoints * point) : (entryPrice - targetOffsetPoints * point);
            bool isForward = (type == POSITION_TYPE_BUY) ? (stageSL > currentSL || currentSL == 0.0) : (stageSL < currentSL || currentSL == 0.0);
            bool respectStops = (type == POSITION_TYPE_BUY) ? (currentPrice - stageSL >= minStopDistance) : (stageSL - currentPrice >= minStopDistance);

            if(isForward && respectStops)
            {
               nextSL = stageSL;
               m_trackedTrades[i].LockStage = nextStage;
               m_trackedTrades[i].BreakEvenActive = true;
               m_trackedTrades[i].LockedProfitPoints = targetOffsetPoints;
               modified = true;
               m_logger.Info(StringFormat("Trade Manager: GITS Multi-Stage Lock Stage %d activated for Ticket %d (Trigger: %.1f, Locked: %.1f points)", nextStage, ticket, triggerPoints, targetOffsetPoints));
            }
         }
      }

      // --- Institutional 50% Partial Scale-Out (+0.8 ATR target)
      if(profitPoints >= lockTrigger && !m_trackedTrades[i].ScaledOut)
      {
         if(PositionSelectByTicket(ticket))
         {
            double posVolume = PositionGetDouble(POSITION_VOLUME);
            double halfVolume = NormalizeDouble(posVolume * 0.5, 2);
            double minVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
            double stepVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
            
            if(stepVolume <= 0.0) stepVolume = 0.01;
            halfVolume = MathRound(halfVolume / stepVolume) * stepVolume;
            halfVolume = NormalizeDouble(halfVolume, 2);
            
            if(halfVolume >= minVolume && halfVolume < posVolume)
            {
               m_logger.Info(StringFormat("[SCALE-OUT] Booking 50%% profit on Ticket %d. Closing %.2f lots at market.", ticket, halfVolume));
               if(m_trade.PositionClosePartial(ticket, halfVolume))
               {
                  m_trackedTrades[i].ScaledOut = true;
                  
                  double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
                  if(tickSize <= 0.0) tickSize = point;
                  
                  double beSL = (type == POSITION_TYPE_BUY) ? (entryPrice + 5.0 * point) : (entryPrice - 5.0 * point);
                  beSL = NormalizeDouble(MathRound(beSL / tickSize) * tickSize, _Digits);
                  
                  nextSL = beSL;
                  m_trackedTrades[i].BreakEvenActive = true;
                  m_trackedTrades[i].LockedProfitPoints = 5.0;
                  modified = true;
                  
                  m_logger.Info(StringFormat("[SCALE-OUT] Moved remaining SL of Ticket %d to Entry+0.5 pips (%.2f).", ticket, beSL));
               }
            }
         }
      }

      // ADVANCED INSTITUTIONAL PROFIT LOCK ENGINE (GITS V5.8)
      // 1. Structure-Based Trailing: Trail SL behind recent Swing Low (BUY) or Swing High (SELL)
      if(m_engines.MarketStructure != NULL && profitPoints >= 200.0)
      {
         double structSL = 0.0;
         if(type == POSITION_TYPE_BUY)
         {
            double swingLow = m_engines.MarketStructure.GetLastSwingLowPrice();
            if(swingLow > entryPrice && (currentPrice - swingLow) >= minStopDistance)
            {
               structSL = swingLow - 20.0 * point;
            }
         }
         else if(type == POSITION_TYPE_SELL)
         {
            double swingHigh = m_engines.MarketStructure.GetLastSwingHighPrice();
            if(swingHigh > 0.0 && swingHigh < entryPrice && (swingHigh - currentPrice) >= minStopDistance)
            {
               structSL = swingHigh + 20.0 * point;
            }
         }

         if(structSL > 0.0)
         {
            bool isForward = (type == POSITION_TYPE_BUY) ? (structSL > nextSL || nextSL == 0.0) : (structSL < nextSL || nextSL == 0.0);
            if(isForward)
            {
               nextSL = structSL;
               modified = true;
            }
         }
      }

      // 2. Multi-Phase ATR & Peak Profit Percentage Lock
      double targetLock = m_trackedTrades[i].LockedProfitPoints;
      if(profitPoints >= atrPoints * 3.5)
      {
         // Phase 3: Lock 75% of Peak Profit Reached
         targetLock = MathMax(targetLock, m_trackedTrades[i].MaxProfitReachedPoints * 0.75);
      }
      else if(profitPoints >= atrPoints * 2.0)
      {
         // Phase 2: Lock 50% of Peak Profit Reached
         targetLock = MathMax(targetLock, m_trackedTrades[i].MaxProfitReachedPoints * 0.50);
      }

      // Prioritize Trade Health (progressive lock on deterioration)
      int healthStateVal = (int)healthCtx.HealthState;
      if(m_config.IsHealthLockEnabled() && healthStateVal >= 2 && profitPoints >= m_config.GetHealthLockMinPoints()) // Stable, Warning, or Critical
      {
         double peakLock = m_trackedTrades[i].MaxProfitReachedPoints * 0.5;
         targetLock = MathMax(targetLock, peakLock);
      }

      if(targetLock > m_trackedTrades[i].LockedProfitPoints)
      {
         double lockSL = (type == POSITION_TYPE_BUY) ? (entryPrice + targetLock * point) : (entryPrice - targetLock * point);
         bool isForward = (type == POSITION_TYPE_BUY) ? (lockSL > nextSL || nextSL == 0.0) : (lockSL < nextSL || nextSL == 0.0);
         bool respectStops = (type == POSITION_TYPE_BUY) ? (currentPrice - lockSL >= minStopDistance) : (lockSL - currentPrice >= minStopDistance);
         
         if(isForward && respectStops)
         {
            nextSL = lockSL;
            m_trackedTrades[i].LockedProfitPoints = targetLock;
            modified = true;
            m_logger.Info(StringFormat("Trade Manager: Progressive Profit Lock updated for Ticket %d. Locked Profit: %.1f points.", ticket, targetLock));
         }
      }

      // Dynamic Trailing Stop (Harmonized with Advanced Profit Lock)
      if(m_config.IsTrailingEnabled() || m_trackedTrades[i].BreakEvenActive || profitPoints >= 250.0)
      {
         double trailingDistance = atrPoints * m_config.GetTmAtrMultiplier();
         
         // Tighten trail if +2.00 ATR reached
         if(profitPoints >= trailTrigger)
         {
            trailingDistance = atrPoints * 0.8;
         }

         // Tighten trail if Trade Health deteriorates
         if(healthStateVal == 3) // HEALTH_WARNING
         {
            trailingDistance *= 0.7;
         }
         else if(healthStateVal == 4) // HEALTH_CRITICAL
         {
            trailingDistance *= 0.5;
         }

         // Clamp trail distance
         trailingDistance = MathMax(m_config.GetMinTrailDistance(), MathMin(m_config.GetMaxTrailDistance(), trailingDistance));

         if(trailingDistance > 0.0)
         {
            double trailSL = (type == POSITION_TYPE_BUY) ? (currentPrice - trailingDistance * point) : (currentPrice + trailingDistance * point);
            bool isForward = (type == POSITION_TYPE_BUY) ? (trailSL > nextSL) : (trailSL < nextSL);
            bool respectStops = (type == POSITION_TYPE_BUY) ? (currentPrice - trailSL >= minStopDistance) : (trailSL - currentPrice >= minStopDistance);
            
            if(isForward && respectStops)
            {
               nextSL = trailSL;
               m_trackedTrades[i].TrailingActive = true;
               m_trackedTrades[i].TrailingDistancePoints = trailingDistance;
               modified = true;
               m_logger.Info(StringFormat("Trade Manager: GITS V5.3 Trailing Stop updated for Ticket %d. SL moved to %.2f (Trailing Dist: %.1f points).", ticket, nextSL, trailingDistance));
            }
         }
      }

      // Apply position modification if stop level changed
      if(modified && nextSL != currentSL)
      {
         if(!m_trade.PositionModify(ticket, NormalizeDouble(nextSL, _Digits), NormalizeDouble(currentTP, _Digits)))
         {
            m_logger.Warning(StringFormat("Trade Manager: Failed to modify stop loss for Ticket %d. Code: %d", ticket, GetLastError()));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Retrieves specific tracked trade state                           |
//+------------------------------------------------------------------+
bool CTradeManager::GetTrackingState(int index, TradeTrackingState &outState) const
{
   if(index < 0 || index >= m_trackedCount) return false;
   outState = m_trackedTrades[index];
   return true;
}

#endif // GOLDENGINEV2_TRADE_MANAGER_MQH
