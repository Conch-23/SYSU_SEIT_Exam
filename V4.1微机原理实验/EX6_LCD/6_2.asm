RS_LCD      BIT P1.0            ; LCD寄存器选择信号(0:指令/1:数据)
RW_LCD      BIT P1.1            ; LCD读写信号(0:写/1:读)
EN_LCD      BIT P1.5            ; LCD使能信号
BUSY        BIT P0.7            ; LCD忙标志位(D7)

LCD_DIS     EQU 38H             ; 指令:设置8位格式,2行显示,5x7点阵
LCD_SHOW    EQU 0CH             ; 指令:开显示,关光标,不闪烁
LCD_CURS    EQU 06H             ; 指令:光标右移,屏幕不移动
LCD_CLR     EQU 01H             ; 指令:清屏
LINE        EQU 1               ; 定义行号(第2行)
ROW         EQU 0               ; 定义列号(第0列)
ADDR_INT    EQU LINE*40H+ROW    ; 计算DDRAM显示起始地址

            ORG     0000H       ; 复位入口地址
            LJMP    START       ; 跳转至主程序
            ORG     001BH       ; 定时器1中断向量地址
            LJMP    TIMER       ; 转定时器1服务程序
            ORG     0050H       ; 主程序起始地址


START:      MOV     SP, #60H    ; 初始化堆栈指针
            MOV     TMOD, #10H  ; 设置T1为模式1(16位定时)
            MOV     TL1, #0FDH  ; 装载T1初值低字节(50ms@11.0592MHz)
            MOV     TH1, #4BH   ; 装载T1初值高字节
            MOV     IE, #88H    ; 开启总中断及定时器1中断
            MOV     R2, #0      ; 初始化显示的数字(0-9)
            MOV     R1, #0      ; 初始化50ms计数器
            SETB    TR1         ; 启动定时器1
            LCALL   LCD_INT     ; 调用LCD初始化子程序
            LJMP    $           ; 死循环等待中断

LCD_INT:    MOV     R6, #LCD_DIS
            LCALL   WRITE_CMD   ; 写入显示模式指令
            MOV     R6, #LCD_SHOW
            LCALL   WRITE_CMD   ; 写入开显示指令
            MOV     R6, #LCD_CURS
            LCALL   WRITE_CMD   ; 写入光标移动指令
            MOV     R6, #LCD_CLR
            LCALL   WRITE_CMD   ; 写入清屏指令
            MOV     A, #ADDR_INT
            ORL     A, #80H     ; 最高位置1,转换为DDRAM地址指令
            MOV     R6, A
            LCALL   WRITE_CMD   ; 写入显示地址
            RET

WRITE_DAT:  LCALL   READ        ; 检测忙信号
            SETB    RS_LCD      ; 选择数据寄存器
            CLR     RW_LCD      ; 选择写操作
            MOV     P0, R7      ; 数据送入P0口
            SETB    EN_LCD      ; 产生使能高脉冲
            CLR     EN_LCD      ; 下降沿锁存数据
            RET

WRITE_CMD:  LCALL   READ        ; 检测忙信号
            CLR     RS_LCD      ; 选择指令寄存器
            CLR     RW_LCD      ; 选择写操作
            MOV     P0, R6      ; 指令送入P0口
            SETB    EN_LCD      ; 产生使能高脉冲
            CLR     EN_LCD      ; 下降沿锁存指令
            RET

READ:       MOV     P0, #0FFH   ; P0口置1(作为输入准备)
            CLR     RS_LCD      ; 选择指令寄存器(读状态)
            SETB    RW_LCD      ; 选择读操作
            SETB    EN_LCD      ; 使能LCD输出
            JNB     BUSY, READ_END ; 检测D7位,为0则空闲跳转
            CLR     EN_LCD      ; 拉低使能
            SJMP    READ        ; 忙则循环检测
READ_END:   RET                 ; 返回


TIMER:      MOV     TL1, #0FDH  ; 重装T1初值低字节
            MOV     TH1, #4BH   ; 重装T1初值高字节
            INC     R1          ; 50ms计数器加1
            CJNE    R1, #20, ENDT ; 判断是否满1秒(20*50ms)
            MOV     R1, #0      ; 清零50ms计数器
            
            LCALL   LCD_INT     ; 重置LCD(通常只需清屏或定位)
            MOV     A, R2       ; 取当前计数值
            ADD     A, #30H     ; 转换为ASCII码
            MOV     R7, A       ; 存入发送缓冲区
            LCALL   WRITE_DAT   ; 显示当前数字
            
            INC     R2          ; 数字加1
            CJNE    R2, #10, ENDT ; 判断是否计满10
            MOV     R2, #0      ; 计满清零
ENDT:       RETI                ; 中断返回

            END