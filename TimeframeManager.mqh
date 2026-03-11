//+------------------------------------------------------------------+
//|                                                      TimeframeManager.mqh |
//|                                    Copyright 2024, MonEA Project |
//|                                             https://www.monea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MonEA Project"
#property link      "https://www.monea.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| TimeframeManager Class                                           |
//| Manages timeframe-specific operations and checks for the EA      |
//+------------------------------------------------------------------+
class CTimeframeManager
{
private:
   // Timeframe variables
   ENUM_TIMEFRAMES m_rangeTF;      // Timeframe for Asian range calculation
   ENUM_TIMEFRAMES m_execTF;       // Timeframe for trade execution
   ENUM_TIMEFRAMES m_atrTF;        // Timeframe for ATR calculation
   ENUM_TIMEFRAMES m_trendTF;      // Timeframe for trend filter
   
   // Timeframe conversion helpers
   int m_rangeBars;                // Number of bars needed for range calculation
   int m_execBars;                 // Number of bars needed for execution checks
   
   // Session time variables (in minutes from day start)
   int m_asianStartMin;            // Asian session start (00:00 GMT = 0)
   int m_asianEndMin;              // Asian session end (06:00 GMT = 360)
   int m_londonStartMin;           // London session start (08:00 GMT = 480)
   
   // Validation flags
   bool m_isRangeTFValid;          // Range timeframe is valid for calculations
   bool m_isExecTFValid;           // Execution timeframe is valid for trading
   bool m_isSessionTimesValid;     // Session times are logically valid
   
public:
   // Constructor
   CTimeframeManager()
   {
      // Set default timeframes based on project specifications
      m_rangeTF = PERIOD_D1;       // Daily for Asian range
      m_execTF = PERIOD_M30;       // M30 for trade execution (default from EA specs)
      m_atrTF = PERIOD_H1;         // H1 for ATR calculation
      m_trendTF = PERIOD_H1;       // H1 for trend filter
      
      // Calculate session times in minutes (GMT)
      m_asianStartMin = 0;         // 00:00 GMT
      m_asianEndMin = 360;         // 06:00 GMT
      m_londonStartMin = 480;      // 08:00 GMT
      
      // Initialize validation flags
      m_isRangeTFValid = false;
      m_isExecTFValid = false;
      m_isSessionTimesValid = false;
      
      // Initialize bar counts
      m_rangeBars = 0;
      m_execBars = 0;
   }
   
   // Destructor
   ~CTimeframeManager() {}
   
