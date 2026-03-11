//+------------------------------------------------------------------+
//|                                                      RiskCalculator.mqh |
//|                        Copyright 2024, MonEA Project              |
//|                                             https://www.monea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MonEA Project"
#property link      "https://www.monea.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Risk Calculator Class                                            |
//+------------------------------------------------------------------+
class CRiskCalculator
{
private:
   // Input parameters
   double   m_risk_percent;      // Risk percentage per trade (0.5-1%)
   double   m_stop_loss_pips;    // Stop loss in pips
   double   m_min_lot;           // Minimum lot size
   double   m_max_lot;           // Maximum lot size
   string   m_symbol;            // Trading symbol
   
   // Internal variables
   double   m_tick_value;        // Tick value for the symbol
   double   m_tick_size;         // Tick size for the symbol
   double   m_point;             // Point value for the symbol
   
public:
   // Constructor
   CRiskCalculator() : m_risk_percent(1.0), m_stop_loss_pips(30.0), 
                       m_min_lot(0.01), m_max_lot(5.0), m_symbol(_Symbol),
                       m_tick_value(0.0), m_tick_size(0.0), m_point(0.0)
   {
      Initialize();
   }
   
   // Parameterized constructor
   CRiskCalculator(double risk_pc, double sl_pips, double min_lot, double max_lot, string symbol = "") : 
      m_risk_percent(risk_pc), m_stop_loss_pips(sl_pips), 
      m_min_lot(min_lot), m_max_lot(max_lot), m_symbol(symbol == "" ? _Symbol : symbol),
      m_tick_value(0.0), m_tick_size(0.0), m_point(0.0)
   {
      Initialize();
   }
   
   // Destructor
   ~CRiskCalculator() {}
   
   // Initialization method
   void Initialize()
   {
      // Get symbol information
      m_symbol = m_symbol == "" ? _Symbol : m_symbol;
      m_point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      m_tick_size = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      m_tick_value = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      
      // Validate inputs
      if(m_risk_percent <= 0.0) m_risk_percent = 1.0;
      if(m_stop_loss_pips <= 0.0) m_stop_loss_pips = 30.0;
      if(m_min_lot < 0.01) m_min_lot = 0.01;
      if(m_max_lot < m_min_lot) m_max_lot = m_min_lot;
   }
   
   // Setter methods
   void SetRiskPercent(double risk_pc) { m_risk_percent = MathMax(risk_pc, 0.01); }
   void SetStopLossPips(double sl_pips) { m_stop_loss_pips = MathMax(sl_pips, 1.0); }
   void SetMinLot(double min_lot) { m_min_lot = MathMax(min_lot, 0.01); }
   void SetMaxLot(double max_lot) { m_max_lot = MathMax(max_lot, m_min_lot); }
   void SetSymbol(string symbol) 
   { 
      m_symbol = symbol == "" ? _Symbol : symbol;
      Initialize();
   }
   
   // Getter methods
   double GetRiskPercent() const { return m_risk_percent; }
   double GetStopLossPips() const { return m_stop_loss_pips; }
   double GetMinLot() const { return m_min_lot; }
   double GetMaxLot() const { return m_max_lot; }
   string GetSymbol() const { return m_symbol; }
   
   // Main calculation method - calculates lot size based on percentage risk
   double CalculateLotSize()
   {
      // Get account equity for risk calculation
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      
      // Calculate risk amount in account currency
      double risk_amount = equity * (m_risk_percent / 100.0);
      
      // Calculate stop loss in points
      double stop_loss_points = m_stop_loss_pips * 10.0; // Convert pips to points (1 pip = 10 points)
      
      // Calculate value per point
      double value_per_point = m_tick_value / m_tick_size;
      
      // Calculate lot size
      double lot_size = risk_amount / (stop_loss_points * value_per_point);
      
      // Normalize lot size to broker requirements
      lot_size = NormalizeLotSize(lot_size);
      
      // Apply min/max constraints
      lot_size = MathMax(lot_size, m_min_lot);
      lot_size = MathMin(lot_size, m_max_lot);
      
      return lot_size;
   }
   
