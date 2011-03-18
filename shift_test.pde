int SER_Pin = 8;   //pin 15 on the 75HC595
int RCLK_Pin = 9;  //pin 12 on the 75HC595
int SRCLK_Pin = 10; //pin 10 on the 75HC595

//How many of the shift registers - change this
#define num_regs 1 

//do not touch
#define num_leds num_regs * 8

//int registers[num_leds];
byte registers[num_regs];
byte *reg_ptr = registers;
byte current_reg = 0;
byte current_pin = B00000001;

void setup(){
  pinMode(SER_Pin, OUTPUT);
  pinMode(RCLK_Pin, OUTPUT);
  pinMode(SRCLK_Pin, OUTPUT);

  //Turn all pins off
  clear_registers();
  write_registers();
}               

//set all registers to LOW
void clear_registers(){
  for (byte i = 0; i < num_regs; i++) {
    *(reg_ptr + i) = B00000000;
  }
} 

//Set and display registers
//Only call AFTER all values are set how you would like (slow otherwise)
void write_registers(){
  digitalWrite(RCLK_Pin, LOW);
  byte mask = B00000001;
  for(byte i = 0; i < num_regs; i++){
    for (byte j = 0; j < 8; j++) {
      digitalWrite(SRCLK_Pin, LOW);
      digitalWrite(SER_Pin, registers[i] & mask ? HIGH : LOW);
      digitalWrite(SRCLK_Pin, HIGH);
      mask = mask << 1;
    } 

  }
  digitalWrite(RCLK_Pin, HIGH);
}

void loop(){
  registers[current_reg] = registers[current_reg] | current_pin;
  write_registers();
  delay(1000);
  
  current_pin = current_pin << 1;
  if (current_pin == B00000000) {
    current_pin = B00000001;
    current_reg++;
  }
  if (current_reg >= num_regs) {
    clear_registers();
    current_reg = 0;
  }
}
