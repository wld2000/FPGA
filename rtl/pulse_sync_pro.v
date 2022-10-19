
module pulse_sync_pro(
    input      clk_a  ,    //输入时钟A
    input      rst_n  ,    //复位信号
    input      pulse_a,    //输入脉冲A
    input      clk_b  ,    //输入时钟B
    output     pulse_b     //输出脉冲B
);

//reg define
reg      pulse_inv    ;    //脉冲信号转换成电平信号
reg      pulse_inv_d0 ;    //时钟B下打拍
reg      pulse_inv_d1 ;
reg      pulse_inv_d2 ;

//*****************************************************
//**                    main code
//*****************************************************

assign pulse_b = pulse_inv_d1 ^ pulse_inv_d2 ;

//输入脉冲转成电平信号，确保时钟B可以采到
always @(posedge clk_a or negedge rst_n) begin
    if(rst_n==1'b0)
        pulse_inv <= 1'b0 ;
    else if(pulse_a)
        pulse_inv <= ~pulse_inv;
end

//A时钟下电平信号转成时钟B下的脉冲信号
always @(posedge clk_b or negedge rst_n) begin
    if(rst_n==1'b0) begin
        pulse_inv_d0 <= 1'b0;
        pulse_inv_d1 <= 1'b0;
        pulse_inv_d2 <= 1'b0;
    end
    else begin
        pulse_inv_d0 <= pulse_inv   ;
        pulse_inv_d1 <= pulse_inv_d0;
        pulse_inv_d2 <= pulse_inv_d1;
    end
end

endmodule