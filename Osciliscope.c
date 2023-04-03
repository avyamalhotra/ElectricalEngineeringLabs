//  freq_gen.c: Uses timer 2 interrupt to generate a square wave at pin
//  P0.0.  The program allows the user to enter a new frequency.
//  ~C51~

#include <stdio.h>
#include <at89lp51rd2.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>
int neg = 1;

#define CLK 22118400L // SYSCLK frequency in Hz
#define BAUD 115200L // Baud rate of UART in bps
#define BRG_VAL (0x100-(CLK/(16L*BAUD)))
#define ONE_USEC (CLK/1000000L) // Timer reload for one microsecond delay
#define DEFAULT_F 2000L

#define TONEOUT P0_0
#define Button_1 P0_3

#define ADC_CE  P2_0
#define BB_MOSI P2_1
#define BB_MISO P2_2
#define BB_SCLK P2_3

#if (CLK/(16L*BAUD))>0x100
#error Can not set baudrate
#endif
#define BRG_VAL (0x100-(CLK/(16L*BAUD)))
#define LCD_RS P3_2
// #define LCD_RW PX_X // Not used in this code, connect the pin to GND
#define LCD_E  P3_3
#define LCD_D4 P3_4
#define LCD_D5 P3_5
#define LCD_D6 P3_6
#define LCD_D7 P3_7
#define CHARS_PER_LINE 16

char c[CHARS_PER_LINE+1];

unsigned char SPIWrite(unsigned char out_byte)
{
// In the 8051 architecture both ACC and B are bit addressable!
ACC=out_byte;

BB_MOSI=ACC_7; BB_SCLK=1; B_7=BB_MISO; BB_SCLK=0;
BB_MOSI=ACC_6; BB_SCLK=1; B_6=BB_MISO; BB_SCLK=0;
BB_MOSI=ACC_5; BB_SCLK=1; B_5=BB_MISO; BB_SCLK=0;
BB_MOSI=ACC_4; BB_SCLK=1; B_4=BB_MISO; BB_SCLK=0;
BB_MOSI=ACC_3; BB_SCLK=1; B_3=BB_MISO; BB_SCLK=0;
BB_MOSI=ACC_2; BB_SCLK=1; B_2=BB_MISO; BB_SCLK=0;
BB_MOSI=ACC_1; BB_SCLK=1; B_1=BB_MISO; BB_SCLK=0;
BB_MOSI=ACC_0; BB_SCLK=1; B_0=BB_MISO; BB_SCLK=0;

return B;
}



void wait_us (unsigned char x)
{
unsigned int j;

TR0=0; // Stop timer 0
TMOD&=0xf0; // Clear the configuration bits for timer 0
TMOD|=0x01; // Mode 1: 16-bit timer

if(x>5) x-=5; // Subtract the overhead
else x=1;

j=-ONE_USEC*x;
TF0=0;
TH0=j/0x100;
TL0=j%0x100;
TR0=1; // Start timer 0
while(TF0==0); //Wait for overflow
}

void waitms (unsigned int ms)
{
unsigned int j;
unsigned char k;
for(j=0; j<ms; j++)
for (k=0; k<4; k++) wait_us(250);
}

void LCD_pulse (void)
{
LCD_E=1;
wait_us(40);
LCD_E=0;
}

void LCD_byte (unsigned char x)
{
// The accumulator in the 8051 is bit addressable!
ACC=x; //Send high nible
LCD_D7=ACC_7;
LCD_D6=ACC_6;
LCD_D5=ACC_5;
LCD_D4=ACC_4;
LCD_pulse();
wait_us(40);
ACC=x; //Send low nible
LCD_D7=ACC_3;
LCD_D6=ACC_2;
LCD_D5=ACC_1;
LCD_D4=ACC_0;
LCD_pulse();
}


void WriteCommand (unsigned char x)
{
LCD_RS=0;
LCD_byte(x);
waitms(5);
}

