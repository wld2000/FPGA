module spi_drive(

	input             clk_100m      ,
	input             sys_rst_n     ,
	
	//user interface
	input             spi_start     ,//spi开启使能。
	input [7:0 ]      spi_cmd       ,//FLAH操作指令
	input [23:0]      spi_addr      ,//FLASH地址
	input [7:0 ]      spi_data      ,//FLASH写入的数据
	input [3:0 ]      cmd_cnt       ,
	
	output            idel_flag_r   ,//空闲状态标志的上升沿 
	output reg        w_data_req    ,//FLASH写数据请求 
	output reg [7:0]  r_data        ,//FLASH读出的数据
	output reg        erro_flag     ,//读出的数据错误标志
	
	//spi interface
	output reg        spi_cs        ,//SPI从机的片选信号，低电平有效。
	output reg        spi_clk       ,//主从机之间的数据同步时钟。
	output reg        spi_mosi      ,//数据引脚，主机输出，从机输入。
	input             spi_miso       //数据引脚，主机输入，从机输出。

);

//状态机
parameter IDLE         =4'd0;//空闲状态
parameter WEL          =4'd1;//写使能状态
parameter S_ERA        =4'd2;//扇区擦除状态
parameter C_ERA        =4'd3;//全局擦除
parameter READ         =4'd4;//读状态
parameter WRITE        =4'd5;//写状态
parameter R_STA_REG    =4'd6;

//指令集
parameter WEL_CMD      =8'h06;
parameter S_ERA_CMD    =8'hd8;
parameter C_ERA_CMD    =8'hc7;
parameter READ_CMD     =8'h03;
parameter WRITE_CMD    =8'h02;
parameter R_STA_REG_CMD=8'h05;

//wire define
wire      idel_flag;

//reg define
reg[3:0]  current_state  ;
reg[3:0]  next_state     ;
reg[7:0 ] data_buffer    ;
reg[7:0 ] cmd_buffer     ;
reg[7:0 ] sta_reg        ;
reg[23:0] addr_buffer    ;
reg[31:0] bit_cnt        ;
reg       clk_cnt        ;
reg       dely_cnt       ;
reg[31:0] dely_state_cnt ;
reg[7:0 ] rd_data_buffer ;
reg       spi_clk0       ;
reg       stdone         ;
reg[7:0 ] data_check     ;
reg       idel_flag0     ;
reg       idel_flag1     ;

//*****************************************************
//**                    main code
//*****************************************************

assign idel_flag=(current_state==IDLE)?1:0;//空闲状态标志
assign idel_flag_r=idel_flag0&&(~idel_flag1);//空闲状态标志的上升沿

always @(posedge clk_100m or negedge sys_rst_n )begin
	if(!sys_rst_n)begin
		idel_flag0<=1'b1;
		idel_flag1<=1'b1;
	end
	else begin
		idel_flag0<=idel_flag;
		idel_flag1<=idel_flag0;
	end
end

//产生写数据请求     /*bit_cnt是数据位计数器，每向 FLASH 传输 1bit 数据，这个计数器就会加一*/
always @(posedge clk_100m or negedge sys_rst_n )begin//产生写数据请求
	if(!sys_rst_n)
		w_data_req<=1'b0;
	else if((bit_cnt+2)%8==0&&bit_cnt>=30&&clk_cnt==0&&current_state==WRITE)
		w_data_req<=1'b1;
	else
		w_data_req<=1'b0;
end

always @(posedge clk_100m or negedge sys_rst_n )begin//读出的数据移位寄存
	if(!sys_rst_n)
		rd_data_buffer<=8'd0;
	else if(bit_cnt>=32&&bit_cnt<=2080&&clk_cnt==0&&current_state==READ)									
		rd_data_buffer<={rd_data_buffer[6:0],spi_miso};
	else
		rd_data_buffer<=rd_data_buffer;
end

