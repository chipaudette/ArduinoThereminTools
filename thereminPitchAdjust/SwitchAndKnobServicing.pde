#define modeNoChange 0
#define modeKeyChange 1
#define modeScaleChange1 2
#define modeScaleChange2 9999
#define modeVibratoChange 3
#define modeBendChange 4
#define modeDeadBandChange 5
#define modeSmoothChange 6
#define nModes 7

//encoder variables
volatile int encoderPos = 0;
boolean A_set = false;
boolean B_set = false;

void initEncoder(const int pushButton_pin,const int encoderPinA,const int encoderPinB) {
  pinMode(pushButton_pin,INPUT);
  digitalWrite(pushButton_pin, HIGH);
  pinMode(encoderPinA, INPUT); 
  digitalWrite(encoderPinA, HIGH);       // turn on pullup resistor
  pinMode(encoderPinB, INPUT); 
  digitalWrite(encoderPinB, HIGH);       // turn on pullup resistor

  //initialize interrupt variables
  A_set = digitalRead(encoderPinA) == HIGH;
  B_set = digitalRead(encoderPinB) == HIGH;

  // setup the interrupts for the encoder services
  attachInterrupt(0, doEncoderA, CHANGE);
  //attachInterrupt(1, doEncoderB, CHANGE);
}

// Interrupt on A changing state
void doEncoderA(){
  static boolean prev_B_set = HIGH;

  // Test transition
  A_set = digitalRead(encoderPinA) == HIGH;
  prev_B_set = B_set;
  B_set = digitalRead(encoderPinB) == HIGH; 

  if (prev_B_set != B_set) {
    // and adjust counter + if A leads B
    encoderPos -= (A_set != B_set) ? +1 : -1;  //reversed sign because of my particular wiring
    //Serial << "doEncoderA: " << encoderPos << endl;
  }
}
void doEncoderA_orig(){
  // Test transition
  A_set = digitalRead(encoderPinA) == HIGH;

  // and adjust counter + if A leads B
  encoderPos += (A_set != B_set) ? +1 : -1;  //reversed sign because of my particular wiring
}

// Interrupt on B changing state
void doEncoderB(){
  // Test transition
  B_set = digitalRead(encoderPinB) == HIGH;
  // and adjust counter + if B follows A
  encoderPos += (A_set == B_set) ? +1 : -1;  //reversed sign because of my particular wiring
  //Serial << "doEncoderB: " << encoderPos << endl;
}

#define WAIT_FOR_PRESS (0)
#define WAIT_FOR_RELEASE (1)
int changeModeCounter=0;
int changeModeCounter_resetValue = (4*510);  //Use 4 x sampleRate
int servicePushbutton (const int pin,boolean &modeWasChange,boolean &endChangeMode) {
  static int state = WAIT_FOR_PRESS;
  static int pushButton_accumVal = 0;
  const int pushButton_thresh (14);  // was 10 for sample rate of 360
  static int curChangeMode = modeNoChange;

  changeModeCounter = constrain(changeModeCounter-1,0,10000);
  if (changeModeCounter <= 0) {
    if (curChangeMode != 0) endChangeMode=true;
    curChangeMode=0;
  }

  //read value and accumulate
  if (digitalRead(pushButton_pin) == HIGH) {
    //button is not pressed
    pushButton_accumVal--;
  } 
  else {
    //button is pressed
    pushButton_accumVal++;
  }
  pushButton_accumVal = constrain(pushButton_accumVal,0,pushButton_thresh);

  switch (state) {
  case WAIT_FOR_PRESS:
    if (pushButton_accumVal >= pushButton_thresh) {
      //changeKey(1,changed_state);
      curChangeMode = (curChangeMode+1) % nModes;
      modeWasChange = true;
      changeModeCounter=changeModeCounter_resetValue;
      if (curChangeMode == modeNoChange) {
        changeModeCounter=0;
        endChangeMode=true;
      }
      Serial << "SwitchAndKnob: changedMode: curChangeMode = " << curChangeMode << endl;
      state = WAIT_FOR_RELEASE; //change state...now wait for the release
    }
    break;
  case WAIT_FOR_RELEASE:
    if (pushButton_accumVal <= 0) {
      state = WAIT_FOR_PRESS;
    }
    break;
  }
  return curChangeMode;
}

int getChangeModeCounter() {
  return changeModeCounter;
}

