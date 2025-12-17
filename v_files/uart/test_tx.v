module test_tx;


localparam FULL_DATA_SIZE = 40;
localparam BYTE_SIZE = 8;

ertq
reg CLK;
reg slow_clk;
reg RST;
reg [FULL_DATA_SIZE - 1 : 0] full_data;
reg opt;
reg len;
reg in_valid;
reg slow_clk_tmp;
wire tx_ready;
reg clk2;

reg  [3 : 0] reg_num  = 4'b1100;
wire [0 : 3] reversed = reg_num;

assign 

    always begin 
        #1 CLK      = ~CLK;
    end




initial begin
    CLK          <= 0;
    clk2 <=0;
    slow_clk     <= 0;
    slow_clk_tmp <= 0;
    RST          <= 1;


    full_data <= 40'h00_03_aa_bb_47;
    // full_data <= 40'h01_00_00_00_00;
    in_valid  <= 0;


end

wire out_bit;

uart_tx
#(
    .FULL_DATA_SIZE ( FULL_DATA_SIZE ),
    .BYTE_SIZE      ( BYTE_SIZE      )
)
uart_tx
(
    .CLK       ( CLK  ),
    .RST       ( RST       ),
    .full_data ( full_data ),
    .in_valid  ( in_valid  ),
    .ready     ( tx_ready  ),
    .out_bit   ( out_bit   )
);






    initial begin

		$dumpfile("dump.vcd"); $dumpvars(0, test_tx);
        #46;
        RST <= 0;
        #29
        @(posedge CLK);
        in_valid <= 1;
        #32;
        in_valid <= 0;

        #3218;
        in_valid  <= 1;
        // full_data <= 40'h00_02_aa_bb_47;
        #16;
        in_valid <= 0;

        #320;
        in_valid  <= 1;
        // full_data <= 40'h00_01_aa_bb_47;
        #16;
        in_valid <= 0;

                #5000;
        in_valid  <= 1;
        // full_data <= 40'h00_00_aa_bb_47;
        #16;
        in_valid <= 0;




        #4000;
        $finish;
    end



endmodule