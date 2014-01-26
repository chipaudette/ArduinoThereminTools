/* 
 Created: Chip Audette, Feb 2011
 Purpose: Pitch processing code for synthesizers with control voltage inpus
 
 Features: pitch quantize (serviceEncoderdiatonic) and triggering
 */

// include the library code:
#include <LiquidCrystal.h>
#include <SPI.h>
#include <Streaming.h>
#include <String.h>

/* This function places the current value of the heap and stack pointers in the
 * variables. You can call it from any place in your code and save the data for
 * outputting or displaying later. This allows you to check at different parts of
 * your program flow.
 * The stack pointer starts at the top of RAM and grows downwards. The heap pointer
 * starts just above the static variables etc. and grows upwards. SP should always
 * be larger than HP or you'll be in big trouble! The smaller the gap, the more
 * careful you need to be. Julian Gall 6-Feb-2009.
 */
uint8_t * heapptr, * stackptr;
void check_mem() {
  stackptr = (uint8_t *)malloc(4);          // use stackptr temporarily
  heapptr = stackptr;                     // save value of heap pointer
  free(stackptr);      // free up the memory again (sets stackptr to 0)
  stackptr =  (uint8_t *)(SP);           // save value of stack pointer
}


// initialize the library with the numbers of the interface pins
LiquidCrystal lcd(4,5,6,7,8,9);  //rs, enable, d0, d1, d2, d3
int currentDisplayMode = 0;  //what type of info is the LCD displaying?
int prevDisplayMode = 0;     //what was the LCD displaying the last time?

// initialize variables for analogIn
const int sensorPin = A0;    // select the input pin for the potentiometer
const int FS1_pin = A2; //footswitch 1
const int FS2_pin = A3; //footswitch 2
const int pushButton_pin=A4;     // Push button on rotary encoder
const int slaveSelectPin = 10; //slave select for the ADC
const int encoderPinA = 3;
const int encoderPinB = 2;


//Define bit depths
int nBitsFS = 14;
int fullScale = ((int)pow(2,nBitsFS));
int nBitsADC = 10;  //Arduino's built-in ADC has 10 bits
//int nBitsPWM = 8;   //Arduino's PWM "analog" output has 8 bits
int nBitsDAC = 12;  //MCP4922 DAC has 12 bits
float floatConstrainValue = ((float)fullScale)-1.0;

// Initialize the measurement and smoothing variables
int FS1_val = HIGH, FS2_val = HIGH; //initialize the two foot switches
int sensorValue = 0;        // value read from the pot
int prevSensorValue = 0;
int outputValue = 0;        // value output to the PWM (analog out)
#if 0
float smoothB[2] = {
  0.2976, 0.2976};  //45-50 Hz low pass
float smooth2[2] = { 
  0.125, 0.875};  //for vibrato calcs...0.125,0.875  (sized for sample rate at 357 Hz)
#else
//float smoothB[2] = {0.11633650601052,   0.11633650601052};  //15 Hz lowpass, fs=360Hz
//float smooth2B[2] = { 0.06, 0.06};  //for vibrato calcs...0.125,0.875  (sized for sample rate at 357 Hz)
float smoothB[2] = {
  0.08480527979559, 0.08480527979559};  //15 Hz lowpass, fs=510Hz
float smooth2B[2] = {
  0.04277788377850, 0.04277788377850};  //for vibrato calcs...0.125,0.875  (sized for sample rate at 357 Hz)
#endif
float smoothA = 0.0; //defined in setup() based upon smoothB
float smooth2A = 0.0;
//#if 1
//float filt_A_vel[3] = {
//  1.0000,  -1.7693,    0.7714}; //bandpass [0.5 15] Hz for fs = 355 Hz
//float filt_B_vel[3] = {
//  0.1143, 0, -0.1143}; //bandpass [0.5 15] Hz for fs = 355 Hz
//#else
//float filt_A_vel[3] = {
//  1.0, -1.8513, 0.8541}; //bandpass [1 15] Hz for fs = 350 Hz
//float filt_B_vel[3] = {
//  0.0730, 0, -0.0730}; //bandpass [1 15] Hz for fs = 350 Hz
//#endif
//float prev_vel_out[3] = {
//  0.0,0.0,0.0};
//float prev_vel_in[3] = {
//  0.0,0.0,0.0};
float smoothedValue = 0.0;

