//+------------------------------------------------------------------+
//|                                                 CombinedEA.mq5   |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
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
input int InpFastPeriod = 14;       // Fast period for SMA
input int InpSlowPeriod = 21;       // Slow period for SMA
input double InpStopLoss = 100;     // Stop Loss in points
input double InpTakeProfit = 200;   // Take Profit in points
input double InpLotSize = 1.0;      // Lot size

input int InpMagicnumber = 546812;      // Magic number for RSI
input int InpRSIPeriod = 21;            // RSI period
input int InpRSILevel = 70;             // RSI level (upper)
input bool InpCloseSignal = false;      // Close trades by opposite signal

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

int rsiHandle;
double rsiBuffer[];
MqlTick currentTick;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Validate inputs for SMA
    if(InpFastPeriod <= 0 || InpSlowPeriod <= 0 || InpFastPeriod >= InpSlowPeriod ||
       InpStopLoss <= 0 || InpTakeProfit <= 0 || InpLotSize <= 0)
    {
        Alert("Invalid input parameters for SMA");
        return INIT_PARAMETERS_INCORRECT;
    }
    
    // Validate inputs for RSI
    if(InpMagicnumber <= 0 || InpRSIPeriod <= 1 || InpRSILevel >= 100 || InpRSILevel <= 50)
    {
        Alert("Invalid input parameters for RSI");
        return INIT_PARAMETERS_INCORRECT;
    }

    // Set magic number for RSI
    trade.SetExpertMagicNumber(InpMagicnumber);

    // Create handles for SMA
    fastHandle = iMA(_Symbol, PERIOD_CURRENT, InpFastPeriod, 0, MODE_SMA, PRICE_CLOSE);
    if(fastHandle == INVALID_HANDLE)
    {
        Alert("Failed to create fast SMA handle");
        return INIT_FAILED;
    }
    slowHandle = iMA(_Symbol, PERIOD_CURRENT, InpSlowPeriod, 0, MODE_SMA, PRICE_CLOSE);
    if(slowHandle == INVALID_HANDLE)
    {
        Alert("Failed to create slow SMA handle");
        return INIT_FAILED;
    }

    // Create handle for RSI
    rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);
    if(rsiHandle == INVALID_HANDLE)
    {
        Alert("Failed to create RSI handle");
        return INIT_FAILED;
    }
    
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
    if(fastHandle != INVALID_HANDLE)
        IndicatorRelease(fastHandle);
    if(slowHandle != INVALID_HANDLE)
        IndicatorRelease(slowHandle);
    if(rsiHandle != INVALID_HANDLE)
        IndicatorRelease(rsiHandle);
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
    
    // Get SMA values
    if(CopyBuffer(fastHandle, 0, 0, 2, fastBuffer) != 2 || CopyBuffer(slowHandle, 0, 0, 2, slowBuffer) != 2)
    {
        Print("Not enough data for SMA");
        return;
    }

    // Get RSI values
    if(CopyBuffer(rsiHandle, 0, 0, 2, rsiBuffer) != 2)
    {
        Print("Failed to get RSI values");
        return;
    }

    // Display values
    Comment("fast[0]: ", fastBuffer[0], "\nfast[1]: ", fastBuffer[1], "\n",
            "slow[0]: ", slowBuffer[0], "\nslow[1]: ", slowBuffer[1], "\n",
            "RSI[0]: ", rsiBuffer[0], "\nRSI[1]: ", rsiBuffer[1]);

    // Count open positions
    int cntBuy, cntSell;
    if (!CountOpenPositions(cntBuy, cntSell))
        return;

    // SMA Crossover Buy condition
    if(fastBuffer[1] <= slowBuffer[1] && fastBuffer[0] > slowBuffer[0] && openTimeBuy != iTime(_Symbol, PERIOD_CURRENT, 0))
    {
        openTimeBuy = iTime(_Symbol, PERIOD_CURRENT, 0);
        double ask = currentTick.ask;
        double sl = ask - InpStopLoss * _Point;
        double tp = ask + InpTakeProfit * _Point;

        if (InpCloseSignal && cntSell > 0)
            ClosePositions(1);

        trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, InpLotSize, ask, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), "SMA Crossover Buy");
    }

    // SMA Crossover Sell condition
    if(fastBuffer[1] >= slowBuffer[1] && fastBuffer[0] < slowBuffer[0] && openTimeSell != iTime(_Symbol, PERIOD_CURRENT, 0))
    {
        openTimeSell = iTime(_Symbol, PERIOD_CURRENT, 0);
        double bid = currentTick.bid;
        double sl = bid + InpStopLoss * _Point;
        double tp = bid - InpTakeProfit * _Point;

        if (InpCloseSignal && cntBuy > 0)
            ClosePositions(2);

        trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, InpLotSize, bid, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), "SMA Crossover Sell");
    }

    // RSI Buy condition
    if(cntBuy == 0 && rsiBuffer[1] >= (100 - InpRSILevel) && rsiBuffer[0] < (100 - InpRSILevel) && openTimeBuy != iTime(_Symbol, PERIOD_CURRENT, 0))
    {
        openTimeBuy = iTime(_Symbol, PERIOD_CURRENT, 0);
        double ask = currentTick.ask;
        double sl = InpStopLoss == 0 ? 0 : ask - InpStopLoss * _Point;
        double tp = InpTakeProfit == 0 ? 0 : ask + InpTakeProfit * _Point;

        if (InpCloseSignal && cntSell > 0)
            ClosePositions(1);

        trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, InpLotSize, ask, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), "RSI Buy");
    }

    // RSI Sell condition
    if(cntSell == 0 && rsiBuffer[1] <= InpRSILevel && rsiBuffer[0] > InpRSILevel && openTimeSell != iTime(_Symbol, PERIOD_CURRENT, 0))
    {
        openTimeSell = iTime(_Symbol, PERIOD_CURRENT, 0);
        double bid = currentTick.bid;
        double sl = InpStopLoss == 0 ? 0 : bid + InpStopLoss * _Point;
        double tp = InpTakeProfit == 0 ? 0 : bid - InpTakeProfit * _Point;

        if (InpCloseSignal && cntBuy > 0)
            ClosePositions(2);

        trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, InpLotSize, bid, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), "RSI Sell");
    }
}

