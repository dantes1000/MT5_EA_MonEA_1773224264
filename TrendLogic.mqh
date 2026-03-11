//+------------------------------------------------------------------+
//|                                                      TrendLogic.mqh |
//|                        Copyright 2024, MonEA Project               |
//|                                             https://www.monea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MonEA Project"
#property link      "https://www.monea.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Trend detection and entry logic for Range Breakout Asian Session  |
//+------------------------------------------------------------------+

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Indicators\Trend.mqh>
#include <Indicators\Volumes.mqh>
#include <Indicators\Oscilators.mqh>

//+------------------------------------------------------------------+
//| Input parameters for trend logic                                 |
//+------------------------------------------------------------------+
sinput string   TrendSection="========== Trend Filter Settings ==========";
sinput bool     UseTrendFilter=true;               // Enable trend filter
sinput ENUM_TIMEFRAMES TrendTF=PERIOD_H1;          // Timeframe for trend analysis
sinput int      EMA_Period=200;                    // EMA period for trend direction
sinput int      ADX_Period=14;                     // ADX period for trend strength
sinput double   ADX_Threshold=20.0;                // ADX threshold for valid trend
sinput string   TrendFilterType="EMA_ADX";         // Trend filter type: EMA, ADX, EMA_ADX

//+------------------------------------------------------------------+
//| Class CTrendLogic: Handles trend detection and entry validation  |
//+------------------------------------------------------------------+
class CTrendLogic
{
private:
   // Indicators
   CiMA          m_ema;
   CiADX         m_adx;
   
   // Trade objects
   CTrade        m_trade;
   CSymbolInfo   m_symbol;
   CPositionInfo m_position;
   
   // Configuration
   bool          m_useTrendFilter;
   ENUM_TIMEFRAMES m_trendTF;
   int           m_emaPeriod;
   int           m_adxPeriod;
   double        m_adxThreshold;
   string        m_filterType;
   
   // State variables
   datetime      m_lastTradeTime;
   double        m_currentPrice;
   
public:
   // Constructor
   CTrendLogic() : 
      m_useTrendFilter(true),
      m_trendTF(PERIOD_H1),
      m_emaPeriod(200),
      m_adxPeriod(14),
      m_adxThreshold(20.0),
      m_filterType("EMA_ADX"),
      m_lastTradeTime(0),
      m_currentPrice(0.0)
   {
   }
   
   // Destructor
   ~CTrendLogic()
   {
   }
   
   // Initialization method
   bool Init(bool useFilter, ENUM_TIMEFRAMES tf, int emaPeriod, int adxPeriod, 
             double adxThreshold, string filterType)
   {
      m_useTrendFilter = useFilter;
      m_trendTF = tf;
      m_emaPeriod = emaPeriod;
      m_adxPeriod = adxPeriod;
      m_adxThreshold = adxThreshold;
      m_filterType = filterType;
      
      // Initialize symbol info
      if(!m_symbol.Name(_Symbol))
         return false;
      
      // Initialize EMA indicator
      if(!m_ema.Create(_Symbol, m_trendTF, m_emaPeriod, 0, MODE_EMA, PRICE_CLOSE))
         return false;
      
      // Initialize ADX indicator
      if(!m_adx.Create(_Symbol, m_trendTF, m_adxPeriod))
         return false;
      
      return true;
   }
   
   // Check if trend filter allows buy entry
   bool IsBuyTrendAllowed()
   {
      if(!m_useTrendFilter)
         return true;
      
      // Get current price and EMA value
      m_currentPrice = m_symbol.Ask();
      double emaValue = GetEMAValue(0);
      
      if(m_filterType == "EMA" || m_filterType == "EMA_ADX")
      {
         // Check if price is above EMA for uptrend
         if(m_currentPrice <= emaValue)
            return false;
      }
      
      if(m_filterType == "ADX" || m_filterType == "EMA_ADX")
      {
         // Check ADX strength
         double adxValue = GetADXValue(0);
         if(adxValue < m_adxThreshold)
            return false;
      }
      
      return true;
   }
   
