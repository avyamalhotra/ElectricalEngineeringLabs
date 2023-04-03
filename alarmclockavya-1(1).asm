; ISR_example.asm: a) Increments/decrements a BCD variable every half second using
; an ISR for timer 2; b) Generates a 2kHz square wave at pin P1.1 using
; an ISR for timer 0; and c) in the 'main' loop it displays the variable
; incremented/decremented using the ISR for timer 2 on the LCD.  Also resets it to 
; zero if the 'BOOT' pushbutton connected to P4.5 is pressed.
$NOLIST
$MODLP51
$LIST

; There is a couple of typos in MODLP51 in the definition of the timer 0/1 reload
; special function registers (SFRs), so:

CLK           EQU 22118400 ; Microcontroller system crystal frequency in Hz
TIMER0_RATE   EQU 4096     ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD EQU ((65536-(CLK/TIMER0_RATE)))
TIMER2_RATE   EQU 1000     ; 1000Hz, for a timer tick of 1ms
TIMER2_RELOAD EQU ((65536-(CLK/TIMER2_RATE)))

BOOT_BUTTON   equ P4.5
SOUND_OUT     equ P1.1
MINUTE_BUTTON equ P0.2
HOUR_BUTTON   equ p0.5
ALARM_HOURS_BUTTON    equ p2.0
ALARM_MINS_BUTTON      equ p2.1    
ALARM_SNOOZE            equ p0.1
 

; Reset vector
org 0x0000
    ljmp main

; External interrupt 0 vector (not used in this code)
org 0x0003
	reti

; Timer/Counter 0 overflow interrupt vector
;org 0x000B
;	ljmp Timer0_ISR;

; External interrupt 1 vector (not used in this code)
org 0x0013
	reti

; Timer/Counter 1 overflow interrupt vector (not used in this code)
org 0x001B
	reti

; Serial port receive/transmit interrupt vector (not used in this code)
org 0x0023 
	reti
	
; Timer/Counter 2 overflow interrupt vector
org 0x002B
	ljmp Timer2_ISR

; In the 8051 we can define direct access variables starting at location 0x30 up to location 0x7F
dseg at 0x30
Count1ms:     ds 2 ; Used to determine when half second has passed
BCD_SECONDS:   ds 1 ; The BCD counter incrememted in the ISR and displayed in the main loop
BCD_MINUTES:  ds 1 
BCD_HOURS: ds 1 
ALARM_HOURS: ds 1
ALARM_MINS: ds 1
fastflag: ds 1


; In the 8051 we have variables that are 1-bit in size.  We can use the setb, clr, jb, and jnb
; instructions with these variables.  This is how you define a 1-bit variable:
bseg
half_seconds_flag: dbit 1 ; Set to one in the ISR every time 500 ms had passed
sixtyseconds_flag: dbit 1 ; 
sixtyminutes_flag: dbit 1 ; 
AMPMFLAG: dbit 1 ;
TIMESETFLAG:  dbit 1 ;
MODEFLAG: dbit 1
ALARMAMPMFLAG: dbit 1

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
Initial_Message:  db 'TIME :', 0

;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 0                     ;
;---------------------------------;
Timer0_Init:
	mov a, TMOD
	anl a, #0xf0 ; Clear the bits for timer 0
	orl a, #0x01 ; Configure timer 0 as 16-timer
	mov TMOD, a
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
	; Set autoreload value
	mov RH0, #high(TIMER0_RELOAD)
	mov RL0, #low(TIMER0_RELOAD)
	; Enable the timer and interrupts
    setb ET0  ; Enable timer 0 interrupt
    setb TR0  ; Start timer 0
	ret

;---------------------------------;
; ISR for timer 0.  Set to execute;
; every 1/4096Hz to generate a    ;
; 2048 Hz square wave at pin P1.1 ;
;---------------------------------;
Timer0_ISR:
	;clr TF0  ; According to the data sheet this is done for us already.
	;clr TR0 ; Connect speaker to P1.1!
	cpl SOUND_OUT
	cpl TR0
	reti

;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 2                     ;
;---------------------------------;
Timer2_Init:
	mov T2CON, #0 ; Stop timer/counter.  Autoreload mode.
	mov TH2, #high(TIMER2_RELOAD)
	mov TL2, #low(TIMER2_RELOAD)
	; Set the reload value
	mov RCAP2H, #high(TIMER2_RELOAD)
	mov RCAP2L, #low(TIMER2_RELOAD)
	; Init One millisecond interrupt counter.  It is a 16-bit variable made with two 8-bit parts
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	; Enable the timer and interrupts
    setb ET2  ; Enable timer 2 interrupt
    setb TR2  ; Enable timer 2
	ret

