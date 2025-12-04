module test_tx;


localparam FULL_DATA_SIZE = 40;
localparam BYTE_SIZE = 8;



reg CLK;
reg RST;
reg [FULL_DATA_SIZE - 1 : 0] full_data;
reg opt;
reg len;
reg in_valid;


    always 
        #1 CLK = ~CLK;


initial begin
    CLK       <= 0;
    RST       <= 1;


    full_data <= 40'h00_03_aa_bb_47;
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
    .CLK       ( CLK       ),
    .RST       ( RST       ),
    .full_data ( full_data ),
    .in_valid  ( in_valid  ),
    .out_bit   ( out_bit   )
);



uart_rx
#(  
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
        #11;
        RST <= 0;
        #4;
        in_valid <= 1;
        #4;
        in_valid <= 0;

        #200;
        in_valid  <= 1;
        full_data <= 40'h00_02_aa_bb_47;
        #4;
        in_valid <= 0;

        #80;
        in_valid  <= 1;
        full_data <= 40'h00_01_aa_bb_47;
        #4;
        in_valid <= 0;

                #80;
        in_valid  <= 1;
        full_data <= 40'h00_00_aa_bb_47;
        #4;
        in_valid <= 0;




        #2000;
        $finish;
    end



endmodule