   // Check if trend filter allows sell entry
   bool IsSellTrendAllowed()
   {
      if(!m_useTrendFilter)
         return true;
      
      // Get current price and EMA value
      m_currentPrice = m_symbol.Bid();
      double emaValue = GetEMAValue(0);
      
      if(m_filterType == "EMA" || m_filterType == "EMA_ADX")
      {
         // Check if price is below EMA for downtrend
         if(m_currentPrice >= emaValue)
            return false;
      }
      
      if(m_filterType == "ADX" || m_filterType == "EMA_ADX")
      {
         // Check ADX strength
         double adxValue = GetADXValue(0);
         if(adxValue < m_adxThreshold)
            return false;
      }
      
      return true;
   }
   
   // Get current trend direction
   int GetTrendDirection()
   {
      if(!m_useTrendFilter)
         return 0; // Neutral
      
      m_currentPrice = m_symbol.Ask();
      double emaValue = GetEMAValue(0);
      
      if(m_currentPrice > emaValue)
         return 1; // Uptrend
      else if(m_currentPrice < emaValue)
         return -1; // Downtrend
      
      return 0; // Neutral
   }
   
   // Check if trend is strong enough for trading
   bool IsTrendStrong()
   {
      if(!m_useTrendFilter || m_filterType == "EMA")
         return true;
      
      double adxValue = GetADXValue(0);
      return (adxValue >= m_adxThreshold);
   }
   
   // Validate entry with all trend filters
   bool ValidateEntry(int direction)
   {
      if(direction == ORDER_TYPE_BUY)
         return IsBuyTrendAllowed();
      else if(direction == ORDER_TYPE_SELL)
         return IsSellTrendAllowed();
      
      return false;
   }
   
   // Check minimum time between trades
   bool CheckMinTimeBetweenTrades(int minHours)
   {
      if(minHours <= 0)
         return true;
      
      datetime currentTime = TimeCurrent();
      if(m_lastTradeTime == 0)
         return true;
      
      int hoursPassed = (int)((currentTime - m_lastTradeTime) / 3600);
      return (hoursPassed >= minHours);
   }
   
   // Update last trade time
   void UpdateLastTradeTime()
   {
      m_lastTradeTime = TimeCurrent();
   }
   
   // Reset last trade time
   void ResetLastTradeTime()
   {
      m_lastTradeTime = 0;
   }
   
   // Get EMA value for specific bar
   double GetEMAValue(int shift)
   {
      double values[1];
      if(m_ema.GetData(shift, 1, values) > 0)
         return values[0];
      return 0.0;
   }
   
   // Get ADX value for specific bar
   double GetADXValue(int shift)
   {
      double values[1];
      if(m_adx.GetData(shift, 1, values) > 0)
         return values[0];
      return 0.0;
   }
   
   // Get current price
   double GetCurrentPrice() const { return m_currentPrice; }
   
   // Get last trade time
   datetime GetLastTradeTime() const { return m_lastTradeTime; }
   
   // Check if position exists
   bool HasOpenPosition()
   {
      return m_position.Select(_Symbol);
   }
   
   // Check if we can open new position based on max trades
   bool CanOpenNewPosition(int maxOpenTrades)
   {
      if(maxOpenTrades <= 0)
         return true;
      
      int positions = PositionsTotal();
      return (positions < maxOpenTrades);
   }
   
   // Check if symbol is in allowed pairs list
   bool IsSymbolAllowed(string allowedPairs)
   {
      if(allowedPairs == "" || allowedPairs == "ALL")
         return true;
      
      string pairs[];
      StringSplit(allowedPairs, ',', pairs);
      
      for(int i = 0; i < ArraySize(pairs); i++)
      {
         string pair = StringTrimRight(StringTrimLeft(pairs[i]));
         if(pair == _Symbol)
            return true;
      }
      
      return false;
   }
   
   // Check volatility conditions
   bool CheckVolatilityConditions(double minATR, double maxATR, double currentATR)
   {
      if(minATR > 0 && currentATR < minATR)
         return false;
      
      if(maxATR > 0 && currentATR > maxATR)
         return false;
      
      return true;
   }
   
   // Check if weekend close is needed
   bool IsWeekendCloseNeeded(bool weekendClose, int closeHourFri)
   {
      if(!weekendClose)
         return false;
      
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      
      // Check if it's Friday and after close hour
      if(dt.day_of_week == 5 && dt.hour >= closeHourFri)
         return true;
      
      return false;
   }
   
