$NOLIST
$MODLP51
$LIST

org 0000H
   ljmp MyProgram
   
; Timer/Counter 2 overflow interrupt vector
org 0x002B
	ljmp Timer2_ISR

; These register definitions needed by 'math32.inc'
DSEG at 30H
x:   ds 4
y:   ds 4
bcd: ds 5
T2ov: ds 2 ; 16-bit timer 2 overflow (to measure the period of very slow signals)

BSEG
mf: dbit 1

$NOLIST
$include(math32.inc)
$LIST


button1 equ p2.0
button2 equ p2.1
button3 equ p0.5
button4 equ p0.2
button5 equ p0.1
button6 equ p4.5
cseg
; These 'equ' must match the hardware wiring
LCD_RS equ P3.2
;LCD_RW equ PX.X ; Not used in this code, connect the pin to GND
LCD_E  equ P3.3
LCD_D4 equ P3.4
LCD_D5 equ P3.5
LCD_D6 equ P3.6
LCD_D7 equ P3.7

$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$LIST

;                     1234567890123456    <- This helps determine the location of the counter
Initial_Message:  db 'Capacitance (nF):   ', 0
No_Signal_Str:    db 'No signal      ', 0
percent:    db '%', 0
message:    db 'ERR', 0

; Sends 10-digit BCD number in bcd to the LCD
Display_10_digit_BCD:
	Display_BCD(bcd+4)
	Display_BCD(bcd+3)
	Display_BCD(bcd+2)
	Display_BCD(bcd+1)
	Display_BCD(bcd+0)
	ret

;Initializes timer/counter 2 as a 16-bit timer
InitTimer2:
	mov T2CON, #0 ; Stop timer/counter.  Set as timer (clock input is pin 22.1184MHz).
	; Set the reload value on overflow to zero (just in case is not zero)
	mov RCAP2H, #0
	mov RCAP2L, #0
	setb ET2
    ret

Timer2_ISR:
	clr TF2  ; Timer 2 doesn't clear TF2 automatically. Do it in ISR
	push acc
	inc T2ov+0
	mov a, T2ov+0
	jnz Timer2_ISR_done
	inc T2ov+1
Timer2_ISR_done:
	pop acc
	reti

;---------------------------------;
; Hardware initialization         ;
;---------------------------------;
Initialize_All:
    lcall InitTimer2
    lcall LCD_4BIT ; Initialize LCD
    setb EA
	ret

