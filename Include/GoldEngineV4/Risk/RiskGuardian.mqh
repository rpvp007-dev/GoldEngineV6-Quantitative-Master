//+------------------------------------------------------------------+
//|                                                 RiskGuardian.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_RISK_GUARDIAN_MQH
#define GOLDENGINEV2_RISK_GUARDIAN_MQH

#include "IRiskGuardian.mqh"
#include "../Core/Logger.mqh"
#include "../Core/Config.mqh"

//+------------------------------------------------------------------+
//| Production Risk Guardian Class implementation (GITS V2.3)        |
//+------------------------------------------------------------------+
class CRiskGuardian : public IRiskGuardian
{
private:
   CLogger*                   m_logger;
   CConfig*                   m_config;
   ISessionEngine*            m_sessionEngine;

   string                     m_blockReason;
   bool                       m_isPaused;
   double                     m_peakEquity;
   double                     m_peakBalance; // V5.5

   //--- Start-of-day broker time helper
   datetime GetStartOfDay()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      dt.hour = 0;
      dt.min = 0;
      dt.sec = 0;
      return StructToTime(dt);
   }

   //--- Start-of-week broker time helper
   datetime GetStartOfWeek()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      datetime serverTime = TimeCurrent();
      datetime startOfDay = serverTime - (dt.hour * 3600 + dt.min * 60 + dt.sec);
      // dt.day_of_week: 0 = Sunday, 1 = Monday, ..., 6 = Saturday
      int daysToSubtract = dt.day_of_week;
      return startOfDay - (daysToSubtract * 86400);
   }

   //--- Realized profit today
   double GetDailyRealizedPL(ulong magic)
   {
      datetime start = GetStartOfDay();
      if(!HistorySelect(start, TimeCurrent())) return 0.0;
      
      double profit = 0.0;
      int total = HistoryDealsTotal();
      for(int i = 0; i < total; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket > 0)
         {
            if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == magic)
            {
               long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
               if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT)
               {
                  profit += HistoryDealGetDouble(ticket, DEAL_PROFIT) + 
                            HistoryDealGetDouble(ticket, DEAL_COMMISSION) + 
                            HistoryDealGetDouble(ticket, DEAL_SWAP);
               }
            }
         }
      }
      return profit;
   }

   //--- Realized profit this week
   double GetWeeklyRealizedPL(ulong magic)
   {
      datetime start = GetStartOfWeek();
      if(!HistorySelect(start, TimeCurrent())) return 0.0;
      
      double profit = 0.0;
      int total = HistoryDealsTotal();
      for(int i = 0; i < total; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket > 0)
         {
            if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == magic)
            {
               long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
               if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT)
               {
                  profit += HistoryDealGetDouble(ticket, DEAL_PROFIT) + 
                            HistoryDealGetDouble(ticket, DEAL_COMMISSION) + 
                            HistoryDealGetDouble(ticket, DEAL_SWAP);
               }
            }
         }
      }
      return profit;
   }

   //--- Streak of losses and timestamp of latest loss
   void GetConsecutiveLossesInfo(ulong magic, int &outConsecutiveLosses, datetime &outLastLossTime)
   {
      outConsecutiveLosses = 0;
      outLastLossTime = 0;
      
      if(!HistorySelect(TimeCurrent() - 14 * 86400, TimeCurrent())) return;
      
      int total = HistoryDealsTotal();
      for(int i = total - 1; i >= 0; i--)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket > 0)
         {
            if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == magic)
            {
               long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
               if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT)
               {
                  double pl = HistoryDealGetDouble(ticket, DEAL_PROFIT) + 
                              HistoryDealGetDouble(ticket, DEAL_COMMISSION) + 
                              HistoryDealGetDouble(ticket, DEAL_SWAP);
                  if(pl < 0.0)
                  {
                     outConsecutiveLosses++;
                     if(outLastLossTime == 0)
                     {
                        outLastLossTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
                     }
                  }
                  else if(pl > 0.0)
                  {
                     // Reset streak on win
                     break;
                  }
               }
            }
         }
      }
   }

    //--- Dynamic timestamp of latest closed trade per strategy comment
    datetime GetLastCloseTime(ulong magic, string strategyName)
    {
       if(!HistorySelect(TimeCurrent() - 7 * 86400, TimeCurrent())) return 0;
       
       int total = HistoryDealsTotal();
       for(int i = total - 1; i >= 0; i--)
       {
          ulong ticket = HistoryDealGetTicket(i);
          if(ticket > 0)
          {
             if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == magic && HistoryDealGetString(ticket, DEAL_COMMENT) == strategyName)
             {
                long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
                if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT)
                {
                   return (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
                }
             }
          }
       }
       return 0;
    }

     //--- Dynamic timestamp of latest closed trade across all strategies
     datetime GetLastSystemCloseTime(ulong magic)
     {
        if(!HistorySelect(TimeCurrent() - 7 * 86400, TimeCurrent())) return 0;
        
        int total = HistoryDealsTotal();
        for(int i = total - 1; i >= 0; i--)
        {
           ulong ticket = HistoryDealGetTicket(i);
           if(ticket > 0)
           {
              if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == magic)
              {
                 long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
                 if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT)
                 {
                    return (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
                 }
              }
           }
        }
        return 0;
     }

   /**
    * @brief Checks if there is an upcoming or recent high-impact USD event.
    */
   bool IsInsideNewsWindow(string &outEventName)
   {
      datetime nowUTC = TimeGMT();
      // Look from 1 hour ago to 2 hours in the future
      datetime fromTime = nowUTC - 3600;
      datetime toTime = nowUTC + 7200;

      MqlCalendarValue values[];
      // Query US events using "USD" currency
      int total = CalendarValueHistory(values, fromTime, toTime, "US", "USD");
      if(total <= 0) return false;

      for(int i = 0; i < total; i++)
      {
         MqlCalendarEvent event;
         if(CalendarEventById(values[i].event_id, event))
         {
            // We only check for high impact events (CALENDAR_IMPORTANCE_HIGH)
            if(event.importance == CALENDAR_IMPORTANCE_HIGH)
            {
               datetime eventTime = values[i].time;
               // Check if current UTC time is within the window (30 mins before, 15 mins after)
               if(nowUTC >= eventTime - 1800 && nowUTC <= eventTime + 900)
               {
                  outEventName = event.name;
                  return true;
               }
            }
         }
      }
      return false;
   }

