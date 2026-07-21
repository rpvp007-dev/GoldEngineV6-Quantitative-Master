//+------------------------------------------------------------------+
//|                                                 SessionEngine.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_SESSION_ENGINE_MQH
#define GOLDENGINEV2_SESSION_ENGINE_MQH

#include "ISessionEngine.mqh"

//+------------------------------------------------------------------+
//| Session Engine Implementation (GITS V2.4)                        |
//+------------------------------------------------------------------+
class CSessionEngine : public ISessionEngine
{
private:
   // Default Session Hour Ranges (Broker Server Time hours)
   int               m_asiaStart;
   int               m_asiaEnd;
   int               m_londonStart;
   int               m_londonEnd;
   int               m_nyStart;
   int               m_nyEnd;

   /**
    * @brief Internal time ranges checker.
    */
   bool IsHourInRange(int hour, int startHour, int endHour)
   {
      if(startHour <= endHour)
      {
         return (hour >= startHour && hour < endHour);
      }
      else // Wraps around midnight
      {
         return (hour >= startHour || hour < endHour);
      }
   }

   /**
    * @brief Gets current broker server time hour and minute.
    */
   void GetCurrentTimeData(int &outHour, int &outMinute)
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      outHour = dt.hour;
      outMinute = dt.min;
   }

