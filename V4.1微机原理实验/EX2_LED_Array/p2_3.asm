;p2_3
		ORG 0000H
		LJMP START
		ORG 0030H

;one
;P0 is the control columns in the circuit
;p1 is the 3_8 translator's  input.
CHAR1:	MOV P1, #0E0H	;打开第一行11100000
		MOV P0, #0FFH
		LCALL DELAY1
		INC P1
		MOV P0, #0FFH 
		LCALL DELAY1
		INC P1
		MOV P0, #0FFH
		LCALL DELAY1
		INC P1
		MOV P0, #081H
		LCALL DELAY1

		RET

;three
CHAR2:	MOV P1, #0E0H	;
		MOV P0, #0FFH	;
		LCALL DELAY1
		INC P1
		MOV P0, #0FFH	;
		LCALL DELAY1
		INC P1
		MOV P0, #081H	;
		LCALL DELAY1
		INC P1
		MOV P0, #0FFH	;
		LCALL DELAY1
		INC P1
		MOV P0, #0C3H	;
		LCALL DELAY1
		INC P1
		MOV P0, #0FFH	;
		LCALL DELAY1
		INC P1
		MOV P0, #081H	;
		LCALL DELAY1
		RET

DELAY_100ms:				;delay 100ms
    MOV R7, #200       
DEL4:
    MOV R6, #0E5H      
DEL5:
    DJNZ R6, DEL5       
    DJNZ R7, DEL4     
    RET

DELAY_1s:				  ;delay 1s
    MOV R2, #10      
DEL6:
	LCALL  DELAY_100ms
    DJNZ R2, DEL6      
    RET

DELAY1:MOV R2, #30    	;delay 2ms
DEL1:	MOV R3, #30
		DJNZ R3, $
		DJNZ R2, DEL1	
		RET




START:	MOV SP, #60H


  		MOV R1, #125
DISP1:
		LCALL CHAR1	
		MOV P0, #0FFH 
		DJNZ R1, DISP1

		;LCALL DELAY_1s

		MOV R1, #71	  ;calc that how mant circle need in 1s.
DISP4:	LCALL CHAR2
	   	MOV P0, #0FFH
		DJNZ R1, DISP4
		;LCALL DELAY_1s


   		END