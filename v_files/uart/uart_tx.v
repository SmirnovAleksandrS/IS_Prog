module uart_tx
#(
    parameter FULL_DATA_SIZE = 40,
    parameter BYTE_SIZE = 8
)
(
    input  wire                                CLK,
    input  wire                                RST,

    input  wire [FULL_DATA_SIZE - 1 : 0] full_data,
    input  wire [     BYTE_SIZE - 1 : 0]       opt,
    input  wire [     BYTE_SIZE - 1 : 0]       len,

    input  wire                           in_valid,
    output wire                              ready,
    output wire                            out_bit     

);

localparam ST_NO_DATA = 0;
localparam ST_INIT    = 1;
localparam ST_LEN     = 2;
localparam ST_OPT     = 3;
localparam ST_DATA    = 4;
localparam ST_CSM     = 5;


localparam USEFUL_DATA_SIZE = FULL_DATA_SIZE - 2 * BYTE_SIZE;
// localparam SHIFT_VAL_SIZE   = BYTE_SIZE * (1 << (BYTE_SIZE + 1) - 1);
localparam SHIFT_VAL_SIZE = BYTE_SIZE;

localparam CSM_BYTES = 4;


reg [3 - 1 : 0] state;

wire hshake;
wire init_en;

reg [BYTE_SIZE        - 1 : 0]       msg_len;
reg [BYTE_SIZE        - 1 : 0]       msg_opt;
reg [USEFUL_DATA_SIZE - 1 : 0]   useful_data;
reg [BYTE_SIZE        - 1 : 0] cur_data_byte;


        
wire data_end; 
wire frame_end;
////////////////////////////////////////////////////////////
/// data input loading
////////////////////////////////////////////////////////////

assign ready  = (state == ST_NO_DATA);
assign hshake = ready && in_valid;

always @(posedge CLK)
if (RST) begin
    msg_len     <= 0;
    msg_opt     <= 0;
    useful_data <= 0;

end else if (hshake) begin
    msg_opt     <= full_data[FULL_DATA_SIZE - 0 * BYTE_SIZE - 1 -: BYTE_SIZE];
    msg_len     <= full_data[FULL_DATA_SIZE - 1 * BYTE_SIZE - 1 -: BYTE_SIZE];
    useful_data <= full_data[FULL_DATA_SIZE - 2 * BYTE_SIZE - 1  :         0];

end else begin
    msg_len     <= msg_len    ;    
    msg_opt     <= msg_opt    ;    
    useful_data <= useful_data;
end



////////////////////////////////////////////////////////////
/// useful data transmition
////////////////////////////////////////////////////////////

reg [SHIFT_VAL_SIZE - 1 : 0] shift_val;
wire final_shift = (shift_val == (msg_len - 1)) && (state == ST_DATA);
wire final_csm_shift;
assign final_csm_shift = (state == ST_CSM) && (shift_val == CSM_BYTES - 1);


always @(posedge CLK)
if (RST)
    shift_val <= 0;

else if ((state == ST_OPT) || (state == ST_DATA))
    shift_val <= !byte_tx_hshake ? shift_val                   :
                 !final_shift    ? shift_val + /*BYTE_SIZE*/ 1 : 
                                                             0 ;
else if (state == ST_CSM)
    shift_val <= !byte_tx_hshake  ? shift_val      :
                 !final_csm_shift ? shift_val +  1 : 
                                                 0 ;

else
    shift_val <= 0;




wire   [USEFUL_DATA_SIZE - 1 : 0] shifted_useful_data;
assign shifted_useful_data = useful_data << (shift_val << 3); /// 3 = clog2(BYTE_SIZE)

/// mb need to reverse //// order???
always @(posedge CLK)
if (RST)
    cur_data_byte <= 0;

else if ((state == ST_OPT) || (state == ST_DATA))
    // cur_data_byte <= byte_tx_hshake ? shifted_useful_data[USEFUL_DATA_SIZE - 1 -: BYTE_SIZE] : cur_data_byte ;
    cur_data_byte <= shifted_useful_data[USEFUL_DATA_SIZE - 1 -: BYTE_SIZE] ;

