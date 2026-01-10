; 功能：红外接收0~9按键码，数码管显示对应数字
ORG    0000H           ; 程序起始地址
LJMP   START           ; 跳转至主函数，跳过中断向量表
ORG    0013H           ; 外部中断1（INT1）向量地址
LJMP   INFARED         ; 中断触发后跳转至红外解码函数
ORG    0050H           ; 主函数起始地址（避开中断区）

START:
    MOV   TMOD, #01H   ; 定时器0设为模式1（16位计时），用于红外信号时长测量
    MOV   TL0, #00H    ; 定时器0低8位初值清零
    MOV   TH0, #00H    ; 定时器0高8位初值清零
    MOV   SP, #60H     ; 设置堆栈指针，避免栈溢出
    SETB  EA           ; 开启全局中断
    SETB  EX1          ; 使能外部中断1
    SETB  IT1          ; 外部中断1设为下降沿触发（检测红外信号）
    CLR   00H          ; 清零：时长低于下限标志（0=符合，1=不符合）
    CLR   01H          ; 清零：时长高于上限标志（0=符合，1=不符合）
    CLR   10H          ; 清零：单个红外比特值存储位（0/1）
    MOV   30H, #00H    ; 30H~33H：存储红外解码的4个字节（用户码/数据码等）
    MOV   31H, #00H
    MOV   32H, #80H
    MOV   33H, #00H
    MOV   R0, #0       ; R0：数码管显示数字索引（对应0~9）
    MOV   R4, #0       ; R4：TAB1按键码查表索引

; 数码管循环显示（持续刷新，避免闪烁）
DISP:
    MOV   DPTR, #TAB0  ; DPTR指向数码管显示码表
    MOV   P1, #0E8H    ; 数码管硬件使能（位选/段选控制）
    MOV   A, R0        ; 取显示索引
    MOVC  A, @A+DPTR   ; 查表获取对应数码管显示码
    MOV   P0, A        ; 输出至P0口，驱动数码管显示
    LCALL DELAY        ; 延时保持显示
    SJMP  DISP         ; 循环刷新

; 外部中断1服务函数：红外信号处理
INFARED:
    PUSH  ACC          ; 入栈保护现场（A、DPTR）
    PUSH  DPL
    PUSH  DPH
    CLR   EA           ; 关闭全局中断，防止解码混乱
    LCALL READ         ; 调用红外解码子程序，解析按键码存入32H

; 查表匹配：将红外按键码转换为显示索引
NUM:
    MOV   DPTR, #TAB1  ; DPTR指向红外按键码表
    MOV   A, R4        ; 取查表索引
    MOVC  A, @A+DPTR   ; 查表获取标准按键码
    CLR   C            
    SUBB  A, 32H       ; 与解码得到的按键码（32H）比较
    MOV   R5, A        ; 暂存比较结果
    INC   R4           ; 索引自增，准备遍历下一个
    MOV   A, R4        
    CLR   C            
    SUBB  A, #11       ; 判断是否遍历完TAB1（11个元素）
    JZ    END_INFA     ; 遍历完毕，跳转至中断结束
    MOV   A, R5        
    JNZ   NUM          ; 未匹配成功，继续查表
    MOV   A, R4        
    MOV   R0, A        ; 匹配成功，更新数码管显示索引

; 中断结束：恢复现场，开启中断
END_INFA:
    CLR   IE1          ; 清除外部中断1请求标志
    SETB  EA           ; 重新开启全局中断
    POP   DPH          ; 出栈恢复现场（先进后出）
    POP   DPL
    POP   ACC
    RETI               ; 中断返回

; 红外解码核心：验证引导码，读取4个字节数据
READ:
READHEAD:
    LCALL T_LOW        ; 计时红外引导码低电平时长
    LCALL T_HEAD1      ; 加载引导码低电平时间上下限
    LCALL COMPARE      ; 验证时长是否有效
    JB    00H, END_READ; 无效则退出
    JB    01H, END_READ

    LCALL T_HIGH       ; 计时引导码高电平时长
    LCALL T_HEAD2      ; 加载引导码高电平时间上下限
    LCALL COMPARE      ; 验证时长是否有效
    JB    00H, END_READ
    JB    01H, END_READ

    MOV   R1, #30H     ; 指向信息码存储起始地址30H
    MOV   R2, #4       ; 需读取4个字节的红外信息码
