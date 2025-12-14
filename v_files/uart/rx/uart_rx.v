module uart_rx
#(
    parameter                             BYTE_SIZE     = 8,
    parameter                             FREQ_COEF     = 16,
    parameter                             MAX_MSG_LEN   = (1 << BYTE_SIZE) - 1,
    parameter                             OUT_DATA_SIZE = $clog2(MAX_MSG_LEN) * BYTE_SIZE

)
(   
    input  wire                           CLK,
         (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 RST RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_HIGH" *)
    input  wire                           RST,
    input  wire                           clk_en,
    input  wire                           in_bit,

    output wire [BYTE_SIZE     - 1 : 0]   o_opt,
    output wire [BYTE_SIZE     - 1 : 0]   o_len,
    output wire [OUT_DATA_SIZE - 1 : 0]   o_data,
    output wire                           o_valid

);


localparam                                CNT_SIZE = (FREQ_COEF <= 1) ? 1 : $clog2(FREQ_COEF);
////////////////////////////////////////////////////////////////////////////

reg [CNT_SIZE - 1 : 0]                    baud_cnt;
wire                                      baud_en;

reg                                       sync_ff_1;
reg                                       sync_ff_2;

/////////////////////////////////////////////////////////////////////////////

assign baud_en = (FREQ_COEF <= 1) ? clk_en : (baud_cnt == FREQ_COEF - 1) && clk_en;

always @(posedge CLK)
if (RST)
    baud_cnt <= 0;
else 
    baud_cnt <= clk_en ? baud_cnt + 1 : baud_cnt;

/////////////////////////////////////////////////////////////////////////////

always @(posedge CLK)
if (RST)
    sync_ff_1 <= 0;
else 
    sync_ff_1 <= clk_en ? in_bit : sync_ff_1;


always @(posedge CLK)
if (RST)
    sync_ff_2 <= 0;
else 
    sync_ff_2 <= clk_en ? sync_ff_1 : sync_ff_2;

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