float vel_adjust_value=0.0;
int prevQuantizedValue=0;
int quantizedValue=0;
float vibratoValue = 0.0;
float smoothedValue2 = 0.0; // for vibrato calcs
float glideFac2 = 0.0;
float glideAmount = 0.0;

float vibratoGain = 2.0; //2.0...zero or 2.0
//float glideFac = 0.05;  //0.1...zero or 0.5, or 0.25 if combined with [1 15] vel
//float vel_adjust_fac = 0.0; //0.0...1.0?  0.1 use 0.5Hz, 0.5 use 1.0Hz
float vibratoFac[14] = {
  0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0,5.0,10.0};
const int nVibratoFac = 14;
int curVibratoFacIndex = 7;  //start at a value of 1.0
float glideFac[12] = {
  0.0, 0.02, 0.05, 0.1, 0.2, 0.3, 0.5, 1.0, 1.5, 2.0, 3.0, 5.0};
const int nGlideFac = 12;
int curGlideFacIndex = 2;

#define nDeadBandFac 6
//float deadBandVibratoScaleFac[nDeadBandFac]={0.0, 0.25, 0.5, 1.0, 1.5, 2.0, 5.0};
float deadBandVibratoScaleFac[nDeadBandFac]={0.0, 0.01, 0.1, 1.0, 10.0, 100.0};
int curDeadBandIndex = 0;

// Initialize the pitch shifting variables (ie, pitch sequencing)
float centerSpacing = ((float)fullScale) / 5.0 / 12.0; //full scale out yields 5 octaves with 12 half steps per octave
int halfCenterSpacing = ((int)(0.5*centerSpacing));
int key[3] = {
  0,0,0};  //zero is C.  counts up by half steps
int scale[3] = {
  2,1,0};  //choices are 0=NO_SCALE, 1=CHROMATIC, 2=MAJOR, 3=MINOR (AEOLIAN), 4=MAJ PENT, 5=MINOR PENT, 6=PHYRGIAN, 7=HARM MINOR
const int chrom_scale = 1;
int key_scale_index = 0;
String keyName = String("NA");
int nHalfSteps = 0;

boolean useInputSmoothing = true;

// Initialize other variables
int sampleCount=0;
float sampleRateHz=0;
unsigned long origMillis = 0;
//int quantizeValueChromatic(float,int,int,String&);
//int quantizeValueByKeyScale(float,int,int,int,int,String&);

void setup() {
  pinMode(FS1_pin,INPUT);
  digitalWrite(FS1_pin, HIGH); 
  pinMode(FS2_pin,INPUT);
  digitalWrite(FS2_pin, HIGH);

  // initialize SPI:
  SPI.begin(); 
  SPI.setDataMode(SPI_MODE0);
  SPI.setBitOrder(MSBFIRST);

  // initialize the serial communications:
  Serial.begin(115200);

  // set up the LCD and put text on the display
  lcd.begin(16, 2);  //columns and rows
  lcd.clear();
  lcd.print("Initializing");
  defineCustomLCDScaleShapes(lcd,0);

  //initialize quantizer status...get keyname
  //quantizeValueChromatic(centerSpacing,fullScale,key[key_scale_index]*(int)centerSpacing,keyName);
  int foo;
  quantizeValueByKeyScale2(centerSpacing,fullScale,key[key_scale_index]*(int)centerSpacing,key[key_scale_index],chrom_scale,0.0,foo,keyName); //0 is for chromatic scale and 0 is for the key of "C", though the key doesn't matter

  //init the Encoder routines
  initEncoder(pushButton_pin,encoderPinA,encoderPinB);

  //define smoothing "A" vector
  float sum = 0.0;
  int i=0;
  for (i=0;i<2;i++) {
    sum += smoothB[i];
  }
  smoothA = (1.0 - sum);
  sum = 0.0;
  for (i=0;i<2;i++) {
    sum += smooth2B[i];
  }
  smooth2A = (1.0 - sum);

  origMillis = millis();
  Serial << "%% origMillis = " << origMillis << endl;

  check_mem();
  Serial << "%% Memory: Heap = " << (int)heapptr << ", Stack = " << (int)stackptr << endl;
}