   //+------------------------------------------------------------------+
   //| Initialize the timeframe manager                                 |
   //+------------------------------------------------------------------+
   bool Initialize(ENUM_TIMEFRAMES rangeTF = PERIOD_D1,
                   ENUM_TIMEFRAMES execTF = PERIOD_M30,
                   ENUM_TIMEFRAMES atrTF = PERIOD_H1,
                   ENUM_TIMEFRAMES trendTF = PERIOD_H1,
                   int asianStartHour = 0,
                   int asianStartMinute = 0,
                   int asianEndHour = 6,
                   int asianEndMinute = 0,
                   int londonStartHour = 8,
                   int londonStartMinute = 0)
   {
      // Set timeframes
      m_rangeTF = rangeTF;
      m_execTF = execTF;
      m_atrTF = atrTF;
      m_trendTF = trendTF;
      
      // Calculate session times in minutes
      m_asianStartMin = asianStartHour * 60 + asianStartMinute;
      m_asianEndMin = asianEndHour * 60 + asianEndMinute;
      m_londonStartMin = londonStartHour * 60 + londonStartMinute;
      
      // Validate timeframes
      m_isRangeTFValid = ValidateTimeframe(m_rangeTF);
      m_isExecTFValid = ValidateTimeframe(m_execTF);
      
      // Validate session times
      m_isSessionTimesValid = ValidateSessionTimes();
      
      // Calculate required bars for each timeframe
      if(m_isRangeTFValid && m_isSessionTimesValid)
      {
         m_rangeBars = CalculateRequiredBars(m_rangeTF, m_asianStartMin, m_asianEndMin);
      }
      
      if(m_isExecTFValid)
      {
         // For execution, we need enough bars for indicators (ATR period 14 + buffer)
         m_execBars = 50;  // Conservative buffer for all indicators
      }
      
      // Check if all validations passed
      if(!m_isRangeTFValid || !m_isExecTFValid || !m_isSessionTimesValid)
      {
         Print("TimeframeManager: Initialization failed. Check timeframe and session settings.");
         return false;
      }
      
      PrintFormat("TimeframeManager: Initialized successfully. RangeTF: %s, ExecTF: %s, ATRTF: %s, TrendTF: %s",
                  TimeframeToString(m_rangeTF),
                  TimeframeToString(m_execTF),
                  TimeframeToString(m_atrTF),
                  TimeframeToString(m_trendTF));
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Validate if a timeframe is supported                            |
   //+------------------------------------------------------------------+
   bool ValidateTimeframe(ENUM_TIMEFRAMES tf)
   {
      // Check if timeframe is valid (not PERIOD_CURRENT which is 0)
      if(tf == PERIOD_CURRENT)
      {
         Print("TimeframeManager: PERIOD_CURRENT is not allowed for configuration.");
         return false;
      }
      
      // Check if timeframe exists in standard MT5 timeframes
      switch(tf)
      {
         case PERIOD_M1:
         case PERIOD_M2:
         case PERIOD_M3:
         case PERIOD_M4:
         case PERIOD_M5:
         case PERIOD_M6:
         case PERIOD_M10:
         case PERIOD_M12:
         case PERIOD_M15:
         case PERIOD_M20:
         case PERIOD_M30:
         case PERIOD_H1:
         case PERIOD_H2:
         case PERIOD_H3:
         case PERIOD_H4:
         case PERIOD_H6:
         case PERIOD_H8:
         case PERIOD_H12:
         case PERIOD_D1:
         case PERIOD_W1:
         case PERIOD_MN1:
            return true;
         
         default:
            PrintFormat("TimeframeManager: Unsupported timeframe: %d", tf);
            return false;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Validate session times are logical                              |
   //+------------------------------------------------------------------+
   bool ValidateSessionTimes()
   {
      // Check if Asian session times are valid
      if(m_asianStartMin < 0 || m_asianStartMin >= 1440)
      {
         PrintFormat("TimeframeManager: Invalid Asian start time: %d minutes", m_asianStartMin);
         return false;
      }
      
      if(m_asianEndMin < 0 || m_asianEndMin >= 1440)
      {
         PrintFormat("TimeframeManager: Invalid Asian end time: %d minutes", m_asianEndMin);
         return false;
      }
      
      if(m_asianStartMin >= m_asianEndMin)
      {
         Print("TimeframeManager: Asian session start must be before end.");
         return false;
      }
      
      // Check if London session time is valid
      if(m_londonStartMin < 0 || m_londonStartMin >= 1440)
      {
         PrintFormat("TimeframeManager: Invalid London start time: %d minutes", m_londonStartMin);
         return false;
      }
      
      // Check if London starts after Asian session ends
      if(m_londonStartMin <= m_asianEndMin)
      {
         Print("TimeframeManager: London session must start after Asian session ends.");
         return false;
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate number of bars needed for a session on given timeframe|
   //+------------------------------------------------------------------+
   int CalculateRequiredBars(ENUM_TIMEFRAMES tf, int sessionStartMin, int sessionEndMin)
   {
      // Calculate session duration in minutes
      int sessionDuration = sessionEndMin - sessionStartMin;
      if(sessionDuration <= 0) return 0;
      
      // Get minutes per bar for the timeframe
      int minutesPerBar = GetMinutesPerTimeframe(tf);
      if(minutesPerBar <= 0) return 0;
      
      // Calculate bars needed (ceil division)
      int barsNeeded = (sessionDuration + minutesPerBar - 1) / minutesPerBar;
      
      // Add buffer for safety
      return barsNeeded + 2;
   }
   
   //+------------------------------------------------------------------+
   //| Get minutes per bar for a timeframe                             |
   //+------------------------------------------------------------------+
   int GetMinutesPerTimeframe(ENUM_TIMEFRAMES tf)
   {
      switch(tf)
      {
         case PERIOD_M1:  return 1;
         case PERIOD_M2:  return 2;
         case PERIOD_M3:  return 3;
         case PERIOD_M4:  return 4;
         case PERIOD_M5:  return 5;
         case PERIOD_M6:  return 6;
         case PERIOD_M10: return 10;
         case PERIOD_M12: return 12;
         case PERIOD_M15: return 15;
         case PERIOD_M20: return 20;
         case PERIOD_M30: return 30;
         case PERIOD_H1:  return 60;
         case PERIOD_H2:  return 120;
         case PERIOD_H3:  return 180;
         case PERIOD_H4:  return 240;
         case PERIOD_H6:  return 360;
         case PERIOD_H8:  return 480;
         case PERIOD_H12: return 720;
         case PERIOD_D1:  return 1440;
         case PERIOD_W1:  return 10080;
         case PERIOD_MN1: return 43200; // Approximate
         default:         return 0;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Convert timeframe to string for display                         |
   //+------------------------------------------------------------------+
   string TimeframeToString(ENUM_TIMEFRAMES tf)
   {
      switch(tf)
      {
         case PERIOD_M1:  return "M1";
         case PERIOD_M2:  return "M2";
         case PERIOD_M3:  return "M3";
         case PERIOD_M4:  return "M4";
         case PERIOD_M5:  return "M5";
         case PERIOD_M6:  return "M6";
         case PERIOD_M10: return "M10";
         case PERIOD_M12: return "M12";
         case PERIOD_M15: return "M15";
         case PERIOD_M20: return "M20";
         case PERIOD_M30: return "M30";
         case PERIOD_H1:  return "H1";
         case PERIOD_H2:  return "H2";
         case PERIOD_H3:  return "H3";
         case PERIOD_H4:  return "H4";
         case PERIOD_H6:  return "H6";
         case PERIOD_H8:  return "H8";
         case PERIOD_H12: return "H12";
         case PERIOD_D1:  return "D1";
         case PERIOD_W1:  return "W1";
         case PERIOD_MN1: return "MN1";
         default:         return "Unknown";
      }
   }
   
   //+------------------------------------------------------------------+
   //| Check if current time is within Asian session                   |
   //+------------------------------------------------------------------+
   bool IsAsianSession(datetime currentTime)
   {
      MqlDateTime dt;
      TimeToStruct(currentTime, dt);
      
      // Calculate minutes from day start
      int currentMin = dt.hour * 60 + dt.min;
      
      return (currentMin >= m_asianStartMin && currentMin < m_asianEndMin);
   }
   
   //+------------------------------------------------------------------+
   //| Check if current time is within London session                  |
   //+------------------------------------------------------------------+
   bool IsLondonSession(datetime currentTime)
   {
      MqlDateTime dt;
      TimeToStruct(currentTime, dt);
      
      // Calculate minutes from day start
      int currentMin = dt.hour * 60 + dt.min;
      
      return (currentMin >= m_londonStartMin);
   }
   
   //+------------------------------------------------------------------+
   //| Check if current time is during trading hours (Asian or London) |
   //+------------------------------------------------------------------+
   bool IsTradingHours(datetime currentTime)
   {
      return IsAsianSession(currentTime) || IsLondonSession(currentTime);
   }
   
   //+------------------------------------------------------------------+
   //| Check if there are enough bars for range calculation            |
   //+------------------------------------------------------------------+
   bool HasEnoughBarsForRange()
   {
      if(!m_isRangeTFValid || m_rangeBars <= 0) return false;
      
      int availableBars = Bars(Symbol(), m_rangeTF);
      return (availableBars >= m_rangeBars);
   }
   
   //+------------------------------------------------------------------+
   //| Check if there are enough bars for execution                    |
   //+------------------------------------------------------------------+
   bool HasEnoughBarsForExecution()
   {
      if(!m_isExecTFValid || m_execBars <= 0) return false;
      
      int availableBars = Bars(Symbol(), m_execTF);
      return (availableBars >= m_execBars);
   }
   
   //+------------------------------------------------------------------+
   //| Get the start time of current Asian session                     |
   //+------------------------------------------------------------------+
   datetime GetAsianSessionStart(datetime currentTime)
   {
      MqlDateTime dt;
      TimeToStruct(currentTime, dt);
      
      // Set to Asian session start time
      dt.hour = m_asianStartMin / 60;
      dt.min = m_asianStartMin % 60;
      dt.sec = 0;
      
      return StructToTime(dt);
   }
   
   //+------------------------------------------------------------------+
   //| Get the end time of current Asian session                       |
   //+------------------------------------------------------------------+
   datetime GetAsianSessionEnd(datetime currentTime)
   {
      MqlDateTime dt;
      TimeToStruct(currentTime, dt);
      
      // Set to Asian session end time
      dt.hour = m_asianEndMin / 60;
      dt.min = m_asianEndMin % 60;
      dt.sec = 0;
      
      return StructToTime(dt);
   }
   
   //+------------------------------------------------------------------+
   //| Get the start time of current London session                    |
   //+------------------------------------------------------------------+
   datetime GetLondonSessionStart(datetime currentTime)
   {
      MqlDateTime dt;
      TimeToStruct(currentTime, dt);
      
      // Set to London session start time
      dt.hour = m_londonStartMin / 60;
      dt.min = m_londonStartMin % 60;
      dt.sec = 0;
      
      return StructToTime(dt);
   }
   
   //+------------------------------------------------------------------+
   //| Get timeframe for range calculation                             |
   //+------------------------------------------------------------------+
   ENUM_TIMEFRAMES GetRangeTF() const { return m_rangeTF; }
   
   //+------------------------------------------------------------------+
   //| Get timeframe for trade execution                               |
   //+------------------------------------------------------------------+
   ENUM_TIMEFRAMES GetExecTF() const { return m_execTF; }
   
   //+------------------------------------------------------------------+
   //| Get timeframe for ATR calculation                               |
   //+------------------------------------------------------------------+
   ENUM_TIMEFRAMES GetATRTF() const { return m_atrTF; }
   
   //+------------------------------------------------------------------+
   //| Get timeframe for trend filter                                  |
   //+------------------------------------------------------------------+
   ENUM_TIMEFRAMES GetTrendTF() const { return m_trendTF; }
   
   //+------------------------------------------------------------------+
   //| Get number of bars needed for range calculation                 |
   //+------------------------------------------------------------------+
   int GetRangeBars() const { return m_rangeBars; }
   
   //+------------------------------------------------------------------+
   //| Get number of bars needed for execution                         |
   //+------------------------------------------------------------------+
   int GetExecBars() const { return m_execBars; }
   
   //+------------------------------------------------------------------+
   //| Get Asian session start time in minutes                         |
   //+------------------------------------------------------------------+
   int GetAsianStartMin() const { return m_asianStartMin; }
   
   //+------------------------------------------------------------------+
   //| Get Asian session end time in minutes                           |
   //+------------------------------------------------------------------+
   int GetAsianEndMin() const { return m_asianEndMin; }
   
   //+------------------------------------------------------------------+
   //| Get London session start time in minutes                        |
   //+------------------------------------------------------------------+
   int GetLondonStartMin() const { return m_londonStartMin; }
   
   //+------------------------------------------------------------------+
   //| Check if timeframe manager is properly initialized              |
   //+------------------------------------------------------------------+
   bool IsInitialized() const
   {
      return (m_isRangeTFValid && m_isExecTFValid && m_isSessionTimesValid);
   }
   
   //+------------------------------------------------------------------+
   //| Reset all validation flags (for re-initialization)              |
   //+------------------------------------------------------------------+
   void Reset()
   {
      m_isRangeTFValid = false;
      m_isExecTFValid = false;
      m_isSessionTimesValid = false;
      m_rangeBars = 0;
      m_execBars = 0;
   }
};

//+------------------------------------------------------------------+
//| End of TimeframeManager.mqh                                      |
//+------------------------------------------------------------------+