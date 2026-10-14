`timescale 1ns/1ps
`default_nettype none
// ��ѡ����ʱ��ת��ģ�飬����PLL��Ҳ���Ƿ�Ƶ��
// ��������Ѿ����ȶ�������100MHzʱ�ӣ��ɺ���ʱ��Դ�ṩ
// �ڰ弶XDCԼ�����������IOSTANDARD����ҪԤ�ȼ��BANK VCCO��ADC��ƽ��׼
module adc_clock_forward_7series (
    input  wire clk_100m,
    output wire adc_clk_p,
    output wire adc_clk_n
);
    wire forwarded;

    ODDR #(
        .DDR_CLK_EDGE("SAME_EDGE"),
        .INIT(1'b0),
        .SRTYPE("SYNC")
    ) u_oddr (
        .Q(forwarded),
        .C(clk_100m),
        .CE(1'b1),
        .D1(1'b1),
        .D2(1'b0),
        .R(1'b0),
        .S(1'b0)
    );

    OBUFDS u_obufds (
        .I(forwarded),
        .O(adc_clk_n),
        .OB(adc_clk_p)
    );

endmodule
`default_nettype wire
