module SPI( clk,rst_n,
				sck,mosi,miso,
				rx_data_1,rx_data_2,tx_data,
				tx_en,rx_en,
				tx_len,rx_len,
				rx_size,
				tx_ready,rx_ready,rx_flag,
				SCSn,buff_8
				);
input clk;		
input rst_n;
input miso;
input [71:0] tx_data;		//SPI要发送的数据，最大的一帧数据，此时最大为6字节的数据
input tx_en;				//发送使能，高有效，作为触发发送状态机的标志
input rx_en;				//接收使能，高有效，作为触发接收状态机的标志
input [2:0] tx_len;		//发送几个字节数据
input [1:0] rx_len;		//读取几个字节
input [15:0] rx_size;	//要读取的字节数
 
output sck;					//SPI时钟
output  reg mosi;
output reg [7:0] rx_data_1;	//SPI接收到的一字节数据
output reg [15:0] rx_data_2;	//SPI接收到的两字节数据
output reg tx_ready;			//一帧数据发送完成标志
output reg rx_ready;			//1/2数据接收完成标志
output reg SCSn;
output reg rx_flag;
output reg [7:0] buff_8;

parameter CLKSPI = 9'd500;

//捕获tx_en的上升沿，重置cnt计数，开始产生SPI时钟
reg tx_en_1;
reg tx_en_2;
reg tx_en_3;
always @(posedge clk or negedge rst_n)
	if (!rst_n)
		begin
			tx_en_1 <= 1'b0;
			tx_en_2 <= 1'b0;
			tx_en_3 <= 1'b0;
		end
	else 
		begin 
			tx_en_1 <= tx_en;
			tx_en_2 <= tx_en_1;
			tx_en_3 <= tx_en_2;
		end
wire tx_en_pos;					//tx_en的上升沿
assign tx_en_pos = tx_en_1 & tx_en_2 & (~tx_en_3);
		
//捕获rx_en的上升沿，重置cnt计数，开始产生SPI时钟		
reg rx_en_1;
reg rx_en_2;
reg rx_en_3;
always @(posedge clk or negedge rst_n)
	if (!rst_n)
		begin
			rx_en_1 <= 1'b0;
			rx_en_2 <= 1'b0;
			rx_en_3 <= 1'b0;
		end
	else 
		begin 
			rx_en_1 <= rx_en;
			rx_en_2 <= rx_en_1;
			rx_en_3 <= rx_en_2;
		end
wire rx_en_pos;					//tx_en的上升沿
assign rx_en_pos = rx_en_1 & rx_en_2 & (~rx_en_3);		
		

