module testbench;

reg CLK;
reg RST;

reg ear;
reg i_valid;
reg [3 : 0] trigger;

reg [12*8 - 1 : 0] message;

initial begin
    CLK         = 1;
    RST         = 1;
    ear = 1;
    i_valid = 0;
    message ='d0;

end


always 
    #1 CLK = ~CLK;

always #20 ear <= ~ear;

attack_hub #(
    .NS_TO_CLK(10),
    .BYTE_SIZE(8),
    .MAX_SIZE(12),
    .PARALLEL(0)
) DUT 
(
    .CLK(CLK),
    .RST(RST),
    .ear(ear),
    .trigger(trigger),
    .i_valid(i_valid),
    .message(message)
);


initial begin
    $dumpfile("out.vcd");
    $dumpvars(0, testbench);
    #11;
    RST = 0;
    trigger <= 4'b0000;
    #9;
    i_valid <= 1;
    message <= 96'h00FF_0004_0008_0FFF_00FF_00_00;
    // message <= 96'h0000_0000_0008_0000_0000_00_00;
    #2;
    i_valid <= 0;
    #45;
    trigger <= 4'b0001;

    #10000;
    $finish;
end


endmodule