unsigned char _c51_external_startup(void)
{
AUXR=0B_0001_0001; // 1152 bytes of internal XDATA, P4.4 is a general purpose I/O

// Configure all pins as bidirectional
P0M0=0x00; P0M1=0x00;    
P1M0=0x00; P1M1=0x00;    
P2M0=0x00; P2M1=0x00;    
P3M0=0x00; P3M1=0x00;
   
    // Initialize the pins used for SPI
ADC_CE=0;  // Disable SPI access to MCP3008
BB_SCLK=0; // Resting state of SPI clock is '0'
BB_MISO=1; // Write '1' to MISO before using as input

// Configure the serial port and baud rate
    PCON|=0x80;
SCON = 0x52;
    BDRCON=0;
    #if (CLK/(16L*BAUD))>0x100
    #error Can not set baudrate
    #endif
    BRL=BRG_VAL;
    BDRCON=BRR|TBCK|RBCK|SPD;
   
CLKREG=0x00; // TPS=0000B

    PCON|=0x80;
SCON = 0x52;
    BDRCON=0;
#if ((CLK/(16L*BAUD))>0x100L)
#error "Can not set baud rate because (CLK/(16*BAUD)) > 0x100 "
#endif
    BRL=BRG_VAL;
    BDRCON=BRR|TBCK|RBCK|SPD;

// Initialize timer 2 for periodic interrupts
T2CON=0x00;   // Stop Timer2; Clear TF2;
RCAP2H=(0x10000L-(CLK/(2*DEFAULT_F)))/0x100; // Change reload value for new frequency high
RCAP2L=(0x10000L-(CLK/(2*DEFAULT_F)))%0x100; // Change reload value for new frequency low
TH2=0xff; // Set to reload immediately
TL2=0xff; // Set to reload immediately
ET2=1; // Enable Timer2 interrupts
TR2=1; // Start Timer2
EA=1; // Global interrupt enable

    return 0;
}

void LCD_4BIT (void)
{
LCD_E=0; // Resting state of LCD's enable is zero
//LCD_RW=0; // We are only writing to the LCD in this program
waitms(20);
// First make sure the LCD is in 8-bit mode and then change to 4-bit mode
WriteCommand(0x33);
WriteCommand(0x33);
WriteCommand(0x32); // Change to 4-bit mode
// Configure the LCD
WriteCommand(0x28);
WriteCommand(0x0c);
WriteCommand(0x01); // Clear screen command (takes some time)
waitms(20); // Wait for clear screen command to finsih.
}



/*Read 10 bits from the MCP3008 ADC converter*/
unsigned int volatile GetADC(unsigned char channel)
{
unsigned int adc;
unsigned char spid;

ADC_CE=0; // Activate the MCP3008 ADC.

SPIWrite(0x01);// Send the start bit.
spid=SPIWrite((channel*0x10)|0x80); //Send single/diff* bit, D2, D1, and D0 bits.
adc=((spid & 0x03)*0x100);// spid has the two most significant bits of the result.
spid=SPIWrite(0x00);// It doesn't matter what we send now.
adc+=spid;// spid contains the low part of the result.

ADC_CE=1; // Deactivate the MCP3008 ADC.

return adc;
}

#define VREF 4.096



void WriteData (unsigned char x)
{
LCD_RS=1;
LCD_byte(x);
waitms(2);
}



void LCDprint(char * string, unsigned char line, bit clear)
{
int j;
WriteCommand(line==2?0xc0:0x80);
waitms(5);
for(j=0; string[j]!=0; j++) WriteData(string[j]);// Write the message
if(clear) for(; j<CHARS_PER_LINE; j++) WriteData(' '); // Clear the rest of the line
}

char bufferval[16];
char bufferval2[16];

//float find_v (float quarter_period_channel){
float find_v (float channel){
 float peak_v=0;
 
 float voltmax = 0;
 TR0=0;
TMOD&=0xf0; // Clear the configuration bits for timer 0
TMOD|=0x01; // Mode 1: 16-bit timer
// Measure half period at ADC CH0 using timer 0
TF0=0; // Clear overflow flag
TL0=0; // Reset the timer
TH0=0;
 
  while (voltmax <= peak_v ){
  peak_v = ((GetADC(channel)*VREF)/1023);
  if (peak_v > voltmax)
  voltmax = peak_v;
 
}

return voltmax * 0.707107;
}