   // Close all positions
   void CloseAllPositions(bool closeIfInProfit)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(m_position.SelectByIndex(i))
         {
            if(m_position.Symbol() == _Symbol)
            {
               // Check if we should close based on profit condition
               if(closeIfInProfit && m_position.Profit() <= 0)
                  continue;
                  
               m_trade.PositionClose(m_position.Ticket());
            }
         }
      }
   }
};

//+------------------------------------------------------------------+
//| Global trend logic object                                        |
//+------------------------------------------------------------------+
CTrendLogic TrendLogic;

//+------------------------------------------------------------------+
//| Initialization function                                          |
//+------------------------------------------------------------------+
bool InitTrendLogic()
{
   return TrendLogic.Init(UseTrendFilter, TrendTF, EMA_Period, ADX_Period, 
                         ADX_Threshold, TrendFilterType);
}

//+------------------------------------------------------------------+
//| Check if buy is allowed by trend filters                         |
//+------------------------------------------------------------------+
bool IsBuyAllowed()
{
   return TrendLogic.IsBuyTrendAllowed();
}

//+------------------------------------------------------------------+
//| Check if sell is allowed by trend filters                        |
//+------------------------------------------------------------------+
bool IsSellAllowed()
{
   return TrendLogic.IsSellTrendAllowed();
}

//+------------------------------------------------------------------+
//| Get current trend direction                                      |
//+------------------------------------------------------------------+
int GetTrendDirection()
{
   return TrendLogic.GetTrendDirection();
}

//+------------------------------------------------------------------+
//| Check if trend is strong enough                                  |
//+------------------------------------------------------------------+
bool IsTrendStrong()
{
   return TrendLogic.IsTrendStrong();
}

//+------------------------------------------------------------------+
//| Validate entry with all trend filters                            |
//+------------------------------------------------------------------+
bool ValidateTrendEntry(int direction)
{
   return TrendLogic.ValidateEntry(direction);
}

//+------------------------------------------------------------------+
//| Check minimum time between trades                                |
//+------------------------------------------------------------------+
bool CheckTradeCooldown(int minHours)
{
   return TrendLogic.CheckMinTimeBetweenTrades(minHours);
}

//+------------------------------------------------------------------+
//| Update last trade time                                           |
//+------------------------------------------------------------------+
void UpdateTradeTime()
{
   TrendLogic.UpdateLastTradeTime();
}

//+------------------------------------------------------------------+
//| Reset last trade time                                            |
//+------------------------------------------------------------------+
void ResetTradeTime()
{
   TrendLogic.ResetLastTradeTime();
}

//+------------------------------------------------------------------+
//| Check if position exists                                         |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   return TrendLogic.HasOpenPosition();
}

//+------------------------------------------------------------------+
//| Check if we can open new position                                |
//+------------------------------------------------------------------+
bool CanOpenNewPosition(int maxOpenTrades)
{
   return TrendLogic.CanOpenNewPosition(maxOpenTrades);
}

//+------------------------------------------------------------------+
//| Check if symbol is allowed                                       |
//+------------------------------------------------------------------+
bool IsSymbolAllowed(string allowedPairs)
{
   return TrendLogic.IsSymbolAllowed(allowedPairs);
}

//+------------------------------------------------------------------+
//| Check volatility conditions                                      |
//+------------------------------------------------------------------+
bool CheckVolatility(double minATR, double maxATR, double currentATR)
{
   return TrendLogic.CheckVolatilityConditions(minATR, maxATR, currentATR);
}

//+------------------------------------------------------------------+
//| Check if weekend close is needed                                 |
//+------------------------------------------------------------------+
bool NeedWeekendClose(bool weekendClose, int closeHourFri)
{
   return TrendLogic.IsWeekendCloseNeeded(weekendClose, closeHourFri);
}

//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
void CloseAllPositionsOnWeekend(bool weekendClose, int closeHourFri, bool closeIfInProfit)
{
   if(TrendLogic.IsWeekendCloseNeeded(weekendClose, closeHourFri))
      TrendLogic.CloseAllPositions(closeIfInProfit);
}

//+------------------------------------------------------------------+
//| Force close all positions                                        |
//+------------------------------------------------------------------+
void ForceCloseAllPositions(bool closeIfInProfit)
{
   TrendLogic.CloseAllPositions(closeIfInProfit);
}

//+------------------------------------------------------------------+
