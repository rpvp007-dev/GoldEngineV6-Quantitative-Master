//+------------------------------------------------------------------+
//|                                                       Logger.mqh |
//|                                  Copyright 2026, GoldEngine V2   |
//|                                       https://github.com/goldv2  |
//+------------------------------------------------------------------+
#ifndef GOLDENGINEV2_LOGGER_MQH
#define GOLDENGINEV2_LOGGER_MQH

#include "CoreDefines.mqh"

//+------------------------------------------------------------------+
//| Structured Logger class                                          |
//+------------------------------------------------------------------+
class CLogger
{
private:
   ENUM_GEV2_LOG_LEVEL m_minLevel;
   string            m_prefix;

   /**
    * @brief Converts ENUM_GEV2_LOG_LEVEL to string.
    */
   string LogLevelToString(ENUM_GEV2_LOG_LEVEL level)
   {
      switch(level)
      {
         case GEV2_LOG_DEBUG:    return "DEBUG";
         case GEV2_LOG_INFO:     return "INFO";
         case GEV2_LOG_WARNING:  return "WARNING";
         case GEV2_LOG_ERROR:    return "ERROR";
         case GEV2_LOG_CRITICAL: return "CRITICAL";
         default:                return "UNKNOWN";
      }
   }

public:
   /**
    * @brief Constructor.
    */
   CLogger()
   {
      m_minLevel = GEV2_LOG_INFO;
      m_prefix = "GoldEngineV4";
   }

   /**
    * @brief Destructor.
    */
   ~CLogger() {}

   /**
    * @brief Set minimum log level.
    */
   void SetMinLevel(ENUM_GEV2_LOG_LEVEL level) { m_minLevel = level; }

   /**
    * @brief Set logging prefix.
    */
   void SetPrefix(string prefix) { m_prefix = prefix; }

   /**
    * @brief Core log method.
    */
   void Log(ENUM_GEV2_LOG_LEVEL level, string message)
   {
      if(level >= m_minLevel)
      {
         string levelStr = LogLevelToString(level);
         PrintFormat("[%s] [%s] %s", m_prefix, levelStr, message);

         // V5.5: Save daily separated log files in MQL5/Files/GoldEngine_Logs folder
         MqlDateTime dt;
         TimeToStruct(TimeLocal(), dt);
         
         string dirName = "GoldEngine_Logs";
         string fileName = StringFormat("%s\\%s_%04d%02d%02d.log", dirName, m_prefix, dt.year, dt.mon, dt.day);
         
         int handle = FileOpen(fileName, FILE_WRITE | FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
         if(handle != INVALID_HANDLE)
         {
            FileSeek(handle, 0, SEEK_END);
            string timeStr = StringFormat("%02d:%02d:%02d", dt.hour, dt.min, dt.sec);
            string logLine = StringFormat("[%s] [%s] %s\r\n", timeStr, levelStr, message);
            FileWriteString(handle, logLine);
            FileClose(handle);
         }
      }
   }

   //--- Convenience methods
   void Debug(string message) { Log(GEV2_LOG_DEBUG, message); }
   void Info(string message) { Log(GEV2_LOG_INFO, message); }
   void Warning(string message) { Log(GEV2_LOG_WARNING, message); }
   void Error(string message) { Log(GEV2_LOG_ERROR, message); }
   void Critical(string message) { Log(GEV2_LOG_CRITICAL, message); }
};

#endif // GOLDENGINEV2_LOGGER_MQH
