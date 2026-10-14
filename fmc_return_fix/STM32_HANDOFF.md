# STM32 对接说明

STM32暂不修改寄存器地址或FMC参数：HCLK168 MHz、SDCLK56 MHz、CAS3、RPIPE2、RBURST0、16位半字访问。保持SDCR1=00004C00、SDCR2=000001D8。

FPGA本次修正当前半字的返回窗口。无需增加空读、重复读或地址平移；每次正常volatile uint16_t访问应得到该地址本身的数据。

下载新FPGA后复位STM32，重新发出完整SDRAM初始化（包括MRS0230）。等待网络恢复后发送FREG。采集尚未开始时预期：

| 项目 | 预期 |
|---|---|
| R00 / ID | ADFC |
| R02 / VERSION | 0100 |
| R04 / STATUS | 通常2061；取决于DDR是否已校准及当前状态 |
| R06 / EVENTS | 通常0000；已有事件时按实际事件位返回 |
| INIT / IERR | 初始化成功后1 / 0 |

四地址验收通过后再执行SET 1,1，检查START_ACCEPTED、DONE、VALID、READ_READY，随后GET。第一轮先用1 ms，再逐步扩大至200 ms。

原有COMMAND地址0xD000000A和数据窗口0xD0002000保持不变：START=1，READ_NEXT=2，ACK=3，RELEASE=4，CLEAR_EVENTS=5。原有分块握手与总长度/块序号/块长度地址保持不变。
