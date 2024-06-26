//+------------------------------------------------------------------+
//|                                                 CombinedEA.mq5   |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property strict
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
input double Lots = 1.0;                // Lot size
input int Period = 20;                  // Period for Bollinger Bands
input double Deviation = 2.0;           // Deviation for Bollinger Bands
input double StopLoss = 100;            // Stop Loss in points
input double TakeProfit = 200;          // Take Profit in points
input int MagicNumber = 123456;         // Magic number

input int InpFastPeriod = 14;           // Fast period for SMA
input int InpSlowPeriod = 21;           // Slow period for SMA
input int InpRSIPeriod = 21;            // RSI period
input int InpRSILevel = 70;             // RSI level (upper)
input bool InpCloseSignal = false;      // Close trades by opposite signal

//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+
double BollingerUpper[], BollingerLower[], BollingerMiddle[];
int fastHandle, slowHandle, rsiHandle;
double fastBuffer[], slowBuffer[], rsiBuffer[];
datetime openTimeBuy = 0, openTimeSell = 0;
CTrade trade;
MqlTick currentTick;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Khởi tạo các mảng cho Bollinger Bands
    ArraySetAsSeries(BollingerUpper, true);
    ArraySetAsSeries(BollingerLower, true);
    ArraySetAsSeries(BollingerMiddle, true);

    // Tạo các handle cho SMA
    fastHandle = iMA(_Symbol, PERIOD_CURRENT, InpFastPeriod, 0, MODE_SMA, PRICE_CLOSE);
    slowHandle = iMA(_Symbol, PERIOD_CURRENT, InpSlowPeriod, 0, MODE_SMA, PRICE_CLOSE);

    // Tạo handle cho RSI
    rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);
    
    ArraySetAsSeries(fastBuffer, true);
    ArraySetAsSeries(slowBuffer, true);
    ArraySetAsSeries(rsiBuffer, true);

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if (fastHandle != INVALID_HANDLE) IndicatorRelease(fastHandle);
    if (slowHandle != INVALID_HANDLE) IndicatorRelease(slowHandle);
    if (rsiHandle != INVALID_HANDLE) IndicatorRelease(rsiHandle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    if (!SymbolInfoTick(_Symbol, currentTick))
    {
        Print("Failed to get current tick");
        return;
    }

    // Tính toán Bollinger Bands
    CalculateBollingerBands();

    // Lấy các giá trị SMA và RSI
    if (CopyBuffer(fastHandle, 0, 0, 2, fastBuffer) != 2 || CopyBuffer(slowHandle, 0, 0, 2, slowBuffer) != 2 || CopyBuffer(rsiHandle, 0, 0, 2, rsiBuffer) != 2)
    {
        Print("Not enough data for indicators");
        return;
    }

    // Hiển thị các giá trị
    Comment("fast[0]: ", fastBuffer[0], "\nfast[1]: ", fastBuffer[1], "\n",
            "slow[0]: ", slowBuffer[0], "\nslow[1]: ", slowBuffer[1], "\n",
            "RSI[0]: ", rsiBuffer[0], "\nRSI[1]: ", rsiBuffer[1]);

    // Đếm số vị thế mở
    int cntBuy, cntSell;
    if (!CountOpenPositions(cntBuy, cntSell)) return;

    // Điều kiện mua
    if (ShouldOpenBuy())
    {
        double ask = currentTick.ask;
        double sl = ask - StopLoss * _Point;
        double tp = ask + TakeProfit * _Point;

        if (InpCloseSignal && cntSell > 0)
            ClosePositions(1);

        trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, Lots, ask, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), "Combined Buy");
    }

    // Điều kiện bán
    if (ShouldOpenSell())
    {
        double bid = currentTick.bid;
        double sl = bid + StopLoss * _Point;
        double tp = bid - TakeProfit * _Point;

        if (InpCloseSignal && cntBuy > 0)
            ClosePositions(2);

        trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, Lots, bid, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), "Combined Sell");
    }
}

//+------------------------------------------------------------------+
//| Tính toán Bollinger Bands                                        |
//+------------------------------------------------------------------+
void CalculateBollingerBands()
{
    int bars = iBars(_Symbol, 0);
    if (bars < Period)
    {
        Print("Not enough bars to calculate Bollinger Bands");
        return;
    }

    int handle = iBands(_Symbol, 0, Period, Deviation, 0, PRICE_CLOSE);
    CopyBuffer(handle, 0, 0, 1, BollingerUpper);
    CopyBuffer(handle, 1, 0, 1, BollingerMiddle);
    CopyBuffer(handle, 2, 0, 1, BollingerLower);
}

//+------------------------------------------------------------------+
//| Kiểm tra điều kiện mở vị thế mua                                 |
//+------------------------------------------------------------------+
bool ShouldOpenBuy()
{
    double close = iClose(_Symbol, 0, 0);

    return (close > BollingerLower[0] &&
            fastBuffer[1] <= slowBuffer[1] && fastBuffer[0] > slowBuffer[0] &&
            rsiBuffer[1] >= (100 - InpRSILevel) && rsiBuffer[0] < (100 - InpRSILevel));
}

//+------------------------------------------------------------------+
//| Kiểm tra điều kiện mở vị thế bán                                 |
//+------------------------------------------------------------------+
bool ShouldOpenSell()
{
    double close = iClose(_Symbol, 0, 0);

    return (close < BollingerUpper[0] &&
            fastBuffer[1] >= slowBuffer[1] && fastBuffer[0] < slowBuffer[0] &&
            rsiBuffer[1] <= InpRSILevel && rsiBuffer[0] > InpRSILevel);
}

//+------------------------------------------------------------------+
//| Đếm số vị thế mở                                                 |
//+------------------------------------------------------------------+
bool CountOpenPositions(int &cntBuy, int &cntSell)
{
    cntBuy = 0;
    cntSell = 0;
    int total = PositionsTotal();
    for (int i = total - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (ticket <= 0 || !PositionSelectByTicket(ticket))
        {
            Print("Failed to get position ticket");
            return false;
        }

        long magic;
        if (!PositionGetInteger(POSITION_MAGIC, magic) || magic != MagicNumber)
            continue;

        long type;
        if (!PositionGetInteger(POSITION_TYPE, type))
            continue;

        if (type == POSITION_TYPE_BUY)
            cntBuy++;
        if (type == POSITION_TYPE_SELL)
            cntSell++;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Đóng các vị thế                                                  |
//+------------------------------------------------------------------+
bool ClosePositions(int all_buy_sell)
{
    int total = PositionsTotal();
    for (int i = total - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (ticket <= 0 || !PositionSelectByTicket(ticket))
        {
            Print("Failed to get position ticket");
            return false;
        }

        long magic;
        if (!PositionGetInteger(POSITION_MAGIC, magic) || magic != MagicNumber)
            continue;

        long type;
        if (!PositionGetInteger(POSITION_TYPE, type))
            continue;

        if (all_buy_sell == 1 && type == POSITION_TYPE_SELL)
            continue;
        if (all_buy_sell == 2 && type == POSITION_TYPE_BUY)
            continue;

        trade.PositionClose(ticket);
        if (trade.ResultRetcode() != TRADE_RETCODE_DONE)
        {
            Print("Failed to close position. Ticket: ", ticket, " Result: ", trade.ResultRetcodeDescription());
        }
    }
    return true;
}
