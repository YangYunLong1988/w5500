module W5500_PRO( 
						clk,rst_n,
						W5500_RST,
						sck,mosi,miso,SCSn
						);
input clk;
input rst_n;
//input start_w5500;		//启动W5500
wire [7:0] rx_data_1;
wire [15:0] rx_data_2;
wire  tx_ready;
wire  rx_ready;
wire  rx_flag;
wire [7:0] buff_8;
//input clk_in1;
//input sys_clk_n;

reg tx_en;
reg rx_en;
output reg W5500_RST;
reg [2:0] tx_len;
reg [1:0] rx_len;
reg [71:0] tx_data;
reg [15:0] rx_size;
output sck;
output mosi;
input  miso;
output SCSn;
 
wire clk;
wire rst_n;
wire locked;
reg [7:0] mem [0:99];
 
parameter	CLKSPI = 9'd500;
parameter	S_RX_SIZE	 =  16'd2048;
//寄存器参数定义
parameter 	PHYCFGR = 16'h002e;
parameter	VDM	 =	 8'h00;	//不定长数据长度
parameter	RWB_READ	  =  8'h00;	  //读寄存器的数据
parameter 	RWB_WRITE	=	8'h04;	//向寄存器写数据
parameter	COMMON_R	= 	8'h00;
parameter	MR	=	16'h0000;
parameter	RST	=	8'h80;
parameter	GAR	=	16'h0001;
parameter	SUBR	=	16'h0005;
parameter	SHAR	=	16'h0009;
parameter	SIPR	=	16'h000f;
parameter	Sn_RXBUF_SIZE	=	16'h001e;
parameter	Sn_TXBUF_SIZE	=	16'h001f;
parameter	RTR	= 	16'h0019;
parameter	RCR	=	16'h001b;
parameter	Sn_MSSR	=	16'h0012;
parameter	Sn_PORT	=	16'h0004;
parameter	Sn_DPORTR	=	16'h0010;
parameter	Sn_DIPR	=	16'h000c;
parameter	Sn_MR		=	16'h0000;
parameter	MR_TCP		=	8'h01;
parameter	Sn_CR		=	16'h0001;
parameter	OPEN			=	8'h01;
parameter	Sn_SR		=	16'h0003;
parameter	CLOSE		=	8'h10;
parameter	CONNECT	=	8'h04;
parameter	SOCK_INIT	=	8'h13;
parameter	SIR			=	16'h0017;
parameter	Sn_IR		=	16'h0002;
parameter	Sn_RX_RSR	=	16'h0026;
parameter	Sn_RX_RD		=	16'h0028;	

parameter	S0_INT		=	8'h01;
parameter	IR_CON		=	8'h01;
parameter	IR_DISCON	=	8'h02;
parameter	IR_SEND_OK	=	8'h10;
parameter	IR_RECV		=	8'h04;
parameter	IR_TIMEOUT	=	8'h08;
parameter	S_CONN			=	8'h02;
parameter	S_TRANSMITOK	=	8'h02;
parameter	S_RECEIVE		=	8'h01;
parameter	RECV		=	8'h40;

