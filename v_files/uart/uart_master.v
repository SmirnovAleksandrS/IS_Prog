module uart_master
#(
    parameter BYTE_SIZE       = 8,
    parameter MAX_MSG_LEN     = (1 << BYTE_SIZE) - 1,
    parameter OUT_DATA_SIZE   = $clog2(MAX_MSG_LEN) * BYTE_SIZE,
    parameter FIFO_DEPTH      = 100,
    parameter TX_FREQ_DIVIDER = 1000,
    parameter RX_FREQ_DIVIDER = 250 
)
(
    input  wire                           CLK,
    input  wire                           RST,

    ///tx
    input  wire [OUT_DATA_SIZE - 1 : 0]   data_to_tx,
    input  wire                           tx_data_valid,

    output wire                           out_bit,
    

    ///rx
    input  wire                           in_bit,

    output wire [BYTE_SIZE     - 1 : 0]   o_opt,
    output wire [BYTE_SIZE     - 1 : 0]   o_len,
    output wire [OUT_DATA_SIZE - 1 : 0]   o_data,
    output wire                           o_valid


);

wire [BYTE_SIZE     - 1 : 0]              o_opt_orig  ;
wire [BYTE_SIZE     - 1 : 0]              o_len_orig  ;
wire [OUT_DATA_SIZE - 1 : 0]              o_data_orig ;
wire                                      o_valid_orig;

wire tx_ready;
                                                         
wire [OUT_DATA_SIZE - 1 : 0]              data_from_victim;
wire [OUT_DATA_SIZE - 1 : 0]              cur_tx_data;
wire                                      cur_tx_valid;

wire [OUT_DATA_SIZE - 1  : 0]             rx_success;
wire [OUT_DATA_SIZE - 1  : 0]             rx_fail;

assign rx_success = {8'hEE, {(OUT_DATA_SIZE - 8){1'b1}}};
assign rx_fail    = {8'hBB, {(OUT_DATA_SIZE - 8){1'b1}}};



uart_tx
#(
    .FULL_DATA_SIZE ( OUT_DATA_SIZE  ),
    .BYTE_SIZE      ( BYTE_SIZE      )
)
uart_tx
(
    .CLK       ( CLK       ),
    .RST       ( RST       ),

    .clk_en    ( tx_clk_en ),

    .full_data ( cur_tx_data ),
    .in_valid  ( cur_tx_valid  ),

    .ready     ( tx_ready  ),
    .out_bit   ( out_bit   )
);


wire rx_msg_err;
uart_rx
#(  
    .FREQ_COEF      ( 1             ), /// needed for really different clocks
    .BYTE_SIZE      ( BYTE_SIZE     )
)
uart_rx
(
    .CLK            ( CLK         ),
    .RST            ( RST         ),

    .clk_en         ( rx_clk_en   ),
    .in_bit         ( in_bit      ),

    .o_msg_err      ( rx_msg_err   ),
    .rx_started     ( rx_started  ),

    .o_opt          ( o_opt       ),  
    .o_len          ( o_len       ), 
    .o_data         ( o_data      ),  
    .o_valid        ( o_valid     )   
);


wire empty;
wire full;
wire tx_free;
assign tx_free = (state == ST_TX_FREE);

fifo_ram #(
    .WIDTH      (OUT_DATA_SIZE ),
    .DEPTH      (FIFO_DEPTH    )
) fifo_before_tx
(
    .CLK        (CLK        ),
    .RST        (RST        ),

    .EN         (1'b1       ),
    .i_peek     (1'b0       ),

    .i_wr_en    (tx_data_valid     ),
    .i_rd_en    (tx_free           ),

    .i_data     ( data_to_tx       ),
    .o_data     ( data_from_victim ),

    .o_empty    (empty      ),
    .o_full     (full       )
);



assign cur_tx_data  = (state == ST_TX_WAIT_RX) && o_valid    ? rx_success :
                      (state == ST_TX_WAIT_RX) && rx_msg_err ? rx_fail    :
                                                         data_from_victim ;

assign cur_tx_valid = (state == ST_TX_WAIT_RX) && (o_valid || rx_msg_err) || 
                      (state != ST_TX_WAIT_RX) && vict_data_valid;



reg [2 - 1 : 0] state;

localparam ST_TX_FREE    = 0;
localparam ST_TX_WAIT_RX = 1;
localparam ST_TX_BUSY    = 2;

wire vict_data_valid;
assign vict_data_valid = !empty;

always @(posedge CLK)
if (RST)
    state <= ST_TX_FREE;

else if (state == ST_TX_FREE)
    state <= rx_started      ? ST_TX_WAIT_RX : 
             vict_data_valid ? ST_TX_BUSY    :
                                state        ;

else if (state == ST_TX_WAIT_RX)
    state <= o_valid         ? ST_TX_BUSY :
             !rx_msg_err     ? state      :
             vict_data_valid ? ST_TX_BUSY :
                               ST_TX_FREE ;

else if (state == ST_TX_BUSY)
    state <= !tx_ready                   ?      state :
              o_valid || vict_data_valid ? ST_TX_BUSY :
                                           ST_TX_FREE ;

assign tx_hshake = tx_ready && vict_data_valid;


localparam TX_FREQ_CNT_SIZE = $clog2(TX_FREQ_DIVIDER);
localparam RX_FREQ_CNT_SIZE = $clog2(RX_FREQ_DIVIDER);
reg [TX_FREQ_CNT_SIZE - 1 : 0] tx_cnt;
reg [TX_FREQ_CNT_SIZE - 1 : 0] rx_cnt;
wire tx_clk_en;
wire rx_clk_en;

always @(posedge CLK)
if (RST)
    tx_cnt <= 0;
else 
    tx_cnt <= tx_clk_en ? 0 : tx_cnt + 1;

always @(posedge CLK)
if (RST)
    rx_cnt <= 0;
else 
    rx_cnt <= rx_clk_en ? 0 : rx_cnt + 1; 


assign tx_clk_en = (tx_cnt == TX_FREQ_DIVIDER - 1);
assign rx_clk_en = (rx_cnt == RX_FREQ_DIVIDER - 1);






endmodule