#ifndef GOLDENGINEV2_EXECUTION_ENGINE_MQH
#define GOLDENGINEV2_EXECUTION_ENGINE_MQH

#include "IExecutionEngine.mqh"
#include "../Core/Logger.mqh"
#include "../Core/Config.mqh"
#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| Concrete Execution Engine Class implementation using CTrade      |
//+------------------------------------------------------------------+
class CExecutionEngine : public IExecutionEngine
{
private:
   CLogger*          m_logger;
   CConfig*          m_config;
   CTrade            m_trade;
   ulong             m_lastDealTicket;
   ulong             m_lastOrderTicket;
   datetime          m_circuitBreakerPauseUntil;

public:
   /**
    * @brief Constructor.
    */
   CExecutionEngine(CLogger* logger, CConfig* config)
      : m_logger(logger),
        m_config(config),
        m_lastDealTicket(0),
        m_lastOrderTicket(0),
        m_circuitBreakerPauseUntil(0)
   {
      m_trade.SetExpertMagicNumber(m_config.GetMagicNumber());
      m_trade.SetDeviationInPoints(m_config.GetSlippagePoints());
   }

   /**
    * @brief Destructor.
    */
   ~CExecutionEngine() {}

   /**
    * @brief Gets the last execution deal ticket.
    */
   virtual ulong GetLastDealTicket() override { return m_lastDealTicket; }

   /**
    * @brief Gets the last execution order ticket.
    */
   virtual ulong GetLastOrderTicket() override { return m_lastOrderTicket; }