;---------------------------------;
; Main program loop               ;
;---------------------------------;
MyProgram:
    ; Initialize the hardware:
    mov SP, #7FH
    lcall Initialize_All
    setb P0.0 ; Pin is used as input

	Set_Cursor(1, 1)
    Send_Constant_String(#Initial_Message)
    
forever:
    ; synchronize with rising edge of the signal applied to pin P0.0
    clr TR2 ; Stop timer 2
    mov TL2, #0
    mov TH2, #0
    mov T2ov+0, #0
    mov T2ov+1, #0
    clr TF2
    setb TR2
synch1:
	mov a, T2ov+1
	anl a, #0xfe
	jnz no_signal ; If the count is larger than 0x01ffffffff*45ns=1.16s, we assume there is no signal
    jb P0.0, synch1
synch2:    
	mov a, T2ov+1
	anl a, #0xfe
	jnz no_signal
    jnb P0.0, synch2
    
    ; Measure the period of the signal applied to pin P0.0
    clr TR2
    mov TL2, #0
    mov TH2, #0
    mov T2ov+0, #0
    mov T2ov+1, #0
    clr TF2
    setb TR2 ; Start timer 2
measure1:
	mov a, T2ov+1
	anl a, #0xfe
	jnz no_signal 
    jb P0.0, measure1
measure2:    
	mov a, T2ov+1
	anl a, #0xfe
	jnz no_signal
    jnb P0.0, measure2
    clr TR2 ; Stop timer 2, [T2ov+1, T2ov+0, TH2, TL2] * 45.21123ns is the period

	sjmp skip_this
no_signal:	
	Set_Cursor(2, 1)
    Send_Constant_String(#No_Signal_Str)
    ljmp forever ; Repeat! 
skip_this:

	; Make sure [T2ov+1, T2ov+2, TH2, TL2]!=0
	mov a, TL2
	orl a, TH2
	orl a, T2ov+0
	orl a, T2ov+1
	jz no_signal
	; Using integer math, convert the period to frequency:
	mov x+0, TL2
	mov x+1, TH2
	mov x+2, T2ov+0
	mov x+3, T2ov+1
	Load_y(45) ; One clock pulse is 1/22.1184MHz=45.21123ns
	lcall mul32

	Load_y(100)
	lcall div32

	Load_y(144)
	lcall mul32
	
	Load_y(100)
	lcall div32
	
	Load_y(1020)
	lcall div32

	Load_y(100)
	lcall mul32
	
	Set_Cursor(2, 1)
	lcall hex2bcd
	lcall Display_10_digit_BCD
	
	one:
;	jb button1,two
;	Wait_Milli_Seconds(#50)	
;	jb button1, two  
	jnb button1, buttononecode
	
	two:
;	jb button2,three
;	Wait_Milli_Seconds(#50)	
;	jb button2,three  
	jnb button2, jump2
	
	three:
;	jb button3,four 
;	Wait_Milli_Seconds(#50)	
;	jb button3, four  
	jnb button3, jump3
	
	four:
;	jb button4,five 
;	Wait_Milli_Seconds(#50)	
;	jb button4, five  
	jnb button4, jump4
	
	five:
;	jb button5,six 
;	Wait_Milli_Seconds(#50)	
;	jb button5, six  
	jnb button5, jump5
	
	six:
;	jb button6,jump 
;	Wait_Milli_Seconds(#50)	
;	jb button6, jump  
	jnb button6, jump6
	
	jump2:
	ljmp buttontwocode
	
	jump3:
	ljmp buttonthreecode
	
	jump4:
	ljmp buttonfourcode
	
	jump:
	ljmp cont
	
	jump5:
	ljmp buttonfivecode
	
	jump6:
	ljmp buttonsixcode
	
	buttononecode:
	lcall copy_xy
	load_x(100)	
	lcall sub32
	
	load_y(100)
	lcall mul32
	
	load_y(100)
	lcall div32
	
	Set_Cursor(2,13)
	lcall hex2bcd
	Display_BCD(BCD)
	Set_Cursor(2,15)
	Send_Constant_String(#percent)
	Wait_Milli_Seconds(#100)
	ljmp cont
	
	buttontwocode:
	lcall copy_xy
	load_x(10000)	
	lcall sub32
	
	load_y(100)
	lcall mul32
	
	load_y(10000)
	lcall div32
	
	Set_Cursor(2,13)
	lcall hex2bcd
	Display_BCD(BCD)
	Set_Cursor(2,15)
	Send_Constant_String(#percent)
	Wait_Milli_Seconds(#100)
	ljmp cont
	
	
	buttonthreecode:
	lcall copy_xy
	load_x(100000)	
	lcall sub32
	
	load_y(100)
	lcall mul32
	
	load_y(100000)
	lcall div32
	
	Set_Cursor(2,13)
	lcall hex2bcd
	Display_BCD(BCD)
	Set_Cursor(2,15)
	Send_Constant_String(#percent)
	Wait_Milli_Seconds(#100)
	ljmp cont
	
	
	buttonfourcode:
	lcall copy_xy
	load_x(220000)	
	lcall sub32
	
	load_y(100)
	lcall mul32
	
	load_y(220000)
	lcall div32
	
	Set_Cursor(2,13)
	lcall hex2bcd
	Display_BCD(BCD)
	Set_Cursor(2,15)
	Send_Constant_String(#percent)
	Wait_Milli_Seconds(#100)
	ljmp cont
	
	
	buttonfivecode:
	lcall copy_xy
	load_x(1000000)	
	lcall sub32
	
	load_y(100)
	lcall mul32
	
	load_y(1000000)
	lcall div32
	
	Set_Cursor(2,13)
	lcall hex2bcd
	Display_BCD(BCD)
	Set_Cursor(2,15)
	Send_Constant_String(#percent)
	Wait_Milli_Seconds(#100)
	ljmp cont
	
	buttonsixcode:
	Set_Cursor(2,13)
	Send_Constant_String(#message)

	ljmp cont
	
	
	cont:

    ljmp forever ; Repeat! 
    

end



;jump:
;sjmp no_signal

; continue:
	
;	Load_y(3000)
;	lcall mul32
;	Load_y(144)
;	lcall div32
;	Load_y(100)
;	lcall mul32
;	lcall copy_xy
;	Load_x(1000000000)
;	lcall div32


;	Load_y(45) ; One clock pulse is 1/22.1184MHz=45.21123ns
;	lcall mul32
;	Load_y(1000)
;	lcall div32
;	lcall copy_xy
;	Load_x(1000000000)
;	lcall div32
;	Load_y(3000)
;	lcall mul32
;	Load_y(144)
;	lcall div32
;	Load_y(100)
;	lcall mul32
;	lcall copy_xy
;	Load_x(1000000000)
;	lcall div32