int firstTime=1;
int printMessageToSerial = 0;
void loop() {
  static int prevRawNoteVal=-1,rawNoteVal=-1;
  static int prevQuantNoteValDisplay=-1;
  static boolean redraw_lcd = false;
  int curChangeMode=0;
  String setPitchName, outPitchName;
  static boolean modeWasChanged=false;
  int foo;
  static boolean startLogging = false;
  static int sampleCount2 = 0;
  sampleCount++;
  sampleCount2++;
  static float deadBandVibratoFac=0.0;

  // is it time to print status info to the Serial?
  static const int countLim = 2000+1;
  if (sampleCount==countLim) {
    sampleRateHz = 1000.0*((float)(sampleCount-1)) / ((float)(millis()-origMillis));
    Serial << "%% Sample Count = " << sampleCount-1 << ", Sample Rate = " << sampleRateHz << endl;
    sampleCount=0;
    origMillis = millis();

    check_mem();
    Serial << "%% Memory: Heap = " << (int)heapptr << ", Stack = " << (int)stackptr << endl;
    //Serial << "%% prev_vel_out[0]/spacing = " << prev_vel_out[0]/centerSpacing << ", glideFac2 = " << glideFac2 << endl;
  }

  //  if (sampleCount2 == 2*countLim) {
  //    //startLogging = true;
  //  }
  //  if (sampleCount2 == 5*countLim) {
  //    startLogging = false;
  //    sampleCount2 = 2*countLim+1;
  //  }


  // read digital inputs for foot controllers
  FS1_val = digitalRead(FS1_pin);
  FS2_val = serviceFootswitch(FS2_pin,redraw_lcd);
  //servicePushbutton(pushButton_pin,redraw_lcd);
  modeWasChanged=false;
  curChangeMode = servicePushbutton (pushButton_pin,modeWasChanged,redraw_lcd);
  serviceEncoder(curChangeMode,redraw_lcd);

  if (redraw_lcd) {
    //get new key name
    quantizeValueByKeyScale2(centerSpacing,fullScale,key[key_scale_index]*(int)centerSpacing,0,chrom_scale,1.0,foo,keyName); //0 is for chromatic scale and 0 is for the key of "C", though the key doesn't matter
  }

  //read analog in
  delayMicroseconds(800);  // tune this to get the sample rate assumed for defining the filters
  prevSensorValue = sensorValue;
  sensorValue = analogRead(sensorPin);
  sensorValue = sensorValue << (nBitsFS - nBitsADC);  //shift from 10-bits to full scale
  int unsmoothedSensorValue = sensorValue;
  outputValue = sensorValue;

  //compute smoothed value
  if (millis() < 250)  {
    // ignore the startup period
    smoothedValue = (float)sensorValue;
  } 
  else {
    //compute a slightly smoothed version of the input value
    smoothedValue = ((float)sensorValue)*smoothB[0] + ((float)prevSensorValue)*smoothB[1] + ((float)smoothedValue)*smoothA;
    smoothedValue = constrain(smoothedValue,0.0,floatConstrainValue);
    if (!useInputSmoothing) smoothedValue = unsmoothedSensorValue;

    //apply a filter to compute the velocity-related portion of the input...used for one type of vibrato
//    if (vel_adjust_fac > 0.0) {
//      prev_vel_in[2] = prev_vel_in[1]; 
//      prev_vel_in[1] = prev_vel_in[0]; 
//      prev_vel_in[0] = (float)sensorValue;
//      prev_vel_out[2] = prev_vel_out[1]; 
//      prev_vel_out[1] = prev_vel_out[0];
//      prev_vel_out[0] = 0.0;
//      for (int j=0;j<3;j++) {
//        prev_vel_out[0] += prev_vel_in[j]*filt_B_vel[j];
//        if (j > 0) {
//          prev_vel_out[0] -= prev_vel_out[j]*filt_A_vel[j];
//        }
//      }
//      vel_adjust_value = prev_vel_out[0];
//    }

    //compute a different velocity-related metric...used for another type of vibrato
    if (vibratoGain > 0.0) {
      smoothedValue2 = ((float)sensorValue)*smooth2B[0] + ((float)prevSensorValue)*smooth2B[1] + smoothedValue2*smooth2A;
      smoothedValue2 = constrain(smoothedValue2,-floatConstrainValue,floatConstrainValue);     
      vibratoValue = vibratoGain*(smoothedValue - smoothedValue2);
    }
  }
  //use the smoothed value as the original value
  sensorValue = (int)(smoothedValue+0.49999);  //rounding instead of trunctating

  //get name of pitch of input value
  //quantizeValueChromatic(centerSpacing,fullScale,sensorValue,setPitchName);
  quantizeValueByKeyScale2(centerSpacing,fullScale,sensorValue,0,chrom_scale,1.0,rawNoteVal,setPitchName); //0 is for chromatic scale and 0 is for the key of "C", though the key doesn't matter

  //quantize the value to get the output
  prevQuantizedValue = quantizedValue;
  deadBandVibratoFac = 1.0+10.0*deadBandVibratoScaleFac[curDeadBandIndex]*vibratoValue / centerSpacing;
  quantizedValue = quantizeValueByKeyScale2(centerSpacing,fullScale,sensorValue,key[key_scale_index],scale[key_scale_index],deadBandVibratoFac,nHalfSteps,outPitchName);
  //if (key[key_scale_index]==0) quantizedValue = unsmoothedSensorValue;
  outputValue = quantizedValue;

  //reset the smoothed values if the pitch has changed
  if (quantizedValue != prevQuantizedValue) {
    vibratoValue = 0.0;
    smoothedValue2 = smoothedValue;
  }

  //now, add in a little bit of sharp or flat based on the original input to allow bends and vibrato
  glideFac2 = glideFac[curGlideFacIndex];
  int outOfTuneness = sensorValue - outputValue;
//  if (vel_adjust_fac > 0.0) {
//    glideFac2 = vibratoFac[curVibratoFacIndex]*((float)(abs(vel_adjust_fac*vel_adjust_value)))/((float)halfCenterSpacing); 
//    //glideFac2 = max(glideFac[curGlideFacIndex],glideFac2);
//    glideFac2 = constrain(glideFac2,0.0,1.0);
//  } else {
//    glideFac2 = glideFac[curGlideFacIndex];
//  }
  glideAmount = glideFac2*(float)outOfTuneness;
  outputValue += (int)(glideAmount+0.5); //0.5 is to make it round
  outputValue += (int)(vibratoValue+0.5); //0.5 is to make it round

  //Add behavior in response to footswitch
  if (FS2_val == LOW) {
    outputValue = sensorValue;  //HIGH is the default state.  LOW means that its been pressed
    outPitchName = setPitchName;
    nHalfSteps = rawNoteVal;
  }

  int outputValueDAC = constrain(outputValue,0,fullScale-1) >> (nBitsFS - nBitsDAC);
  dacWrite(slaveSelectPin,outputValueDAC,(fullScale-1)>>(nBitsFS-nBitsDAC));

  if (startLogging) {
    Serial << unsmoothedSensorValue << " " << smoothedValue << " " << outputValueDAC  << endl; // print the values to the LCD
  }

  int nPrintBits = nBitsDAC+1;  //nBitsADC or nBitsDAC or whatever
  const int update_samps = 510/10;  //update screen at 10 Hz
  if ((firstTime==1) | ((sampleCount % update_samps) == 1)) {
    switch (5) {
    case 4:
      prevDisplayMode = currentDisplayMode;
      if (FS2_val == HIGH) {
        currentDisplayMode = 41;
        if ((redraw_lcd == true) | (firstTime==1) | (prevDisplayMode != currentDisplayMode)) {
          lcd.clear();
          lcd.print(keyName + " " + getScaleName(scale[key_scale_index]));
          redraw_lcd = false;
        }
      } 
      else { 
        currentDisplayMode = 42;
        if ((redraw_lcd == true) | (prevDisplayMode != currentDisplayMode)) {
          lcd.clear(); 
          lcd.print("FS2 Is Pressed"); 
          redraw_lcd = false;
        }
      }
      lcd.setCursor(0,1); 
      lcd.print("In: " + setPitchName + " ");
      lcd.setCursor(8,1);
      lcd.print("Out: " + outPitchName + " "); 
      break;
    case 5:
      int row=0;
      int col=0;
      //if (modeWasChanged) {
      if (getChangeModeCounter()  > 0) {
        lcd.clear();
        drawChangeModeInterface(lcd,row,col,keyName,getScaleName(scale[key_scale_index]),vibratoFac[curVibratoFacIndex],
             glideFac[curGlideFacIndex],deadBandVibratoScaleFac[curDeadBandIndex],useInputSmoothing,curChangeMode);
      } 
      else if (getChangeModeCounter() <= 0) {
        if ((redraw_lcd == true) | (firstTime==1) | (prevDisplayMode != currentDisplayMode)) {
          lcd.clear();
          lcd.print(keyName.substring(0,keyName.length()-1) + " " + getScaleName(scale[key_scale_index]));
        }
        if (redraw_lcd | (rawNoteVal != prevRawNoteVal) | (nHalfSteps != prevQuantNoteValDisplay)) {
          row = 1;
          col=0;
          drawScale(lcd,row,col,scale[key_scale_index],rawNoteVal-key[key_scale_index],nHalfSteps-key[key_scale_index]);
          prevRawNoteVal = rawNoteVal;
          prevQuantNoteValDisplay = nHalfSteps;
          lcd.setCursor(13,1);
          lcd.print("   ");
          lcd.setCursor(13,1);
          lcd.print(outPitchName);
        }
      }
      redraw_lcd = false;
      break;
    }
  }
  firstTime=0;
}

