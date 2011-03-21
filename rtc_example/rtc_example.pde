/*
 Example 7.3
 reading and writing to the Maxim DS1307 real time clock IC
 tronixstuff.com/tutorials
 based on code by Maurice Ribble
 17-4-2008 - http://www.glacialwanderer.com/hobbyrobotics
 
 */

#include "Wire.h"
#define DS1307_I2C_ADDRESS 0x68

// Convert normal decimal numbers to binary coded decimal
byte decToBcd(byte val)
{
  return ( (val/10*16) + (val%10) );
}

// Convert binary coded decimal to normal decimal numbers
byte bcdToDec(byte val)
{
  return ( (val/16*10) + (val%16) );
}

// 1) Sets the date and time on the ds1307
// 2) Starts the clock
// 3) Sets hour mode to 24 hour clock

// Assumes you're passing in valid numbers

void setDateDs1307(byte second,        // 0-59
byte minute,        // 0-59
byte hour,          // 1-23
byte dayOfWeek,     // 1-7
byte dayOfMonth,    // 1-28/29/30/31
byte month,         // 1-12
byte year)          // 0-99
{
  Wire.beginTransmission(DS1307_I2C_ADDRESS);
  Wire.send(0);
  Wire.send(decToBcd(second));    // 0 to bit 7 starts the clock
  Wire.send(decToBcd(minute));
  Wire.send(decToBcd(hour));     
  Wire.send(decToBcd(dayOfWeek));
  Wire.send(decToBcd(dayOfMonth));
  Wire.send(decToBcd(month));
  Wire.send(decToBcd(year));
  Wire.send(00010000); // sends 0x10 (hex) 00010000 (binary) to control register - turns on square wave
  Wire.endTransmission();
}

// Gets the date and time from the ds1307
void getDateDs1307(byte *second,
byte *minute,
byte *hour,
byte *dayOfWeek,
byte *dayOfMonth,
byte *month,
byte *year)
{
  // Reset the register pointer
  Wire.beginTransmission(DS1307_I2C_ADDRESS);
  Wire.send(0);
  Wire.endTransmission();

  Wire.requestFrom(DS1307_I2C_ADDRESS, 7);

  // A few of these need masks because certain bits are control bits
  *second     = bcdToDec(Wire.receive() & 0x7f);
  *minute     = bcdToDec(Wire.receive());
  *hour       = bcdToDec(Wire.receive() & 0x3f);  // Need to change this if 12 hour am/pm
  *dayOfWeek  = bcdToDec(Wire.receive());
  *dayOfMonth = bcdToDec(Wire.receive());
  *month      = bcdToDec(Wire.receive());
  *year       = bcdToDec(Wire.receive());
}

void setup()
{
  byte second, minute, hour, dayOfWeek, dayOfMonth, month, year;
  Wire.begin();
  Serial.begin(9600);

  // Change these values to what you want to set your clock to.
  // You probably only want to set your clock once and then remove
  // the setDateDs1307 call.

  second = 0;
  minute = 54;
  hour = 14;
  dayOfWeek = 4;
  dayOfMonth = 9;
  month = 5;
  year = 10;
setDateDs1307(second, minute, hour, dayOfWeek, dayOfMonth, month, year);
}

void loop()
{
  byte second, minute, hour, dayOfWeek, dayOfMonth, month, year;

  getDateDs1307(&second, &minute, &hour, &dayOfWeek, &dayOfMonth, &month, &year);
  Serial.print(hour, DEC);// convert the byte variable to a decimal number when being displayed
  Serial.print(":");
  if (minute<10)
  {
      Serial.print("0");
  }
  Serial.print(minute, DEC);
  Serial.print(":");
  if (second<10)
  {
      Serial.print("0");
  }
  Serial.print(second, DEC);
  Serial.print("  ");
  Serial.print(dayOfMonth, DEC);
  Serial.print("/");
  Serial.print(month, DEC);
  Serial.print("/");
  Serial.print(year, DEC);
  Serial.print("  Day of week:");
  switch(dayOfWeek){
  case 1: 
    Serial.println("Sunday");
    break;
  case 2: 
    Serial.println("Monday");
    break;
  case 3: 
    Serial.println("Tuesday");
    break;
  case 4: 
    Serial.println("Wednesday");
    break;
  case 5: 
    Serial.println("Thursday");
    break;
  case 6: 
    Serial.println("Friday");
    break;
  case 7: 
    Serial.println("Saturday");
    break;
  }
  //  Serial.println(dayOfWeek, DEC);
  delay(1000);
}