//+------------------------------------------------------------------+
//| Count open positions                                             |
//+------------------------------------------------------------------+
bool CountOpenPositions(int &cntBuy, int &cntSell)
{
    cntBuy = 0;
    cntSell = 0;
    int total = PositionsTotal();
    for (int i = total - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0 || !PositionSelectByTicket(ticket))
        {
            Print("Failed to get position ticket");
            return false;
        }

        long magic;
        if(!PositionGetInteger(POSITION_MAGIC, magic) || magic != InpMagicnumber)
            continue;

        long type;
        if(!PositionGetInteger(POSITION_TYPE, type))
            continue;

        if(type == POSITION_TYPE_BUY)
            cntBuy++;
        if(type == POSITION_TYPE_SELL)
            cntSell++;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Close positions                                                  |
//+------------------------------------------------------------------+
bool ClosePositions(int all_buy_sell)
{
    int total = PositionsTotal();
    for (int i = total - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0 || !PositionSelectByTicket(ticket))
        {
            Print("Failed to get position ticket");
            return false;
        }

        long magic;
        if(!PositionGetInteger(POSITION_MAGIC, magic) || magic != InpMagicnumber)
            continue;

        long type;
        if(!PositionGetInteger(POSITION_TYPE, type))
            continue;

        if(all_buy_sell == 1 && type == POSITION_TYPE_SELL)
            continue;
        if(all_buy_sell == 2 && type == POSITION_TYPE_BUY)
            continue;

        trade.PositionClose(ticket);
        if(trade.ResultRetcode() != TRADE_RETCODE_DONE)
        {
            Print("Failed to close position. Ticket: ", ticket, " Result: ", trade.ResultRetcodeDescription());
        }
    }
    return true;
}