   // Calculate lot size with custom equity (for testing or special cases)
   double CalculateLotSizeWithEquity(double custom_equity)
   {
      // Calculate risk amount in account currency
      double risk_amount = custom_equity * (m_risk_percent / 100.0);
      
      // Calculate stop loss in points
      double stop_loss_points = m_stop_loss_pips * 10.0; // Convert pips to points
      
      // Calculate value per point
      double value_per_point = m_tick_value / m_tick_size;
      
      // Calculate lot size
      double lot_size = risk_amount / (stop_loss_points * value_per_point);
      
      // Normalize lot size to broker requirements
      lot_size = NormalizeLotSize(lot_size);
      
      // Apply min/max constraints
      lot_size = MathMax(lot_size, m_min_lot);
      lot_size = MathMin(lot_size, m_max_lot);
      
      return lot_size;
   }
   
   // Calculate risk amount for a given lot size (reverse calculation)
   double CalculateRiskAmount(double lot_size)
   {
      // Calculate stop loss in points
      double stop_loss_points = m_stop_loss_pips * 10.0;
      
      // Calculate value per point
      double value_per_point = m_tick_value / m_tick_size;
      
      // Calculate risk amount
      double risk_amount = lot_size * stop_loss_points * value_per_point;
      
      return risk_amount;
   }
   
   // Calculate risk percentage for a given lot size (reverse calculation)
   double CalculateRiskPercentage(double lot_size)
   {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double risk_amount = CalculateRiskAmount(lot_size);
      
      if(equity <= 0.0) return 0.0;
      
      return (risk_amount / equity) * 100.0;
   }
   
   // Validate if lot size is within acceptable risk limits
   bool IsLotSizeValid(double lot_size)
   {
      if(lot_size < m_min_lot || lot_size > m_max_lot)
         return false;
      
      double risk_pc = CalculateRiskPercentage(lot_size);
      
      // Check if risk is within acceptable range (0.1% to 5%)
      return (risk_pc >= 0.1 && risk_pc <= 5.0);
   }
   
   // Get recommended lot size based on current market conditions
   double GetRecommendedLotSize()
   {
      return CalculateLotSize();
   }
   
   // Display risk information for debugging
   void DisplayRiskInfo()
   {
      double lot_size = CalculateLotSize();
      double risk_amount = CalculateRiskAmount(lot_size);
      double risk_pc = CalculateRiskPercentage(lot_size);
      
      Print("=== Risk Calculator Info ===");
      Print("Symbol: ", m_symbol);
      Print("Risk Percentage: ", DoubleToString(m_risk_percent, 2), "%");
      Print("Stop Loss: ", DoubleToString(m_stop_loss_pips, 1), " pips");
      Print("Calculated Lot Size: ", DoubleToString(lot_size, 2));
      Print("Risk Amount: $", DoubleToString(risk_amount, 2));
      Print("Actual Risk Percentage: ", DoubleToString(risk_pc, 2), "%");
      Print("Min Lot: ", DoubleToString(m_min_lot, 2));
      Print("Max Lot: ", DoubleToString(m_max_lot, 2));
      Print("============================");
   }
   
private:
   // Normalize lot size to broker step size
   double NormalizeLotSize(double lot_size)
   {
      double lot_step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
      
      if(lot_step > 0.0)
      {
         lot_size = MathRound(lot_size / lot_step) * lot_step;
      }
      
      // Ensure lot size has correct precision
      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      lot_size = NormalizeDouble(lot_size, 2); // Most brokers use 2 decimal places for lots
      
      return lot_size;
   }
};

//+------------------------------------------------------------------+
//| Helper Functions                                                 |
//+------------------------------------------------------------------+

// Function to create and configure a risk calculator instance
CRiskCalculator* CreateRiskCalculator(double risk_pc = 1.0, double sl_pips = 30.0, 
                                      double min_lot = 0.01, double max_lot = 5.0, string symbol = "")
{
   CRiskCalculator* calculator = new CRiskCalculator(risk_pc, sl_pips, min_lot, max_lot, symbol);
   return calculator;
}

// Function to safely delete risk calculator instance
void DeleteRiskCalculator(CRiskCalculator* &calculator)
{
   if(CheckPointer(calculator) == POINTER_DYNAMIC)
   {
      delete calculator;
      calculator = NULL;
   }
}

// Function to calculate lot size directly (simplified interface)
double CalculateLotSizeSimple(double risk_percent, double stop_loss_pips, 
                             double min_lot = 0.01, double max_lot = 5.0, string symbol = "")
{
   CRiskCalculator calculator(risk_percent, stop_loss_pips, min_lot, max_lot, symbol);
   return calculator.CalculateLotSize();
}

//+------------------------------------------------------------------+