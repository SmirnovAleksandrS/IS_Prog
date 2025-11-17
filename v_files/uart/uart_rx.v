module uart_rx
#(
    parameter       BYTE_SIZE     = 8,
    parameter       MAX_MSG_LEN   = (1 << BYTE_SIZE) - 1,
    parameter [0:0] BYTE_START_EN = 1,
    parameter [0:0] BYTE_STOP_EN  = 0

)
(   
    input wire CLK,
    input wire RST,

    input wire in_bit


);

localparam INIT_WIDTH = 7;
localparam REAL_BYTE_SIZE = BYTE_SIZE + BYTE_START_EN + BYTE_STOP_EN;

localparam SHIFT_SIZE     = $clog2(MAX_MSG_LEN);
localparam FULL_DATA_SIZE = $clog2(MAX_MSG_LEN) * BYTE_SIZE;
localparam CSM_SIZE       = 32;

localparam ST_INIT      = 0;
localparam ST_OPT       = 1;
localparam ST_LEN       = 2;
localparam ST_DATA      = 3;
localparam ST_CSM       = 4;
localparam ST_CHECK_CSM = 5;


reg [3 - 1 : 0] state;
reg [FULL_DATA_SIZE - 1 : 0] useful_data;

wire   init_en;
assign init_en = (state == ST_INIT);

wire [INIT_WIDTH - 1 : 0] init_byte = 7'h7e; 
wire init_frame;
wire byte_valid;

wire [BYTE_SIZE - 1 : 0] cur_byte;

reg [SHIFT_SIZE - 1 : 0] shift_val;

reg [BYTE_SIZE - 1 : 0] opt;
reg [BYTE_SIZE - 1 : 0] msg_len;

uart_init_catcher
#(
    .INIT_WIDTH ( INIT_WIDTH )
)
init_catch
(
    .CLK        ( CLK        ),
    .RST        ( RST        ),
    .en         ( init_en    ),

    .ref_init   ( init_byte  ),
    .in_bit     ( in_bit     ),
    .out_init   ( init_frame )

);

wire useful_in_bit;

uart_byte_rx 
#(
    .BYTE_SIZE  ( BYTE_SIZE  )
)
uart_byte_rx
(
    .CLK           ( CLK           ),
    .RST           ( RST           ),
    .en            ( 1'b1          ),

    .in_bit        ( in_bit        ),
    .useful_in_bit ( useful_in_bit ),
    .init_frame    ( init_frame    ),
    
    .msg_err       ( msg_lost      ),
    .out_valid     ( byte_valid    ),
    .out_data      ( cur_byte      )
);


////////////////////////////////////////////////////////////
/// get len
////////////////////////////////////////////////////////////

always @(posedge CLK)
if (RST)
    msg_len <= 0;

else if (state == ST_LEN)
    msg_len <= byte_valid ? cur_byte : msg_len ;

else 
    msg_len <= msg_len;


////////////////////////////////////////////////////////////
/// get opt
////////////////////////////////////////////////////////////

always @(posedge CLK)
if (RST)
    opt <= 0;

else if (state == ST_OPT)
    opt <= byte_valid ? cur_byte : opt ;

else 
    opt <= opt;

////////////////////////////////////////////////////////////
/// data frame ctrl
////////////////////////////////////////////////////////////

///  1 <= cnt <= msg_len

always @(posedge CLK)
if (RST)
    shift_val <= 1;

else if (state == ST_DATA)
    shift_val <= data_end  ?             1 :
                byte_valid ? shift_val + 1 :
                             shift_val     ;

else if (state == ST_CSM)
    shift_val <= check_end  ?             1 :
                 byte_valid ? shift_val + 1 :
                              shift_val     ;

else 
    shift_val <= shift_val;



wire [FULL_DATA_SIZE - 1 : 0] new_data_byte;

wire [FULL_DATA_SIZE - BYTE_SIZE - 1 : 0] concat_zeros = 'd0;
assign new_data_byte = {concat_zeros, cur_byte};


reg byte_valid_ff;
always @(posedge CLK)
if (RST)
    byte_valid_ff <= 0;
else 
    byte_valid_ff <= byte_valid;
    


always @(posedge CLK)
if (RST)
    useful_data <= 0;

else if (state == ST_DATA)
    useful_data <= byte_valid    ? useful_data | new_data_byte :
                   byte_valid_ff ? useful_data << BYTE_SIZE    :
                                   useful_data                 ;

else
    useful_data <= useful_data;




localparam CSM_BYTE_NUM = 4;
wire  check_end;
wire  frame_end;

assign data_end  = (state == ST_DATA) && byte_valid && (shift_val == msg_len      );
assign frame_end = (state == ST_CSM ) && byte_valid && (shift_val == CSM_BYTE_NUM );


wire msg_lost;
// assign msg_lost = (state == ST_INIT)

////////////////////////////////////////////////////////////
/// receiving csm
////////////////////////////////////////////////////////////

reg [CSM_SIZE - 1 : 0] csm;

always @(posedge CLK)
if (RST)
    csm <= 0;

else if (state == ST_INIT)
    csm <= 0;

else if (state == ST_CSM)
    csm <= byte_valid    ? csm | new_data_byte :
           byte_valid_ff ? csm << BYTE_SIZE    :
                                           csm ;

else
    csm <= csm;

////////////////////////////////////////////////////////////
/// checking csm
////////////////////////////////////////////////////////////

wire                    csm_calc_en;
wire                    csm_matching;
wire                    csm_tmp_valid;
wire [CSM_SIZE - 1 : 0] csm_tmp;

assign csm_calc_en = useful_in_bit && (state != ST_INIT);

crc_32
#(
    .CRC_SIZE  (CSM_SIZE   )
)
crc_32
(
    .CLK       ( CLK         ),
    .RST       ( RST         ),

    .in_valid  ( csm_calc_en ),
    .in_last   ( check_end   ),
    .in_bit    ( in_bit      ),

    .out_valid ( csm_tmp_valid   ),
    .o_crc     ( csm_tmp     )
);

wire msg_err;
assign check_end = csm_tmp_valid;

assign csm_matching = (csm == csm_tmp) && (state == ST_CSM);
assign msg_err = msg_lost || csm_matching;


////////////////////////////////////////////////////////////
/// data receiving logic fsm
////////////////////////////////////////////////////////////

always @(posedge CLK) 
if (RST)
    state <= ST_INIT;

else if (msg_err)
    state <= ST_INIT;

else if (state == ST_INIT)
    state <= init_frame ? ST_OPT : state;

else if (state == ST_OPT)
    state <= byte_valid ? ST_LEN : state;

else if (state == ST_LEN)
    state <= byte_valid ? ST_DATA : state;    

else if (state == ST_DATA)
    state <= data_end ? ST_CSM : state;    

else if (state == ST_CSM)
    state <= frame_end ? ST_CHECK_CSM : state;    

else if (state == ST_CHECK_CSM)
    state <= check_end ? ST_INIT : state;    


else 
    state <= state;









endmodule