//W5500读写帧组合
parameter	Read_PHYCFGR	= {PHYCFGR,(VDM | RWB_READ | COMMON_R),48'h000000000000};
parameter	SoftWare_RST	=	{MR,(VDM | RWB_WRITE | COMMON_R),RST,40'h0000000000};
parameter	Set_Gateway	=	{GAR,(VDM | RWB_WRITE | COMMON_R),8'hc0,8'ha8,8'h64,8'h01,16'h0000};	
parameter	Set_Mask	=	{SUBR,(VDM | RWB_WRITE | COMMON_R),8'hff,8'hff,8'hff,8'h00,16'h0000};
parameter	Set_PHYADDR		=	{SHAR,(VDM | RWB_WRITE | COMMON_R),8'h0c,8'h29,8'hab,8'h7c,8'h00,8'h01};	//本机物理地址
parameter	Set_IPADDR	=	{SIPR,(VDM | RWB_WRITE | COMMON_R),8'hc0,8'ha8,8'h64,8'h64,16'h0000};	//本机IP
parameter	Set_TXBUFF	=	{Sn_TXBUF_SIZE,(VDM | RWB_WRITE | 8'h08),8'h02,40'h0000000000};
parameter	Set_RXBUFF	=	{Sn_RXBUF_SIZE,(VDM | RWB_WRITE | 8'h08),8'h02,40'h0000000000};
parameter	Set_RETXTIME	=	{RTR,(VDM | RWB_WRITE | COMMON_R),8'h07,8'hd0,32'h00000000};
parameter	Set_TXTIMES	=	{RCR,(VDM | RWB_WRITE | COMMON_R),8'h08,40'h0000000000};

parameter	Set_FP	=	{Sn_MSSR,(VDM | RWB_WRITE | 8'h08),8'h05,8'hb4,32'h00000000};
parameter	Set_PORT0	=	{Sn_PORT,(VDM | RWB_WRITE | 8'h08),8'h13,8'h88,32'h00000000};				//本机端口号5000
parameter	Set_DESPORT0	=	{Sn_DPORTR,(VDM | RWB_WRITE | 8'h08),8'h17,8'h70,32'h00000000};	//目的端口号6000
parameter	Set_DESIP0	=	{Sn_DIPR,(VDM | RWB_WRITE | 8'h08),8'hc0,8'ha8,8'h64,8'h69,16'h0000};	//目的IP 9b

parameter	Set_TCP		=	{Sn_MR,(VDM | RWB_WRITE | 8'h08),MR_TCP,40'h0000000000};
parameter	Set_OPEN	=	{Sn_CR,(VDM | RWB_WRITE | 8'h08),OPEN,40'h0000000000};
parameter	Read_SR	=	{Sn_SR,(VDM | RWB_READ | 8'h08),48'h000000000000};
parameter	Set_CLOSE	=	{Sn_CR,(VDM | RWB_WRITE | 8'h08),CLOSE,40'h0000000000};
parameter	Set_CONN	=	{Sn_CR,(VDM | RWB_WRITE | 8'h08),CONNECT,40'h0000000000};

parameter	Set_READSIR	=	{SIR,(VDM | RWB_READ | COMMON_R),48'h000000000000};
parameter	Set_READSNIR	=	{Sn_IR,(VDM | RWB_READ | 8'h08),48'h000000000000};

parameter	Set_RX_RSR	=	{Sn_RX_RSR,(VDM | RWB_READ | 8'h08),48'h000000000000};
parameter	Set_RX_RD	=	{Sn_RX_RD,(VDM | RWB_READ | 8'h08),48'h000000000000};




//调用SPI模块

SPI	SPI(	
.clk    			(clk),
.rst_n			(rst_n),
.sck			(sck),
.mosi			(mosi),
.miso			(miso),
.rx_data_1		(rx_data_1),
.rx_data_2		(rx_data_2),
.tx_data			(tx_data),
.tx_en			(tx_en),
.rx_en			(rx_en),
.tx_len			(tx_len),
.rx_len			(rx_len),
.rx_size			(rx_size),
.tx_ready		(tx_ready),
.rx_ready		(rx_ready),
.rx_flag			(rx_flag),
.SCSn			(SCSn),
.buff_8			(buff_8)

				);
				
/* clk_wiz_0  u_clk_wiz_0
   (
    // Clock out ports
    .clk_out1(clk),     // output clk_out1
    // Status and control signals
    //.reset(), // input reset
    .locked(locked),       // output locked
   // Clock in ports
	.clk_in1(clk_in1));  */


/* vio_0 u_vio_0 (
  .clk(clk),                // input wire clk
  .probe_out0(rst_n)  // output wire [0 : 0] probe_out0
); */
	
//W5500配置部分分为几个状态机编写 
//1、硬件复位状态机
//2、W5500模块初始化配置状态机
//3、W5500端口初始化配置状态机
//4、数据处理状态机，不断查询状态寄存器的数据，判断当前W5500模块的状态
//外环状态机
reg [2:0] W5500_STATE;
parameter	IDLE	=	3'd0;
parameter	HARD_RST	=	3'd1;
parameter	W5500_INIT	=	3'd2;
parameter	W5500_SOCKET_INIT	=	3'd3;
parameter	SOCKET_WHILE	=	3'd4;
//下面三个状态放在SOCKET_WHILE下面
reg [2:0] SOCKET_STATE;
parameter	SOCKET_IDLE	=	3'd0;
parameter	SOCKET_CONNECT	=	3'd1;
parameter	W5500_STATUS_CHECK 	=	3'd2;
parameter	W5500_READ_MEM	=	3'd3;
parameter	W5500_WRITE_MEM	=	3'd4;	//写w5500的缓存
//1、硬件复位状态机
reg [2:0] Hardware_State;
parameter	Hard_IDLE	 =	 3'd0;
parameter	Hard_RST_LOW 	= 	3'd1;
parameter	Hard_DELAY50 	=	 3'd2;
parameter	Hard_RST_HIGH 	= 	3'd3;
parameter	Hard_DELAY200 	= 	3'd4;
parameter	Hard_WAIT_CONNECT 	= 	3'd5;
//2、W5500模块初始化状态机
reg [3:0]	W5500_INIT_State;
parameter	W5500_INIT_IDLE	=	4'd0;
parameter	W5500_INIT_SOFTWARE_RST	=	4'd1;
parameter	W5500_INIT_DELAY10	=	4'd2;
parameter	W5500_INIT_SET_GATEWAY	=	4'd3;		//设置网关
parameter	W5500_INIT_SET_MASK	=	4'd4;			//设置子网掩码
parameter	W5500_INIT_SET_PHYADDR	=	4'd5;		//设置本机物理地址
parameter	W5500_INIT_SET_IPADDR	=	4'd6;		//设置本机IP地址
parameter	W5500_INIT_SET_RXBUFF	=	4'd7;		//设置接收缓冲区大小
parameter	W5500_INIT_SET_TXBUFF	=	4'd8;		//设置发送缓冲区大小
parameter	W5500_INIT_SET_RETXTIME	=	4'd9;		//设置重发时间
parameter	W5500_INIT_SET_TXTIMES	=	4'd10;		//设置重发次数
//3、W5500socket初始化状态机
reg [2:0]	SOCKET_INIT_State;
parameter	SOCKET_INIT_IDLE	=	3'd0;
parameter	SOCKET_INIT_FP		=	3'd1;
parameter	SOCKET_INIT_PORT0	=	3'd2;
parameter	SOCKET_INIT_DESPORT0	=	3'd3;
parameter	SOCKET_INIT_DESIP0	= 3'd4;
//4、SOCKET建立连接状态机
reg [2:0]	SOCKET_CONN_State;
parameter	SOCKET_CONN_IDLE	=	3'd0;
parameter	SOCKET_CONN_TCP		=	3'd1;
parameter	SOCKET_CONN_OPEN	=	3'd2;
parameter	SOCKET_CONN_DELAY5	=	3'd3;
parameter	SOCKET_CONN_READSR	=	3'd4;
parameter	SOCKET_CONN_CLOSE	=	3'd5;
parameter	SOCKET_CONN_SETCONN	=	3'd6; 
parameter	SOCKET_CONN_READSNR	=	3'd7;/////读状态寄存器的内容，验证设置连接成功
//5、SOCKET状态检查状态机
reg [2:0] SOCKET_CHACK_State;
parameter	SOCKET_CHACK_IDLE	=	3'd0;
parameter	SOCKET_CHACK_READSIR	=	3'd1;
parameter	SOCKET_CHACK_READSNIR	=	3'd2;
parameter	SOCKET_CHACK_WRSNIR		=	3'd3;
parameter	SOCKET_CHACK_IFIR		=	3'd4;
parameter	SOCKET_CHACK_CLOSE	=	3'd5;
//6、W5500_READ_MEM读取缓存中数据的状态机
reg [2:0] READ_MEM_State;
parameter	READ_MEM_IDLE		=	3'd0;
parameter	READ_MEM_READ_RX_RSR	=	3'd1;
parameter	READ_MEM_READ_RX_RD		=	3'd2;
parameter	READ_MEM_REC_DATA		=	3'd3;
parameter	READ_MEM_WR_RX_RD	=	3'd4;
parameter	READ_MEM_WR_RECV		=	3'd5;
parameter	READ_MEM_FULL_1			=	3'd6;
parameter	READ_MEM_TRANS			=	3'd7;
//发送数据的状态机，即向W5500缓存中写数据
reg [2:0] WRITE_MEM_State;
parameter	WRITE_MEM_IDLE		=	3'd0;




//本状态机中用到的延时计数器
//延时50ms计数器
reg [23:0] Delay50_1;
always @(posedge clk or negedge rst_n)
	if (!rst_n)	Delay50_1 <= 24'd0;
	else if (Hardware_State == Hard_DELAY50)	Delay50_1 <= Delay50_1 + 1'b1;
//延时200ms计数器
reg [23:0] Delay200_1;
always @(posedge clk or negedge rst_n)
	if (!rst_n)	Delay200_1 <= 24'd0;
	else if (Hardware_State == Hard_DELAY200)	Delay200_1 <= Delay200_1 + 1'b1;
	else Delay200_1 <= 24'd0;
//延时10ms计数器
reg [23:0] Delay10_1;
always @(posedge clk or negedge rst_n)
	if (!rst_n)	Delay10_1 <= 24'd0;
	else if (W5500_INIT_State == W5500_INIT_DELAY10)		Delay10_1 <= Delay10_1 + 1'b1;
	else Delay10_1 <= 24'd0;
//延时5ms计数器
reg [23:0] Delay5_1;
always @(posedge clk or negedge rst_n)
	if (!rst_n)	Delay5_1 <= 24'd0;
	else if (SOCKET_CONN_State == SOCKET_CONN_DELAY5)	Delay5_1 <= Delay5_1 + 1'b1;
	else Delay5_1 <= 24'd0;
//延时8个时钟周期
//reg [2:0] cnt_RST;
reg [2:0] cnt_MASK;
reg [2:0] cnt_PHYADDR;
reg [2:0] cnt_IPADDR;
reg [2:0] cnt_RXBUFF;
reg [2:0] cnt_TXBUFF;
reg [2:0] cnt_RETXTIME;
reg [2:0] cnt_TXTIMES;
reg [2:0] cnt_FP;
reg [2:0] cnt_PORT0;
reg [2:0] cnt_DESPORT0;
reg [2:0] cnt_DESIP0;
reg [2:0] cnt_TCP;
reg [2:0] cnt_OPEN;
//reg [2:0] cnt_CLOSE;
//reg [2:0] cnt_SETCONN;
reg [2:0] cnt_READSIR;
reg [2:0] cnt_READSNIR;
reg [2:0] cnt_SOCKET_CLOSE;
reg [2:0] cnt_RX_RSR;
reg [2:0] cnt_RX_RD;
reg [2:0] cnt_REC_DATA;
reg [2:0] cnt_WR_RX_RD	;
reg [2:0] cnt_WR_RECV;
reg [2:0] cnt_FULL_1;
reg [2:0] cnt_SETCONN;
reg [2:0] cnt_READSNR;	
reg [2:0] cnt_WRSNIR;

always @(posedge clk or negedge rst_n)
	if (!rst_n)	
		begin
			//cnt_RST <= 3'd0;
			cnt_MASK <= 3'd0;
			cnt_PHYADDR <= 3'd0;
			cnt_IPADDR <= 3'd0;
			cnt_RXBUFF <= 3'd0;
			cnt_TXBUFF <= 3'd0;
			cnt_RETXTIME <= 3'd0;
			cnt_TXTIMES <= 3'd0;
			cnt_FP <= 3'd0;
			cnt_PORT0 <= 3'd0;
			cnt_DESPORT0 <= 3'd0;
			cnt_DESIP0 <= 3'd0;
			cnt_TCP<= 3'd0;
			cnt_OPEN <= 3'd0;
			//cnt_CLOSE <= 3'd0;
			//cnt_SETCONN <= 3'd0;
			cnt_READSIR	<= 3'd0;
			cnt_READSNIR <= 3'd0;
			cnt_SOCKET_CLOSE <= 3'd0;
			cnt_RX_RSR	<= 3'd0;
			cnt_RX_RD  <= 3'd0;
			cnt_WR_RX_RD	<=	3'd0;
			cnt_WR_RECV		<=	3'd0;
			cnt_REC_DATA	<=	3'd0;
			cnt_FULL_1	<= 3'd0;
			cnt_SETCONN <= 3'd0;
			cnt_READSNR <= 3'd0;
			cnt_WRSNIR <= 3'd0;
		end
	else
		begin 
			// if (W5500_INIT_State == W5500_INIT_SOFTWARE_RST && cnt_RST < 3'd7)	cnt_RST <= cnt_RST + 1'b1;
			// else 	cnt_RST <= cnt_RST;
			if (W5500_INIT_State == W5500_INIT_SET_MASK && cnt_MASK < 3'd7)	cnt_MASK <= cnt_MASK + 1'b1;
			else 	cnt_MASK <= cnt_MASK;
			if (W5500_INIT_State == W5500_INIT_SET_PHYADDR && cnt_PHYADDR < 3'd7)	  cnt_PHYADDR <= cnt_PHYADDR + 1'b1;
			else 	cnt_PHYADDR <= cnt_PHYADDR;			
			if (W5500_INIT_State == W5500_INIT_SET_IPADDR && cnt_IPADDR < 3'd7)	cnt_IPADDR <= cnt_IPADDR + 1'b1;
			else 	cnt_IPADDR <= cnt_IPADDR;			
			if (W5500_INIT_State == W5500_INIT_SET_RXBUFF && cnt_RXBUFF < 3'd7)	cnt_RXBUFF <= cnt_RXBUFF + 1'b1;
			else 	cnt_RXBUFF <= cnt_RXBUFF;	
			if (W5500_INIT_State == W5500_INIT_SET_TXBUFF && cnt_TXBUFF < 3'd7)	cnt_TXBUFF <= cnt_TXBUFF + 1'b1;
			else 	cnt_TXBUFF <= cnt_TXBUFF;				
			if (W5500_INIT_State == W5500_INIT_SET_RETXTIME && cnt_RETXTIME < 3'd7)	cnt_RETXTIME <= cnt_RETXTIME + 1'b1;
			else 	cnt_RETXTIME <= cnt_RETXTIME;
			if (W5500_INIT_State == W5500_INIT_SET_TXTIMES && cnt_TXTIMES < 3'd7)	cnt_TXTIMES <= cnt_TXTIMES + 1'b1;//改动
			else 	cnt_TXTIMES <= cnt_TXTIMES;//改动
			
			if (SOCKET_INIT_State == SOCKET_INIT_FP && cnt_FP < 3'd7)		cnt_FP <= cnt_FP + 1'b1;
			else cnt_FP <= cnt_FP;
			if (SOCKET_INIT_State == SOCKET_INIT_PORT0 && cnt_PORT0 < 3'd7)		cnt_PORT0 <= cnt_PORT0 + 1'b1;
			else cnt_PORT0 <= cnt_PORT0;
			if (SOCKET_INIT_State == SOCKET_INIT_DESPORT0 && cnt_DESPORT0 < 3'd7)		cnt_DESPORT0 <= cnt_DESPORT0 + 1'b1;
			else cnt_DESPORT0 <= cnt_DESPORT0;
			if (SOCKET_INIT_State == SOCKET_INIT_DESIP0 && cnt_DESIP0 < 3'd7)		cnt_DESIP0 <= cnt_DESIP0 + 1'b1;
			else cnt_DESIP0 <= cnt_DESIP0;
			
			if (SOCKET_CONN_State == SOCKET_CONN_TCP && cnt_TCP < 3'd7)		cnt_TCP <= cnt_TCP + 1'b1;
			else if (SOCKET_CONN_State == SOCKET_CONN_TCP && cnt_TCP == 3'd7)	cnt_TCP <= cnt_TCP;
			else cnt_TCP <= 3'd0;
			
			if (SOCKET_CONN_State == SOCKET_CONN_OPEN && cnt_OPEN < 3'd7)		cnt_OPEN <= cnt_OPEN + 1'b1;
			else if (SOCKET_CONN_State == SOCKET_CONN_OPEN && cnt_OPEN == 3'd7)	cnt_OPEN <= cnt_OPEN;
			else cnt_OPEN <= 3'd0;
			
			if (SOCKET_CONN_State == SOCKET_CONN_SETCONN && cnt_SETCONN < 3'd7)		cnt_SETCONN <= cnt_SETCONN + 1'b1;
			else if (SOCKET_CONN_State == SOCKET_CONN_SETCONN && cnt_SETCONN == 3'd7)	cnt_SETCONN <= cnt_SETCONN;
			else cnt_SETCONN <= 3'd0;			
			
			if (SOCKET_CONN_State == SOCKET_CONN_READSNR && cnt_READSNR < 3'd7)		cnt_READSNR <= cnt_READSNR + 1'b1;
			else if (SOCKET_CONN_State == SOCKET_CONN_READSNR && cnt_READSNR == 3'd7)	cnt_READSNR <= cnt_READSNR;
			else cnt_READSNR <= 3'd0;				
			
			
			
			// if (SOCKET_CONN_State == SOCKET_CONN_CLOSE && cnt_CLOSE < 3'd7)		cnt_CLOSE <= cnt_CLOSE + 1'b1;
			// else if (SOCKET_CONN_State == SOCKET_CONN_CLOSE && cnt_CLOSE == 3'd7) cnt_CLOSE <= cnt_CLOSE;
			// else cnt_CLOSE <=3'd0;
			
			// if (SOCKET_CONN_State == SOCKET_CONN_SETCONN && cnt_SETCONN < 3'd7)		cnt_SETCONN <= cnt_SETCONN + 1'b1;
			// else if (SOCKET_CONN_State == SOCKET_CONN_SETCONN && cnt_SETCONN == 3'd7) cnt_SETCONN <= cnt_SETCONN;	
			// else 	cnt_SETCONN <= 3'd0;	
			//////这里需要考虑一下!!!!!!!
			if (SOCKET_CHACK_State == SOCKET_CHACK_READSIR && cnt_READSIR < 3'd7)		cnt_READSIR <= cnt_READSIR + 1'b1;
			else if (SOCKET_CHACK_State == SOCKET_CHACK_READSIR  && cnt_READSIR == 3'd7)  cnt_READSIR <= cnt_READSIR;
			else cnt_READSIR <= 3'd0;
			
			if (SOCKET_CHACK_State == SOCKET_CHACK_READSNIR && cnt_READSNIR < 3'd7)		cnt_READSNIR <= cnt_READSNIR + 1'b1;
			else if (SOCKET_CHACK_State == SOCKET_CHACK_READSNIR  && cnt_READSNIR == 3'd7)  cnt_READSNIR <= cnt_READSNIR;
			else cnt_READSNIR <= 3'd0;
			
			if (SOCKET_CHACK_State == SOCKET_CHACK_WRSNIR && cnt_WRSNIR < 3'd7)		cnt_WRSNIR <= cnt_WRSNIR + 1'b1;
			else if (SOCKET_CHACK_State == SOCKET_CHACK_WRSNIR  && cnt_WRSNIR == 3'd7)  cnt_WRSNIR <= cnt_WRSNIR;
			else cnt_WRSNIR <= 3'd0;			
			
			if (SOCKET_CHACK_State == SOCKET_CHACK_CLOSE && cnt_SOCKET_CLOSE < 3'd7)		cnt_SOCKET_CLOSE <= cnt_SOCKET_CLOSE + 1'b1;
			else if (SOCKET_CHACK_State == SOCKET_CHACK_CLOSE  && cnt_SOCKET_CLOSE == 3'd7)  cnt_SOCKET_CLOSE <= cnt_SOCKET_CLOSE;
			else cnt_SOCKET_CLOSE <= 3'd0;
			
			if (READ_MEM_State == READ_MEM_READ_RX_RSR && cnt_RX_RSR < 3'd7)		cnt_RX_RSR <= cnt_RX_RSR + 1'b1;
			else if (READ_MEM_State == READ_MEM_READ_RX_RSR  && cnt_RX_RSR == 3'd7)  cnt_RX_RSR <= cnt_RX_RSR;
			else cnt_RX_RSR <= 3'd0;			
			
			if (READ_MEM_State == READ_MEM_READ_RX_RD && cnt_RX_RD < 3'd7)		cnt_RX_RD <= cnt_RX_RD + 1'b1;
			else if (READ_MEM_State == READ_MEM_READ_RX_RD  && cnt_RX_RD == 3'd7)  cnt_RX_RD <= cnt_RX_RD;
			else cnt_RX_RD <= 3'd0;			

			if (READ_MEM_State == READ_MEM_WR_RECV && cnt_WR_RECV < 3'd7)		cnt_WR_RECV <= cnt_WR_RECV + 1'b1;
			else if (READ_MEM_State == READ_MEM_WR_RECV  && cnt_WR_RECV == 3'd7)  cnt_WR_RECV <= cnt_WR_RECV;
			else cnt_WR_RECV <= 3'd0;			

			if (READ_MEM_State == READ_MEM_REC_DATA && cnt_REC_DATA < 3'd7)		cnt_REC_DATA <= cnt_REC_DATA + 1'b1;
			else if (READ_MEM_State == READ_MEM_REC_DATA  && cnt_REC_DATA == 3'd7)  cnt_REC_DATA <= cnt_REC_DATA;
			else cnt_REC_DATA <= 3'd0;	

			if (READ_MEM_State == READ_MEM_WR_RX_RD && cnt_WR_RX_RD < 3'd7)		cnt_WR_RX_RD <= cnt_WR_RX_RD + 1'b1;
			else if (READ_MEM_State == READ_MEM_WR_RX_RD  && cnt_WR_RX_RD == 3'd7)  cnt_WR_RX_RD <= cnt_WR_RX_RD;
			else cnt_WR_RX_RD <= 3'd0;	

			if (READ_MEM_State == READ_MEM_WR_RECV && cnt_WR_RECV < 3'd7)		cnt_WR_RECV <= cnt_WR_RECV + 1'b1;
			else if (READ_MEM_State == READ_MEM_WR_RECV  && cnt_WR_RECV == 3'd7)  cnt_WR_RECV <= cnt_WR_RECV;
			else cnt_WR_RECV <= 3'd0;		

			if (READ_MEM_State == READ_MEM_FULL_1 && cnt_FULL_1 < 3'd7)		cnt_FULL_1 <= cnt_FULL_1 + 1'b1;
			else if (READ_MEM_State == READ_MEM_FULL_1  && cnt_FULL_1 == 3'd7)  cnt_FULL_1 <= cnt_FULL_1;
			else cnt_FULL_1 <= 3'd0;	
			
		end 
//计数十个时钟周期，用于等待ready信号拉低	
reg [3:0] cnt_10;
always @(posedge clk or negedge rst_n)
	if (!rst_n)	cnt_10 <= 4'd0;
	else if (tx_en == 1'b1 || rx_en == 1'b1)		
		begin
			if (cnt_10 < 4'd10)	cnt_10 <= cnt_10 +1'b1;
			else cnt_10 <= cnt_10;
		end
	else if (tx_en == 1'b0 && rx_en == 1'b0)  cnt_10 <= 4'd0;
	
//捕获rx_flag上升沿
reg 	rx_flag_1;
reg	rx_flag_2;
reg 	rx_flag_3;
always @(posedge clk or negedge rst_n)
	if (!rst_n)
		begin
			rx_flag_1 <= 1'b0;
			rx_flag_2 <= 1'b0;
			rx_flag_3 <= 1'b0;
		end
	else
		begin
			rx_flag_1 <= rx_flag;
			rx_flag_2 <= rx_flag_1;
			rx_flag_3 <= rx_flag_2;
		end
wire rx_flag_pos;
assign rx_flag_pos = rx_flag_1 & rx_flag_2 & (~rx_flag_3);
//状态机	
reg [7:0] S0_State;
reg [7:0] DATA_1;
//reg [15:0] DATA_2;
reg [15:0] offset;
reg [15:0] offset1;
reg [7:0] IR_State;
reg [6:0] mem_num;
reg [15:0] rx_size_r;
reg [15:0] tx_size_next;
reg [7:0] S0_Data;
//~~~~~~~增加定义~~~~~~
reg [15:0] Back_Len;
reg [15:0] Back_Wid;
reg [15:0] Front_Len;
reg [15:0] Front_Wid;
reg [15:0] Point_X;
reg [15:0] Point_Y;
reg [15:0] Width;
reg [15:0] Hight;
reg [7:0] Save;
reg All_Finish;
always @(posedge clk or negedge rst_n)
	if (!rst_n) 
		begin
			W5500_RST <= 1'b1;
			S0_State <= 8'd0;
			rx_size <= 16'd0;
			mem_num <= 7'd0;
			rx_size_r <= 16'd0;
			tx_size_next <= 16'd0;
			DATA_1 <= 8'd0;
			offset <= 16'd0;
			offset1 <= 16'd0;
			IR_State <= 8'd0;
			S0_Data <= 8'd0;
			tx_en <= 1'b0;
			rx_en <= 1'b0;
			tx_len <= 3'd0;
			rx_len <= 2'd0;
			tx_data <= 72'd0;
			
			//~~~~~~~增加定义~~~~~~
			Back_Len <= 16'd0;
			Back_Wid <= 16'd0;
			Front_Len <= 16'd0;
			Front_Wid <= 16'd0;
			Point_X <= 16'd0;
			Point_Y <= 16'd0;
			Width <= 16'd0;
			Hight <= 16'd0;
			Save <= 8'd0;
			All_Finish <= 1'b0;
			
			W5500_STATE <= IDLE;
			Hardware_State <= Hard_IDLE;
			W5500_INIT_State <= W5500_INIT_IDLE;
			SOCKET_INIT_State <= SOCKET_INIT_IDLE;
			SOCKET_STATE <= SOCKET_IDLE;
			SOCKET_CONN_State <= SOCKET_CONN_IDLE;
			SOCKET_CHACK_State <= SOCKET_CHACK_IDLE;
			READ_MEM_State <= READ_MEM_IDLE;
		end
	else	
		begin
			case (W5500_STATE)
				IDLE :
				begin
					W5500_STATE <= 	HARD_RST;	
					//else  W5500_STATE <= IDLE;									
				end
				
				HARD_RST :							//1
				begin
					case (Hardware_State)
						Hard_IDLE :						//1					
						begin
							Hardware_State <= Hard_RST_LOW;	
						end
						Hard_RST_LOW :					//1
						begin
							W5500_RST <= 1'b0;
							Hardware_State <= Hard_DELAY50;
						end				
						Hard_DELAY50 :					//1
						begin
							if (Delay50_1 == 24'd2500000)		Hardware_State <= Hard_RST_HIGH;
							else Hardware_State <= Hard_DELAY50;
						end				
						Hard_RST_HIGH :				//1
						begin
							W5500_RST <= 1'b1;
							Hardware_State <= Hard_DELAY200;
						end				
						Hard_DELAY200 :				//1
						begin
							if (Delay200_1 == 24'd10000000)	 Hardware_State <= Hard_WAIT_CONNECT;										
							else Hardware_State <= Hard_DELAY200;
						end
						Hard_WAIT_CONNECT :					//1
						begin															
							if (rx_en == 1'b0) 
								begin							
									rx_en <= 1'b1;
									rx_len <= 2'd1;
									tx_data <= Read_PHYCFGR;//组成数据帧 Read_PHYCFGR		spi只会执行tx_data里面的数据	 ，只会并行执行，C不同					
								end
							if (rx_ready == 1'b1 && cnt_10 == 4'd10)				
								begin
									rx_en <= 1'b0;
									if (rx_data_1 & 8'h01)
										begin
											W5500_STATE <= W5500_INIT;
											//rx_en <= 1'b0;
											tx_data <= 72'd0;
										end
									else 
										begin
											rx_en <= 1'b0;
											tx_data <= 72'd0;
											Hardware_State <= Hard_DELAY200;											
										end									
								end
							else 	Hardware_State <= Hard_WAIT_CONNECT;	
						end
					endcase					
				end
				
				W5500_INIT :
				begin
					case (W5500_INIT_State)
						W5500_INIT_IDLE :
						begin
							W5500_INIT_State <= W5500_INIT_SOFTWARE_RST;
						end
						
						W5500_INIT_SOFTWARE_RST :				//1		
						begin
							//if (cnt_RST == 3'd7) 
							//begin 
								if (tx_en == 1'b0) 
									begin
										tx_en <= 1'b1;
										tx_len <= 3'd1;	
										tx_data <= SoftWare_RST;
									end
								if (tx_ready == 1'b1 && cnt_10 == 4'd10)//tx_ready发送完成
									begin
										tx_en <= 1'b0;
										tx_data <= 72'd0;
										W5500_INIT_State <= W5500_INIT_DELAY10;
									end
								else W5500_INIT_State <= W5500_INIT_SOFTWARE_RST;
							//end
						end
						
						W5500_INIT_DELAY10 :		//1
						begin
							if (Delay10_1 == 24'd500000)	
								begin
									W5500_INIT_State <= W5500_INIT_SET_GATEWAY;
								end
							else  W5500_INIT_State <= W5500_INIT_DELAY10;
						end
						
						W5500_INIT_SET_GATEWAY	:			//1
						begin
							if (tx_en == 1'b0)
								begin
									tx_en <= 1'b1;
									tx_len <= 3'd4;
									tx_data <= Set_Gateway;					
								end
							if (tx_ready == 1'b1 && cnt_10 == 4'd10) //spi.v 给出了tx_ready表示发送完成，cnt_10延时， 两次间隔太短，拉长
								begin
									tx_en <= 1'b0;
									tx_data <= 72'd0;
									W5500_INIT_State <= W5500_INIT_SET_MASK;
								end
							else	W5500_INIT_State <= W5500_INIT_SET_GATEWAY;
						end
						
						W5500_INIT_SET_MASK:			//1
						begin
							if (cnt_MASK == 3'd7)
							begin
								tx_en <= 1'b1;
								tx_len <= 3'd4;
								tx_data <= Set_Mask;
								if (tx_ready == 1'b1 && cnt_10 == 4'd10)
									begin
										tx_en <= 1'b0;
										tx_data <= 72'd0;
										W5500_INIT_State <= W5500_INIT_SET_PHYADDR;
									end
								else	W5500_INIT_State <= W5500_INIT_SET_MASK;
							end
								else W5500_INIT_State <= W5500_INIT_SET_MASK;
						end
						
						W5500_INIT_SET_PHYADDR :			//1
						begin
							if (cnt_PHYADDR == 3'd7)
							begin
								tx_en <= 1'b1;
								tx_len <= 3'd6;	
								tx_data <= Set_PHYADDR;
								if (tx_ready == 1'b1 && cnt_10 == 4'd10)
									begin
										tx_en <= 1'b0;
										tx_data <= 72'd0;
										W5500_INIT_State <= W5500_INIT_SET_IPADDR;
									end
								else	W5500_INIT_State <= W5500_INIT_SET_PHYADDR;
							end
							else	W5500_INIT_State <= W5500_INIT_SET_PHYADDR;
						end
						
						W5500_INIT_SET_IPADDR :			//w5500 IP
						begin
							if (cnt_IPADDR == 3'd7)
							begin
								tx_en <= 1'b1;
								tx_len <= 3'd4;
								tx_data <= Set_IPADDR;
								if (tx_ready == 1'b1 && cnt_10 == 4'd10)
									begin
										tx_en <= 1'b0;
										tx_data <= 72'd0;
										W5500_INIT_State <= W5500_INIT_SET_RXBUFF;
									end
								else	W5500_INIT_State <= W5500_INIT_SET_IPADDR;
							end
							else	W5500_INIT_State <= W5500_INIT_SET_IPADDR;
						end
						
						W5500_INIT_SET_RXBUFF :		//1
						begin
							if (cnt_RXBUFF == 3'd7)
							begin
								tx_en <= 1'b1;
								tx_len <= 3'd1;
								tx_data <= Set_RXBUFF;
								if (tx_ready == 1'b1 && cnt_10 == 4'd10)
									begin
										tx_en <= 1'b0;
										tx_data <= 72'd0;
										W5500_INIT_State <= W5500_INIT_SET_TXBUFF;
									end		
								else	W5500_INIT_State <= W5500_INIT_SET_RXBUFF;
							end
							else	W5500_INIT_State <= W5500_INIT_SET_RXBUFF;
						end
						
						W5500_INIT_SET_TXBUFF :			//1
						begin
							if (cnt_TXBUFF == 3'd7)
							begin
								tx_en <= 1'b1;
								tx_len <= 3'd1;
								tx_data <= Set_TXBUFF;
								if (tx_ready == 1'b1 && cnt_10 == 4'd10)
									begin
										tx_en <= 1'b0;
										tx_data <= 72'd0;
										W5500_INIT_State <= W5500_INIT_SET_RETXTIME;
									end
								else 	W5500_INIT_State <= W5500_INIT_SET_TXBUFF;									
							end
							else	W5500_INIT_State <= W5500_INIT_SET_TXBUFF;	
						end
						
						W5500_INIT_SET_RETXTIME :			//1
						begin
							if (cnt_RETXTIME == 3'd7)
							begin
								tx_en <= 1'b1;
								tx_len <= 3'd2;
								tx_data <= Set_RETXTIME;
								if (tx_ready == 1'b1 && cnt_10 == 4'd10)
									begin
										tx_en <= 1'b0;
										tx_data <= 72'd0;
										W5500_INIT_State <= W5500_INIT_SET_TXTIMES;
									end
								else	W5500_INIT_State <= W5500_INIT_SET_RETXTIME;
							end
							else	W5500_INIT_State <= W5500_INIT_SET_RETXTIME;
						end
						
						W5500_INIT_SET_TXTIMES :			//1
						begin
							if (cnt_TXTIMES == 3'd7)
							begin
								tx_en <= 1'b1;
								tx_len <= 3'd1;
								tx_data <= Set_TXTIMES;
								if (tx_ready == 1'b1 && cnt_10 == 4'd10)
									begin
										tx_en <= 1'b0;
										tx_data <= 72'd0;
										W5500_STATE <= W5500_SOCKET_INIT;
									end
								else	W5500_INIT_State <= W5500_INIT_SET_TXTIMES;
							end
							else	W5500_INIT_State <= W5500_INIT_SET_TXTIMES;
						end												
					endcase
				end
				
				W5500_SOCKET_INIT :
				begin
					case(SOCKET_INIT_State) 				//1
						SOCKET_INIT_IDLE : begin
							SOCKET_INIT_State <= SOCKET_INIT_FP;
						end
						
						SOCKET_INIT_FP: begin			//1
							if (cnt_FP == 3'd7)
							begin
								tx_en <= 1'b1;
								tx_len <= 3'd2;
								tx_data <= Set_FP;
								if (tx_ready == 1'b1 && cnt_10 == 4'd10)
									begin
										tx_en <= 1'b0;
										tx_data <= 72'd0;
										SOCKET_INIT_State <= SOCKET_INIT_PORT0;
									end
								else SOCKET_INIT_State <= SOCKET_INIT_FP;
							end
							else	SOCKET_INIT_State <= SOCKET_INIT_FP;
						end
						
						SOCKET_INIT_PORT0: begin			//设置端口
							if (cnt_PORT0 == 3'd7)
							begin
								tx_en <= 1'b1;
								tx_len <= 3'd2;
								tx_data <= Set_PORT0;
								if (tx_ready == 1'b1 && cnt_10 == 4'd10)
									begin
										tx_en <= 1'b0;
										tx_data <= 72'd0;
										SOCKET_INIT_State <= SOCKET_INIT_DESPORT0;
									end
								else SOCKET_INIT_State <= SOCKET_INIT_PORT0;
							end
							else	SOCKET_INIT_State <= SOCKET_INIT_PORT0;
						end
						
						SOCKET_INIT_DESPORT0 : begin				//设置目的端口（我的电脑）
							if (cnt_DESPORT0 == 3'd7)
							begin
								tx_en <= 1'b1;
								tx_len <= 3'd2;
								tx_data <= Set_DESPORT0;
								if (tx_ready == 1'b1 && cnt_10 == 4'd10)
									begin
										tx_en <= 1'b0;
										tx_data <= 72'd0;
										SOCKET_INIT_State <= SOCKET_INIT_DESIP0;
									end
								else SOCKET_INIT_State <= SOCKET_INIT_DESPORT0;
							end
							else	SOCKET_INIT_State <= SOCKET_INIT_DESPORT0;
						end
						
						SOCKET_INIT_DESIP0 : begin					
							if (cnt_DESIP0 == 3'd7)
							begin
								tx_en <= 1'b1;
								tx_len <= 3'd4;
								tx_data <= Set_DESIP0;
								if (tx_ready == 1'b1 && cnt_10 == 4'd10)
									begin
										tx_en <= 1'b0;
										tx_data <= 72'd0;
										W5500_STATE <= SOCKET_WHILE;										
										SOCKET_INIT_State <= SOCKET_INIT_IDLE;
									end
								else SOCKET_INIT_State <= SOCKET_INIT_DESIP0;
							end
							else	SOCKET_INIT_State <= SOCKET_INIT_DESIP0;
						end								
					endcase
				end
		SOCKET_WHILE:		
			begin
			case (SOCKET_STATE)
				SOCKET_IDLE:
				begin
					if (S0_State == 8'd0)
						SOCKET_STATE <= SOCKET_CONNECT;
					else	SOCKET_STATE <= W5500_STATUS_CHECK;
				end				
								
				SOCKET_CONNECT:
				begin
					case (SOCKET_CONN_State)
						SOCKET_CONN_IDLE: begin			//1
								SOCKET_CONN_State <= SOCKET_CONN_TCP;						
						end
						
						SOCKET_CONN_TCP: begin				//设置TCP通信
							if (cnt_TCP == 3'd7)
							begin
								tx_en <= 1'b1;
								tx_len <= 3'd1;
								tx_data <= Set_TCP;
								if (tx_ready == 1'b1 && cnt_10 == 4'd10)
									begin
										tx_en <= 1'b0;
										tx_data <= 72'd0;
										SOCKET_CONN_State <= SOCKET_CONN_OPEN;										
									end
								else	SOCKET_CONN_State <= SOCKET_CONN_TCP;
							end
							else	SOCKET_CONN_State <= SOCKET_CONN_TCP;
						end
						
						SOCKET_CONN_OPEN: begin			//打开socket
							if (cnt_OPEN == 3'd7)
							begin
								tx_en <= 1'b1;
								tx_len <= 3'd1;
								tx_data <= Set_OPEN;
								if (tx_ready == 1'b1 && cnt_10 == 4'd10) 
									begin
										tx_en <= 1'b0;
										tx_data <= 72'd0;
										SOCKET_CONN_State <= SOCKET_CONN_DELAY5;										
									end
								else	SOCKET_CONN_State <= SOCKET_CONN_OPEN;	
							end
							else	SOCKET_CONN_State <= SOCKET_CONN_OPEN;	
						end
						
						SOCKET_CONN_DELAY5: begin
							if (Delay5_1 == 24'd250000)
								SOCKET_CONN_State <= SOCKET_CONN_READSR;
							else SOCKET_CONN_State <= SOCKET_CONN_DELAY5;
						end
						
						SOCKET_CONN_READSR: begin					//1
							if (rx_en == 1'b0)
								begin
									rx_en <= 1'b1;
									rx_len <= 2'd1;
									tx_data <= Read_SR;	
								end	
							if (rx_ready == 1'b1 && cnt_10 == 4'd10)	
								begin
									if (rx_data_1 != SOCK_INIT)			//!=和!==的区别
										begin
											rx_en <= 1'b0;
											tx_data <= 72'd0;	
											S0_State <= 8'h00;
											SOCKET_CONN_State <= SOCKET_CONN_CLOSE;											
										end
									else 
										begin
											rx_en <= 1'b0;
											tx_data <= 72'd0;								
											SOCKET_CONN_State <= SOCKET_CONN_SETCONN;
										end
								end
						end
						
						SOCKET_CONN_CLOSE: begin			//1
							if (tx_en == 1'b0)
							begin
								tx_en <= 1'b1;
								tx_len <= 3'd1;
								tx_data <= Set_CLOSE;							
							end
								if (tx_ready == 1'b1 && cnt_10 == 4'd10)
									begin
										tx_en <= 1'b0;
										tx_data <= 72'd0;
										SOCKET_CONN_State <= SOCKET_CONN_IDLE;
									end
								else SOCKET_CONN_State <= SOCKET_CONN_CLOSE;							
						end
						
						SOCKET_CONN_SETCONN: begin			//1
							if (cnt_SETCONN == 3'd7)
							begin
								tx_en <= 1'b1;
								tx_len <= 3'd1;
								tx_data <= Set_CONN;
							
								if (tx_ready == 1'b1 && cnt_10 == 4'd10)
									begin
										tx_en <= 1'b0;
										tx_data <= 72'd0;
										S0_State <= 8'h01;		//SOCKET连接成功
										//SOCKET_CONN_State <= SOCKET_CONN_READSNR;
										SOCKET_STATE <= W5500_STATUS_CHECK;
										SOCKET_CONN_State <= SOCKET_CONN_IDLE;
									end
								else SOCKET_CONN_State <= SOCKET_CONN_SETCONN;		
							end 
						end	
/* 						//这里可以加一个很短的延时状态
						SOCKET_CONN_READSNR	:begin
							if (rx_en == 1'b0)
								begin
									rx_en <= 1'b1;
									rx_len <= 2'd1;
									tx_data <= Read_SR;	
								end	
							if (rx_ready == 1'b1 && cnt_10 == 4'd10)	
								begin
									if (rx_data_1 == 8'h17)			//!=和!==的区别
										begin
											rx_en <= 1'b0;
											tx_data <= 72'd0;	
											// S0_State <= 8'h00;
											SOCKET_STATE <= W5500_STATUS_CHECK;
											
											// SOCKET_CONN_State <= SOCKET_CONN_IDLE;											
										end
									else 							
											SOCKET_CONN_State <= SOCKET_CONN_READSNR;
								end							
						end */
						

						
					endcase 
				end				
				
				W5500_STATUS_CHECK ://查询状态寄存器看是否有数据
				begin
					 case (SOCKET_CHACK_State)
						SOCKET_CHACK_IDLE:begin				//0
							SOCKET_CHACK_State <= SOCKET_CHACK_READSIR;
						end
						
						SOCKET_CHACK_READSIR	:begin		//1			//此处需要循环读取中断标志寄存器，直到读取到数据。也就是要循环发送72字节的帧数据							
							if (rx_en == 1'b0)
								begin
									rx_en <= 1'b1;
									rx_len <= 2'd1;
									tx_data <= Set_READSIR;
								end
							if (rx_ready == 1'b1 &&  cnt_10 == 4'd10)
								begin
									rx_en <= 1'b0;
									tx_data <= 72'd0;
									if ((rx_data_1 & S0_INT) == S0_INT)									
										SOCKET_CHACK_State <= SOCKET_CHACK_READSNIR;									
									else SOCKET_CHACK_State <= SOCKET_CHACK_IDLE;			//重新回到IDLE状态
								end
						end
						
						SOCKET_CHACK_READSNIR:begin			//判断哪种中断
							if (cnt_READSNIR == 3'd7)
							begin
								rx_en <= 1'b1;
								rx_len <= 2'd1;
								tx_data <= Set_READSNIR;
								if (rx_ready == 1'b1 &&  cnt_10 == 4'd10)
									begin
										DATA_1 <= rx_data_1;
										rx_en <= 1'b0;
										tx_data <= 72'd0;
										SOCKET_CHACK_State <= SOCKET_CHACK_WRSNIR;										
									end
								else SOCKET_CHACK_State <= SOCKET_CHACK_READSNIR;
							end
						end
						
						SOCKET_CHACK_WRSNIR:begin			//清空状态寄存器						
								if (cnt_WRSNIR == 3'd7)
								begin
										tx_en <= 1'b1;
										tx_len <= 3'd1;
										tx_data <= {Sn_IR,(VDM | RWB_WRITE | 8'h08),DATA_1,40'h0000000000};
								
								if (tx_ready == 1'b1 && cnt_10 == 4'd10)
									begin
										tx_en <= 1'b0;
										tx_data <= 72'd0;
										SOCKET_CHACK_State <= SOCKET_CHACK_IFIR;
									end
								else  SOCKET_CHACK_State <= SOCKET_CHACK_WRSNIR;
								end
						end
						
						SOCKET_CHACK_IFIR:begin		//判断到底什么中断
						if (DATA_1 & 8'h1f)
						begin
							if (DATA_1 & IR_CON)
								begin
									S0_State<= S0_State | S_CONN;
									SOCKET_CHACK_State <= SOCKET_CHACK_IDLE;
								end							
							 if (DATA_1 & IR_DISCON)
								begin
									S0_State <= 8'h00;
									SOCKET_CHACK_State <= SOCKET_CHACK_CLOSE;
								end
							 if (DATA_1 & IR_SEND_OK)
								begin
									S0_Data <= S0_Data | S_TRANSMITOK;
									SOCKET_CHACK_State <= SOCKET_CHACK_IDLE;
								end
							 if (DATA_1 & IR_RECV)					//检测到  接收  到数据了开始进入接收数据状态机
								begin
									S0_Data	 <= S0_Data | S_RECEIVE;
									SOCKET_CHACK_State <= SOCKET_CHACK_IDLE;
									SOCKET_STATE <= W5500_READ_MEM;
								end
							 if (DATA_1 & IR_TIMEOUT)
								begin
									S0_State <= 8'd0;
									SOCKET_CHACK_State <= SOCKET_CHACK_CLOSE;									
								end
							//else  SOCKET_CHACK_State <= SOCKET_CHACK_IDLE;
						end
						else 	SOCKET_CHACK_State <= SOCKET_CHACK_IDLE;
						end							

						SOCKET_CHACK_CLOSE:begin						//5
							if (cnt_SOCKET_CLOSE == 3'd7)
							begin
								tx_en <= 1'b1;
								tx_len <= 3'd1;
								tx_data <= Set_CLOSE;
								if (tx_ready == 1'b1 && cnt_10 == 4'd10)
									begin
										tx_en <= 1'b0;
										tx_data <= 72'd0;
										W5500_STATE <= W5500_SOCKET_INIT;	
										SOCKET_STATE <= SOCKET_IDLE;
										SOCKET_CHACK_State <= SOCKET_CHACK_IDLE;
									end
								else SOCKET_CHACK_State <= SOCKET_CHACK_CLOSE;
							end							
						end
					endcase	
				end
				
				W5500_READ_MEM :
				begin
					case (READ_MEM_State)
						READ_MEM_IDLE: begin						//0
							READ_MEM_State <= READ_MEM_READ_RX_RSR;
						end
						
						READ_MEM_READ_RX_RSR: begin				//确认spi 数据长度，电脑发来的
							if (cnt_RX_RSR == 3'd7)
							begin
								rx_en <= 1'b1;
								rx_len <= 2'd2;
								tx_data <= Set_RX_RSR;
								if (rx_ready == 1'b1 &&  cnt_10 == 4'd10)
									begin
										rx_en <= 1'b0;
										tx_data <= 72'd0;
										//rx_size <= rx_data_2;
										rx_size_r <= rx_data_2;
										if (rx_data_2 == 16'd0)
											begin
												SOCKET_STATE <=	W5500_STATUS_CHECK;
												READ_MEM_State <= READ_MEM_IDLE;
											end											
										else if (rx_data_2 > 16'd1460)	
											begin
												rx_size_r <= 16'd1460;
												READ_MEM_State <= READ_MEM_READ_RX_RD;
											end
										else 	READ_MEM_State <= READ_MEM_READ_RX_RD;
										
									end
							end
						end
						
						READ_MEM_READ_RX_RD: begin						////确认spi 数据地址，电脑发来的
							if (cnt_RX_RD == 3'd7)
							begin
								rx_en <= 1'b1;
								rx_len <= 2'd2;
								tx_data <= Set_RX_RD;
								if (rx_ready == 1'b1 &&  cnt_10 == 4'd10)
									begin
										rx_en <= 1'b0;
										tx_data <= 72'd0;
										offset1 <= rx_data_2;
										offset <= (S_RX_SIZE-1) & rx_data_2;
										if (((S_RX_SIZE-1) & rx_data_2)+ rx_size_r < S_RX_SIZE)   
											begin
												rx_size <= rx_size_r;
												READ_MEM_State <= READ_MEM_REC_DATA;
											end
										else 
											begin
												tx_size_next <= S_RX_SIZE - ((S_RX_SIZE-1) & rx_data_2);
												rx_size <= S_RX_SIZE - ((S_RX_SIZE-1) & rx_data_2);												
												READ_MEM_State <= 	READ_MEM_REC_DATA;										
											end
									end
								else READ_MEM_State <= READ_MEM_READ_RX_RD;
							end
							else	READ_MEM_State <= READ_MEM_READ_RX_RD;
						end
						
						READ_MEM_REC_DATA: begin					//根据地址 ，长度开始取数据
							if (cnt_REC_DATA == 3'd7)
							begin
								rx_en <= 1'b1;
								rx_len <= 2'd0;
								tx_data <= {offset,(VDM | RWB_READ | 8'h18),48'h000000000000};
								if (rx_flag_pos)
									begin
										if (mem_num <= 7'd100)				//接收到的数据如何处理
											begin
												mem [mem_num] <= buff_8;
												mem_num <= mem_num + 1'b1;											
											end 
									end
								if (rx_ready == 1'b1 &&  cnt_10 == 4'd10)
									begin
										rx_en <= 1'b0;
										tx_data <= 72'd0;
										if ((offset + rx_size_r) > S_RX_SIZE)	
											begin
												READ_MEM_State  <= READ_MEM_FULL_1;
											end
										else
											begin
												offset1 <= offset1 + rx_size_r;
												READ_MEM_State <= READ_MEM_WR_RX_RD;	
											end
									end
							end							
						end
						
						READ_MEM_FULL_1: begin			//
							if (cnt_FULL_1 == 3'd7)
								begin
									rx_en <= 1'b1;
									rx_len <= 2'd0;		
									tx_data <= {16'h0000,(VDM | RWB_READ | 8'h18),48'h000000000000};
									rx_size <= rx_size_r - tx_size_next;
									if (rx_flag_pos)
										begin
											if (mem_num <= 7'd100)	
												begin
													mem [mem_num] <= buff_8;
													mem_num <= mem_num + 1'b1;			
												end
										end									
									if (rx_ready == 1'b1 &&  cnt_10 == 4'd10)
										begin
											rx_en <= 1'b0;
											tx_data <= 72'd0;
											offset1 <= offset1 + rx_size_r;
											READ_MEM_State <= READ_MEM_WR_RX_RD;											
										end
								end
						end 
						
						READ_MEM_WR_RX_RD: begin					//
							if (cnt_WR_RX_RD == 3'd7)
							begin
								tx_en <= 1'b1;
								tx_len <= 3'd2;
								tx_data <= {Sn_RX_RD,(VDM | RWB_WRITE | 8'h08),offset1,32'h00000000};
								All_Finish <= 1'b0;			//拉低标志位等待数据帧组合完成后拉高		
								if (tx_ready == 1'b1 &&  cnt_10 == 4'd10)
									begin
										tx_en <= 1'b0;
										tx_data <= 72'd0;
										READ_MEM_State <= READ_MEM_WR_RECV;
									end
								else READ_MEM_State <= READ_MEM_WR_RX_RD;
							end
							else	READ_MEM_State <= READ_MEM_WR_RX_RD;
						end
						
						READ_MEM_WR_RECV: begin					//
							if (cnt_WR_RECV == 3'd7)
							begin
								tx_en <= 1'b1;
								tx_len <= 3'd1;
								tx_data <= {Sn_CR,(VDM | RWB_WRITE | 8'h08),RECV,40'h0000000000};
								if (tx_ready == 1'b1 &&  cnt_10 == 4'd10)
									begin
										tx_en <= 1'b0;
										tx_data <= 72'd0;
										//mem_num <= 7'd0;
										//SOCKET_STATE <= SOCKET_IDLE;
										//READ_MEM_State <= READ_MEM_IDLE;
										READ_MEM_State <= READ_MEM_TRANS;
									end
								else READ_MEM_State <= READ_MEM_WR_RECV;
							end
							else		READ_MEM_State <= READ_MEM_WR_RECV;
						end	

						READ_MEM_TRANS : begin
							if (mem_num == 7'd17)
							begin
								Back_Len <= {mem[0],mem[1]};
								Back_Wid <= {mem[2],mem[3]};
								Front_Len <= {mem[4],mem[5]};
								Front_Wid <= {mem[6],mem[7]};
								Point_X <= {mem[8],mem[9]};
								Point_Y <= {mem[10],mem[11]};
								Width <= {mem[12],mem[13]};
								Hight <= {mem[14],mem[15]};
								Save <= mem[16];
								mem_num <= 7'd0;
								All_Finish <= 1'b1;			//一帧数据已全部接受完毕，标志位拉高
								SOCKET_STATE <= SOCKET_IDLE;
								READ_MEM_State <= READ_MEM_IDLE;								
							end
							else READ_MEM_State <= READ_MEM_TRANS;
						end
			endcase		
			    end
			W5500_WRITE_MEM: begin
			
			end
		endcase
		end
	endcase
	end
	
endmodule



















































