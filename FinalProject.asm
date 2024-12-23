;-------------------------------------------------------------------------------
; MSP430 Assembler Code Template for use with TI Code Composer Studio
;
;
;-------------------------------------------------------------------------------
            .cdecls C,LIST,"msp430.h"       ; Include device header file
            
;-------------------------------------------------------------------------------
            .def    RESET                   ; Export program entry-point to
                                            ; make it known to linker.
;-------------------------------------------------------------------------------
            .global _main
            .global __STACK_END
            .sect   .stack                  ; Make stack linker segment ?known?

            .text                           ; Assemble into program memory.
            .retain                         ; Override ELF conditional linking
                                            ; and retain current section.
            .retainrefs                     ; And retain any sections that have
                                            ; references to current section.

SEGA        .set    BIT0 ; P2.0
SEGB        .set    BIT1 ; P2.1
SEGC        .set    BIT2 ; P2.2
SEGD        .set    BIT3 ; P2.3
SEGE        .set    BIT4 ; P2.4
SEGF        .set    BIT5 ; P2.5
SEGG        .set    BIT6 ; P2.6
SEGDP       .set    BIT7 ; P2.7

DIG1        .set    BIT0 ; P3.0
DIG2        .set    BIT1 ; P3.1
DIG3        .set    BIT2 ; P3.2
DIG4        .set    BIT3 ; P3.3
DIGCOL      .set    BIT7 ; P3.7

BTN1		.set	BIT7 ; P4.7 **some boards appear to have BTN1 and BTN3 flipped?
BTN2		.set	BIT3 ; P1.3
BTN3		.set    BIT5 ; P1.5

digit       .set	R5   	; Digit of 7-seg currently being multiplexed
count		.set	R10	 	; Stores 4 values to be displayed on 7 seg displays
state		.set	R4		; Stores 4 bits corresponding to sensors reading white/black
RDelay		.set	R7
LRChoice	.set	R8
lastTurn	.set	R9
leftTime	.set	R13
rightTime	.set	R14

running		.set	R6

FALSE		.set	0
TRUE		.set	1

LEFT		.set	0
RIGHT		.set	1


                                            ; Standby = 5v
AI1		.set	BIT0                        ; A (left motor) AO1=+, AO2=-
AI2     .set    BIT1                        ; AI1=9.0, AI2=9.1
PWMA	.set	BIT6                        ; PWMA= 1.6
BI1		.set    BIT5                        ; B (right motor) BO1=+, BO2=-
BI2		.set	BIT6                        ; BI1=9.5, BI2=9.6
PWMB	.set	BIT7                        ; PWMB= 1.7

;SensorR	.set	4
;SensorC	.set	5							; A4= right sensor
;SensorF	.set	6							; A5= center sensor
;SensorL	.set	7							; A6= front sensor
											; A7= left sensor
;-------------------------------------------------------------------------------
_main

RESET       mov.w   #__STACK_END,SP         ; Initialize stackpointer
StopWDT     mov.w #WDTPW+WDTCNTCL+WDTTMSEL+7+WDTSSEL__ACLK,&WDTCTL ; Interval mode with ACLK
			bis.w #WDTIE, &SFRIE1                                       ; enable interrupts for the watchdog

SetupPB     bic.b   #BIT1+BIT2, &P1DIR      ; Set P1.1 to input direction (Push Button)
			bis.b   #BIT1+BIT2, &P1REN      ; **ENABLE RESISTORS ON BUTTONS
			bis.b   #BIT1+BIT2, &P1OUT      ; **SET TO BE PULLUP
			bis.b   #BIT1+BIT2, &P1IES
			bis.b   #BIT1+BIT2, &P1IE

			bic.b   #BTN1, &P4DIR
			bic.b   #BTN3+BTN2, &P1DIR
			bis.b   #BTN1, &P4REN
			bis.b   #BTN3+BTN2, &P1REN
			bis.b   #BTN1, &P4OUT
			bis.b   #BTN3+BTN2, &P1OUT
			bis.b   #BTN1, &P4IES
			bis.b   #BTN3+BTN2, &P1IES
			bis.b   #BTN1, &P4IE
			bis.b   #BTN3+BTN2, &P1IE

