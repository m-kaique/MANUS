#ifndef VISUALPANEL_MQH_
#define VISUALPANEL_MQH_

//+------------------------------------------------------------------+
//|                                             VisualPanel.mqh |qh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include "Structures.mqh"
#include "PerformanceTracker.mqh"

//+------------------------------------------------------------------+
//| Classe para exibição de painel visual                            |
//+------------------------------------------------------------------+
class CVisualPanel {
private:
   // Configurações do painel
   int               m_xPos;              // Posição X
   int               m_yPos;              // Posição Y
   int               m_width;             // Largura
   int               m_height;            // Altura
   string            m_fontName;          // Nome da fonte
   int               m_fontSize;          // Tamanho da fonte
   color             m_bgColor;           // Cor de fundo
   color             m_textColor;         // Cor do texto
   color             m_headerColor;       // Cor do cabeçalho
   color             m_profitColor;       // Cor para lucro
   color             m_lossColor;         // Cor para prejuízo
   
   // Prefixo para objetos
   string            m_prefix;
   
   // Ponteiro para o rastreador de performance
   CPerformanceTracker* m_performanceTracker;
   
   // Métodos privados
   void CreateBackground();
   void CreateHeader();
   void CreateAccountInfo(int &yOffset);
   void CreatePerformanceInfo(int &yOffset);
   void CreateQualityInfo(int &yOffset);
   void CreateActivePositions(int &yOffset);
   void CreateLabel(string name, string text, int x, int y, color clr = clrNONE, int fontSize = 0);
   void DeleteAllObjects();
   string FormatPercent(double value);
   string FormatMoney(double value);
   
public:
   // Construtor e destrutor
   CVisualPanel();
   ~CVisualPanel();
   
   // Inicialização
   bool Initialize(int xPos, int yPos, CPerformanceTracker* tracker);
   
   // Atualização
   void Update();
   void UpdateAccountInfo();
   void UpdatePerformance();
   void UpdateActivePositions();
   
   // Controle de visibilidade
   void Show();
   void Hide();
   bool IsVisible();
   
   // Configurações
   void SetColors(color bg, color text, color header, color profit, color loss);
   void SetFont(string fontName, int fontSize);
   void SetPosition(int x, int y);
};

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
CVisualPanel::CVisualPanel() {
   m_xPos = 10;
   m_yPos = 30;
   m_width = 350;
   m_height = 600;
   m_fontName = "Arial";
   m_fontSize = 9;
   m_bgColor = C'20,20,20';
   m_textColor = clrWhite;
   m_headerColor = clrGold;
   m_profitColor = clrLime;
   m_lossColor = clrRed;
   m_prefix = "VP_";
   m_performanceTracker = NULL;
}

//+------------------------------------------------------------------+
//| Destrutor                                                        |
//+------------------------------------------------------------------+
CVisualPanel::~CVisualPanel() {
   DeleteAllObjects();
}

//+------------------------------------------------------------------+
//| Inicialização                                                    |
//+------------------------------------------------------------------+
bool CVisualPanel::Initialize(int xPos, int yPos, CPerformanceTracker* tracker) {
   if(tracker == NULL) {
      return false;
   }
   
   m_xPos = xPos;
   m_yPos = yPos;
   m_performanceTracker = tracker;
   
   // Criar elementos do painel
   CreateBackground();
   Update();
   
   return true;
}

//+------------------------------------------------------------------+
//| Atualizar painel                                                 |
//+------------------------------------------------------------------+
void CVisualPanel::Update() {
   int yOffset = m_yPos + 10;
   
   // Criar cabeçalho
   CreateHeader();
   yOffset += 30;
   
   // Informações da conta
   CreateAccountInfo(yOffset);
   yOffset += 20;
   
   // Informações de performance
   CreatePerformanceInfo(yOffset);
   yOffset += 20;
   
   // Informações por qualidade
   CreateQualityInfo(yOffset);
   yOffset += 20;
   
   // Posições ativas
   CreateActivePositions(yOffset);
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Criar fundo do painel                                            |
//+------------------------------------------------------------------+
void CVisualPanel::CreateBackground() {
   string name = m_prefix + "Background";
   
   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   }
   
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, m_xPos);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, m_yPos);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, m_width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, m_height);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, m_bgColor);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
}