void printDigitsToLCD(LiquidCrystal lcd, int value, int dispDigits,int col, int row) {
  int digits = 0;
  int i=0;
  int foo = 0;

  foo = abs(value);

  if (foo >= 10000) {
    digits = 5;
  } 
  else if (foo >= 1000) {
    digits = 4;
  } 
  else if (foo >= 100) {
    digits = 3;
  } 
  else if (foo >= 10) {
    digits = 2;
  } 
  else if (foo >= 0) {
    digits = 1;
  }
  if (value < 0) digits = digits+1;
  lcd.setCursor(col,row);
  for (i=0;i<dispDigits-digits;i++) {
    lcd.print(' ');
  }
  //lcd.setCursor(col+Ndigits+shift,row);
  lcd.print(value);
}


void changeKey(int change,boolean &changed_state) {
  int nKeys = getNumKeys();

  Serial << "ChangeKey: nKeys = " << nKeys << ", key_scale_index = " << key_scale_index << ", key = " << key[key_scale_index] << endl;


  changed_state = true;
  key[key_scale_index] += change;
  if (key[key_scale_index] < 0) key[key_scale_index]+=nKeys;
  key[key_scale_index] = key[key_scale_index] % nKeys;
  key[(key_scale_index+1)%3] = key[key_scale_index];  // keep all key settings in-sync.  Maybe I won't like this. 
  key[(key_scale_index+2)%3] = key[key_scale_index];  // keep all key settings in-sync.  Maybe I won't like this. 
}

