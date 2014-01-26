
#define NO_SCALE 0
#define CHROMATIC 1
#define MAJOR 2
#define MINOR 3
#define MAJ_PENT 4
#define MIN_PENT 5
#define PHRYGIAN 6
#define HARM_MIN 7
#define MARIACHI 8

#define n_scales 9
#define n_keys 12

//how many notes per scale...include the octave
#define n_chrom 13
#define n_diatonic 8 
#define n_pent 6

int no_scale_steps[n_chrom]={
  0,1,2,3,4,5,6,7,8,9,10,11,12};
int chrom_steps[n_chrom]={
  0,1,2,3,4,5,6,7,8,9,10,11,12};
int major_steps[n_diatonic] = {
  0, 2, 4, 5, 7, 9, 11, 12};
int minor_steps[n_diatonic] = {
  0, 2, 3, 5, 7, 8, 10, 12};
int major_pent_steps[n_pent] = {
  0,2,4,7,9,12};
int minor_pent_steps[n_pent] = {
  0,3,5,7,10,12};
int phrygian_steps[n_diatonic] = {
  0, 1, 3, 5, 7, 8 ,10, 12};
int harmonic_minor_steps[n_diatonic]={
  0,2,3,5,7,8,11,12};
int mariachi_steps[n_diatonic] = {
  0,1,4,5,7,8,10,12};

//assume 5 volts is full scale
//assume 1 volt per octave (12 notes per octave
//so, center spacing is (fullscale / 5 / 12)
const String all_names[n_keys] = { 
  String("C"),  String("C#"), String("D"),  String("D#"), 
  String("E"),  String("F"),  String("F#"), String("G"), 
  String("G#"), String("A"),  String("A#"), String("B")  };
const char* scale_names[n_scales] = {
  "No Scale","Chromatic", "Major", "Aeolian", "Maj Pent", "Min Pent", "Phrygian", "Harm Min","Mariachi"};

int quantizeValueChromatic(float centerSpacing, int fullScale, int value, int &nHalfSteps, String &name) {
  float f_value = (float)value;  //convert to float
  nHalfSteps = ((int)(f_value / centerSpacing + 0.5));  //the 0.5 makes this a rounding operation

  //get name of the resulting note
  name = String(all_names[nHalfSteps % n_keys]);
  name = name + String((int)(nHalfSteps/n_keys)+1);

  //return the pitch value
  return (int) (centerSpacing * ((float)nHalfSteps));
}

int quantizeValueByKeyScale(float centerSpacing, int fullScale, int value, int key, int scale, String &name) {
  float f_value = (float)value;  //convert to float
  int nHalfSteps = ((int)(f_value / centerSpacing + 0.5));  //the 0.5 makes this a rounding operation
  if (scale >= CHROMATIC) nHalfSteps = quantizeStepByKeyAndScale(nHalfSteps,key,scale);

  //get name of the resulting note
  name = all_names[nHalfSteps % n_keys];
  name = name + String((int)(nHalfSteps/n_keys)+1);

  //return the pitch value
  if (scale > NO_SCALE) {
    return (int) (centerSpacing * ((float)nHalfSteps));
  } else {
    return value;
  }
}

//this function adds a dead band (hysteresis) around the current step to reduce flutter when on boundary of a note
float deadBandFactor = (0.08/12.0);  //scales by octave.  this is the value at 1.0V
int quantizeValueByKeyScale2(float centerSpacing, int fullScale, int value, int key, int scale, const float deadBandVibratoFac, int &nHalfSteps, String &name) {
  float f_value = (float)value;  //convert to float
  float newNHalfSteps = f_value / centerSpacing;  

  //apply deadband and determine what half-step we're on
  float foo = (float)nHalfSteps - newNHalfSteps;
  float thresh = newNHalfSteps*deadBandFactor*deadBandVibratoFac+0.5;
  if (abs(foo) < thresh) { 
    //in the dead-band keep the same value as before
  } 
  else {
    nHalfSteps = (int)(newNHalfSteps+0.5);  //use new value...the 0.5 makes this a rounding operation
  }

  //quantize by scale
  if (scale >= CHROMATIC) nHalfSteps = quantizeStepByKeyAndScale(nHalfSteps,key,scale);

  //get name of the resulting note
  name = all_names[nHalfSteps % n_keys];
  name = name + String((int)(nHalfSteps/n_keys)+1);

  //return the pitch value
  if (scale > NO_SCALE) {
    return (int) (centerSpacing * ((float)nHalfSteps));
  } else {
    return value;
  }
} 

int *cur_scale_steps;
int cur_scale_n_steps;  
int quantizeStepByKeyAndScale(int nHalfSteps, int key, int scale) {

  if (nHalfSteps < key) key = key - n_keys;  //make sure that the next step doesn't go negative
  nHalfSteps = nHalfSteps - key;  //make relative to root of the key
  int octave = nHalfSteps / n_keys;   //how many octaves up
  nHalfSteps = nHalfSteps - octave*n_keys;
  int distance=0;
  int minDistance=nHalfSteps;
  int bestInd=0;

  cur_scale_steps = getScaleSteps(scale,cur_scale_n_steps);

  //step through each scale step
  for (int i=1;i<cur_scale_n_steps;i++) {
    distance = abs(cur_scale_steps[i] - nHalfSteps);
    if (distance <= minDistance) {
      minDistance = distance;
      bestInd = i;
    }
  }

  //define the current step to be the closest fitting 
  //(the logic above should round up in a the case of a tie)
  nHalfSteps = key + octave*n_keys + cur_scale_steps[bestInd];
  return nHalfSteps;
}

String getScaleName(int scale) {
  return String(scale_names[scale]);
}

int* getScaleSteps(int scale, int &n_steps) {
  int* scale_steps;
  switch (scale) {
  case NO_SCALE:
    scale_steps = no_scale_steps;
    n_steps = n_chrom;
    break;
  case CHROMATIC:
    scale_steps = chrom_steps;
    n_steps = n_chrom;
    break;
  case MAJOR:
    scale_steps = major_steps;
    n_steps = n_diatonic;
    break;
  case MINOR:
    scale_steps = minor_steps;
    n_steps = n_diatonic;
    break;
  case MAJ_PENT:
    scale_steps = major_pent_steps;
    n_steps = n_pent;
    break;
  case MIN_PENT:
    scale_steps = minor_pent_steps;
    n_steps = n_pent;
    break;
  case PHRYGIAN:
    scale_steps = phrygian_steps;
    n_steps = n_diatonic;
    break;
  case HARM_MIN:
    scale_steps = harmonic_minor_steps;
    n_steps = n_diatonic;
    break;
  case MARIACHI:
    scale_steps = mariachi_steps;
    n_steps = n_diatonic;
    break;
  default:
    scale_steps = major_steps;
    n_steps = n_diatonic;
    break;
  }
  return scale_steps;
}


int getNumScales() {
  return n_scales;
}

int getNumKeys() {
  return n_keys;
}

