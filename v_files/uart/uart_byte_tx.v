module uart_byte_tx
#(
    parameter BYTE_SIZE = 8
)
(

    input  wire                          CLK,
    input  wire                          RST,
    input  wire                           en,

    input  wire                      init_en,
    input  wire [BYTE_SIZE - 1 : 0]  in_data,
    input  wire                     in_valid,

    output wire                   out_useful,
    output wire                    out_valid,
    output wire                        ready,
    output wire                        o_bit

);  /// useful means not start signal but only useful


localparam ST_NO_DATA = 0;
localparam ST_START   = 1;
localparam ST_DATA    = 2;


localparam BIT_CNT_SIZE = $clog2(BYTE_SIZE);

reg [BYTE_SIZE - 1 : 0] cur_data;
reg [2 - 1 : 0] state;



////////////////////////////////////////////////////////////
/// cnt of sent bits 
////////////////////////////////////////////////////////////

reg [BIT_CNT_SIZE - 1 : 0] bit_cnt;
wire hshake;

assign ready      = (state == ST_NO_DATA) || ((state == ST_DATA) && last_bit);
assign out_valid  = ((state == ST_DATA) && last_bit);
assign out_useful = (state == ST_DATA);

assign hshake   = ready && in_valid;

assign last_bit = (bit_cnt == (BYTE_SIZE - 1));


always @(posedge CLK)
if (RST)
    bit_cnt <= 0;

else if (state == ST_DATA)
    bit_cnt <= last_bit ? 0 : bit_cnt + 1;

else 
    bit_cnt <= bit_cnt;


////////////////////////////////////////////////////////////
/// out bit logic 
////////////////////////////////////////////////////////////

reg [BYTE_SIZE - 1 : 0] shift_data;
wire cur_bit;
assign cur_bit = shift_data[BYTE_SIZE - 1];


assign o_bit = (state == ST_START  ) ? 1'b0 :
               (state == ST_NO_DATA) ? 1'b1 :
                                    cur_bit ; 

always @(posedge CLK)
if (RST)
    shift_data <= 1;
else 
    shift_data <= hshake             ?          in_data  : 
                  (state == ST_DATA) ? (shift_data << 1) :
                                              shift_data ;


////////////////////////////////////////////////////////////
/// data transmitting logic fsm
////////////////////////////////////////////////////////////

always @(posedge CLK)
if (RST)
    state <= ST_NO_DATA;

else if (!en)
    state <= ST_NO_DATA;

else if (state == ST_NO_DATA)
    state <= !hshake ? state    :
             init_en ? ST_DATA  :
                       ST_START ;

else if (state == ST_START)
    state <= ST_DATA ;

else if (state == ST_DATA)
    state <= !last_bit ?      state :
             hshake    ?   ST_START :
                         ST_NO_DATA ;

else 
    state <= state;






endmodule