READBYTE:
    MOV   R3, #8       ; 每个字节8个比特位
    CLR   A            
READBIT:
    RL    A            ; 左移腾出最低位，存储新比特
    ACALL ONEBIT       ; 读取单个比特值（存入10H）
    MOV   C, 10H       
    MOV   ACC.0, C     ; 存入A的最低位
    DJNZ  R3, READBIT  ; 读取完8位
    MOV   @R1, A       ; 存储1个字节到30H~33H
    INC   R1           
    DJNZ  R2, READBYTE ; 读取完4个字节
END_READ:
    RET

; 配置各类红外信号的时间上下限（用于有效性验证）
T_HEAD1:               ; 引导码低电平（8.5~9.5ms）
    MOV   44H, #34
    MOV   43H, #51
    MOV   42H, #25
    MOV   41H, #154
    RET
T_HEAD2:               ; 引导码高电平（4~5ms）
    MOV   44H, #18
    MOV   43H, #0
    MOV   42H, #14
    MOV   41H, #102
    RET
T_BIT1:                ; 比特位低电平（340~780us）
    MOV   44H, #2
    MOV   43H, #206
    MOV   42H, #1
    MOV   41H, #59
    RET
T_BIT2:                ; 比特位高电平（1.45~1.9ms）
    MOV   44H, #6
    MOV   43H, #214
    MOV   42H, #5
    MOV   41H, #65
    RET

; 计时红外信号低电平时长
T_LOW:
    MOV   TL0, #00H
    MOV   TH0, #00H
    SETB  P3.3
    SETB  TR0          ; 启动定时器0
    JNB   P3.3, $      ; 等待低电平结束
    CLR   TR0          ; 停止计时
    RET

; 计时红外信号高电平时长
T_HIGH:
    MOV   TL0, #00H
    MOV   TH0, #00H
    SETB  P3.3
    SETB  TR0          ; 启动定时器0
    JB    P3.3, $      ; 等待高电平结束
    CLR   TR0          ; 停止计时
    RET

; 比较实测时长与上下限，设置标志位
COMPARE:
    PUSH  ACC
    CLR   00H
    CLR   01H
    CLR   C
    MOV   A, 43H
    SUBB  A, TL0       ; 与上限比较
    MOV   A, 44H
    SUBB  A, TH0
    MOV   01H, C       ; 高于上限标志
    CLR   C
    MOV   A, TL0
    SUBB  A, 41H       ; 与下限比较
    MOV   A, TH0
    SUBB  A, 42H
    MOV   00H, C       ; 低于下限标志
    POP   ACC
    RET

; 读取单个红外比特位（0/1）
ONEBIT:
    CLR   10H
    ACALL  T_LOW
    ACALL  T_BIT1
    LCALL  COMPARE     ; 验证低电平时长
    JB     00H, END_BIT
    JB     01H, END_BIT
BIT_0:
    ACALL  T_HIGH
    ACALL  T_BIT1
    LCALL  COMPARE     ; 验证高电平时长，判断是否为0
    JB     00H, END_BIT
    JB     01H, BIT_1
    SJMP   END_BIT
BIT_1:
    ACALL  T_BIT2
    LCALL  COMPARE     ; 验证高电平时长，判断是否为1
    JB     00H, END_BIT
    JB     01H, END_BIT
    SETB   10H         ; 标记为比特1
END_BIT:
    RET

; 查表表定义
TAB0:   DB 7FH,0C0H,0F9H,0A4H,0B0H,99H,92H,82H,0F8H,80H,90H  ; 0~9数码管显示码
TAB1:   DB 68H,30H,18H,7AH,10H,38H,5AH,42H,4AH,52H            ; 0~9红外按键码

; 简单延时函数（防止数码管闪烁）
DELAY:
    MOV   R6, #20
DEL1:
    MOV   R7, #50
DEL2:
    DJNZ  R7, DEL2
    DJNZ  R6, DEL1
    RET
END                     ; 程序结束