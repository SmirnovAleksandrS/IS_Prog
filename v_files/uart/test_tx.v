module test_tx;


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


    always begin 
        #1 CLK      = ~CLK;
    end


always @(posedge CLK)
    slow_clk_tmp <= !slow_clk_tmp;


always @(posedge slow_clk_tmp)
    slow_clk <= !slow_clk;


initial begin
    CLK          <= 0;
    slow_clk     <= 0;
    slow_clk_tmp <= 0;
    RST          <= 1;


    // full_data <= 40'h00_03_aa_bb_47;
    full_data <= 40'h01_00_00_00_00;
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
    .FREQ_COEF      (4               ),
    .BYTE_SIZE     ( BYTE_SIZE     )
    // .MAX_MSG_LEN   ( MAX_MSG_LEN   ),
)
uart_rx
(
    .CLK       ( CLK        ),
    .RST       ( RST        ),
    .in_bit    ( out_bit    )
);





    initial begin

		$dumpfile("dump.vcd"); $dumpvars(0, test_tx);
        #48;
        RST <= 0;
        #24;
        in_valid <= 1;
        #32;
        in_valid <= 0;

        #800;
        in_valid  <= 1;
        full_data <= 40'h00_02_aa_bb_47;
        #16;
        in_valid <= 0;

        #320;
        in_valid  <= 1;
        full_data <= 40'h00_01_aa_bb_47;
        #16;
        in_valid <= 0;

                #160;
        in_valid  <= 1;
        full_data <= 40'h00_00_aa_bb_47;
        #16;
        in_valid <= 0;




        #2000;
        $finish;
    end



endmodule