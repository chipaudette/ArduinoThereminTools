
#include <LiquidCrystal.h>
#include <Streaming.h>

#define NOTSCALE_NOTRAW_NOTQUANT 0
#define SCALE_NOTRAW_NOTQUANT 1
#define NOTSCALE_RAW_NOTQUANT 2
#define SCALE_RAW_NOTQUANT 3
#define NOTSCALE_NOTRAW_QUANT 4
#define SCALE_NOTRAW_QUANT 5
#define NOTSCALE_RAW_QUANT 6
#define SCALE_RAW_QUANT 7

byte composed_symbol[8];
void defineCustomLCDScaleShapes(LiquidCrystal lcd, int start_lcd_storage_index) {
  //Create dash with top and bottom bracket to show that this is the current note, but not on the scale
  byte top[2] = {
    B11111, B10001  };
  byte nottopbottom[2] = {
    B00000,B00000  };
  byte bottom[2] = {
    B10001,B11111  };
  byte mid[3] = {
    B00000,B00100,B00000  };
  byte notmid[3] = {
    B00000,B00000,B00000  };

  lcd.createChar(NOTSCALE_NOTRAW_NOTQUANT,composeSymbol(nottopbottom,notmid,nottopbottom));
  lcd.createChar(SCALE_NOTRAW_NOTQUANT,composeSymbol(nottopbottom,mid,nottopbottom));
  lcd.createChar(NOTSCALE_RAW_NOTQUANT,composeSymbol(nottopbottom,notmid,bottom));
  lcd.createChar(SCALE_RAW_NOTQUANT,composeSymbol(nottopbottom,mid,bottom));
  lcd.createChar(NOTSCALE_NOTRAW_QUANT,composeSymbol(top,notmid,nottopbottom));
  lcd.createChar(SCALE_NOTRAW_QUANT,composeSymbol(top,mid,nottopbottom));
  lcd.createChar(NOTSCALE_RAW_QUANT,composeSymbol(top,notmid,bottom));
  lcd.createChar(SCALE_RAW_QUANT,composeSymbol(top,mid,bottom));
}

byte* composeSymbol(byte top[], byte mid[], byte bottom[]) {
  composed_symbol[0]=top[0];
  composed_symbol[1]=top[1];
  composed_symbol[2]=mid[0];
  composed_symbol[3]=mid[1];
  composed_symbol[4]=mid[2];
  composed_symbol[5]=bottom[0];
  composed_symbol[6]=bottom[1];
  return composed_symbol;
}


#define LEN_STRING 13
void drawScale(LiquidCrystal lcd,int row, int col,int scale,int rawNote,int quantNote) {
  int n_steps;
  int i;
  int* scale_steps;
  boolean is_scale[LEN_STRING];
  //char scale_string[] = "0123456789012";
  if (rawNote >= 12) rawNote = rawNote % 12; 
  if (rawNote < 0) rawNote = rawNote + 12*(abs(rawNote / 12)+1);
  if (quantNote >= 12) quantNote = quantNote % 12; 
  if (quantNote < 0) {
    quantNote = quantNote + 12*abs((quantNote / 12)+1);
  }

  //get which notes are in the scale and which are not
  scale_steps = getScaleSteps(scale,n_steps); // returns n_steps and scale_steps
  int cur_step = 0;
  for (i=0;i<LEN_STRING;i++) {
    if (i==scale_steps[cur_step]) {
      //this is a step in the scale
      is_scale[i]=true;
      cur_step++;
    } 
    else {
      is_scale[i]=false;
    }
  }

  //print scale and notes to screen
  for (int i=0; i<LEN_STRING; i++) {
    lcd.setCursor(col+i,row);
    lcd.write(getScaleCode(is_scale[i],rawNote,quantNote,i)); // returns scale_string  
  }
  if ((rawNote==0) | (quantNote==0)) {
    //print again at the octave
    lcd.setCursor(col+12,row);
    lcd.write(getScaleCode(is_scale[12],rawNote,quantNote,0)); // returns scale_string  
  }
}

int getScaleCode(const boolean &is_scale,const int &rawNote, const int &quantNote, const int &cur_step) {
  if (cur_step!=quantNote) {
    if (cur_step!=rawNote) {
      if (!is_scale) {
        return NOTSCALE_NOTRAW_NOTQUANT;
      } 
      else {
        return SCALE_NOTRAW_NOTQUANT;
      }
    } 
    else {
      if (!is_scale) {
        return NOTSCALE_RAW_NOTQUANT;
      } 
      else {
        return SCALE_RAW_NOTQUANT;
      }
    }
  } 
  else {
    if (cur_step!=rawNote) {
      if (!is_scale) {
        return NOTSCALE_NOTRAW_QUANT;
      } 
      else {
        return SCALE_NOTRAW_QUANT;
      }
    } 
    else {
      if (!is_scale) {
        return NOTSCALE_RAW_QUANT;
      } 
      else {
        return SCALE_RAW_QUANT;
      }
    }
  }
}



