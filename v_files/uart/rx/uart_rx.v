module uart_rx
#(
    parameter                             BYTE_SIZE     = 8,
    parameter                             FREQ_COEF     = 16,
    parameter                             MAX_MSG_LEN   = (1 << BYTE_SIZE) - 1,
    parameter                             OUT_DATA_SIZE = $clog2(MAX_MSG_LEN) * BYTE_SIZE

)
(   
    input  wire                           CLK,
    input  wire                           RST,
    input  wire                           in_bit,

    output wire [BYTE_SIZE     - 1 : 0]   o_opt,
    output wire [BYTE_SIZE     - 1 : 0]   o_len,
    output wire [OUT_DATA_SIZE - 1 : 0]   o_data,
    output wire                           o_valid

);

localparam                                CNT_SIZE = $clog2(FREQ_COEF);
////////////////////////////////////////////////////////////////////////////

reg [CNT_SIZE - 1 : 0]                    baud_cnt;
wire                                      baud_en;

reg                                       sync_ff_1;
reg                                       sync_ff_2;

/////////////////////////////////////////////////////////////////////////////

assign baud_en = (baud_cnt == FREQ_COEF - 1);

always @(posedge CLK)
if (RST)
    baud_cnt <= 0;
else 
    baud_cnt <= baud_cnt + 1;

/////////////////////////////////////////////////////////////////////////////

always @(posedge CLK)
if (RST)
    sync_ff_1 <= 0;
else 
    sync_ff_1 <= in_bit;


always @(posedge CLK)
if (RST)
    sync_ff_2 <= 0;
else 
    sync_ff_2 <= sync_ff_1;

/////////////////////////////////////////////////////////////////////////////


sync_uart_rx
#(
    .BYTE_SIZE     ( BYTE_SIZE     ),
    .MAX_MSG_LEN   ( MAX_MSG_LEN   ),
    .OUT_DATA_SIZE ( OUT_DATA_SIZE )
)
sync_uart_rx
(
    .CLK           ( CLK           ),
    .RST           ( RST           ),
    
    .in_bit        ( in_bit        ),
    .baud_en       ( baud_en       ),

    .o_opt         ( o_opt         ),
    .o_len         ( o_len         ),
    .o_data        ( o_data        ),
    .o_valid       ( o_valid       )
);

endmodule