SetupSeg    bic.b   #SEGA+SEGB+SEGC+SEGD+SEGE+SEGF+SEGG+SEGDP,&P2OUT
            bic.b   #DIG1+DIG2+DIG3+DIG4+DIGCOL,&P3OUT
            bis.b   #SEGA+SEGB+SEGC+SEGD+SEGE+SEGF+SEGG+SEGDP,&P2DIR
            bis.b   #DIG1+DIG2+DIG3+DIG4+DIGCOL,&P3DIR
            bic.b   #SEGA+SEGB+SEGC+SEGD+SEGE+SEGF+SEGG+SEGDP,&P2OUT
            bic.b   #DIG1+DIG2+DIG3+DIG4,&P3OUT
            bis.b   #DIGCOL,&P3OUT

EditClock   mov.b   #CSKEY_H,&CSCTL0_H      ; Unlock CS registers
            mov.w   #DCOFSEL_3,&CSCTL1      ; Set DCO setting for 4MHz
            mov.w   #DIVA__1+DIVS__1+DIVM__1,&CSCTL3 ; MCLK = SMCLK = DCO = 4MHz
            clr.b   &CSCTL0_H               ; Lock CS registers

SetupADC12  bis.w   #ADC12SHT0_10+ADC12MSC+ADC12ON, &ADC12CTL0 ; ADC12SHT = hold time. longer time= more time in isr
			bis.w   #ADC12SHP+ADC12SSEL_3+ADC12CONSEQ_3,&ADC12CTL1    ; Make ADC in consecutive mode
			bis.w   #ADC12RES_2,&ADC12CTL2  ; 12-bit conversion results
            bis.w   #ADC12INCH_4,&ADC12MCTL0; A10 ADC input select; Vref=AVCC
            bis.w   #ADC12INCH_5,&ADC12MCTL1; A10 ADC input select; Vref=AVCC
            bis.w   #ADC12INCH_6,&ADC12MCTL2; A10 ADC input select; Vref=AVCC
            bis.w   #ADC12INCH_7+ADC12EOS,&ADC12MCTL3; A10 ADC input select; Vref=AVCC
            ;bis.w   #ADC12IE0,&ADC12IER0    ; Enable ADC conv complete interrupt
			bis.w   #ADC12ENC+ADC12SC, &ADC12CTL0 ; Start conversions

			; Motor Duty Cycle Timer
SetupTA0    mov.w   #2600,&TA0CCR0           ; TA0 bound to update motors
            bis.w   #TASSEL__SMCLK+MC__UP,&TA0CTL ; SMCLK continuous mode
			bis.w   #OUTMOD_7, &TA0CCTL1
			bis.w   #OUTMOD_7, &TA0CCTL2

		; Countdown Decrement Timer
SetupTA1	mov.w   #CCIE,&TA1CCTL0           ; TACCR0 interrupt enabled
            mov.w   #40000,&TA1CCR0           ; count to 9999 for 1cs
            bis.w   #TASSEL__SMCLK+MC__STOP,TA1CTL ; SMCLK stop mode

			; 50ms Debounce Timer
SetupTA2	mov.w   #CCIE,&TA2CCTL0           ; TACCR0 interrupt enabled
            mov.w   #10000,&TA2CCR0           ; count to 49999 for 50ms delay
            bis.w   #TASSEL__SMCLK+MC__STOP,&TA2CTL ; SMCLK stop mode

UnlockGPIO  bic.w   #LOCKLPM5,&PM5CTL0      ; Disable the GPIO power-on default
                                            ; high-impedance mode to activate
                                            ; previously configured port settings
			;clr     PM5CTL0
;-------------------------------------------------------------------------------
; Reset all
;-------------------------------------------------------------------------------
			; Set motor speed
			mov.w	#1, &TA0CCR1	;Left wheel speed
			mov.w	#1, &TA0CCR2 ;Right wheel speed (max 2600, 2599?)
			; Initialize motor driver directions
			bis.b	#AI1+AI2+BI1+BI2, &P9DIR
			bis.b	#PWMA+PWMB, &P1DIR
			; Route PWMA and PWMB to the timer a0 output
			bis.b	#PWMA+PWMB, &P1SELC
			; Route a4,5,6,7 to the adc
			bis.b	#0xF0, &P8SELC
			; Motor setup
			bis.w	#0xC0, &P1OUT 	; Enable motors
			mov.w	#0x00, &P9OUT ; No power to start

			; Initialize variable registers
			mov.w	#0x0000, count
			mov.w	#5, digit
			clr		state
			bic		#TAIFG, &TA1CTL		; start the countdown decrement timer
			mov.w	#FALSE, running

			nop
			eint
			nop

			nop

