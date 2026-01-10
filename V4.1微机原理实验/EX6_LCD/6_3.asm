RS_LCD      BIT P1.0          ; 定义 RS_LCD 位于 P1.0
            RW_LCD      BIT P1.1          ; 定义 RW_LCD 位于 P1.1
            EN_LCD      BIT P1.5          ; 定义 EN_LCD 位于 P1.5
            BUSY        BIT P0.7          ; 定义 BUSY 位于 P0.7
            LCD_DIS     EQU 38H           ; LCD 显示模式命令
            LCD_SHOW    EQU 0CH           ; LCD 显示开命令
            LCD_CURS    EQU 06H           ; LCD 光标移动命令
            LCD_CLR     EQU 01H           ; LCD 清屏命令
            TIMER_MODE  EQU 01H           ; 定时器模式1
            TIMER_HIGH  EQU 0DCH          ; 定时器初始值高字节
            TIMER_LOW   EQU 0H            ; 定时器初始值低字节
            ORG         0000H             ; 起始地址
            LJMP        START             ; 跳转到 START
            ORG         000BH             ; 定时器0中断向量地址
            LJMP        TIMER0_ISR        ; 跳转到定时器0中断处理程序

START:      MOV         SP, #60H          ; 初始化堆栈指针
            LCALL       LCD_INT           ; 调用 LCD 初始化子程序
            
            ; --- 初始化第一位显示 '0' ---
            MOV         A, #30H           ; 初始化显示字符 '0'
            MOV         R7, A             
            MOV         R6, #84H          ; 设置地址指针到第一行中间位置
            LCALL       WRITE_CMD         
            LCALL       WRITE_DAT         

            ; --- 显示 "+" ---
            MOV         DPTR, #PLUS       
            MOV         R0, #1
DISPLAY_PLUS_0:
            CLR         A
            MOVC        A, @A+DPTR
            MOV         R7, A
            INC         DPTR
            LCALL       WRITE_DAT
            DJNZ        R0, DISPLAY_PLUS_0
            
            ; --- 【修改】显示固定加数 '3' (原代码这里显示了1和5，删除多余的，改为3) ---
            MOV         A, #33H           ; 【修改】显示 "3" (ASCII码 33H)
            MOV         R7, A
            LCALL       WRITE_DAT

            ; --- 显示 "=" ---
            MOV         DPTR, #EQUAL      
            MOV         R0, #1
DISPLAY_EQUAL_0:
            CLR         A
            MOVC        A, @A+DPTR
            MOV         R7, A
            INC         DPTR
            LCALL       WRITE_DAT
            DJNZ        R0, DISPLAY_EQUAL_0

            ; --- 【修改】初始化显示结果 0+3=03 ---
            MOV         A, #30H           ; 【修改】结果十位显示 "0"
            MOV         R7, A
            MOV         R6, #89H          ; 设置地址指针
            LCALL       WRITE_CMD         
            LCALL       WRITE_DAT         
            
            MOV         A, #33H           ; 【修改】结果个位显示 "3"
            MOV         R7, A
            MOV         R6, #8AH          ; 设置地址指针
            LCALL       WRITE_CMD         
            LCALL       WRITE_DAT         

            ; --- 定时器设置 ---
            MOV         TMOD, #TIMER_MODE 
            MOV         TH0, #TIMER_HIGH  
            MOV         TL0, #TIMER_LOW   
            SETB        TR0               
            SETB        ET0               
            SETB        EA                
            SJMP        $                 ; 无限循环

LCD_INT:    MOV         R6, #LCD_DIS      ; 设置显示模式
            LCALL       WRITE_CMD         
            MOV         R6, #LCD_SHOW     ; 打开显示
            LCALL       WRITE_CMD         
            MOV         R6, #LCD_CURS     ; 设置光标移动
            LCALL       WRITE_CMD         
            MOV         R6, #LCD_CLR      ; 清屏
            LCALL       WRITE_CMD         
            RET                           

WRITE_DAT:  LCALL       READ              ; 调用读子程序
            SETB        RS_LCD            
            CLR         RW_LCD            
            MOV         P0, R7            
            SETB        EN_LCD            
            CLR         EN_LCD            
            RET                           

WRITE_CMD:  LCALL       READ              
            CLR         RS_LCD            
            CLR         RW_LCD            
            MOV         P0, R6            
            SETB        EN_LCD            
            CLR         EN_LCD            
            RET                           

READ:       MOV         P0, #0FFH         
            CLR         RS_LCD            
            SETB        RW_LCD            
            SETB        EN_LCD            
            JNB         BUSY, READ_END    
            CLR         EN_LCD            
            SJMP        READ              
READ_END:   RET                           

TIMER0_ISR: CLR         TR0               ; 停止定时器0
            MOV         TH0, #TIMER_HIGH  
            MOV         TL0, #TIMER_LOW   
            INC         R2                ; 溢出计数器自增
            CJNE        R2, #100, NOT_100 ; 1秒定时判断
            MOV         R2, #0            
            INC         R1                ; 计数器自增 (X)
            CJNE        R1, #10, NOT_10   
            MOV         R1, #0            ; 0-9循环
NOT_10:     
            ; --- 更新显示 X ---
            MOV         A, R1             
            ADD         A, #30H           ; 转ASCII
            MOV         R7, A             
            MOV         R6, #84H          ; 地址指针
            LCALL       WRITE_CMD         
            LCALL       WRITE_DAT         
            
            ; --- 显示 "+" ---
            MOV         DPTR, #PLUS       
            MOV         R0, #1
DISPLAY_PLUS:
            CLR         A
            MOVC        A, @A+DPTR
            MOV         R7, A
            INC         DPTR
            LCALL       WRITE_DAT
            DJNZ        R0, DISPLAY_PLUS
            
            ; --- 【修改】更新循环中显示的固定加数 '3' ---
            MOV         A, #33H           ; 【修改】显示 "3"
            MOV         R7, A
            LCALL       WRITE_DAT
            
            ; --- 显示 "=" ---
            MOV         DPTR, #EQUAL      
            MOV         R0, #1
DISPLAY_EQUAL:
            CLR         A
            MOVC        A, @A+DPTR
            MOV         R7, A
            INC         DPTR
            LCALL       WRITE_DAT
            DJNZ        R0, DISPLAY_EQUAL
            
            ; --- 【修改】计算 Z = X + 3 ---
            MOV         A, R1             ; 取出 X
            ADD         A, #3             ; 【修改】加上 3
            MOV         B, #10
            DIV         AB                ; A = 十位(商), B = 个位(余数)
            
            ADD         A, #30H           ; 十位转ASCII
            MOV         R7, A             
            MOV         R6, #89H          ; 结果十位显示地址
            LCALL       WRITE_CMD         
            LCALL       WRITE_DAT         
            
            MOV         A, B              ; 取出个位
            ADD         A, #30H           ; 个位转ASCII
            MOV         R7, A             
            MOV         R6, #8AH          ; 结果个位显示地址
            LCALL       WRITE_CMD         
            LCALL       WRITE_DAT         

NOT_100:    SETB        TR0               ; 重新启动定时器0
            RETI                          ; 返回中断

PLUS:       DB '+'                        
EQUAL:      DB '='                        
            END