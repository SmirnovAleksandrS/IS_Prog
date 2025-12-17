module test_uart;


localparam FULL_DATA_SIZE = 40;
localparam BYTE_SIZE = 8;



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

    always begin 
        #1 CLK      = ~CLK;
        // #4 clk2     = !clk2;
    end


always @(posedge CLK)
    slow_clk_tmp <= !slow_clk_tmp;


always @(posedge slow_clk_tmp)
    slow_clk <= !slow_clk;


initial begin
    CLK          <= 0;
    clk2 <=0;
    slow_clk     <= 0;
    slow_clk_tmp <= 0;
    RST          <= 1;


    // full_data <= 40'h00_03_aa_bb_47;
    full_data <= 40'h00_00_00_00_00;
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
    .CLK       ( slow_clk  ),
    .RST       ( RST       ),
    .full_data ( full_data ),
    .in_valid  ( in_valid  ),
    .ready     ( tx_ready  ),
    .out_bit   ( out_bit   )
);



uart_rx
#(  
    .FREQ_COEF      (1               ),
    .BYTE_SIZE     ( 1     )
    // .MAX_MSG_LEN   ( MAX_MSG_LEN   ),
)
uart_rx
(
    .CLK       ( slow_clk           ),
    .RST       ( RST        ),
    .in_bit    ( out_bit    )
);





    initial begin

		$dumpfile("dump.vcd"); $dumpvars(0, test_uart);
        #46;
        RST <= 0;
        #29
        @(posedge CLK);
        in_valid <= 1;
        #32;
        in_valid <= 0;

        #3218;
        in_valid  <= 1;
        full_data <= 40'h00_02_aa_bb_47;
        #16;
        in_valid <= 0;

        #320;
        in_valid  <= 1;
        full_data <= 40'h00_01_aa_bb_47;
        #16;
        in_valid <= 0;

                #5000;
        in_valid  <= 1;
        full_data <= 40'h00_00_aa_bb_47; 
        #16;
        in_valid <= 0;




        #4000;
        $finish;
    end



endmodule