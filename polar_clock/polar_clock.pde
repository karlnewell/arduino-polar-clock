//include arduino wire api for I2C communications
#include <Wire.h>

//constants related to DS1307 rtc chip communications (copy'd and paste'd, may need cleanup)
#define DS1307_SEC 0
#define DS1307_MIN 1
#define DS1307_HR 2
#define DS1307_DOW 3
#define DS1307_DATE 4
#define DS1307_MTH 5
#define DS1307_YR 6
#define DS1307_CTRLREG 7

#define DS1307_CTRL_ID B1101000

 // Define register bit masks	
#define DS1307_CLOCKHALT B10000000
 
#define DS1307_LO_BCD	B00001111
#define DS1307_HI_BCD	B11110000

#define DS1307_HI_SEC	B01110000
#define DS1307_HI_MIN	B01110000
#define DS1307_HI_HR	 B00110000
#define DS1307_LO_DOW	B00000111
#define DS1307_HI_DATE B00110000
#define DS1307_HI_MTH	B00110000
#define DS1307_HI_YR	 B11110000

#define DS1307_SQWOFF0 B00000000
#define DS1307_SQWOFF1 B10000000
#define DS1307_1HZ		 B10010000
#define DS1307_4KHZ		B10010001
#define DS1307_8KHZ		B10010010
#define DS1307_32KHZ	 B10010011

#define DS1307_DATASTART 0x08

#define DS1307_I2C_ADDRESS 0x68
//the digital pin on which we will receive the square-wave input
//should be set to 2 or 3 as those are the pins that the arduino can catch interrupts on
#define ISRPIN 2

//the analog output pins through which we will communicate with the shift registers controlling the seconds LEDs
#define SECONDS_SER_PIN 8
#define SECONDS_RCLK_PIN 9
#define SECONDS_SRCLK_PIN 10

//How many of the shift registers are chained together in the seconds circuit
#define SECONDS_NUM_REGS 2 
//number of seconds pins which are actually wired up to LEDs
#define SECONDS_NUM_LEDS 16
//the frequency of the interrupt which will be generated from the square-wave output of the DS1307
//changing this value does not change the frequency of the square-wave input! (see setup())
#define TICK_RATE 4000

//total number of pins which we need to set on or off
byte seconds_num_pins = SECONDS_NUM_REGS * 8;

//define data structures to keep track of pin settings
byte seconds_registers[SECONDS_NUM_REGS];
//an integer indicating how far into the seconds register chain we are (see read_clock() and increment_time())
byte seconds_current_reg = 0;
//a bit-mask indicating which pin on the current seconds register will be the next to be lit up (see read_clock() and increment_time())
byte seconds_current_pin = 0;
//zero seconds is a special case where we allow all the LEDs to be off for one cycle. use this var to keep track of that case
boolean at_zero_seconds = false;
//calculate the number of LEDs to be lit every second (will be non-integer when number of LEDs is not divisible by 60!)
float leds_per_second = (SECONDS_NUM_LEDS + 1) / 60.0;
//keep track of the number of second LEDs list so we don't exceed the limit of SECONDS_NUM_LEDS
byte seconds_num_leds_lit = 0;

//keep track of the number of interrupts we've received from the square-wave input (rolls over to zero when ticks_per_update is reached)
unsigned int ticks = 0;
//calculate number of ticks before the seconds display updates, round to nearest integer
unsigned int ticks_per_update = TICK_RATE / leds_per_second + 0.5;

//vars to store the time as it's read from the rtc
byte second, minute, hour, day_of_week, day_of_month, month, year = 0;

//this will be set to true each time the square wave output voltage rises (see tick())
volatile boolean clock_ticked = false;

//set all registers to LOW
void clear_registers() {
	clear_second_registers();
}

//set seconds registers to LOW
void clear_second_registers() {
	for (byte i = 0; i < SECONDS_NUM_REGS; i++) {
		seconds_registers[i] = B00000000;
	}
} 

//write to all registers
void write_registers() {
	write_seconds_registers();
}

//write to seconds registers
void write_seconds_registers() {
	digitalWrite(SECONDS_RCLK_PIN, LOW);
	for(int i = SECONDS_NUM_REGS - 1; i >= 0; i--){
		byte mask = B00000001;
		for (byte j = 0; j < 8; j++) {
			digitalWrite(SECONDS_SRCLK_PIN, LOW);
			digitalWrite(SECONDS_SER_PIN, seconds_registers[i] & mask ? HIGH : LOW);
			digitalWrite(SECONDS_SRCLK_PIN, HIGH);
			mask = mask << 1;
		} 
	}
	digitalWrite(SECONDS_RCLK_PIN, HIGH);
}

// Convert normal decimal numbers to binary coded decimal
byte dec_to_bcd(byte val) {
	return ( (val/10*16) + (val%10) );
}

// Convert binary coded decimal to normal decimal numbers
byte bcd_to_dec(byte val) {
	return ( (val/16*10) + (val%16) );
}

void set_date_ds1307(byte second, byte minute, byte hour, byte day_of_week, byte day_of_month, byte month, byte year) {
	Wire.beginTransmission(DS1307_I2C_ADDRESS);
	Wire.send(0);
	Wire.send(dec_to_bcd(second)); // 0 to bit 7 starts the clock
	Wire.send(dec_to_bcd(minute));
	Wire.send(dec_to_bcd(hour));		 
	Wire.send(dec_to_bcd(day_of_week));
	Wire.send(dec_to_bcd(day_of_month));
	Wire.send(dec_to_bcd(month));
	Wire.send(dec_to_bcd(year));
	Wire.send(00010000); // sends 0x10 (hex) 00010000 (binary) to control register - turns on square wave
	Wire.endTransmission();
}

