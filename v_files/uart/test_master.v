module test_master;


localparam data_to_tx_SIZE = 40;
localparam BYTE_SIZE = 8;
localparam OUT_DATA_SIZE = 256;


reg                         CLK;
reg                         RST;
reg                         tx_data_valid;
reg                         in_bit;
reg [OUT_DATA_SIZE - 1 : 0] data_to_tx;




always begin 
    #1 CLK      = ~CLK;
end



initial begin
    CLK          <= 0;
    RST          <= 1;


    data_to_tx <= 40'h00_03_aa_bb_47;
    // data_to_tx <= 40'h01_00_00_00_00;
    tx_data_valid  <= 0;


end

uart_master #(
    .BYTE_SIZE       (8 ),
    .TX_FREQ_DIVIDER (16),
    .OUT_DATA_SIZE (OUT_DATA_SIZE),
    .RX_FREQ_DIVIDER (4 )
)
uart_master
(
    .CLK           ( CLK           ),
    .RST           ( RST           ),
    .tx_data_valid ( tx_data_valid ),
    .in_bit        ( 1'b1        ),
    .data_to_tx    ( data_to_tx    )
);


    initial begin

		$dumpfile("dump.vcd"); $dumpvars(0, test_master);
        #46;
        RST <= 0;
        #29
        @(posedge CLK);
        tx_data_valid <= 1;
        #2;
        tx_data_valid <= 0;

        #3218;
        tx_data_valid  <= 1;
        data_to_tx <= 40'h00_02_aa_bb_47;
        #16;
        tx_data_valid <= 0;

        #320;
        tx_data_valid  <= 1;
        data_to_tx <= 40'h00_01_aa_bb_47;
        #16;
        tx_data_valid <= 0;

                #5010;
        tx_data_valid  <= 1;
        data_to_tx <= 40'h00_00_aa_bb_47; 
        #160;
        tx_data_valid <= 0;




        #4000;
        $finish;
    end



endmodule