;---------------------------------;
; ISR for timer 2                 ;
;---------------------------------;
Timer2_ISR:
	clr TF2  ; Timer 2 doesn't clear TF2 automatically. Do it in ISR
	cpl P1.0 ; To check the interrupt rate with oscilloscope. It must be precisely a 1 ms pulse.
	
	; The two registers used in the ISR must be saved in the stack
	push acc
	push psw
	
	; Increment the 16-bit one mili second counter
	inc Count1ms+0    ; Increment the low 8-bits first
	mov a, Count1ms+0 ; If the low 8-bits overflow, then increment high 8-bits
	jnz Inc_Done
	inc Count1ms+1

Inc_Done:
	; Check if half second has passed
;	checkif:
;	jb HOUR_BUTTON, checkNORMAL  
;	Wait_Milli_Seconds(#50)	
;	jb HOUR_BUTTON, checkNORMAL  
;	jnb HOUR_BUTTON, $
	
;	mov a, fastflag
  ;  cjne a, #0, decre
 ;   add a, #0x01
 ;   mov fastflag, a
;	sjmp decision
	
;	decre:
;	mov a, fastflag
;	add a, #0x99
;	mov fastflag, a
;	sjmp decision
	
;	decision:
;	mov a, fastflag
;	cjne a, #0, checkfast
;	sjmp checknormal
	
;	checkfast:
;	mov a, Count1ms+0
;	cjne a, #low(5), Timer2_ISR_done ; Warning: this instruction changes the carry flag!
;	mov a, Count1ms+1
;	cjne a, #high(5), Timer2_ISR_done

;	sjmp continue
	
;	checkNORMAL:
	mov a, Count1ms+0
	cjne a, #low(1000), Timer2_ISR_done ; Warning: this instruction changes the carry flag!
	mov a, Count1ms+1
	cjne a, #high(1000), Timer2_ISR_done
	
;	sjmp continue
	
;	continue:
	; 500 milliseconds have passed.  Set a flag so the main program knows
	setb half_seconds_flag ; Let the main program know half second had passed
	cpl SOUND_OUT
	;setb AMPMFLAG;
    ; Enable/disable timer/counter 0. This line creates a beep-silence-beep-silence sound.
	; Reset to zero the milli-seconds counter, it is a 16-bit variable
	
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	
;	continue:
	mov a, BCD_SECONDS
	cjne a, #0x59, Timer2_INCSECOND
	mov a, #0
	da a
	mov BCD_SECONDS, a
	sjmp Timer2_ISR_MINUTEDONE
	
	Timer2_INCSECOND:
	
	add a, #0x01
	da a
	mov BCD_SECONDS, a
	sjmp Timer2_ISR_done
	
	Timer2_ISR_MINUTEDONE:
	
    mov a, BCD_MINUTES
	cjne a, #0x59, Timer2_INCMINUTES
	mov a, #0
	da a
	mov BCD_MINUTES, a
    mov a, BCD_HOURS
	sjmp Timer2_ISR_PM
	
	Timer2_ISR_PM:
	cjne	a, 	#0x12, Timer2_ISR_PM12
	mov		a, 	#1
	da		a
	mov		BCD_HOURS, 	a
	sjmp	Timer2_ISR_done
	
	Timer2_ISR_PM12:
	cjne 	a, 	#0x11, Timer2_INCHOURS
	cpl		AMPMFLAG
	mov 	a,	#12
	da		a
	mov 	BCD_HOURS,	a
	sjmp    Timer2_ISR_done
	
	Timer2_INCMINUTES:
	
    add a, #0x01
	da a
	mov BCD_MINUTES, a
	sjmp Timer2_ISR_done
	
	Timer2_INCHOURS:
    add a, #0x01
	da a
	mov BCD_HOURS, a
	sjmp Timer2_ISR_done
	
;Timer2_ISR_decrement:
;	add a, #0x99 ; Adding the 10-complement of -1 is like subtracting 1.
;Timer2_ISR_da:
;	da a ; Decimal adjust instruction.  Check datasheet for more details!
;	mov BCD_SECONDS, a
	
;Timer2_TIMESET:
;	jb BOOT_BUTTON, loop_a  ; if the 'BOOT' button is not pressed skip
;	Wait_Milli_Seconds(#50)	; Debounce delay.  This macro is also in 'LCD_4bit.inc'
;	jb BOOT_BUTTON, loop_a  ; if the 'BOOT' button is not pressed skip
;	jnb BOOT_BUTTON, $


Timer2_ISR_done:

mov a, BCD_MINUTES
cjne a, ALARM_MINS, NOALARM
sjmp check2

check2:
mov a, BCD_HOURS
cjne a, ALARM_HOURS, NOALARM
sjmp check3

check3: ; ampm 1
jb AMPMFLAG,check3b
sjmp check3c

check3b: ; ampm 1 alarmampm 1
jb ALARMAMPMFLAG,boom
sjmp lol

check3c:  ;ampm 0 alarmpm 0
jb ALARMAMPMFLAG, lol
sjmp boom

boom:
;cpl TR0
cpl SOUND_OUT
sjmp lol

lol:
	pop psw
	pop acc
	reti

NOALARM:
sjmp lol

;soundalarm:
;cpl SOUND_OUT
;sjmp Timer2_ISR_done


;---------------------------------;
; Main program. Includes hardware ;
; initialization and 'forever'    ;
; loop.                           ;
;---------------------------------;

Alarm: db 'Alarm:', 0   
main:
	; Initialization
    mov SP, #0x7F
    lcall Timer0_Init
    lcall Timer2_Init
    ; In case you decide to use the pins of P0, configure the port in bidirectional mode:
    mov P0M0, #0
    mov P0M1, #0
    setb EA   ; Enable Global interrupts
    lcall LCD_4BIT
    ; For convenience a few handy macros are included in 'LCD_4bit.inc':
	Set_Cursor(1, 1)
    Send_Constant_String(#Initial_Message)
    setb half_seconds_flag
	mov BCD_SECONDS, #0x55
	mov BCD_MINUTES, #0X00
	mov BCD_HOURS, #0X12
	mov ALARM_HOURS, #0X12
	mov ALARM_MINS, #0X01
	
	; After initialization the program stays in this 'forever' loop
snooze:
    jb ALARM_SNOOZE, loop
	Wait_Milli_Seconds(#50)	
	jb ALARM_SNOOZE, loop  
	jnb ALARM_SNOOZE, $
	
	add a, #0x10
	da a
	mov ALARM_MINS, a
	sjmp loop
	
loop:	
	jb BOOT_BUTTON, loop_2  ; if the 'BOOT' button is not pressed skip
	Wait_Milli_Seconds(#50)	; Debounce delay.  This macro is also in 'LCD_4bit.inc'
	jb BOOT_BUTTON, loop_2  ; if the 'BOOT' button is not pressed skip
	jnb BOOT_BUTTON, $		; Wait for button release.  The '$' means: jump to same instruction.
	; A valid press of the 'BOOT' button has been detected, reset the BCD counter.
	; But first stop timer 2 and reset the milli-seconds counter, to resync everything.
	clr TR2                 ; Stop timer 2
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	; Now clear the BCD counter
	mov BCD_SECONDS, #0x59
	mov BCD_MINUTES, #0X59
	mov BCD_HOURS, #0X1
	setb TR2                ; Start timer 2
	sjmp loopconnect2      ; Display the new value
	
loop_2:

	jb HOUR_BUTTON, loop_3  
	Wait_Milli_Seconds(#50)	
	jb HOUR_BUTTON, loop_3  
	jnb HOUR_BUTTON, $
	
	mov a, BCD_HOURS
	cjne	a, 	#0x12, loopconnect3
	mov		a, 	#1
	da		a
	mov		BCD_HOURS, 	a
	sjmp loopconnect2

loop_3:

	jb MINUTE_BUTTON, loop_4  
	Wait_Milli_Seconds(#50)	
	jb MINUTE_BUTTON, loop_4  
	jnb MINUTE_BUTTON, $
	
	mov a, BCD_MINUTES	
	cjne	a, 	#0x59, minute
	mov		a, 	#0
	da		a
	mov		BCD_MINUTES, 	a
	
	sjmp loop_b

loop_4:
	jb ALARM_MINS_BUTTON, loop_5  
	Wait_Milli_Seconds(#50)	
	jb ALARM_MINS_BUTTON, loop_5  
	jnb ALARM_MINS_BUTTON, $
	
	mov a, ALARM_MINS
	cjne	a, 	#0x59, alarmmin
	mov		a, 	#0
	da		a
	mov		ALARM_MINS, 	a
	
	sjmp loop_b
	
loopconnect3:
sjmp hour2

loop_5:

	jb ALARM_HOURS_BUTTON, loop_a  
	Wait_Milli_Seconds(#50)	
	jb ALARM_HOURS_BUTTON, loop_a  
	jnb ALARM_HOURS_BUTTON, $
	
	mov a, ALARM_HOURS
	cjne	a, 	#0x12, alarmhour2
	mov		a, 	#1
	da		a
	mov		ALARM_HOURS, 	a
	sjmp loop_b
	
loopconnect:
ljmp loop
loopconnect2:
ljmp loop_b

alarmmin:
	add a, #0x01
	da a
	mov ALARM_MINS, a
	sjmp loop_b

	
minute:
	add a, #0x01
	da a
	mov BCD_MINUTES, a
	sjmp loop_b

alarmhour:
	add a, #0x01
	da a
	mov ALARM_HOURS, a
	sjmp loop_b

hour:
	add a, #0x01
	da a
	mov BCD_HOURS, a
	sjmp loop_b
	
hour2:
	cjne 	a, 	#0x11, hour
	cpl		AMPMFLAG
	mov 	a,	#12
	da		a
	mov 	BCD_HOURS,	a
	
	sjmp loop_b	
	
alarmhour2:
	cjne 	a, 	#0x11, alarmhour
	cpl		ALARMAMPMFLAG
	mov 	a,	#12
	da		a
	mov 	ALARM_HOURS,	a
	
	sjmp loop_b	
	
loop_a:
	jnb half_seconds_flag, loopconnect

loop_b:

    clr half_seconds_flag ; We clear this flag in the main loop, but it is set in the ISR for timer 2
    
    
	Set_Cursor(1, 7)     ; the place in the LCD where we want the BCD counter value
	Display_BCD(BCD_HOURS) ; This macro is also in 'LCD_4bit.inc'
	
	Set_Cursor(1, 9)     ; the place in the LCD where we want the BCD counter value
	Display_char(#':') ; This macro is also in 'LCD_4bit.inc'
	
	Set_Cursor(1, 10)     ; the place in the LCD where we want the BCD counter value
	Display_BCD(BCD_MINUTES) ; This macro is also in 'LCD_4bit.inc'
	
	Set_Cursor(1, 12)     ; the place in the LCD where we want the BCD counter value
	Display_char(#':') ; This macro is also in 'LCD_4bit.inc'
	
	Set_Cursor(1, 13)     ; the place in the LCD where we want the BCD counter value
	Display_BCD(BCD_SECONDS) ; This macro is also in 'LCD_4bit.inc'
	
	Set_Cursor(2, 1)     ; the place in the LCD where we want the BCD counter value
	Send_Constant_String(#Alarm) ; This macro is also in 'LCD_4bit.inc'
	
	Set_Cursor(2, 8)     ; the place in the LCD where we want the BCD counter value
	Display_BCD(ALARM_HOURS) ; This macro is also in 'LCD_4bit.inc'
	
	Set_Cursor(2, 10)     ; the place in the LCD where we want the BCD counter value
	Display_char(#':') ; This macro is also in 'LCD_4bit.inc'
	
	Set_Cursor(2, 11)     ; the place in the LCD where we want the BCD counter value
	Display_BCD(ALARM_MINS) ; This macro is also in 'LCD_4bit.inc'
	
;	button click reverse flag
;	take time or alarm path depeding on flag
	
;	button click
;	reverse flag
;	display corresponding char
	
;	if hour = hour
;	if min = min
;	playsound ?
	
;	 if button click increment hour
;	 if button click increment minutes
	
    
FLAGSETP:
	jb AMPMFLAG, FLAGSETA
	Set_Cursor(1,16)
	Display_char(#'P')
	sjmp ALARMFLAGSETP
	
ALARMFLAGSETP:

	jb ALARMAMPMFLAG, ALARMFLAGSETA
	Set_Cursor(2,13)
	Display_char(#'P')
	ljmp snooze
	
FLAGSETA:	

	Set_Cursor(1,16)
	Display_char(#'A')
	ljmp ALARMFLAGSETP

	
ALARMFLAGSETA:	

	Set_Cursor(2,13)
	Display_char(#'A')
	ljmp snooze
	
	

END
	
    