//+------------------------------------------------------------------+
//| Criar cabeçalho                                                  |
//+------------------------------------------------------------------+
void CVisualPanel::CreateHeader() {
   CreateLabel(m_prefix + "Header", "INTEGRATED PA EA - PAINEL DE CONTROLE", 
               m_xPos + 10, m_yPos + 10, m_headerColor, 11);
   
   // Linha separadora
   string lineName = m_prefix + "HeaderLine";
   if(ObjectFind(0, lineName) < 0) {
      ObjectCreate(0, lineName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   }
   
   ObjectSetInteger(0, lineName, OBJPROP_XDISTANCE, m_xPos + 10);
   ObjectSetInteger(0, lineName, OBJPROP_YDISTANCE, m_yPos + 30);
   ObjectSetInteger(0, lineName, OBJPROP_XSIZE, m_width - 20);
   ObjectSetInteger(0, lineName, OBJPROP_YSIZE, 1);
   ObjectSetInteger(0, lineName, OBJPROP_BGCOLOR, m_headerColor);
   ObjectSetInteger(0, lineName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, lineName, OBJPROP_BACK, false);
}

//+------------------------------------------------------------------+
//| Criar informações da conta                                       |
//+------------------------------------------------------------------+
void CVisualPanel::CreateAccountInfo(int &yOffset) {
   CreateLabel(m_prefix + "AccTitle", "INFORMAÇÕES DA CONTA", m_xPos + 10, yOffset, m_headerColor, 10);
   yOffset += 20;
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double margin = AccountInfoDouble(ACCOUNT_MARGIN);
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double marginLevel = (margin > 0) ? equity / margin * 100 : 0;
   
   CreateLabel(m_prefix + "Balance", "Saldo: " + FormatMoney(balance), m_xPos + 20, yOffset);
   yOffset += 15;
   
   color equityColor = (equity >= balance) ? m_profitColor : m_lossColor;
   CreateLabel(m_prefix + "Equity", "Patrimônio: " + FormatMoney(equity), m_xPos + 20, yOffset, equityColor);
   yOffset += 15;
   
   CreateLabel(m_prefix + "Margin", "Margem Usada: " + FormatMoney(margin), m_xPos + 20, yOffset);
   yOffset += 15;
   
   CreateLabel(m_prefix + "FreeMargin", "Margem Livre: " + FormatMoney(freeMargin), m_xPos + 20, yOffset);
   yOffset += 15;
   
   color marginLevelColor = (marginLevel > 200) ? m_profitColor : (marginLevel > 100) ? m_textColor : m_lossColor;
   CreateLabel(m_prefix + "MarginLevel", "Nível de Margem: " + FormatPercent(marginLevel), m_xPos + 20, yOffset, marginLevelColor);
   yOffset += 15;
}

//+------------------------------------------------------------------+
//| Criar informações de performance                                 |
//+------------------------------------------------------------------+
void CVisualPanel::CreatePerformanceInfo(int &yOffset) {
   CreateLabel(m_prefix + "PerfTitle", "PERFORMANCE GERAL", m_xPos + 10, yOffset, m_headerColor, 10);
   yOffset += 20;
   
   if(m_performanceTracker == NULL) return;
   
   double winRate = m_performanceTracker.GetWinRate();
   double profitFactor = m_performanceTracker.GetProfitFactor();
   double expectancy = m_performanceTracker.GetExpectancy();
   double maxDrawdown = m_performanceTracker.GetMaxDrawdown();
   
   color winRateColor = (winRate >= 60) ? m_profitColor : (winRate >= 50) ? m_textColor : m_lossColor;
   CreateLabel(m_prefix + "WinRate", "Taxa de Acerto: " + FormatPercent(winRate), m_xPos + 20, yOffset, winRateColor);
   yOffset += 15;
   
   color pfColor = (profitFactor >= 1.5) ? m_profitColor : (profitFactor >= 1.0) ? m_textColor : m_lossColor;
   CreateLabel(m_prefix + "ProfitFactor", "Fator de Lucro: " + DoubleToString(profitFactor, 2), m_xPos + 20, yOffset, pfColor);
   yOffset += 15;
   
   color expColor = (expectancy > 0) ? m_profitColor : m_lossColor;
   CreateLabel(m_prefix + "Expectancy", "Expectativa: " + FormatMoney(expectancy), m_xPos + 20, yOffset, expColor);
   yOffset += 15;
   
   color ddColor = (maxDrawdown < 10) ? m_profitColor : (maxDrawdown < 20) ? m_textColor : m_lossColor;
   CreateLabel(m_prefix + "MaxDD", "Drawdown Máx: " + FormatPercent(maxDrawdown), m_xPos + 20, yOffset, ddColor);
   yOffset += 15;
}

//+------------------------------------------------------------------+
//| Criar informações por qualidade                                  |
//+------------------------------------------------------------------+
void CVisualPanel::CreateQualityInfo(int &yOffset) {
   CreateLabel(m_prefix + "QualityTitle", "ESTATÍSTICAS POR QUALIDADE", m_xPos + 10, yOffset, m_headerColor, 10);
   yOffset += 20;
   
   if(m_performanceTracker == NULL) return;
   
   string qualities[] = {"A+", "A", "B", "C"};
   SETUP_QUALITY qualityEnums[] = {SETUP_A_PLUS, SETUP_A, SETUP_B, SETUP_C};
   
   for(int i = 0; i < 4; i++) {
      SetupQualityStats stats = m_performanceTracker.GetQualityStats(qualityEnums[i]);
      
      if(stats.totalSignals > 0) {
         string text = StringFormat("%s: %d sinais, %d trades, %.1f%% win, PF: %.2f",
                                   qualities[i],
                                   stats.totalSignals,
                                   stats.totalTrades,
                                   stats.winRate,
                                   stats.profitFactor);
         
         color textColor = (stats.winRate >= 60) ? m_profitColor : (stats.winRate >= 50) ? m_textColor : m_lossColor;
         CreateLabel(m_prefix + "Quality" + IntegerToString(i), text, m_xPos + 20, yOffset, textColor);
         yOffset += 15;
      }
   }
}

//+------------------------------------------------------------------+
//| Criar lista de posições ativas                                   |
//+------------------------------------------------------------------+
void CVisualPanel::CreateActivePositions(int &yOffset) {
   CreateLabel(m_prefix + "PosTitle", "POSIÇÕES ATIVAS", m_xPos + 10, yOffset, m_headerColor, 10);
   yOffset += 20;
   
   int totalPositions = PositionsTotal();
   
   if(totalPositions == 0) {
      CreateLabel(m_prefix + "NoPos", "Nenhuma posição aberta", m_xPos + 20, yOffset, m_textColor);
      yOffset += 15;
   } else {
      for(int i = 0; i < MathMin(totalPositions, 5); i++) { // Mostrar até 5 posições
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0) {
            string symbol = PositionGetString(POSITION_SYMBOL);
            double volume = PositionGetDouble(POSITION_VOLUME);
            double profit = PositionGetDouble(POSITION_PROFIT);
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            
            string typeStr = (type == POSITION_TYPE_BUY) ? "BUY" : "SELL";
            string text = StringFormat("#%d %s %.2f %s P/L: %.2f",
                                      ticket,
                                      symbol,
                                      volume,
                                      typeStr,
                                      profit);
            
            color profitColor = (profit >= 0) ? m_profitColor : m_lossColor;
            CreateLabel(m_prefix + "Pos" + IntegerToString(i), text, m_xPos + 20, yOffset, profitColor, 8);
            yOffset += 15;
         }
      }
      
      if(totalPositions > 5) {
         CreateLabel(m_prefix + "MorePos", "... e mais " + IntegerToString(totalPositions - 5) + " posições", 
                    m_xPos + 20, yOffset, m_textColor, 8);
         yOffset += 15;
      }
   }
}