public:
   /**
    * @brief Constructor.
    */
   CRiskGuardian(CLogger* logger, CConfig* config)
      : m_logger(logger),
        m_config(config),
        m_sessionEngine(NULL),
        m_blockReason("None"),
        m_isPaused(false),
        m_peakEquity(0.0),
        m_peakBalance(0.0) // V5.5
   {}

   /**
    * @brief Destructor.
    */
   ~CRiskGuardian() {}

   /**
    * @brief Inject Session Engine dependency.
    */
   virtual void InitializeRiskGuardian(ISessionEngine* sessionEngine) override
   {
      m_sessionEngine = sessionEngine;
   }

   /**
    * @brief Audits risk parameters and updates structural results.
    */
    virtual bool AuditSignal(const StrategyResponse &signal, RiskAuditResponse &outResponse) override
    {
       outResponse.Approved = true;
       outResponse.Reason = "None";
       outResponse.CurrentRiskLevel = m_config.GetRiskPercent();
       outResponse.PenaltyScore = 0.0;

       // Capital Protection Guardian 1: Friday 21:00 UTC Weekend Gap Protection
       MqlDateTime dtNow;
       TimeToStruct(TimeCurrent(), dtNow);
       if(dtNow.day_of_week == 5 && dtNow.hour >= 21)
       {
          outResponse.Reason = "Friday 21:00 UTC Weekend Gap Protection Active (No Weekend Exposure)";
          outResponse.Approved = false;
          return false;
       }

       // 45-Minute System Cooldown Guard (Eliminates Overtrading / Whipsawing)
       datetime lastCloseTime = GetLastSystemCloseTime(m_config.GetMagicNumber());
       if(lastCloseTime > 0 && (TimeCurrent() - lastCloseTime) < 2700)
       {
          int remainingSec = (int)(2700 - (TimeCurrent() - lastCloseTime));
          outResponse.Reason = StringFormat("System Cooldown Active: Waiting %d minutes before next trade entry.", (remainingSec / 60) + 1);
          outResponse.Approved = false;
          return false;
       }

       // Low Volatility Squeeze Prohibition (Blocks trading in flat sideways chop)
       int atrHandle = iATR(_Symbol, PERIOD_M15, 14);
       if(atrHandle != INVALID_HANDLE)
       {
          double atrVals[];
          ArraySetAsSeries(atrVals, true);
          if(CopyBuffer(atrHandle, 0, 0, 1, atrVals) > 0)
          {
             double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
             if(point > 0.0 && atrVals[0] < 7.0 * point)
             {
                outResponse.Reason = StringFormat("Low Volatility Squeeze Blocked: ATR (%.2f pips) is too low for safe trading.", atrVals[0] / (point * 10.0));
                IndicatorRelease(atrHandle);
                outResponse.Approved = false;
                return false;
             }
          }
          IndicatorRelease(atrHandle);
       }

       // Strict H1 Higher-Timeframe Trend Lock (Never trade against H1 EMA 200)
       // Enforce H1 Trend Lock ONLY for Trending/Breakout strategies (G-008 and G-001)
       if(signal.StrategyName == "G-008" || signal.StrategyName == "G-001")
       {
          int h1EmaHandle = iMA(_Symbol, PERIOD_H1, 200, 0, MODE_EMA, PRICE_CLOSE);
          if(h1EmaHandle != INVALID_HANDLE)
          {
             double h1Ema200Val[];
             ArraySetAsSeries(h1Ema200Val, true);
             if(CopyBuffer(h1EmaHandle, 0, 0, 1, h1Ema200Val) > 0)
             {
                double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                if(currentPrice < h1Ema200Val[0] && signal.Signal == GEV2_SIGNAL_BUY)
                {
                   outResponse.Reason = "H1 Trend Lock Blocked BUY: H1 Price is in Strong Downtrend below H1 EMA 200";
                   m_logger.Warning("[RISK] " + outResponse.Reason);
                   IndicatorRelease(h1EmaHandle);
                   outResponse.Approved = false;
                   return false;
                }
                else if(currentPrice > h1Ema200Val[0] && signal.Signal == GEV2_SIGNAL_SELL)
                {
                   outResponse.Reason = "H1 Trend Lock Blocked SELL: H1 Price is in Strong Uptrend above H1 EMA 200";
                   m_logger.Warning("[RISK] " + outResponse.Reason);
                   IndicatorRelease(h1EmaHandle);
                   outResponse.Approved = false;
                   return false;
                }
             }
             IndicatorRelease(h1EmaHandle);
          }
       }

       // CRITICAL ISSUE 3 Validation: Verify signal is only BUY or SELL (Hard Check)
       if(signal.Signal != GEV2_SIGNAL_BUY && signal.Signal != GEV2_SIGNAL_SELL)
       {
          outResponse.Reason = StringFormat("Risk Guardian Blocked: Invalid signal type (%d)", signal.Signal);
          m_logger.Warning("[RISK] " + outResponse.Reason);
          outResponse.Approved = false;
          return false;
       }

       // Emergency Stop / Manual Pause (Hard Check)
       if(m_config.IsEmergencyStopActive())
       {
          outResponse.Reason = "Emergency Stop Switch is Active (Manual Stop)";
          m_logger.Warning("[RISK] " + outResponse.Reason);
          outResponse.Approved = false;
          return false;
       }
        if(m_isPaused)
        {
           outResponse.Reason = "Risk Guardian manually paused (Manual Stop)";
           m_logger.Warning("[RISK] " + outResponse.Reason);
           outResponse.Approved = false;
           return false;
        }

        // Economic Calendar News Filter check (Hard Check)
        if(m_config.IsCalendarNewsFilterEnabled())
        {
           string eventName = "";
           if(IsInsideNewsWindow(eventName))
           {
              // GITS V5.11: If strategy is S-003b and News Opportunity Mode is enabled, bypass this block
              if(signal.StrategyName == "S-003b" && m_config.GetS003_NewsOpportunityMode())
              {
                 // Allowed as news opportunity!
              }
              else
              {
                 outResponse.Reason = StringFormat("Economic Calendar Pause: High-Impact USD event '%s' active.", eventName);
                 m_logger.Warning("[RISK] " + outResponse.Reason);
                 outResponse.Approved = false;
                 return false;
              }
           }
        }

       // Insufficient Margin Check (Hard Check)
       double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
       double proposedLot = AllowedRisk(signal);
       double initialMargin = 0.0;
       if(SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_INITIAL, initialMargin) && initialMargin > 0.0)
       {
          double requiredMargin = proposedLot * initialMargin;
          if(freeMargin < requiredMargin)
          {
             outResponse.Reason = StringFormat("Insufficient Margin. Required: %.2f, Free: %.2f", requiredMargin, freeMargin);
             m_logger.Warning("[RISK] " + outResponse.Reason);
             outResponse.Approved = false;
             return false;
          }
       }

       // GITS V5.5: Trailing Capital Lock Guard (Layer 1)
      double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(m_peakBalance <= 0.0) m_peakBalance = currentBalance;
      if(currentBalance > m_peakBalance) m_peakBalance = currentBalance;

       double floor = m_config.GetCapitalLockFloor();
       bool isLockEnabled = m_config.IsCapitalLockEnabled();

       if(m_config.IsAutoCapitalLock())
       {
          isLockEnabled = true; // Auto-lock is always active if enabled
          double baseFloor = m_config.GetCapitalLockFloor();
          double profit = currentBalance - baseFloor;
          double stepSize = m_config.GetLockStepUSD();
          if(profit > 0.0 && stepSize > 0.0)
          {
             double completedSteps = MathFloor(profit / stepSize) * stepSize;
             if(completedSteps > 0.0)
             {
                double lockedProfit = completedSteps * (1.0 - m_config.GetRiskProfitPercent() / 100.0);
                floor = baseFloor + lockedProfit;
             }
          }
       }

       if(isLockEnabled)
       {
          bool triggerMet = true;
          if(!m_config.IsAutoCapitalLock() && m_peakBalance < m_config.GetCapitalLockTrigger())
          {
             triggerMet = false;
          }
          
          bool isBreached = false;
          if(m_config.IsAutoCapitalLock())
          {
             if(currentBalance < floor || currentEquity < floor)
                isBreached = true;
          }
          else
          {
             if(currentBalance <= floor || currentEquity <= floor)
                isBreached = true;
          }
          
          if(triggerMet && isBreached)
          {
             outResponse.Reason = StringFormat("Capital Lock Active. Core capital protected. Dynamic Floor: %.2f", floor);
             m_logger.Warning("[RISK] " + outResponse.Reason);
             outResponse.Approved = false;
             return false;
          }
       }

      // V5.1 RESEARCH MODE BYPASS (All soft penalties default to 0 in Research mode)
       if(m_config.IsResearchMode())
       {
          outResponse.Approved = true;
          outResponse.Reason   = "PROFILE_RESEARCH: All internal soft penalties bypassed.";
          outResponse.PenaltyScore = 0.0;
          return true;
       }

       // V5.2.0 Unified Decision Engine: Soft conditions become weighted penalties
       ulong magic = m_config.GetMagicNumber();

       // 3. Peak Equity Drawdown calculations
       if(m_peakEquity <= 0.0) m_peakEquity = currentBalance;
       
       outResponse.CurrentDrawdown = ((m_peakEquity - currentEquity) / m_peakEquity) * 100.0;
       if(outResponse.CurrentDrawdown < 0.0) outResponse.CurrentDrawdown = 0.0;

       if(outResponse.CurrentDrawdown >= m_config.GetMaxDrawdownPercent())
       {
          outResponse.PenaltyScore += 20.0;
          outResponse.Reason = "Drawdown Limit Breach; ";
       }

       // 4. Daily Loss Limit Checks
       double dailyPL = GetDailyRealizedPL(magic);
       double startBalanceDaily = currentBalance - dailyPL;
       double maxDailyLossAmount = startBalanceDaily * (m_config.GetMaxDailyLossPercent() / 100.0);
       outResponse.RemainingDailyLoss = maxDailyLossAmount + dailyPL;
       if(outResponse.RemainingDailyLoss < 0.0) outResponse.RemainingDailyLoss = 0.0;

       if(dailyPL <= -maxDailyLossAmount)
       {
          outResponse.PenaltyScore += 25.0;
          outResponse.Reason += "Daily Loss Limit Breach; ";
       }

       // 5. Weekly Loss Limit Checks
       double weeklyPL = GetWeeklyRealizedPL(magic);
       double startBalanceWeekly = currentBalance - weeklyPL;
       double maxWeeklyLossAmount = startBalanceWeekly * (m_config.GetMaxWeeklyLossPercent() / 100.0);
       outResponse.RemainingWeeklyLoss = maxWeeklyLossAmount + weeklyPL;
       if(outResponse.RemainingWeeklyLoss < 0.0) outResponse.RemainingWeeklyLoss = 0.0;

       if(weeklyPL <= -maxWeeklyLossAmount)
       {
          outResponse.PenaltyScore += 25.0;
          outResponse.Reason += "Weekly Loss Limit Breach; ";
       }

       // 6. Consecutive Losses Streak and pause timer Checks
       int streak = 0;
       datetime lastLossTime = 0;
       GetConsecutiveLossesInfo(magic, streak, lastLossTime);
       if(streak >= m_config.GetMaxConsecutiveLosses())
       {
          datetime elapsed = TimeCurrent() - lastLossTime;
          datetime pauseThreshold = m_config.GetPauseMinutes() * 60;
          if(elapsed < pauseThreshold)
          {
             outResponse.PenaltyScore += 25.0;
             outResponse.Reason += "Consecutive Losses Pause; ";
          }
       }

       // 7. Maximum Open Positions Checks
       int openCount = 0;
       double totalLots = 0.0;
       for(int i = 0; i < PositionsTotal(); i++)
       {
          if(PositionGetSymbol(i) == _Symbol)
          {
             if(PositionGetInteger(POSITION_MAGIC) == magic)
             {
                openCount++;
                totalLots += PositionGetDouble(POSITION_VOLUME);
             }
          }
       }

       if(openCount >= m_config.GetMaximumOpenPositions())
       {
          outResponse.PenaltyScore += 20.0;
          outResponse.Reason += "Max Open Positions Reached; ";
       }

       // 8. Maximum Portfolio Exposure Checks
       double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
       double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
       double exposureVal = totalLots * contractSize * currentPrice;
       outResponse.CurrentExposure = (currentBalance > 0.0) ? (exposureVal / currentBalance) * 100.0 : 0.0;

       if(outResponse.CurrentExposure >= m_config.GetMaximumExposurePercent())
       {
          outResponse.PenaltyScore += 20.0;
          outResponse.Reason += "Exposure Limit Exceeded; ";
       }

        // 9. Cooldown Timer checks (V5.5: Hard Block to prevent immediate reentry loss loops)
        if(m_config.IsCooldownEnabled())
        {
           datetime lastClose = GetLastCloseTime(magic, signal.StrategyName);
           if(lastClose > 0)
           {
              datetime elapsed = TimeCurrent() - lastClose;
              datetime cooldownThreshold = m_config.GetCooldownMinutes() * 60;
              if(elapsed < cooldownThreshold)
              {
                 outResponse.Reason = StringFormat("Risk Guardian Blocked: Cooldown Active (wait %d more seconds)", (cooldownThreshold - elapsed));
                 m_logger.Warning("[RISK] " + outResponse.Reason);
                 outResponse.Approved = false;
                 return false;
              }
           }
        }

        // 10. Spread Protection Checks
        int currentSpread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
        if(currentSpread > m_config.GetMaximumSpreadPoints())
        {
           outResponse.Reason = StringFormat("Spread Too High. Current: %d, Max allowed: %d", currentSpread, m_config.GetMaximumSpreadPoints());
           m_logger.Warning("[RISK] " + outResponse.Reason);
           outResponse.Approved = false;
           return false;
        }

       // 11. Trading Session Checks (Sessions)
       if(m_config.IsSessionFilterEnabled() && m_sessionEngine != NULL)
       {
          string activeSession = m_sessionEngine.GetCurrentSession();
          if(activeSession == "OFF-HOURS / CLOSE")
          {
             outResponse.PenaltyScore += 15.0;
             outResponse.Reason += "Off-Hours / Closed Session; ";
          }
       }

       outResponse.Approved = true;
       return true;
    }

   /**
    * @brief Legacy boolean check.
    */
   virtual bool CanTrade(const StrategyResponse &signal) override
   {
      RiskAuditResponse resp;
      return AuditSignal(signal, resp);
   }

   /**
    * @brief Computes maximum risk capital allowed (lot size bounds) for a proposed signal.
    */
    virtual double AllowedRisk(const StrategyResponse &signal) override
    {
       double balance = AccountInfoDouble(ACCOUNT_BALANCE);
       double baseBalance = balance;

       if(m_config.IsAutoCapitalLock())
       {
          double baseFloor = m_config.GetCapitalLockFloor();
          double currentFloor = baseFloor;
          double profit = balance - baseFloor;
          double stepSize = m_config.GetLockStepUSD();
          if(profit > 0.0 && stepSize > 0.0)
          {
             double completedSteps = MathFloor(profit / stepSize) * stepSize;
             if(completedSteps > 0.0)
             {
                double lockedProfit = completedSteps * (1.0 - m_config.GetRiskProfitPercent() / 100.0);
                currentFloor = baseFloor + lockedProfit;
             }
          }
          
          double activeBuffer = balance - currentFloor;
          if(activeBuffer > 0.0)
          {
             baseBalance = activeBuffer;
          }
       }

       double riskAmount = baseBalance * (m_config.GetRiskPercent() / 100.0);
       
       double slPoints = MathAbs(signal.EntryPrice - signal.StopLoss) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
       if(slPoints <= 0.0) return m_config.GetFixedLotSize();

       double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
       double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
       double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
       
       double calculatedLot = riskAmount / (slPoints * (tickValue / (tickSize / point)));
       double lot = m_config.IsUsingFixedLot() ? m_config.GetFixedLotSize() : calculatedLot;

       // V5.5: Compounding lot size override: starts at 0.01 lot for $100 and adds 0.01 lot per $50 increase
       if(m_config.IsUsingCompoundingLot())
       {
          double compBalance = m_config.IsCompoundingOnTotalBalance() ? balance : (m_config.IsAutoCapitalLock() ? baseBalance : balance);
          lot = 0.01 + MathFloor((compBalance - 100.0) / 50.0) * 0.01;
          if(lot < 0.01) lot = 0.01; // Bug Fix: Force minimum 0.01 lot size to prevent halting under $100
       }

       // V5.5: Clamp calculated lot size to symbol's minimum lot size to support low-balance trading (<$100)
       double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
       if(minVol > 0.0 && lot < minVol)
       {
          lot = minVol;
       }
       return lot;
    }

   virtual bool CanIncreaseRisk(double currentRisk) override { return true; }
   virtual bool CanOpenAdditionalPosition() override { return true; }
   virtual double MaximumExposure() override { return m_config.GetMaximumExposurePercent(); }
   
   virtual void PauseTrading(const string reason) override
   {
      m_isPaused = true;
      m_blockReason = reason;
      m_logger.Warning("Risk Guardian: Manually PAUSED. Reason: " + reason);
   }

   virtual void ResumeTrading() override
   {
      m_isPaused = false;
      m_blockReason = "None";
      m_logger.Info("Risk Guardian: Manually RESUMED.");
   }

   virtual string Reason() const override { return m_blockReason; }

   /**
    * @brief Updates daily drawdown peak equity metrics.
    */
   virtual void UpdateRiskState() override
   {
      double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(currentEquity > m_peakEquity)
      {
         m_peakEquity = currentEquity;
      }
      double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      if(currentBalance > m_peakBalance)
      {
         m_peakBalance = currentBalance;
      }
   }
};

#endif // GOLDENGINEV2_RISK_GUARDIAN_MQH