always @(posedge clk_100m or negedge sys_rst_n )begin//检查读出的数据是否正确
	if(!sys_rst_n)
		data_check<=8'd0;
	else if(bit_cnt%8==0&&bit_cnt>=40&&clk_cnt==1&&current_state==READ)
		data_check<=data_check+1'd1;
	else
		data_check<=data_check;
end
//和读出的数据错误标志一起看
always @(posedge clk_100m or negedge sys_rst_n )begin//读出的数据
	if(!sys_rst_n)
		r_data<=8'd0;
	else if(bit_cnt%8==0&&bit_cnt>38&&clk_cnt==1&&current_state==READ)
		r_data<=rd_data_buffer;
	else
		r_data<=r_data;
end

always @(posedge clk_100m or negedge sys_rst_n )begin//读出的数据错误标志
	if(!sys_rst_n)
		erro_flag<=1'd0;
	else if(bit_cnt>32&&bit_cnt<=2080&&current_state==READ&&cmd_cnt==6)begin
		if(data_check!=r_data)
			erro_flag<=1'd1;
		else
			erro_flag<=erro_flag;
		end
	else
		erro_flag<=erro_flag;
end         //和读出的数据一起看
//把数据移位寄存	
always @(posedge clk_100m or negedge sys_rst_n )begin
	if(!sys_rst_n)
		data_buffer<=8'd0;
	else if((bit_cnt+1)%8==0&&bit_cnt>30&&clk_cnt==1)
		data_buffer<=spi_data;
	else if(clk_cnt==1&&current_state==WRITE&&bit_cnt>=32)
		data_buffer<={data_buffer[6:0],data_buffer[7]};
	else
		data_buffer<=data_buffer;
end