   /**
    * @brief Executes an approved trade signal.
    */
   virtual bool ExecuteSignal(const StrategyResponse &signal, ulong magicNumber) override
   {
      // Reset ticket cache
      m_lastDealTicket = 0;
      m_lastOrderTicket = 0;

      // 1. Basic assertions
      if(signal.Signal != GEV2_SIGNAL_BUY && signal.Signal != GEV2_SIGNAL_SELL)
      {
         Print("ASSERTION FAILED: Signal != NO_TRADE before execution");
         return false;
      }

      if(TimeCurrent() < m_circuitBreakerPauseUntil)
      {
         m_logger.Warning(StringFormat("[CIRCUIT BREAKER] Execution Blocked: Trading paused for 2-hour session cooldown until %s due to consecutive losses.", TimeToString(m_circuitBreakerPauseUntil, TIME_DATE|TIME_MINUTES)));
         return false;
      }

      if(signal.StrategyName == "" || _Symbol == "")
      {
         Print("Execution Blocked: Invalid Symbol or Strategy Name");
         return false;
      }

      if(magicNumber <= 0)
      {
         Print("Execution Blocked: Invalid Magic Number");
         return false;
      }

      if(signal.EntryPrice <= 0.0 || signal.StopLoss <= 0.0 || signal.TakeProfit <= 0.0)
      {
         Print("Execution Blocked: Price levels <= 0");
         return false;
      }

      // Check risk consistency
      if(signal.Signal == GEV2_SIGNAL_BUY && signal.StopLoss >= signal.EntryPrice)
      {
         Print("Execution Blocked: Invalid Risk (Stop Loss >= Entry Price for BUY)");
         return false;
      }
      else if(signal.Signal == GEV2_SIGNAL_SELL && signal.StopLoss <= signal.EntryPrice)
      {
         Print("Execution Blocked: Invalid Risk (Stop Loss <= Entry Price for SELL)");
         return false;
      }

      // 2. Pre-Trade Validations
      if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || 
         !MQLInfoInteger(MQL_TRADE_ALLOWED) || 
         !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
      {
         m_logger.Error("Execution Blocked: Trading not allowed by terminal, MQL5, or account permissions.");
         return false;
      }

      ENUM_SYMBOL_TRADE_MODE tradeMode = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
      if(tradeMode == SYMBOL_TRADE_MODE_DISABLED)
      {
         m_logger.Error("Execution Blocked: Symbol trade mode is disabled.");
         return false;
      }
      if(signal.Signal == GEV2_SIGNAL_BUY && tradeMode == SYMBOL_TRADE_MODE_CLOSEONLY)
      {
         m_logger.Error("Execution Blocked: Symbol trade mode is Close-Only, cannot BUY.");
         return false;
      }
      if(signal.Signal == GEV2_SIGNAL_SELL && tradeMode == SYMBOL_TRADE_MODE_CLOSEONLY)
      {
         m_logger.Error("Execution Blocked: Symbol trade mode is Close-Only, cannot SELL.");
         return false;
      }

      if(!SymbolInfoInteger(_Symbol, SYMBOL_SELECT))
      {
         if(!SymbolSelect(_Symbol, true))
         {
            m_logger.Error("Execution Blocked: Symbol not selected in Market Watch.");
            return false;
         }
      }

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(bid <= 0.0 || ask <= 0.0 || bid >= ask)
      {
         m_logger.Error("Execution Blocked: Invalid Bid/Ask prices.");
         return false;
      }

      // 3. Position and Exposure Checks (Prevent double-entries & Handle Position Flipping)
      
      // GITS V5.5: Position Flipping (Stop & Reverse)
      // Close any opposing positions before executing the new signal direction
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionGetSymbol(i) == _Symbol)
         {
            if(PositionGetInteger(POSITION_MAGIC) == magicNumber && PositionGetString(POSITION_COMMENT) == signal.StrategyName)
            {
               long posType = PositionGetInteger(POSITION_TYPE);
               if((signal.Signal == GEV2_SIGNAL_BUY && posType == POSITION_TYPE_SELL) ||
                  (signal.Signal == GEV2_SIGNAL_SELL && posType == POSITION_TYPE_BUY))
               {
                  ulong ticket = PositionGetInteger(POSITION_TICKET);
                  m_logger.Warning(StringFormat("[FLIP] Opposing position ticket %d detected. Force closing before opening reverse trade.", ticket));
                  m_trade.PositionClose(ticket);
               }
            }
         }
      }

      bool hasDuplicateEntry = false;
      int totalPositions = PositionsTotal();
      for(int i = 0; i < totalPositions; i++)
      {
         if(PositionGetSymbol(i) == _Symbol)
         {
            if(PositionGetInteger(POSITION_MAGIC) == magicNumber)
            {
               double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
               double diff = MathAbs(signal.EntryPrice - openPrice);
               double minSpacing = 10.0 * SymbolInfoDouble(_Symbol, SYMBOL_POINT); // 10 points minimum difference
               if(diff < minSpacing)
               {
                  hasDuplicateEntry = true;
                  break;
               }
            }
         }
      }
      // Enforce 1 active position per strategy
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionGetSymbol(i) == _Symbol)
         {
            if(PositionGetString(POSITION_COMMENT) == signal.StrategyName)
            {
               m_logger.Warning(StringFormat("Execution Blocked: Strategy '%s' already has an open active position.", signal.StrategyName));
               return false;
            }
         }
      }

      if(hasDuplicateEntry)
      {
         m_logger.Warning("Execution Blocked: Duplicate position already open at the same price level.");
         return false;
      }

      // Calculate lot size
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

      // Dynamic Dynamic Scale-Up / Scale-Down Lot Ladder:
      // $50 = 0.01 lot, $100 = 0.02 lots, $150 = 0.03 lots, $200 = 0.04 lots, $250 = 0.05 lots...
      // Dynamically increases as account grows and decreases as account drops!
      double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      double lotSize = MathFloor(currentBalance / 50.0) * 0.01;
      if(lotSize < 0.01) lotSize = 0.01;

      if(lotSize <= 0.0)
      {
         Print("Execution Blocked: Calculated lot size <= 0");
         return false;
      }
      
      // Safety Cap: Maximum 5.0 lots per trade to protect account against catastrophic slippage
      double absoluteMaxCap = 5.0;
      if(lotSize > absoluteMaxCap)
      {
         m_logger.Warning(StringFormat("Execution Engine: Calculated lot size (%.2f) exceeded safety cap. Clamping to %.2f lots.", lotSize, absoluteMaxCap));
         lotSize = absoluteMaxCap;
      }

      // 4. Volume Normalization & Bounds Verification
      double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double maxVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double stepVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      if(stepVol <= 0.0) stepVol = 0.01;

      int volDecimals = 0;
      double tempStep = stepVol;
      while(tempStep < 1.0)
      {
         tempStep *= 10.0;
         volDecimals++;
         if(volDecimals > 4) break;
      }

      double normalizedLot = MathRound(lotSize / stepVol) * stepVol;
      normalizedLot = NormalizeDouble(normalizedLot, volDecimals);

      // V5.5: Clamp normalized lot size to symbol's minimum lot size to support low-balance trading (<$100)
      if(normalizedLot < minVol)
      {
         normalizedLot = minVol;
      }

      if(normalizedLot < minVol || normalizedLot > maxVol)
      {
         m_logger.Error(StringFormat("Execution Blocked: Lot %.2f normalized to %.2f is outside limits [Min: %.2f, Max: %.2f]",
            lotSize, normalizedLot, minVol, maxVol));
         return false;
      }

      // Calculate required margin
      double marginRequired = 0.0;
      ENUM_ORDER_TYPE orderType = (signal.Signal == GEV2_SIGNAL_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      double checkPrice = (signal.Signal == GEV2_SIGNAL_BUY) ? ask : bid;
      if(!OrderCalcMargin(orderType, _Symbol, normalizedLot, checkPrice, marginRequired))
      {
         m_logger.Error("Execution Blocked: Failed to calculate margin required.");
         return false;
      }
      double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      if(freeMargin < marginRequired)
      {
         m_logger.Error(StringFormat("Execution Blocked: Insufficient margin. Required: %.2f, Free: %.2f", marginRequired, freeMargin));
         return false;
      }

      // 5. Price Normalization & Level Checks
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tickSize <= 0.0) tickSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

      double entryPrice = NormalizeDouble(MathRound(signal.EntryPrice / tickSize) * tickSize, _Digits);
      double slPrice = NormalizeDouble(MathRound(signal.StopLoss / tickSize) * tickSize, _Digits);
      double tpPrice = NormalizeDouble(MathRound(signal.TakeProfit / tickSize) * tickSize, _Digits);

      double stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(stopsLevel > 0.0)
      {
         if(signal.Signal == GEV2_SIGNAL_BUY)
         {
            if(entryPrice - slPrice < stopsLevel || tpPrice - entryPrice < stopsLevel)
            {
               m_logger.Error("Execution Blocked: Stop Loss or Take Profit distance is inside Stops Level.");
               return false;
            }
         }
         else
         {
            if(slPrice - entryPrice < stopsLevel || entryPrice - tpPrice < stopsLevel)
            {
               m_logger.Error("Execution Blocked: Stop Loss or Take Profit distance is inside Stops Level.");
               return false;
            }
         }
      }

      // Set filling mode dynamically
      uint filling = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
      if((filling & SYMBOL_FILLING_FOK) != 0) m_trade.SetTypeFilling(ORDER_FILLING_FOK);
      else if((filling & SYMBOL_FILLING_IOC) != 0) m_trade.SetTypeFilling(ORDER_FILLING_IOC);
      else m_trade.SetTypeFilling(ORDER_FILLING_RETURN);

      // 6. Real Trade Execution with Retry Logic
      m_trade.SetExpertMagicNumber(magicNumber);
      bool success = false;
      int attempts = 0;
      int maxAttempts = 2;
      int lastErr = 0;

      while(attempts < maxAttempts)
      {
         attempts++;
         
         // Refresh prices
         double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double execPrice = (signal.Signal == GEV2_SIGNAL_BUY) ? currentAsk : currentBid;
         execPrice = NormalizeDouble(MathRound(execPrice / tickSize) * tickSize, _Digits);
         
         // Keep relative distance for SL/TP
         double entryShift = execPrice - entryPrice;
         double slAdjusted = slPrice + entryShift;
         double tpAdjusted = tpPrice + entryShift;
         slAdjusted = NormalizeDouble(MathRound(slAdjusted / tickSize) * tickSize, _Digits);
         tpAdjusted = NormalizeDouble(MathRound(tpAdjusted / tickSize) * tickSize, _Digits);

         ResetLastError();
         bool res = false;
         
         if(signal.Signal == GEV2_SIGNAL_BUY)
         {
            res = m_trade.Buy(normalizedLot, _Symbol, execPrice, slAdjusted, tpAdjusted, signal.StrategyName);
         }
         else
         {
            res = m_trade.Sell(normalizedLot, _Symbol, execPrice, slAdjusted, tpAdjusted, signal.StrategyName);
         }

         uint retcode = m_trade.ResultRetcode();
         lastErr = GetLastError();

         // Check if retry is needed
         if(!res && (retcode == TRADE_RETCODE_REQUOTE || retcode == TRADE_RETCODE_PRICE_CHANGED || retcode == TRADE_RETCODE_PRICE_OFF))
         {
            m_logger.Warning(StringFormat("Execution Engine: Trade failed with retcode %d (%s). Retrying (Attempt %d/%d)...",
               retcode, m_trade.ResultRetcodeDescription(), attempts, maxAttempts));
            Sleep(100);
            continue;
         }

         success = res && (retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_PLACED);
         break;
      }

      // Populate tickets on success
      if(success)
      {
         m_lastDealTicket = m_trade.ResultDeal();
         m_lastOrderTicket = m_trade.ResultOrder();
         if(m_lastDealTicket == 0)
         {
            m_lastDealTicket = m_lastOrderTicket;
         }
      }

      // 7. Print Execution Report
      Print("====================================================");
      Print("MT5 EXECUTION REPORT");
      Print("Direction: " + ((signal.Signal == GEV2_SIGNAL_BUY) ? "BUY" : "SELL"));
      Print(StringFormat("Volume: %.2f", normalizedLot));
      Print(StringFormat("Entry Price: %.5f", entryPrice));
      Print(StringFormat("Stop Loss: %.5f", slPrice));
      Print(StringFormat("Take Profit: %.5f", tpPrice));
      Print("Buy()/Sell() Return: " + (success ? "TRUE" : "FALSE"));
      Print(StringFormat("Retcode: %d", m_trade.ResultRetcode()));
      Print("Retcode Description: " + m_trade.ResultRetcodeDescription());
      Print(StringFormat("Deal Ticket: %I64u", m_trade.ResultDeal()));
      Print(StringFormat("Order Ticket: %I64u", m_trade.ResultOrder()));
      Print(StringFormat("Executed Price: %.5f", m_trade.ResultPrice()));
      Print(StringFormat("Executed Volume: %.2f", m_trade.ResultVolume()));
      Print(StringFormat("LastError: %d", lastErr));
      Print("====================================================");

      return success;
   }

   /**
    * @brief Modifies Stop Loss and Take Profit levels of an active trade.
    */
   virtual bool ModifyPosition(ulong ticket, double sl, double tp) override
   {
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tickSize <= 0.0) tickSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      double normSL = NormalizeDouble(MathRound(sl / tickSize) * tickSize, _Digits);
      double normTP = NormalizeDouble(MathRound(tp / tickSize) * tickSize, _Digits);

      m_logger.Info(StringFormat("Execution Engine: Modifying position ticket #%I64u [SL: %.5f, TP: %.5f]", ticket, normSL, normTP));
      
      ResetLastError();
      bool res = m_trade.PositionModify(ticket, normSL, normTP);
      if(!res)
      {
         m_logger.Error(StringFormat("Execution Engine: Position modification failed for ticket #%I64u. Retcode: %d (%s). LastError: %d",
            ticket, m_trade.ResultRetcode(), m_trade.ResultRetcodeDescription(), GetLastError()));
      }
      return res;
   }

   /**
    * @brief Cancels a pending order.
    */
   virtual bool CancelOrder(ulong ticket) override
   {
      m_logger.Info(StringFormat("Execution Engine: Cancelling order ticket #%I64u", ticket));
      
      ResetLastError();
      bool res = m_trade.OrderDelete(ticket);
      if(!res)
      {
         m_logger.Error(StringFormat("Execution Engine: Order cancellation failed for ticket #%I64u. Retcode: %d (%s). LastError: %d",
            ticket, m_trade.ResultRetcode(), m_trade.ResultRetcodeDescription(), GetLastError()));
      }
      return res;
   }

   /**
    * @brief Trade synchronization.
    */
   virtual void SynchronizeTrades() override
   {
      // Synchronization logic will map running trades in the future
   }
};

#endif // GOLDENGINEV2_EXECUTION_ENGINE_MQH