// Gets the date and time from the ds1307; reads into global second, minute, etc. vars
void get_date_ds1307() {
	// Reset the register pointer
	Wire.beginTransmission(DS1307_I2C_ADDRESS);
	Wire.send(0);
	Wire.endTransmission();

	Wire.requestFrom(DS1307_I2C_ADDRESS, 7);

	// A few of these need masks because certain bits are control bits
	//TODO change masks to use constants #define'd at top
	second = bcd_to_dec(Wire.receive() & 0x7f);
	minute = bcd_to_dec(Wire.receive());
	hour = bcd_to_dec(Wire.receive() & 0x3f);
	day_of_week = bcd_to_dec(Wire.receive());
	day_of_month = bcd_to_dec(Wire.receive());
	month = bcd_to_dec(Wire.receive());
	year = bcd_to_dec(Wire.receive());
}

byte get_single_register(byte reg) {
	// use the Wire lib to connect to tho rtc
	// reset the register pointer to zero
	Wire.beginTransmission(DS1307_CTRL_ID);
	Wire.send(reg);
	Wire.endTransmission();

	Wire.requestFrom(DS1307_CTRL_ID, 1);
	byte val = Wire.receive();
	return val;
}

void set_single_register(byte reg, byte b) {
	Wire.beginTransmission(DS1307_CTRL_ID);
    Wire.send(reg);
    Wire.send(b);
    Wire.endTransmission();  
}

void tick() {
	clock_ticked = true;
}

/*
TODO
- cascading updates to time variables: every x seconds, update minutes; every y minutes update hours, etc. (only keep track of seconds at 4kHz resolution)
*/
void increment_display() {
	//increment seconds
	if (seconds_current_pin == 0 || seconds_num_leds_lit == SECONDS_NUM_LEDS) {
		seconds_current_reg++;
		seconds_current_pin = B10000000;

		if (seconds_current_reg == SECONDS_NUM_REGS || seconds_num_leds_lit == SECONDS_NUM_LEDS) {
			clear_second_registers();
			seconds_current_reg = 0;
			seconds_num_leds_lit = 0;
		}
		else {
			seconds_registers[seconds_current_reg] = seconds_registers[seconds_current_reg] | seconds_current_pin;
			seconds_current_pin = seconds_current_pin >> 1;
			seconds_num_leds_lit++;
		}
	}
	else {
		seconds_registers[seconds_current_reg] = seconds_registers[seconds_current_reg] | seconds_current_pin;
		seconds_current_pin = seconds_current_pin >> 1;
		seconds_num_leds_lit++;
	}
	write_registers();
}

void read_clock() {
	get_date_ds1307();

	//load the time information into the local data structures
	//calculate the number of seconds LEDs that should be on
	//by adding 0.5, we are effectively rounding seconds_num_leds_lit to nearest integer instead of just truncating
	//TODO investigate the error in this calculation as the number of LEDs is scaled up (floats are only accurate to ~6 digits on arduino)
	seconds_num_leds_lit = leds_per_second * second + 0.5;
	if (seconds_num_leds_lit == 0)
		at_zero_seconds = true;

	seconds_current_reg = seconds_num_leds_lit / 8;
	byte i, j;
	for (i = 0; i < SECONDS_NUM_REGS; i++) {
		if (i < seconds_current_reg)
			seconds_registers[i] = B11111111;
		else
			seconds_registers[i] = B00000000;
	}
	seconds_current_pin = B10000000;
	for (j = 0; j < (seconds_num_leds_lit % 8); j++) {
		seconds_registers[seconds_current_reg] = seconds_registers[seconds_current_reg] | seconds_current_pin;
		seconds_current_pin = seconds_current_pin >> 1;
	}

	//write dat shit
	write_registers();
}

void setup() {
	Wire.begin();
	Serial.begin(9600);

	//setup shift register output pins
	pinMode(SECONDS_SER_PIN, OUTPUT);
	pinMode(SECONDS_RCLK_PIN, OUTPUT);
	pinMode(SECONDS_SRCLK_PIN, OUTPUT);

	//read the time off of the rtc chip and into our local data structures
	read_clock();

	//initialize the 4kHz square-wave output from the DS1307
	pinMode(ISRPIN, INPUT);
	// pull-up ISRPIN (see DS1307 datasheet)
	digitalWrite(ISRPIN, HIGH); 
	// set external interrupt for 4kHz interruption
	attachInterrupt(ISRPIN - 2, tick, RISING);
	//set ctrl register for 4kHz output
	byte secs = get_single_register(DS1307_HI_SEC);
	set_single_register(DS1307_HI_SEC, secs | DS1307_CLOCKHALT);
	set_single_register(DS1307_CTRLREG, DS1307_4KHZ);	
	set_single_register(DS1307_HI_SEC, secs);
}

void loop() {
	if (!clock_ticked)
		return;
	clock_ticked = false;
	ticks = (ticks + 1) % ticks_per_update;
	if (ticks == 0)
		increment_display();
}
