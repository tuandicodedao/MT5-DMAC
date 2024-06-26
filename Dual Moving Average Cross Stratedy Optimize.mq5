#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Include                                                         |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Input variables                                                  |
//+------------------------------------------------------------------+
input int InpFastPeriod = 14;       // Fast period
input int InpSlowPeriod = 21;       // Slow period
input double InpStopLoss = 100;     // Stop Loss in points
input double InpTakeProfit = 200;   // Take Profit in points
input double InpLotSize = 1.0;      // Lot size

//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+
int fastHandle;
int slowHandle;
double fastBuffer[];
double slowBuffer[];
datetime openTimeBuy = 0;
datetime openTimeSell = 0;
CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Kiểm tra giá trị đầu vào
   if(InpFastPeriod <= 0)
     {
      Alert("Fast period <= 0");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpSlowPeriod <= 0)
     {
      Alert("Slow period <= 0");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpFastPeriod >= InpSlowPeriod)
     {
      Alert("Fast period >= Slow period");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpStopLoss <= 0)
     {
      Alert("Stop loss <= 0");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpTakeProfit <= 0)
     {
      Alert("Take Profit <= 0");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpLotSize <= 0)
     {
      Alert("Lot size <= 0");
      return INIT_PARAMETERS_INCORRECT;
     }

   // Tạo các handle cho SMA nhanh và chậm
   fastHandle = iMA(_Symbol, PERIOD_CURRENT, InpFastPeriod, 0, MODE_SMA, PRICE_CLOSE);
   if(fastHandle == INVALID_HANDLE)
     {
      Alert("Failed to create fast Handle");
      return INIT_FAILED;
     }
   slowHandle = iMA(_Symbol, PERIOD_CURRENT, InpSlowPeriod, 0, MODE_SMA, PRICE_CLOSE);
   if(slowHandle == INVALID_HANDLE)
     {
      Alert("Failed to create slow Handle");
      return INIT_FAILED;
     }

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Lấy giá trị của các SMA
   int values = CopyBuffer(fastHandle, 0, 0, 2, fastBuffer);
   if(values != 2)
     {
      Print("Not enough data for fast moving average");
      return;
     }
   values = CopyBuffer(slowHandle, 0, 0, 2, slowBuffer);
   if(values != 2)
     {
      Print("Not enough data for slow moving average");
      return;
     }

   // Hiển thị các giá trị SMA
   Comment("fast[0]:", fastBuffer[0], "\n",
           "fast[1]:", fastBuffer[1], "\n",
           "slow[0]:", slowBuffer[0], "\n",
           "slow[1]:", slowBuffer[1]);

   // Kiểm tra điều kiện mua
   if(fastBuffer[1] <= slowBuffer[1] && fastBuffer[0] > slowBuffer[0] && openTimeBuy != iTime(_Symbol, PERIOD_CURRENT, 0))
     {
      openTimeBuy = iTime(_Symbol, PERIOD_CURRENT, 0);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = ask - InpStopLoss * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double tp = ask + InpTakeProfit * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(ask == 0.0)
        {
         Print("Failed to get ask price");
         return;
        }
      trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, InpLotSize, ask, sl, tp, "Cross EA");
     }

   // Kiểm tra điều kiện bán
   if(fastBuffer[1] >= slowBuffer[1] && fastBuffer[0] < slowBuffer[0] && openTimeSell != iTime(_Symbol, PERIOD_CURRENT, 0))
     {
      openTimeSell = iTime(_Symbol, PERIOD_CURRENT, 0);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = bid + InpStopLoss * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double tp = bid - InpTakeProfit * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(bid == 0.0)
        {
         Print("Failed to get bid price");
         return;
        }
      trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, InpLotSize, bid, sl, tp, "Cross EA");
     }
}

//+------------------------------------------------------------------+
//| Hàm ghi lại kết quả giao dịch để phân tích tối ưu hóa            |
//+------------------------------------------------------------------+
void LogTradeResults()
{
   double profit = AccountInfoDouble(ACCOUNT_PROFIT);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   Print("Profit: ", profit);
   Print("Balance: ", balance);
   Print("Equity: ", equity);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   LogTradeResults(); // Ghi lại kết quả khi kết thúc
   if(fastHandle != INVALID_HANDLE)
     {
      IndicatorRelease(fastHandle);
     }
   if(slowHandle != INVALID_HANDLE)
     {
      IndicatorRelease(slowHandle);
     }
}