else
    cur_data_byte <= cur_data_byte;

    
assign init_en = (state == ST_NO_DATA) && hshake;

wire [BYTE_SIZE - 1 : 0] init_msg;
wire [BYTE_SIZE - 1 : 0] next_byte;

assign init_msg = {{(BYTE_SIZE - 1){1'b1}}, 1'b0};


assign next_byte = ( state == ST_NO_DATA)                        && hshake                      ? init_msg      :
                   ( state == ST_INIT   )                        && byte_tx_hshake              ? msg_opt       :
                   ( state == ST_LEN    )                        && byte_tx_hshake              ? msg_len       :
                   ((state == ST_OPT    ) || (state == ST_DATA)) && byte_tx_hshake && !data_end ? cur_data_byte :
                   ( state == ST_DATA   ) || (state == ST_CSM )  && byte_tx_hshake              ? cur_csm_byte  :
                                                                            {BYTE_SIZE{1'b1}}  ;



wire byte_tx_ready;
wire byte_tx_valid;
wire byte_tx_hshake;


wire next_b_valid = ((byte_tx_hshake && !data_end) || csm_valid) && (state != ST_NO_DATA) || hshake ;

assign byte_tx_hshake = byte_tx_ready && byte_tx_valid;

assign data_end = final_shift && byte_tx_hshake;



uart_byte_tx
#(
    .BYTE_SIZE ( BYTE_SIZE )
)
uart_byte_tx
(
    .CLK        (      CLK      ),
    .RST        (      RST      ),
    .en         (       en      ),

    .init_en    (  init_en      ),  
    .in_data    (  next_byte    ),
    .in_valid   (  next_b_valid ),

    .out_useful ( out_useful    ),
    .ready      ( byte_tx_ready ),
    .out_valid  ( byte_tx_valid ),
    .o_bit      (  out_bit_slow )
);

reg out_bit_ff;
always @(posedge CLK)
if (RST)
    out_bit_ff <= 1;
else 
    out_bit_ff <= out_bit_slow;


assign out_bit = (state == ST_CSM) ? out_bit_slow : out_bit_ff;
////////////////////////////////////////////////////////////
/// csm_logic
////////////////////////////////////////////////////////////

localparam CSM_SIZE = 32;
wire [CSM_SIZE - 1 : 0] csm;
wire csm_valid;
wire out_useful;
wire csm_calc_en;

assign csm_calc_en = out_useful && (state != ST_INIT);

crc_32
#(
    .CRC_SIZE  (CSM_SIZE   )
)
crc_32
(
    .CLK       ( CLK        ),
    .RST       ( RST        ),

    .in_valid  ( csm_calc_en ),
    .in_last   ( data_end   ),
    .in_bit    ( out_bit_slow    ),

    .out_valid ( csm_valid  ),
    .o_crc     ( csm        )
);


wire [BYTE_SIZE - 1 : 0] cur_csm_byte;

wire   [CSM_SIZE - 1: 0] shifted_csm;
assign shifted_csm  = csm << (shift_val << 3);

assign cur_csm_byte = shifted_csm[CSM_SIZE - 1 -: BYTE_SIZE]; 

assign frame_end = final_csm_shift && (state == ST_CSM);

////////////////////////////////////////////////////////////
/// data transmition logic fsm
////////////////////////////////////////////////////////////

always @(posedge CLK) 
if (RST)
    state <= ST_NO_DATA;

else if (state == ST_NO_DATA)
    state <= in_valid ? ST_INIT : state;

else if (state == ST_INIT)
    state <= byte_tx_ready ? ST_LEN : state;

else if (state == ST_LEN)
    state <= byte_tx_ready ? ST_OPT : state;

else if (state == ST_OPT)
    state <= byte_tx_ready ? ST_DATA : state;    

else if (state == ST_DATA)
    state <= data_end ? ST_CSM : state;    

else if (state == ST_CSM)
    state <= frame_end ? ST_NO_DATA : state;    

else 
    state <= state;










endmodule