public:
   /**
    * @brief Constructor.
    */
   CSessionEngine()
      : m_asiaStart(0),
        m_asiaEnd(9),
        m_londonStart(8),
        m_londonEnd(17),
        m_nyStart(13),
        m_nyEnd(22)
   {}

   /**
    * @brief Destructor.
    */
   ~CSessionEngine() {}

   /**
    * @brief Configures custom session ranges.
    */
   void ConfigureSessions(int asiaStart, int asiaEnd, int lonStart, int lonEnd, int nyStart, int nyEnd)
   {
      m_asiaStart = asiaStart;
      m_asiaEnd = asiaEnd;
      m_londonStart = lonStart;
      m_londonEnd = lonEnd;
      m_nyStart = nyStart;
      m_nyEnd = nyEnd;
   }

   /**
    * @brief Checks if a specific session is active.
    */
   virtual bool IsSessionActive(const string sessionName) override
   {
      int hour, minute;
      GetCurrentTimeData(hour, minute);
      string name = sessionName;
      StringToUpper(name);

      if(name == "ASIA" || name == "TOKYO")
      {
         return IsHourInRange(hour, m_asiaStart, m_asiaEnd);
      }
      if(name == "LONDON" || name == "EUROPE")
      {
         return IsHourInRange(hour, m_londonStart, m_londonEnd);
      }
      if(name == "NEWYORK" || name == "NY" || name == "US")
      {
         return IsHourInRange(hour, m_nyStart, m_nyEnd);
      }

      return false;
   }

   /**
    * @brief Gets description of active sessions and overlaps.
    */
   virtual string GetCurrentSession() override
   {
      bool asia = IsSessionActive("ASIA");
      bool london = IsSessionActive("LONDON");
      bool ny = IsSessionActive("NEWYORK");

      if(london && ny)    return "LONDON/NEWYORK OVERLAP";
      if(asia && london)  return "ASIA/LONDON OVERLAP";
      if(asia)            return "ASIAN SESSION";
      if(london)          return "LONDON SESSION";
      if(ny)              return "NEW YORK SESSION";

      return "OFF-HOURS / CLOSE";
   }

   /**
    * @brief Checks if session overlap is active.
    */
   virtual bool IsOverlapActive() override
   {
      bool asia = IsSessionActive("ASIA");
      bool london = IsSessionActive("LONDON");
      bool ny = IsSessionActive("NEWYORK");

      return ((london && ny) || (asia && london));
   }

   /**
    * @brief Calculates session progress percentage (0.0 to 100.0).
    */
   virtual double GetSessionProgress(const string sessionName) override
   {
      if(!IsSessionActive(sessionName)) return 0.0;

      int hour, minute;
      GetCurrentTimeData(hour, minute);
      int currentMinutes = hour * 60 + minute;

      string name = sessionName;
      StringToUpper(name);

      int startMins = 0;
      int durationMins = 540; // 9 hours is default standard duration

      if(name == "ASIA" || name == "TOKYO")
      {
         startMins = m_asiaStart * 60;
         durationMins = (m_asiaEnd - m_asiaStart) * 60;
      }
      else if(name == "LONDON" || name == "EUROPE")
      {
         startMins = m_londonStart * 60;
         durationMins = (m_londonEnd - m_londonStart) * 60;
      }
      else if(name == "NEWYORK" || name == "NY" || name == "US")
      {
         startMins = m_nyStart * 60;
         durationMins = (m_nyEnd - m_nyStart) * 60;
      }
      else
      {
         return 0.0;
      }

      if(durationMins <= 0) return 0.0;
      
      int elapsed = currentMinutes - startMins;
      if(elapsed < 0) elapsed += 1440; // wrap day
      
      double progress = ((double)elapsed / durationMins) * 100.0;
      if(progress > 100.0) progress = 100.0;
      if(progress < 0.0) progress = 0.0;
      
      return progress;
   }

   /**
    * @brief Gets remaining minutes in the specified session.
    */
   virtual int GetSessionTimeRemaining(const string sessionName) override
   {
      if(!IsSessionActive(sessionName)) return 0;

      int hour, minute;
      GetCurrentTimeData(hour, minute);
      int currentMinutes = hour * 60 + minute;

      string name = sessionName;
      StringToUpper(name);

      int endMins = 0;
      if(name == "ASIA" || name == "TOKYO")
      {
         endMins = m_asiaEnd * 60;
      }
      else if(name == "LONDON" || name == "EUROPE")
      {
         endMins = m_londonEnd * 60;
      }
      else if(name == "NEWYORK" || name == "NY" || name == "US")
      {
         endMins = m_nyEnd * 60;
      }
      else
      {
         return 0;
      }

      int remaining = endMins - currentMinutes;
      if(remaining < 0) remaining += 1440; // wrap day

      return remaining;
   }

   /**
    * @brief Returns a static volatility index relative to standard session ranges.
    */
   virtual double GetSessionVolatilityProfile(const string sessionName) override
   {
      string name = sessionName;
      StringToUpper(name);

      if(name == "ASIA" || name == "TOKYO") return 30.0;
      if(name == "LONDON" || name == "EUROPE") return 85.0;
      if(name == "NEWYORK" || name == "NY" || name == "US") return 75.0;
      
      // If we query current session name dynamically
      if(name == "LONDON/NEWYORK OVERLAP") return 95.0;
      if(name == "ASIA/LONDON OVERLAP") return 60.0;

      return 10.0;
   }

   virtual void Update() override {}

   /**
    * @brief Checks if current time is within windowMinutes of any session open.
    */
   virtual bool IsSessionOpenWindow(int windowMinutes) override
   {
      int hour, minute;
      GetCurrentTimeData(hour, minute);
      
      int currentMinutes = hour * 60 + minute;
      
      // Calculate minutes since start for each session
      int asiaMinutesSinceStart = currentMinutes - (m_asiaStart * 60);
      if(asiaMinutesSinceStart < 0) asiaMinutesSinceStart += 24 * 60; // Handle wrapping
      
      int londonMinutesSinceStart = currentMinutes - (m_londonStart * 60);
      if(londonMinutesSinceStart < 0) londonMinutesSinceStart += 24 * 60;
      
      int nyMinutesSinceStart = currentMinutes - (m_nyStart * 60);
      if(nyMinutesSinceStart < 0) nyMinutesSinceStart += 24 * 60;
      
      // Check if current time is within the first windowMinutes of any session open
      if(asiaMinutesSinceStart >= 0 && asiaMinutesSinceStart <= windowMinutes) return true;
      if(londonMinutesSinceStart >= 0 && londonMinutesSinceStart <= windowMinutes) return true;
      if(nyMinutesSinceStart >= 0 && nyMinutesSinceStart <= windowMinutes) return true;
      
      return false;
   }
};

#endif // GOLDENGINEV2_SESSION_ENGINE_MQH
