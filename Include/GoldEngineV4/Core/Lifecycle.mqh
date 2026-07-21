//+------------------------------------------------------------------+
//|                                                    Lifecycle.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_LIFECYCLE_MQH
#define GOLDENGINEV2_LIFECYCLE_MQH

#include "Logger.mqh"
#include "Config.mqh"

//+------------------------------------------------------------------+
//| System Lifecycle and Health Checker                              |
//+------------------------------------------------------------------+
class CLifecycle
{
private:
   CLogger*          m_logger;
   CConfig*          m_config;
   bool              m_isOperational;

public:
   /**
    * @brief Constructor.
    */
   CLifecycle(CLogger* logger, CConfig* config)
      : m_logger(logger),
        m_config(config),
        m_isOperational(false)
   {}

   /**
    * @brief Destructor.
    */
   ~CLifecycle() {}

   /**
    * @brief Performs checks on broker connection, account permissions, and MT5 environment.
    * @return true if all environment checks pass, false otherwise.
    */
   bool AuditEnvironment(const string symbol)
   {
      m_isOperational = false;

      // 1. Check Terminal connection
      if(!TerminalInfoInteger(TERMINAL_CONNECTED))
      {
         m_logger.Error("Lifecycle Audit Failed: Terminal is not connected to broker server.");
         return false;
      }



      if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
      {
         m_logger.Warning("Lifecycle Warning: Trade context is currently busy or EA trading disabled in settings.");
      }

      // 3. Verify trade permissions for symbol
      ENUM_SYMBOL_TRADE_MODE tradeMode = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
      if(tradeMode == SYMBOL_TRADE_MODE_DISABLED)
      {
         m_logger.Error("Lifecycle Audit Failed: Trading is disabled for symbol: " + symbol);
         return false;
      }

      // 4. Audit settings config
      string validationErr;
      if(!m_config.Validate(validationErr))
      {
         m_logger.Error("Lifecycle Audit Failed: Configuration is invalid. Detail: " + validationErr);
         return false;
      }

      m_logger.Info("Lifecycle Audit Passed: System environment is fully operational.");
      m_isOperational = true;
      return true;
   }

   /**
    * @brief Check if the system is currently marked as operational.
    */
   bool IsOperational() const { return m_isOperational; }

   /**
    * @brief Manually set the operational state.
    */
   void SetOperational(bool state) { m_isOperational = state; }
};

#endif // GOLDENGINEV2_LIFECYCLE_MQH