void changeScale(int change,boolean &changed_state) {
  int nScales = getNumScales();
  int foo_index;
  //foo_index = key_scale_index_plus1 -1;
  foo_index = key_scale_index;

  Serial << "changeScale: nScales = " << nScales << ", key_scale_index = " << foo_index << ", Scale = " << scale[foo_index] << endl;

  changed_state = true;
  scale[ foo_index] += change;
  if (scale[ foo_index] < 0) scale[ foo_index]+=nScales;
  scale[ foo_index] = scale[ foo_index] % nScales;
  //scale[(key_scale_index+1)%2] = scale[key_scale_index];  // keep both key settings in-sync.  Maybe I won't like this.
}

void changeVibratoFac(int change) {
  curVibratoFacIndex += change;
  if (curVibratoFacIndex < 0) {
    curVibratoFacIndex += nVibratoFac;
  }
  curVibratoFacIndex = curVibratoFacIndex % nVibratoFac;
}  

void changeGlideFac(int change) {
  curGlideFacIndex += change;
  if (curGlideFacIndex < 0) {
    curGlideFacIndex += nGlideFac;
  }
  curGlideFacIndex = curGlideFacIndex % nGlideFac;
}  

void changeDeadBandFac(int change) {
  curDeadBandIndex += change;
  if (curDeadBandIndex < 0) {
    curDeadBandIndex += nDeadBandFac;
  }
  curDeadBandIndex = curDeadBandIndex % nDeadBandFac;
}  

void changeUseSmooth(int change) {
  useInputSmoothing = !useInputSmoothing;
}