always @(posedge clk_100m or negedge sys_rst_n )begin
	if(!sys_rst_n)
		cmd_buffer<=8'd0;
	else if(spi_cs==0&&dely_cnt==0)
		cmd_buffer<=spi_cmd;
	else if(clk_cnt==1&&(current_state==WEL||current_state==S_ERA||current_state==C_ERA
	       ||current_state==READ||current_state==WRITE||current_state==R_STA_REG)&&bit_cnt<8)
		cmd_buffer<={cmd_buffer[6:0],1'b1};
	else
		cmd_buffer<=cmd_buffer;
end

always @(posedge clk_100m or negedge sys_rst_n )begin
	if(!sys_rst_n)
		addr_buffer<=8'd0;
	else if(spi_cs==0&&dely_cnt==0)
		addr_buffer<=spi_addr;
	else if(clk_cnt==1&&(current_state==READ||current_state==WRITE)&&bit_cnt>=8&&bit_cnt<32)
		addr_buffer<={addr_buffer[22:0],addr_buffer[23]};
	else
		addr_buffer<=addr_buffer;
end

always @(posedge clk_100m or negedge sys_rst_n )begin
	if(!sys_rst_n)
		clk_cnt<=1'd0;
	else if(dely_cnt==1)
		clk_cnt<=clk_cnt+1'd1;
	else 
		clk_cnt<=1'd0;
end

always @(posedge clk_100m or negedge sys_rst_n )begin
	if(!sys_rst_n)
		dely_cnt<=1'd0;
	else if(spi_cs==0)begin
	    if(dely_cnt<1)
			dely_cnt<=dely_cnt+1'd1;
		else
			dely_cnt<=dely_cnt;
	end
	else
		dely_cnt<=1'd0;
end

always @(posedge clk_100m or negedge sys_rst_n )begin
	if(!sys_rst_n)
		dely_state_cnt<=1'd0;
	else if(spi_cs)begin
	    if(dely_state_cnt<400000000)
			dely_state_cnt<=dely_state_cnt+1'd1;
		else
			dely_state_cnt<=dely_state_cnt;
	end
	else
		dely_state_cnt<=1'd0;
end

always @(posedge clk_100m or negedge sys_rst_n )begin
	if(!sys_rst_n)
		bit_cnt<=11'd0;
	else if(dely_cnt==1)begin
			if(clk_cnt==1'b1)
				bit_cnt<=bit_cnt+1'd1;
			else
				bit_cnt<=bit_cnt;
	end
	else
		bit_cnt<=11'd0;
end
		
//三段式状态机
always @(posedge clk_100m or negedge sys_rst_n )begin
	if(!sys_rst_n)
		current_state<=IDLE;
	else
		current_state<=next_state;
end

always @(*)begin

	case(current_state)
	
	   IDLE: begin
	          if(spi_start&&spi_cmd==WEL_CMD)
				next_state=WEL;
			  else if(spi_start&&spi_cmd==C_ERA_CMD)
				next_state=C_ERA;
			  else if(spi_start&&spi_cmd==S_ERA_CMD)
				next_state=S_ERA;
			  else if(spi_start&&spi_cmd==READ_CMD)
				next_state=READ;
			  else if(spi_start&&spi_cmd==WRITE_CMD)
				next_state=WRITE;
			  else if(spi_start&&spi_cmd==R_STA_REG_CMD)
				next_state=R_STA_REG;
			  else
	            next_state=IDLE;
			end
	
		WEL: begin
			  if(stdone&&bit_cnt>=8)
				   next_state=IDLE;
			  else
		           next_state=WEL;
			  end
			 
		S_ERA: begin
				if(stdone)
					next_state=IDLE;
				else
					next_state=S_ERA;
				end
		C_ERA: begin		
				if(stdone)
					next_state=IDLE;
				else
					next_state=C_ERA;
				end
		READ: begin 		
				if(stdone&&bit_cnt>=8)
					next_state=IDLE;
				else
					next_state=READ;
				end
		WRITE: begin		
				 if(stdone&&bit_cnt>=8)
					next_state=IDLE;
				else
					next_state=WRITE;
				end
		R_STA_REG: begin		
				 if(stdone)
					next_state=IDLE;
				else
					next_state=R_STA_REG;
				end
		
	default: next_state=IDLE;			
	endcase				
end
									
always @(posedge clk_100m or negedge sys_rst_n )begin
	if(!sys_rst_n) begin
		spi_cs<=1'b1;
		spi_clk<=1'b0;
		spi_clk0<=1'b0;
		spi_mosi<=1'b0;	
		stdone<=1'b0;		
	end
	else begin
		case(current_state)
			IDLE: begin
				spi_cs<=1'b1;
				spi_clk<=1'b0;
				spi_mosi<=1'b0;				
			end
			
			WEL: begin
			     stdone<=1'b0;
				 spi_cs<=1'b0;
					 if(dely_cnt==1&&bit_cnt<8) begin						
						spi_clk0<=~spi_clk0;
						spi_clk<=spi_clk0;
						spi_mosi<=cmd_buffer[7];
						end
					 else if(bit_cnt==8&&clk_cnt==0)begin
					    stdone<=1'b1;
						spi_clk<=1'b0;						
						spi_mosi<=1'b0;						
					 end
					 else if(bit_cnt==8&&clk_cnt==1)begin
						spi_cs<=1'b1;						
                     end
				  end
			C_ERA: begin
					stdone<=1'b0;
			         if(dely_state_cnt==10)                
						spi_cs<=1'b0;
					 else if(dely_cnt==1&&bit_cnt<8) begin						
						spi_clk0<=~spi_clk0;
						spi_clk<=spi_clk0;
						spi_mosi<=cmd_buffer[7];
						end
					 else if(bit_cnt==8&&clk_cnt==0)begin
					    stdone<=1'b1;				    
						spi_clk<=1'b0;
						spi_mosi<=1'b0;	
					 end
					 else if(bit_cnt==8&&clk_cnt==1)begin
						spi_cs<=1'b1;						
				     end
				  end
			S_ERA: begin
			       stdone<=1'b0;				 
					if(dely_state_cnt==10)                
						spi_cs<=1'b0;
					 else if(dely_cnt==1&&bit_cnt<8) begin						
						spi_clk0<=~spi_clk0;
						spi_clk<=spi_clk0;
						spi_mosi<=cmd_buffer[7];
						end
					 else if(bit_cnt>=8&&bit_cnt<32&&spi_cs==0)begin
					    spi_cs<=1'b0;
						spi_clk0<=~spi_clk0;
						spi_clk<=spi_clk0;
						spi_mosi<=addr_buffer[23];
					 end
					 else if(bit_cnt==32&&clk_cnt==0) begin
						spi_cs<=1'b1;
						spi_clk<=1'b0;
						spi_mosi<=1'b0;
						stdone<=1'b1;
					 end
				 end
            READ: begin
			      stdone<=1'b0;
				  if(dely_state_cnt==10)                
						spi_cs<=1'b0;
					else if(dely_cnt==1&&bit_cnt<8) begin						
						spi_clk0<=~spi_clk0;
						spi_clk<=spi_clk0;
						spi_mosi<=cmd_buffer[7];
						end
					 else if(bit_cnt>=8&&bit_cnt<32&&spi_cs==0)begin					    
						spi_clk0<=~spi_clk0;
						spi_clk<=spi_clk0;
						spi_mosi<=addr_buffer[23];
					 end
					 else if(bit_cnt>=32&&bit_cnt<2080)begin						
						spi_clk0<=~spi_clk0;
						spi_clk<=spi_clk0;
						spi_mosi<=1'b0;						
					 end
					 else if(bit_cnt==2080&&clk_cnt==0) begin						
						spi_clk<=1'b0;
						spi_mosi<=1'b0;
						stdone<=1'b1;						
					 end
					  else if(bit_cnt==2080&&clk_cnt==1) begin
						spi_cs<=1'b1;
					 end
				 end
            WRITE: begin
			     stdone<=1'b0;
				  if(dely_state_cnt==10)                
						spi_cs<=1'b0;
					 else if(dely_cnt==1&&bit_cnt<8) begin						
						spi_clk0<=~spi_clk0;
						spi_clk<=spi_clk0;
						spi_mosi<=cmd_buffer[7];
						end
					 else if(bit_cnt>=8&&bit_cnt<32&&spi_cs==0)begin					   
						spi_clk0<=~spi_clk0;
						spi_clk<=spi_clk0;
						spi_mosi<=addr_buffer[23];
					 end
					 else if(bit_cnt>=32&&bit_cnt<2080)begin						
						spi_clk0<=~spi_clk0;
						spi_clk<=spi_clk0;
						spi_mosi<=data_buffer[7];
					 end
					 else if(bit_cnt==2080&&clk_cnt==0) begin
						
						spi_clk<=1'b0;
						spi_mosi<=1'b0;
						stdone<=1'b1;
					 end
					  else if(bit_cnt==2080&&clk_cnt==1) begin
						spi_cs<=1'b1;
					 end
                  end
			R_STA_REG:begin				              
						stdone<=1'b0;
				     if(dely_state_cnt==10)                
						spi_cs<=1'b0;
					else if(dely_cnt==1&&bit_cnt<8)begin						
						spi_clk0<=~spi_clk0;
						spi_clk<=spi_clk0;
						spi_mosi<=cmd_buffer[7];
						end
					 else if(bit_cnt==8)begin					   				    
						spi_clk0<=~spi_clk0;
						spi_clk<=spi_clk0;
						spi_mosi<=1'b0;						
					 end                      				 
					  else if(~spi_miso&&bit_cnt%8==0)begin
					    spi_clk<=1'b0;
						spi_cs<=1'b1;
						stdone<=1'b1;
				      end
					 else if(~spi_cs&&dely_cnt==1)begin
						spi_clk0<=~spi_clk0;
						spi_clk<=spi_clk0;
				 end	   			         	 
			  end 
             default: begin
			            stdone<=1'b0;
                        spi_cs<=1'b1;
				        spi_clk<=1'b0;
						spi_clk0<=1'b0;
				        spi_mosi<=1'b0;				        
			end
         endcase
	end
end

endmodule
