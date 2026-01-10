; =============================================
; 实验 3.3：标志位法 (反应快、无倒带)
; =============================================
		ORG		0000H
		LJMP	START
		ORG		0003H
		LJMP	INT0_ISR
		ORG		0013H
		LJMP	INT1_ISR
		ORG		0030H

; 定义一个标志位 (位地址 00H，位于 RAM 20H 处)
INT_FLAG  BIT   00H 

START:	MOV		SP, #60H
		MOV 	TCON, #00H		; 低电平触发
		SETB	EA
		SETB	EX0
		SETB	EX1
		SETB	PX1
		CLR 	PX0
		MOV 	PSW, #00H
		CLR     INT_FLAG        ; 上电先清除标志位

MAIN:	
		MOV 	DPTR, #TABLE_NUM 
		ACALL	SHOW_SEQUENCE
		SJMP	MAIN

; =============================================
; 通用显示子程序 (逻辑重构：先显示，后+1)
; =============================================
SHOW_SEQUENCE:
		MOV 	R4, #0			; 偏移量初始值 (对应数字1)
		MOV 	R3, #0E8H		; 位选初始值 (直接指向第1个管)
		MOV 	R5, #6			; 循环6次

SEQ_LOOP:
		; --- 1. 查表取数 ---
		MOV 	A, R4
		MOVC	A, @A+DPTR
		
		; --- 2. 显示 ---
		MOV 	P0, A
		MOV 	P1, R3
		
		; --- 3. 延时 (带检测) ---
		ACALL	DELAY
		
		; ===========================================
		; 【关键逻辑】检查是否发生过中断
		; ===========================================
		JB      INT_FLAG, REPEAT_CURRENT ; 如果标志位是1，跳去重播
		
		; --- 正常流程：准备下一个数字 ---
		INC 	R4				; 数字+1
		INC 	R3				; 位选+1
		DJNZ	R5, SEQ_LOOP	; 循环
		
		; --- 结束清理 ---
		MOV 	P0, #0FFH
		MOV 	P1, #0FFH
		RET

; --- 重播逻辑 ---
REPEAT_CURRENT:
		CLR     INT_FLAG        ; 清除报警器
		SJMP    SEQ_LOOP        ; 直接跳回开头显示同一个数
								; 注意：因为跳过了 INC，所以 R3, R4 还是原来的值

; =============================================
; 延时子程序 (带“立马退出”功能)
; =============================================
DELAY:	MOV 	R6, #200		
DEL1:	MOV 	R7, #4			
DEL2:	MOV 	R2, #229
		
		; 【关键】延时中途检查标志位
		JB      INT_FLAG, DELAY_EXIT ; 发现中断，立马逃跑，不再死等

DEL3:	DJNZ	R2, DEL3
		DJNZ	R7, DEL2
		DJNZ	R6, DEL1
		RET

DELAY_EXIT:
		RET     ; 直接返回

; =============================================
; 中断 0 服务程序
; =============================================
INT0_ISR:
		PUSH	ACC
		PUSH	PSW
		PUSH	DPH
		PUSH	DPL
		
		MOV 	PSW, #10H		; 切换寄存器组
		SETB    INT_FLAG        ; 【拉警报】告诉主程序：我来过！
		
		MOV 	DPTR, #TABLE_ID ;
		
		; 显示 '1'
		MOV 	P1, #0E8H
		MOV 	A, #0
		MOVC	A, @A+DPTR
		MOV 	P0, A
		ACALL	DELAY_ISR       ; 中断里用死延时即可 
		
		; 显示 '3'
		MOV 	P1, #0E9H
		MOV 	A, #1
		MOVC	A, @A+DPTR
		MOV 	P0, A
		ACALL	DELAY_ISR

		MOV 	P0, #0FFH
		MOV 	P1, #0FFH

		POP 	DPL
		POP 	DPH
		POP 	PSW
		POP 	ACC
		RETI

INT1_ISR:
		; --- 1. 保护现场 ---
		PUSH	ACC
		PUSH	PSW
		PUSH	DPH
		PUSH	DPL
		
		MOV 	PSW, #18H		; 切换到第3组寄存器
		MOV 	DPTR, #TABLE_NUM ; 指向数字表

		; --- 2. 初始化循环变量 ---
		MOV 	R4, #0			; 偏移量
		MOV 	R5, #6			; 循环6次
		MOV 	R3, #0E7H		; 位选初值

INT1_LOOP:
		; ==============================
		; 松手检测
		; ==============================
		JB		P3.3, INT1_EXIT

		; --- 正常显示逻辑 ---
		INC 	R3				
		MOV 	A, R4			
		MOVC	A, @A+DPTR		
		MOV 	P0, A			
		MOV 	P1, R3			
		
		; 这里必须用普通的延时函数(不查标志位的)，否则逻辑会乱
		ACALL	DELAY_ISR			
		
		INC 	R4				
		DJNZ	R5, INT1_LOOP	

		; 显示完一轮(1-6)，跳回开头继续循环，直到松手
		SJMP    INT1_LOOP      ; 【这里加一句SJMP，实现按住循环显示】

INT1_EXIT:
		; --- 3. 关灯清理 ---
		MOV 	P0, #0FFH
		MOV 	P1, #0FFH

		; --- 4. 恢复现场 ---
		POP 	DPL
		POP 	DPH
		
		; ========================================================
		; 【核心修改】在这里手动“倒带”
		; ========================================================
		POP 	PSW 			; 【关键】先恢复PSW，此时寄存器组切回了主程序(第0组)
								; 现在操作的 R3, R4, R5 都是主程序里的变量了

		DEC 	R3				; 位选退回上一位
		DEC 	R4				; 数字偏移量退回上一个
		INC 	R5				; 循环计数器加回1 (因为主程序里是DJNZ减1，我们要补回来)
		
		POP 	ACC
		RETI

; 中断专用的普通延时 (不需要检测标志位，否则会死循环)
DELAY_ISR:
		MOV 	R6, #200		
DI_1:	MOV 	R7, #4			
DI_2:	MOV 	R2, #229		
DI_3:	DJNZ	R2, DI_3	
		DJNZ	R7, DI_2	
		DJNZ	R6, DI_1	
		RET

TABLE_NUM:
		DB 0F9H, 0A4H, 0B0H, 99H, 92H, 82H

TABLE_ID:
		DB 0F9H  ; 1
		DB 0B0H  ; 3 

		END