//+------------------------------------------------------------------+
//| Criar label                                                      |
//+------------------------------------------------------------------+
void CVisualPanel::CreateLabel(string name, string text, int x, int y, color clr = clrNONE, int fontSize = 0) {
   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   }
   
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, m_fontName);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, (fontSize > 0) ? fontSize : m_fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, (clr != clrNONE) ? clr : m_textColor);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 1);
}

//+------------------------------------------------------------------+
//| Deletar todos os objetos                                         |
//+------------------------------------------------------------------+
void CVisualPanel::DeleteAllObjects() {
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--) {
      string name = ObjectName(0, i);
      if(StringFind(name, m_prefix) == 0) {
         ObjectDelete(0, name);
      }
   }
}

//+------------------------------------------------------------------+
//| Formatar percentual                                              |
//+------------------------------------------------------------------+
string CVisualPanel::FormatPercent(double value) {
   return DoubleToString(value, 1) + "%";
}

//+------------------------------------------------------------------+
//| Formatar valor monetário                                         |
//+------------------------------------------------------------------+
string CVisualPanel::FormatMoney(double value) {
   string currency = AccountInfoString(ACCOUNT_CURRENCY);
   return currency + " " + DoubleToString(value, 2);
}

//+------------------------------------------------------------------+
//| Atualizar informações da conta                                   |
//+------------------------------------------------------------------+
void CVisualPanel::UpdateAccountInfo() {
   int yOffset = m_yPos + 40;
   CreateAccountInfo(yOffset);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Atualizar performance                                            |
//+------------------------------------------------------------------+
void CVisualPanel::UpdatePerformance() {
   int yOffset = m_yPos + 140;
   CreatePerformanceInfo(yOffset);
   CreateQualityInfo(yOffset);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Atualizar posições ativas                                        |
//+------------------------------------------------------------------+
void CVisualPanel::UpdateActivePositions() {
   int yOffset = m_yPos + 400;
   CreateActivePositions(yOffset);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Mostrar painel                                                   |
//+------------------------------------------------------------------+
void CVisualPanel::Show() {
   Update();
}

//+------------------------------------------------------------------+
//| Esconder painel                                                  |
//+------------------------------------------------------------------+
void CVisualPanel::Hide() {
   DeleteAllObjects();
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Verificar se está visível                                        |
//+------------------------------------------------------------------+
bool CVisualPanel::IsVisible() {
   return (ObjectFind(0, m_prefix + "Background") >= 0);
}

//+------------------------------------------------------------------+
//| Configurar cores                                                 |
//+------------------------------------------------------------------+
void CVisualPanel::SetColors(color bg, color text, color header, color profit, color loss) {
   m_bgColor = bg;
   m_textColor = text;
   m_headerColor = header;
   m_profitColor = profit;
   m_lossColor = loss;
}

//+------------------------------------------------------------------+
//| Configurar fonte                                                 |
//+------------------------------------------------------------------+
void CVisualPanel::SetFont(string fontName, int fontSize) {
   m_fontName = fontName;
   m_fontSize = fontSize;
}

//+------------------------------------------------------------------+
//| Configurar posição                                               |
//+------------------------------------------------------------------+
void CVisualPanel::SetPosition(int x, int y) {
   m_xPos = x;
   m_yPos = y;
   if(IsVisible()) {
      Update();
   }
}

#endif // VISUALPANEL_MQH_
