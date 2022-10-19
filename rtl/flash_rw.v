module flash_rw(

	input            sys_clk      ,
	input            sys_rst_n    ,
	
	input            idel_flag_r  ,//空闲状态标志位
	input            w_data_req   ,
    
    input            eth_tx_data ,    //MII输出数据      
    
	output reg[3:0 ] cmd_cnt      ,
	output reg       spi_start    ,//spi开启使能。
	output reg[7:0 ] spi_cmd      ,
	output reg[7:0] spi_data      
   
);

//指令集
parameter WEL_CMD      =16'h06;
parameter S_ERA_CMD    =16'hd8;
parameter C_ERA_CMD    =16'hc7;
parameter READ_CMD     =16'h03;
parameter WRITE_CMD    =16'h02;
parameter R_STA_REG_CMD=8'h05 ;

//reg define
reg[3:0] flash_start;

//*****************************************************
//**                    main code
//*****************************************************

always @(posedge sys_clk or negedge sys_rst_n )begin
	if(!sys_rst_n)
		flash_start<=0;
	else if(flash_start<=5)
	    flash_start<=flash_start+1;
	else
		flash_start<=flash_start;
end

always @(posedge sys_clk or negedge sys_rst_n )begin
	if(!sys_rst_n)
		cmd_cnt<=0;
	else if(flash_start==4)
	    spi_start<=1'b1;
	else if(idel_flag_r&&cmd_cnt<10)begin
	    cmd_cnt<=cmd_cnt+1;
		spi_start<=1'b1;
	end
	else begin
		cmd_cnt<=cmd_cnt;
		spi_start<=1'b0;
	end
end

always @(posedge sys_clk or negedge sys_rst_n )begin
	if(!sys_rst_n)
		spi_data<=8'd0;
	else if(w_data_req)
		spi_data<=eth_tx_data;
	else
		spi_data<=spi_data;
end

always @(*)begin
	case(cmd_cnt)
		0:spi_cmd=WEL_CMD;
		1:spi_cmd=C_ERA_CMD;
		2:spi_cmd=R_STA_REG_CMD;
		3:spi_cmd=WEL_CMD;
		4:spi_cmd=WRITE_CMD;
		5:spi_cmd=R_STA_REG_CMD;
		6:spi_cmd=READ_CMD;
		7:spi_cmd=WEL_CMD;
		8:spi_cmd=S_ERA_CMD;
		9:spi_cmd=R_STA_REG_CMD;
		10:spi_cmd=READ_CMD;
		
	default:;
	endcase
end

endmodule