void serviceEncoder(const int changeModeFlag, boolean &redraw_lcd) {
  static int encoderDelayCount=0;
  encoderDelayCount=constrain(encoderDelayCount-1,0,100);
  if (encoderPos != 0) {

    if (encoderDelayCount <= 0) {
      //Serial << "ChangingKey: encoderPos: " << encoderPos << endl;
      int change = constrain(encoderPos,-1,1);
      switch (changeModeFlag) {
      case modeNoChange:
        //no action
        break;
      case modeKeyChange:
        //change key
        changeKey(change,redraw_lcd);
        //Serial << "SwitchAndKnob: Changing Key..." << endl;
        break;
      case modeScaleChange1:
        //change scale
        changeScale(change,redraw_lcd);
        //Serial << "SwitchAndKnob: Changing Scale..." << endl;
        break;
//     case modeScaleChange2:
//        //change scale
//        changeScale(2,change,redraw_lcd);
//        //Serial << "SwitchAndKnob: Changing Scale..." << endl;
//        break;       
      case modeVibratoChange:
        //change vibrato level
        changeVibratoFac(change);
        break;
      case modeBendChange:
        //change vibrato level
        changeGlideFac(change);
        break;
      case modeDeadBandChange:
        changeDeadBandFac(change);
        break;
      case modeSmoothChange:
        changeUseSmooth(change);
        break;
      } 
      if (changeModeFlag > 0) changeModeCounter=changeModeCounter_resetValue;
      encoderDelayCount=56;   //this works as my de-bounce...assume 40 at fs=350Hz
    }
    encoderPos=0;
  }
}

int serviceFootswitch(const int pin, boolean &changed_state) {
  static int state = WAIT_FOR_PRESS;
  static int pushButton_accumVal = 0;
  static int max_val = 0;
  const int pushButton_thresh1=7;  //5 for fs = 360
  const int pushButton_thresh2=140; //100 for fs = 360

  //read value and accumulate
  int cur_val = digitalRead(pin);
  if (cur_val == HIGH) {
    //button is not pressed
    pushButton_accumVal--;    
    if (pushButton_accumVal < (pushButton_thresh1-pushButton_thresh2)) { 
      pushButton_accumVal = min(pushButton_accumVal,pushButton_thresh1);  
    }
  } 
  else {
    //button is pressed
    pushButton_accumVal++;
    max_val = max(max_val,pushButton_accumVal);
  }
  pushButton_accumVal = constrain(pushButton_accumVal,0,pushButton_thresh2);

  switch (state) {
  case WAIT_FOR_PRESS:
    if (pushButton_accumVal >= pushButton_thresh1) {
      state = WAIT_FOR_RELEASE; //change state...now wait for the release
    }
    break;
  case WAIT_FOR_RELEASE:
    if (pushButton_accumVal <= (max_val - pushButton_thresh1)) {
      state = WAIT_FOR_PRESS;
      if (max_val >= pushButton_thresh2) {
        //do nothing here
      } 
      else if (max_val >= pushButton_thresh1) {
        key_scale_index = (key_scale_index+1) % 3;  //the "3" is for the number of scales the user can toggle between with the footswitch
        changed_state = true;
      }
      max_val = 0;
    }
    break;
  }

  return cur_val;
}



void drawChangeModeInterface(LiquidCrystal lcd,const int row,const int col,String keyName,String scaleName1,float vibratoScaleFac,float bendScaleFac,float deadBandScaleFac, const boolean useInputSmoothing,int curChangeMode) {
  String fooStr;
  
  if (curChangeMode> modeNoChange) {
    lcd.setCursor(row,col);
    lcd.print("                ");
    lcd.setCursor(row,col);
    switch (curChangeMode) {
    case modeKeyChange:
      lcd.print("Change Key: " + keyName.substring(0,keyName.length()-1));
       break;
    case modeScaleChange1:
      lcd.print("Scale: " + scaleName1);
      break;
//    case modeScaleChange2:
//      lcd.print("Scale2: " + scaleName2);
//      break;
    case modeVibratoChange:
      makeFloatString(vibratoScaleFac,2,fooStr);
      lcd.print("Vibrato: " + fooStr);
      break;
    case modeBendChange:
      makeFloatString(bendScaleFac,2,fooStr);
      lcd.print("Bend: " + fooStr);
      break;
    case modeDeadBandChange:
      makeFloatString(deadBandScaleFac,2,fooStr);
      lcd.print("Dead-band: " + fooStr);
      break;
    case modeSmoothChange:
      if (useInputSmoothing) {
        lcd.print("Smoothing: YES");
      } else {
        lcd.print("Smoothing: NO");
      }
      break;
    }
  }
}


void makeFloatString(float in, int n_decimal, String &str) {
  int val;
  val = floor(in);
  str=String(val);
  str = str + String(".");
  in -= val;
  
  for (int i=0;i<n_decimal;i++) {
    in *= 10;
    val = floor(in);
    str = str + String(val);
    in -= val;
  }
}
