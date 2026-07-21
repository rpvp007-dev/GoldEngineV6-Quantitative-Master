//+------------------------------------------------------------------+
//|                                              StrategyManager.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_STRATEGY_MANAGER_MQH
#define GOLDENGINEV2_STRATEGY_MANAGER_MQH

#include "IStrategy.mqh"
#include "../Core/Logger.mqh"

//+------------------------------------------------------------------+
//| Strategy Manager Class (Refactored GITS V2.1)                    |
//| Responsible ONLY for registering, loading, and evaluating       |
//| strategies, collecting and returning their raw responses.        |
//+------------------------------------------------------------------+
class CStrategyManager
{
private:
   IStrategy*        m_strategies[];  // Dynamic array of strategy pointers
   int               m_strategyCount; // Number of registered strategies
   CLogger*          m_logger;

public:
   /**
    * @brief Constructor.
    */
   CStrategyManager(CLogger* logger)
      : m_strategyCount(0),
        m_logger(logger)
   {
      ArrayResize(m_strategies, 0);
   }

   /**
    * @brief Destructor. Cleans up all registered strategies memory.
    */
   ~CStrategyManager()
   {
      for(int i = 0; i < m_strategyCount; i++)
      {
         if(CheckPointer(m_strategies[i]) == POINTER_DYNAMIC)
         {
            delete m_strategies[i];
         }
      }
      m_strategyCount = 0;
      ArrayResize(m_strategies, 0);
   }

   /**
    * @brief Registers a strategy dynamically.
    */
   bool RegisterStrategy(IStrategy* strategy)
   {
      if(strategy == NULL)
      {
         m_logger.Error("Strategy Manager: Cannot register NULL strategy.");
         return false;
      }
 
      // Check for duplicate names
      for(int i = 0; i < m_strategyCount; i++)
      {
         if(m_strategies[i].GetName() == strategy.GetName())
         {
            m_logger.Warning("Strategy Manager: Strategy '" + strategy.GetName() + "' is already registered. Skipping.");
            return false;
         }
      }
 
      m_strategyCount++;
      ArrayResize(m_strategies, m_strategyCount);
      m_strategies[m_strategyCount - 1] = strategy;
      
      m_logger.Info("Strategy Manager: Registered strategy '" + strategy.GetName() + "' successfully.");
      return true;
   }
 
   /**
    * @brief Loads and initializes all registered strategies.
    * @param engines Ptr container to the 9 independent quant engines
    */
   void LoadStrategies(const QuantEnginesContainer &engines)
   {
      m_logger.Info("Strategy Manager: Initializing registered strategies...");
      for(int i = 0; i < m_strategyCount; i++)
      {
         if(m_strategies[i].Initialize(engines))
         {
            m_logger.Info("Strategy Manager: Strategy '" + m_strategies[i].GetName() + "' initialized successfully.");
         }
         else
         {
            m_logger.Error("Strategy Manager: Strategy '" + m_strategies[i].GetName() + "' failed initialization.");
            m_strategies[i].SetEnabled(false);
         }
      }
   }
 
   /**
    * @brief Enables or disables a strategy by name.
    */
   void SetStrategyEnabled(const string name, bool enabled)
   {
      for(int i = 0; i < m_strategyCount; i++)
      {
         if(m_strategies[i].GetName() == name)
         {
            m_strategies[i].SetEnabled(enabled);
            m_logger.Info("Strategy Manager: Strategy '" + name + "' set to " + (enabled ? "ENABLED" : "DISABLED"));
            return;
         }
      }
      m_logger.Warning("Strategy Manager: Strategy '" + name + "' not found to enable/disable.");
   }

    bool IsStrategyEnabled(const string name) const
    {
       for(int i = 0; i < m_strategyCount; i++)
       {
          if(m_strategies[i].GetName() == name)
          {
             return m_strategies[i].IsEnabled();
          }
       }
       return false;
    }
 
   /**
    * @brief Evaluates all enabled strategies and collects their raw responses.
    * @param symbol Trading symbol (e.g. "XAUUSD")
    * @param outResponses Array to populate with raw strategy responses
    * @return Total number of responses collected
    */
   int EvaluateAll(const string symbol, StrategyResponse &outResponses[])
   {
      ArrayResize(outResponses, 0);
      int collectedCount = 0;
 
      for(int i = 0; i < m_strategyCount; i++)
      {
         if(m_strategies[i].IsEnabled())
         {
            // Call Evaluate on strategy
            StrategyResponse response = m_strategies[i].Evaluate(symbol);
            response.StrategyName = m_strategies[i].GetName();
 
            collectedCount++;
            ArrayResize(outResponses, collectedCount);
            outResponses[collectedCount - 1] = response;
            
            m_logger.Debug(StringFormat("Strategy Manager: Evaluated strategy '%s' [Raw Signal: %d]", 
               response.StrategyName, response.Signal));
         }
      }
 
      return collectedCount;
   }

   /**
    * @brief Get count of registered strategies.
    */
   int GetStrategyCount() const { return m_strategyCount; }
};

#endif // GOLDENGINEV2_STRATEGY_MANAGER_MQH