//产生100K的SPI时钟
reg [8:0] cnt;
always @(posedge clk or negedge rst_n)
	if(!rst_n)
		cnt <= 9'd0;
	else 
		begin
			if (rx_en == 1'b0 &&  tx_en == 1'b0)	
				cnt <= 9'd0;
			if (cnt == 9'd499)
				cnt <= 9'd0;
			if (rx_en == 1'b1 ||  tx_en == 1'b1)
				cnt <= cnt + 1'b1;
		end
		
		
	// else if (tx_en_pos || rx_en_pos)
		// cnt <= 9'd0;
	// else if(cnt == 9'd499 && (tx_en | rx_en) == 1'b1)	//
		// cnt <= 9'd0;
	// else if(cnt < 9'd499 && (tx_en | rx_en) == 1'b1)		//只有使能发送期间才进行计数产生SPI时钟信号
		// cnt <= cnt + 1'b1;
reg sck_r;
always @(posedge clk or negedge rst_n)
	if (!rst_n)
		sck_r <= 1'b1;
	else if (cnt == 9'd1)
		sck_r <= 1'b0;
	else if (cnt == CLKSPI/2 - 1)
		sck_r <= 1'b1;

assign sck = sck_r;		
//计数10个时钟周期
reg [3:0] cnt_delay10;
always @(posedge clk or negedge rst_n)
	if (!rst_n) cnt_delay10 <= 4'd0;
	else if (rx_flag == 1'b1) cnt_delay10 <= cnt_delay10 + 1'b1;
	else if (rx_flag == 1'b0) cnt_delay10 <= 4'd0;
		
//发送1/2/4/6字节数据，使用不定长数据传输模式，但是要把传输的数据字节数传过来
reg [6:0] num;			//发送数据计数
reg [4:0] num_rx;
reg [6:0] num_tx;
reg [13:0] num_bit;
reg [2:0] num_byte;
reg [3:0] byte_8;
reg [7:0] data_8;
always @(posedge clk or negedge rst_n)
	if (!rst_n)
		begin
			num <= 7'b0;
			num_rx <= 5'd0;
			num_tx <= 7'd0;
			rx_ready <= 1'd0;
			tx_ready <= 1'd0;
			mosi <= 1'b0;			
			SCSn <= 1'b1;
			num_bit <= 14'd0;
			num_byte <= 3'd0;
			rx_flag <= 1'b0;
			byte_8 <= 4'd0;
			data_8 <= 8'd0;
			rx_data_1 <= 8'd0;
			buff_8 <= 8'h00;
			rx_data_2 <= 16'h0000;
		end
	else 
		begin
			if (tx_en_pos)  //
			begin
				tx_ready <= 1'b0;		//一旦上升沿处于刚开始状态，将完成标志置0
				SCSn <= 1'b0;	
			end
			if (tx_en == 1'b1)
			begin
			case (tx_len)
				3'd1: begin		//一字节数据	
						if (cnt == 9'd1 && num < 7'd32)		//加一个SCSn == 1'b0的条件确保发送数据前SCSn已经拉低
							begin
								num <= num + 1'b1;
								mosi <= tx_data[71-num];
								//tx_ready <= 1'b0;//改动
							end
						if (cnt == 9'd251 && num == 7'd32) 
							begin
								num <= 7'd0;
								tx_ready <= 1'b1;
								SCSn <= 1'b1;
							end
				end
				
				3'd2:	begin		//两字节数据	
						if (cnt == 9'd1 && num < 7'd40)
							begin
								num <= num + 1'b1;
								mosi <= tx_data[71-num];
								//tx_ready <= 1'b0;//改动
							end
						if (cnt == 9'd251 && num == 7'd40) 
							begin
								num <= 7'd0;
								tx_ready <= 1'b1;
								SCSn <= 1'b1;
							end
				end
				
				3'd4: begin		//四字节数据
						if (cnt == 9'd1 && num < 7'd56)
							begin
								num <= num + 1'b1;
								mosi <= tx_data[71-num];
								//tx_ready <= 1'b0;//改动
							end
						if (cnt == 9'd251 && num == 7'd56) 
							begin
								num <= 7'd0;
								tx_ready <= 1'b1;
								SCSn <= 1'b1;
							end
				end
				
				3'd6: begin		//六字节数据
						if (cnt == 9'd1 && num < 7'd72)
							begin
								num <= num + 1'b1;
								mosi <= tx_data[71-num];
								//tx_ready <= 1'b0;//改动
							end
						if (cnt == 9'd251 && num == 7'd72) 
							begin
								num <= 7'd0;
								tx_ready <= 1'b1;
								SCSn <= 1'b1;
							end
					end		
			endcase
		end

			//读取寄存器中的1/2个字节数据
			if (rx_en_pos)
			begin 
				rx_ready <= 1'b0;		//一旦上升沿处于刚开始状态，将完成标志置0
				SCSn <= 1'b0;
			end
			if (rx_en == 1'b1)
			begin
			case (rx_len)
				2'd0: begin	//在这里面读取所有接受到的数据						
						if (cnt == 9'd1 && num < 7'd24)		
							begin
								num <= num + 1'b1;
								mosi <= tx_data[71-num];
								//tx_ready <= 1'b0;
							end
						if (num_bit < rx_size * 8 && num == 7'd24 && cnt == 9'd1)
							begin
								mosi <= 1'b0;
								num_bit <= num_bit + 1'b1;
								//num_byte <= num_byte + 1'b1;
							end
						if (num_bit < (rx_size * 8 + 1'b1)  && num == 7'd24 && num_bit > 14'd0 && cnt == 9'd250)
							begin
								byte_8 <= byte_8 + 1'b1;
								data_8[7-byte_8] <= miso;
							end
						if (num_bit > 14'd0 && byte_8 == 4'd8 && rx_flag == 1'b0)
							begin								
								rx_flag <= 1'b1;
								buff_8 <= data_8;		//完成一个字节的接收
								byte_8 <= 4'd0;
							end
						if (cnt_delay10 == 4'd10 && rx_flag == 1'b1)
							begin
								rx_flag <= 1'b0;
							end
						if (cnt == 9'd255 && num_bit == rx_size * 8) 
							begin
								num <= 7'd0;
								num_bit <=14'd0;
								rx_ready <= 1'b1;
								SCSn <= 1'b1;
								rx_flag <= 1'b0;
							end						
				end			
				2'd1:	begin			
						if (cnt == 9'd1 && num_tx < 7'd32)
							begin
								num_tx <= num_tx + 1'b1;
								mosi <= tx_data[71-num_tx];
							end
						// if (cnt == 9'd251 && num_tx == 7'd32) 
							// begin
								// num_tx <= 7'd0;
								
							// end	
						if (num_tx > 7'd24 && cnt == 9'd255 && num_rx < 5'd8)
							begin
								num_rx <= num_rx + 1'b1;
								rx_data_1[7 - num_rx] <= miso;
							end
						if (num_rx == 5'd8)
							begin
								num_tx <= 7'd0;
								num_rx <= 5'd0;
								rx_ready <= 1'b1;
								SCSn <= 1'b1;
							end					
				end
				
				2'd2:	begin
						if (cnt == 9'd1 && num_tx < 7'd40)
							begin
								num_tx <= num_tx + 1'b1;
								mosi <= tx_data[71-num_tx];
							end
						if (cnt == 9'd251 && num_tx == 7'd40) 
							begin
								num_tx <= 7'd0;
								//rx_ready <= 1'b0;
							end	
						if (num_tx > 7'd24 && cnt == 9'd250 && num_rx < 5'd16)
							begin
								num_rx <= num_rx + 1'b1;
								rx_data_2[15 - num_rx] <= miso;
							end
						if (num_rx == 5'd16)
							begin
								num_rx <= 5'd0;
								rx_ready <= 1'b1;
								SCSn <= 1'b1;
							end
					end
			endcase
			end
				
		end
	

endmodule