float find_p(float half_period_channel_1)
{
float phase;
int OVcnt;
TR0=0;
TMOD&=0xf0; // Clear the configuration bits for timer 0
TMOD|=0x01; // Mode 1: 16-bit timer
// Measure half period at ADC CH0 using timer 0
TF0=0; // Clear overflow flag
TL0=0; // Reset the timer
TH0=0;
OVcnt=0;

while (GetADC(0)>2); // Wait for the signal to be zero
while (GetADC(0)<4); // Wait for the signal to be one

if (GetADC(1)>2){
TR0=1;
while (GetADC(1)!=0)  // Wait for the signal to be zero
{
if (TF0)
{
TF0=0;
OVcnt++;
}
}
neg=0;
}
else{
while (GetADC(1)>2); // Wait for the signal to be zero
while (GetADC(1)<4);
TR0=1;
while (GetADC(0)>2)  // Wait for the signal to be zero
{
if (TF0)
{
TF0=0;
OVcnt++;
}
}
neg = 1;
}


TR0=0;

phase =OVcnt*65536.0+TH0*256.0+TL0;
phase = phase/22118400.0;
phase = phase*(360.0/(2.0*half_period_channel_1));
phase = phase-180.0;
if (phase<0){
phase = phase*-1;}
if (phase ==0){
neg =0;
}
return phase;
}


void main (void)
{
float peak_voltage_1;
float peak_voltage_2;
float half_period_channel_1;
float freq;
int OVcnt;
float amp;
float period;
float half_period_ms;
float phasediff;
char ch=223;
waitms(500); // Gives time to putty to start before sending text

// Configure the LCD
LCD_4BIT();
peak_voltage_1 = find_v(0);
peak_voltage_2 = find_v(1);

while(1){
TR0=0;
TMOD&=0xf0; // Clear the configuration bits for timer 0
TMOD|=0x01; // Mode 1: 16-bit timer
// Measure half period at ADC CH0 using timer 0
TF0=0; // Clear overflow flag
TL0=0; // Reset the timer
TH0=0;
OVcnt=0;
while (GetADC(0)>2); // Wait for the signal to be zero
while (GetADC(0)<4); // Wait for the signal to be one
TR0=1; // Start timing
while (GetADC(0)>2) // Wait for the signal to be zero
{
if (TF0)
{
TF0=0;
OVcnt++;
}
}
TR0=0; // Stop timer 0
half_period_channel_1=OVcnt*65536.0+TH0*256.0+TL0; // half_period is “float

half_period_channel_1=half_period_channel_1/22118400.0;
half_period_ms = half_period_channel_1 * 1000.0;
freq= (1/(2*half_period_channel_1));

//while (voltmax <= peak_voltage_1 ){
//peak_voltage_1= ((GetADC(0)*VREF)/1023);
//if (peak_voltage_1 >voltmax)
//voltmax = peak_voltage_1;
//}

phasediff = find_p(half_period_channel_1);


sprintf(bufferval, "CH1: %.2fV %.0f hz", peak_voltage_1,freq);

if (neg == 1){
sprintf(bufferval2, "CH2: %.2fV %.0f%c", peak_voltage_2, phasediff, ch);}
else {
sprintf(bufferval2, "CH2: %.2fV -%.0f%c", peak_voltage_2, phasediff, ch);
}
amp = peak_voltage_2/0.707107;
period = (half_period_channel_1*2);

while (Button_1 != 1){
sprintf(bufferval, "sin function is");
sprintf(bufferval2, "%.1fsin(%.2f(x-p))",amp,period);
LCDprint(bufferval, 1, 1);
LCDprint(bufferval2, 2, 1);
}


LCDprint(bufferval, 1, 1);
LCDprint(bufferval2, 2, 1);

}}