;-------------------------------------------------------------------------------
Mainloop	; Handles all sensor pathing
;-------------------------------------------------------------------------------
			call	#ReadSensors	; Read Sensors
			cmp		#TRUE, running	; Exit out of here if running =/= true
			jeq		Redirect
			jmp		Mainloop

Redirect
			cmp		#11, state		; 1011 highest priority
			jeq		State1011

			cmp		#14, state
			jeq		State1110

			cmp		#7, state
			jeq		State0111

			cmp		#1, state
			jeq		State0001

			cmp		#2, state
			jeq		State0010

			cmp		#3, state
			jeq		State0011

			cmp		#4, state
			jeq		State0100

			cmp		#5, state
			jeq		State0101

			cmp		#6, state
			jeq		State0110

			cmp		#8, state
			jeq		State1000

			cmp		#9, state
			jeq		State1001

			cmp		#10, state
			jeq		State1010


			cmp		#12, state
			jeq		State1100

			cmp		#13, state
			jeq		State1101


			cmp		#15, state
			jeq		State1111

			cmp		#0, state
			jeq		State0000

State0000:	; No line sensed (make sure we're actually at the end, then end)
		call	#Delay
		call	#Delay
		call	#SlowBrake	; Stop

		call	#ReadSensors
		cmp		#0, state	; Do sensors still read 0000?
		jne		Mainloop	; If not, exit
		cmp		#LEFT, lastTurn ; Check which direction we last turned
		jne		State0000Right
State0000Left	; If we last turned left, turn left and check if theres still a path nearby
		call	#TurnLeft

		call	#Delay
		call	#ReadSensors
		cmp		#0, state
		jne		Mainloop
		call	#Delay
		call	#ReadSensors
		cmp		#0, state
		jne		Mainloop
		call	#Delay
		call	#ReadSensors
		cmp		#0, state
		jne		Mainloop
		call	#Delay
		call	#ReadSensors
		cmp		#0, state
		jne		Mainloop
		call	#Delay
		call	#ReadSensors
		cmp		#0, state
		jne		Mainloop
		call	#Delay
		call	#ReadSensors
		cmp		#0, state
		jne		Mainloop
		call	#Delay
		call	#ReadSensors
		cmp		#0, state
		jne		Mainloop
		call	#Delay
		call	#ReadSensors
		cmp		#0, state
		jne		Mainloop
		jmp		State0000Exit		; If sensors still read 0000, end timer and exit running mode

State0000Right ; If we last turned right, turn right and check if theres still a path nearby
		call	#TurnRight

		call	#Delay
		call	#ReadSensors
		cmp		#0, state
		jne		Mainloop
		call	#Delay
		call	#ReadSensors
		cmp		#0, state
		jne		Mainloop
		call	#Delay
		call	#ReadSensors
		cmp		#0, state
		jne		Mainloop
		call	#Delay
		call	#ReadSensors
		cmp		#0, state
		jne		Mainloop
		call	#Delay
		call	#ReadSensors
		cmp		#0, state
		jne		Mainloop
		call	#Delay
		call	#ReadSensors
		cmp		#0, state
		jne		Mainloop
		call	#Delay
		call	#ReadSensors
		cmp		#0, state
		jne		Mainloop
		call	#Delay
		call	#ReadSensors
		cmp		#0, state
		jne		Mainloop
		jmp		State0000Exit	; If sensors still read 0000, end timer and exit running mode

State0000Exit	; Exit running mode, stop timer
		call	#FastBrake	; Brake
		mov.w	#FALSE, running ; Exit running mode
		mov.w	#MC_0, &TA1CTL	; Stop stopwatch timer
		bis.w	#TACLR, &TA1CTL

		cmp		#LEFT, LRChoice	; Check which pathing mode (left/right) we are currently in
		jne		ExitRight1
ExitLeft1	; If we're in left pathing mode
		mov.w	count, leftTime	; Store the left path time
		jmp		Mainloop
ExitRight1
		mov.w	count,	rightTime	; If we're in right pathing mode
		jmp		Mainloop	; Store the rgiht path time

State0001:	; Only right sensor showing
		call	#TurnRight		; Turn right
		call	#ReadSensors
		cmp		#4, state		; Exit if we see 0100
		jeq		Mainloop
		cmp		#11, state		; or 1011
		jeq		Mainloop
		cmp		#6, state		; or 0110
		jne		State0001
		;call	#FastBrake		; Brake
		jmp		Mainloop

State0010:	; Only back sensor showing (do nothing
		jmp		Mainloop

State0100:	; Only front sensor showing
		call	#Forwards	; Gor forwards
		jmp		Mainloop

State1000:	; Only left sensor showing
		call	#TurnLeft		; Turn left
		call	#ReadSensors
		cmp		#4, state		; Exit if we see 0100
		jeq		Mainloop
		cmp		#11, state		; or 1011
		jeq		Mainloop
		cmp		#6, state		; or 0110
		jne		State1000
		;call	#FastBrake
		jmp		Mainloop

State0011:	; Back/right sensor showing
		call	#TurnRight
		jmp		Mainloop

State0110:	; Front/back sensor showing (On a straight line)
		call	#Forwards
		jmp		Mainloop

State0101:	; Front/right sensor showing
		jmp		Mainloop

State1001:	; Left/right sensor showing (error)
		jmp		Mainloop

State1010:	; Left/back sensor showing
		call	#TurnLeft
		jmp		Mainloop

State1100:	; Left/front sensor showing

		jmp		Mainloop

State0111:	; Front/back/right sensor showing (Straight/right turn intersection)
		call 	#Delay
		call 	#Delay
		call	#SlowBrake		; Brake
		call	#ReadSensors
		cmp		#7, state		; Make sure we're still on 0111
		jne		Mainloop		; Else, exit


State0111Loop
		call	#TurnRight		; Turn right
		call	#Delay
		call	#Delay
		call	#Delay
		call	#Forwards		; Go forwards
		call	#Delay
		call	#ReadSensors
		cmp		#15, state		; Exit if we are in 1111
		jeq		Mainloop
		cmp		#6, state		; or 0110
		jeq		Mainloop
		cmp		#14, state		; or 1110
		jeq		State0111Loop
		jmp     State0111Loop
		jmp		Mainloop


State1011:	; Left/back/right sensor showing (Make a choice)
		; See which version of trial is faster, call left or right depending on that
		call	#ReadSensors
		cmp		#11, state		; Are we still in 1011
		jne		Mainloop

		cmp		#LEFT, LRChoice		; Which pathing mode are we in?
		jeq		State1011Left
		jmp		State1011Right

State1011Left
		call	#TurnLeft	; Turn left
		call	#Delay
		call	#Delay
		call	#Delay
		call	#Forwards	; Go forwards
		call	#Delay
		call	#ReadSensors
		cmp		#6, state	; Are we on 0110?
		jne		State1011Left	; If not, loop until on 0110?
		jmp		Mainloop

State1011Right
		call	#TurnRight	; Turn Right
		call	#Delay
		call	#Delay
		call	#Delay
		call	#Forwards	; Go forwards
		call	#Delay
		call	#ReadSensors
		cmp		#6, state	; Are we on 0110?
		jne		State1011Right	; If not, loop until on 0110?
		jmp		Mainloop


State1101:	; Left/front/right showing (Do nothing)
		jmp		Mainloop

State1110:	; Left/front/back showing (Straight/left turn intersection)
		call 	#Delay
		call 	#Delay
		call	#ReadSensors
		cmp		#14, state		; Are we still in 1110?
		jne		Mainloop		; If not, exit

State1110Loop
		call	#TurnLeft		; Turn left
		call	#Delay
		call	#Delay
		call	#Delay
		call	#Forwards		; Go forwards
		call	#Delay
		call	#ReadSensors
		cmp		#15, state		; Are we in 1111?
		jeq		Mainloop
		cmp		#6, state		; or 0110, if yes, exit.
		jeq		Mainloop
		cmp		#14, state		; If we are in 1110
		jeq		State1110Loop	; Loop
		jmp     State1110Loop
		jmp		Mainloop

State1111:	; All showing (error, possibly at a t intersection)
		call	#Forwards
		jmp		Mainloop


		jmp     Mainloop                ; Again
			nop
;-------------------------------------------------------------------------------
TIMER1_A0_ISR:		; Timer Increment
;-------------------------------------------------------------------------------

		dadd.w	#0x0001, count ; Increment count at 10ms
		reti

;-------------------------------------------------------------------------------
TIMER2_A0_ISR:		; Button Debounce and Tasks
;-------------------------------------------------------------------------------
			bit.b	#BIT1, &P1IN			; Debounce all inputs, go to respective section
			jz		BTN1_1Pressed
			bit.b	#BIT2, &P1IN
			jz		BTN1_2Pressed
			bit.b	#BTN1, &P4IN
			jz		BTN1Pressed
			bit.b	#BTN2, &P1IN
			jz		BTN2Pressed
			bit.b	#BTN3, &P1IN
			jz		BTN3Pressed

			jmp		TA2_EXIT

BTN1_1Pressed	; MSP Left Button Pressed
			; Do nothing
			jmp		TA2_EXIT

BTN1_2Pressed	; MSP Right Button Pressed
			; Do nothing
			jmp		TA2_EXIT

BTN1Pressed		; DB Right Button Pressed (Run trial with left pathing mode)
			clr		count	; Clear count (holds time on timer)
			bic		#TAIFG, &TA1CTL		; start the countdown decrement timer
			mov		#MC_1, &TA1CTL
			bis		#TASSEL_2+TACLR, &TA1CTL
			mov		#LEFT, LRChoice		; Enter left pathing mode
 			mov		#TRUE, running		; Start

			jmp		TA2_EXIT
BTN2Pressed		; DB Middle Button Pressed
			clr		count	; Clear count (holds time on timer)
			bic		#TAIFG, &TA1CTL		; start the countdown decrement timer
			mov		#MC_1, &TA1CTL
			bis		#TASSEL_2+TACLR, &TA1CTL
			mov		#RIGHT, LRChoice	; Enter right pathing mode
			mov		#TRUE, running
			jmp		TA2_EXIT			; Start
BTN3Pressed		; DB Left Button Pressed
			clr		count			; Clear count (holds time on timer)
			bic		#TAIFG, &TA1CTL		; start the countdown decrement timer
			mov		#MC_1, &TA1CTL
			bis		#TASSEL_2+TACLR, &TA1CTL
			cmp		leftTime, rightTime		; Choose whichever pathing mode is shorter
			jge		BTN3Left
BTN3Right
			mov		#RIGHT, LRChoice		; If right was faster
			mov		#TRUE, running
			jmp		TA2_EXIT
BTN3Left
			mov		#LEFT, LRChoice			; If left was faster
			mov		#TRUE, running
			jmp		TA2_EXIT

TA2_EXIT
			bic.w	#MC__UP, &TA2CTL	; Clear debounce timer
			reti
;-------------------------------------------------------------------------------
WDT_ISR:	; Multiplexer
;-------------------------------------------------------------------------------
    		push        count		; store count in stack 1233

    		dec         digit		; decrement digit each cycle to multiplex
    		jnz         SkipReset	; if not zero, skip resetting
    		mov         #4, digit	; reset digit back to 4 if digit=0

SkipReset:
    		clr.b       &P2OUT		; clear segments of previous cycle
    		bic.b       #0x0F, &P3OUT	; clear currently stored digit port

    		bis.b       sDIG(digit), &P3OUT		; assign P3OUT to current digit being multiplexed

CheckDig4: ; rightmost
    		cmp         #4, digit		; are we currently mpxing digit 4?
    		jne         CheckDig3		; if not, skip to test next digit
    		and         #0x000F, count	; mask rightmost digit from countdown variable
    		mov.b       BCD(count), &P2OUT	; move digits respective segments to P2OUT for display
    		jmp         WDT_ISR_END

CheckDig3:
    		rra.w       count			; roll right x4 on countdown variable to make 3rd digit rightmost
    		rra.w       count			;
    		rra.w       count			;
    		rra.w       count			; 1234=count 0123 = 0003
    		cmp         #3, digit		; are we currently mpxing digit 3?
    		jne         CheckDig2		; if not, skip to next digit
    		and         #0x000F, count	; mask rightmost digit from countdown variable
    		mov.b       BCD(count), &P2OUT	; move digits respective segments to P2OUT for display
    		jmp         WDT_ISR_END

CheckDig2:
    		rra.w       count			; roll right x4 on countdown variable to make 3rd digit (originally 2nd digit) rightmost
    		rra.w       count			;
    		rra.w       count			;
    		rra.w       count			; 0012
    		cmp         #2, digit		; are we currently mpxing digit 2?
    		jne         CheckDig1		; if not, skip to next digit
    		and         #0x000F, count	; mask rightmost digit from countdown variable 0002
    		mov.b       BCD(count), &P2OUT	; move digits respective segments to P2OUT for display
    		jmp         WDT_ISR_END

CheckDig1:
    		rra.w       count			; roll right x4 on countdown variable to make 3rd digit (originally 1st digit) rightmost
    		rra.w       count			;
    		rra.w       count			;
    		rra.w       count			;1234= 0001
    		cmp         #1, digit		; are we currently mpxing digit 1?
    		jne         WDT_ISR_END		; if not, leave (not sure how we'd get here)
    		and         #0x000F, count	; mask rightmost digit from countdown variable 0001
    		mov.b       BCD(count), &P2OUT	; move digits respective segments to P2OUT for display

WDT_ISR_END:
    		pop.w       count	; pop original countdown value back onto count variable 1234



WDT_reti:    	reti
;-------------------------------------------------------------------------------
PORT1_ISR;    Port 1 ISR (Left and Middle DB Buttons, MSP 1.1 & 1.2 Buttons)
;-------------------------------------------------------------------------------
			bis.w	#MC__UP+TACLR, &TA2CTL  ; go to debounce timer
P1EXIT		bic.b   #BTN3+BTN2+BIT1+BIT2,&P1IFG	; clear all button interrupt flags
			reti

;-------------------------------------------------------------------------------
PORT4_ISR;    Port 4 ISR (Right DB Button)
;-------------------------------------------------------------------------------
			bis.w	#MC__UP+TACLR, &TA2CTL  ; go to debounce timer
P4EXIT		bic.b   #BTN1,&P4IFG	; clear button interrupt flag
			reti
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; Calls
;-------------------------------------------------------------------------------
;--------------------------
; Motor Handlers
;--------------------------
Forwards:
			mov.w	#900, &TA0CCR1	;Right wheel speed
			mov.w	#1000, &TA0CCR2 ;Left wheel speed (max 2600, 2599?)
			mov.w	#0x21, &P9OUT ;21=forwards
			ret
Backwards:
			mov.w	#900, &TA0CCR1	;Right wheel speed
			mov.w	#1000, &TA0CCR2 ;Left wheel speed (max 2600, 2599?)
			mov.w	#0x42, &P9OUT ;42=backwards
			ret
TurnLeft:
			mov.w	#LEFT, lastTurn
			mov.w	#1400, &TA0CCR1	;Right wheel speed
			mov.w	#1000, &TA0CCR2 ;Left wheel speed (max 2600, 2599?)
			mov.w	#0x41, &P9OUT ;41=left circle
			ret
TurnRight:
			mov.w	#LEFT, lastTurn
			mov.w	#RIGHT, lastTurn
			mov.w	#1000, &TA0CCR1	;Right wheel speed
			mov.w	#1400, &TA0CCR2 ;Left wheel speed (max 2600, 2599?)
			mov.w	#0x22, &P9OUT ;22=right circle
			ret
FastBrake:
			mov.w	#0x63, &P9OUT ;63=fast brake
			ret
SlowBrake:
			mov.w	#0x00, &P9OUT ;0=slow brake
			ret

;--------------------------
ReadSensors:
;--------------------------
Check0:		cmp.w	#0xE30, &ADC12MEM0 ;MEM0 = Right Sensor (adjusted for tolerance)
			jlo		Black0
White0		;bic.b	#BIT0, &P1OUT		; Debug
			bis.b	#BIT0, state		; Right Sensor = 000x in state
			jmp		Check1
Black0		;bis.b	#BIT0, &P1OUT		; Debug
			bic.b	#BIT0, state

Check1:		; Back Sensor
			cmp.w	#0xE00, &ADC12MEM1 ;MEM1 = Back Sensor
			jlo		Black1
White1		;bic.b	#BIT6, &P3OUT		; Debug
			bis.b	#BIT1, state		; Back Sensor = 00x0 in state
			jmp		Check2
Black1		;bis.b	#BIT6, &P3OUT		; Debug
			bic.b	#BIT1, state

Check2:		; Front Sensor
			cmp.w	#0xE00, &ADC12MEM2	;MEM2 = Front Sensor
			jlo		Black2
White2		;bic.b	#BIT6, &P3OUT		; Debug
			bis.b	#BIT2, state		; Front Sensor = 0x00 in state
			jmp		Check3
Black2		;bis.b	#BIT6, &P3OUT		; Debug
			bic.b	#BIT2, state

Check3:		; Left Sensor
			cmp.w	#0xE50, &ADC12MEM3	;MEM3 = Left Sensor (adjusted for tolerance)
			jlo		Black3
White3		;bic.b	#BIT7, &P9OUT		; Debug
			bis.b	#BIT3, state		; Left Sensor = x000 in state
			jmp		ReadSensorsExit
Black3		;bis.b	#BIT7, &P9OUT		; Debug
			bic.b	#BIT3, state

ReadSensorsExit:
			ret

;-------------------------------------------------------------------------------
; Delay
;-------------------------------------------------------------------------------
Delay
			mov.w   #50000,RDelay           ; Delay to R15
L1          dec.w   RDelay                  ; Decrement R15
            jnz     L1                      ; Delay over?
            ret                             ; Return From Subroutine


;-------------------------------------------------------------------------------
; Look Up Tables
;-------------------------------------------------------------------------------
; Hex -> Segment conversion
BCD         .byte   SEGA+SEGB+SEGC+SEGD+SEGE+SEGF      ; 0
            .byte        SEGB+SEGC                     ; 1
            .byte   SEGA+SEGB+     SEGD+SEGE+     SEGG ; 2
            .byte   SEGA+SEGB+SEGC+SEGD+          SEGG ; 3
            .byte        SEGB+SEGC+          SEGF+SEGG ; 4
            .byte   SEGA+     SEGC+SEGD+     SEGF+SEGG ; 5
            .byte   SEGA+     SEGC+SEGD+SEGE+SEGF+SEGG ; 6
            .byte   SEGA+SEGB+SEGC                     ; 7
            .byte   SEGA+SEGB+SEGC+SEGD+SEGE+SEGF+SEGG ; 8
            .byte   SEGA+SEGB+SEGC+SEGD+     SEGF+SEGG ; 9
            .byte   SEGA+SEGB+SEGC+     SEGE+SEGF+SEGG ; A
            .byte             SEGC+SEGD+SEGE+SEGF+SEGG ; b
            .byte   SEGA+          SEGD+SEGE+SEGF      ; C
            .byte   0x0								   ; D (null)
            .byte   							  SEGG ; E (-)
            .byte                  		SEGE	 +SEGG ; F (r)

sDIG        .byte   0
			.byte   DIG1
			.byte   DIG2
			.byte   DIG3
			.byte   DIG4


;-------------------------------------------------------------------------------
; Interrupt Vectors
;-------------------------------------------------------------------------------
            .sect   ".reset"                ; MSP430 RESET Vector
            .short  RESET
            .sect   TIMER1_A0_VECTOR            ; TIMER1 Interrupt Vector
            .short  TIMER1_A0_ISR               ;
            .sect   WDT_VECTOR              ; Watchdog Timer
            .short  WDT_ISR
            .sect   PORT1_VECTOR        ; BTN2+BTN3 Interrupt Vector
            .short  PORT1_ISR
            .sect   PORT4_VECTOR        ; BTN1 Interrupt Vector
            .short  PORT4_ISR
            .sect   TIMER2_A0_VECTOR            ; TIMER2 Interrupt Vector
            .short  TIMER2_A0_ISR               ;
            .end
            
