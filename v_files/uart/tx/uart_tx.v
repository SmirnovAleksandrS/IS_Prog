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

////////////////////////////////////////////////////////////
/// parameters definition
////////////////////////////////////////////////////////////


/// fsm states
localparam ST_NO_DATA  = 0;
localparam ST_INIT     = 1;
localparam ST_LEN      = 2;
localparam ST_OPT      = 3;
localparam ST_DATA     = 4;
localparam ST_WAIT_CSM = 5;
localparam ST_CSM      = 6;
localparam ST_WAIT_END = 7;


/// datactrl parameters
localparam USEFUL_DATA_SIZE = FULL_DATA_SIZE - 2 * BYTE_SIZE;
localparam SHIFT_VAL_SIZE  = BYTE_SIZE;


/// csm parameters
localparam CSM_BYTES = 4;
localparam CSM_SIZE = 32;

////////////////////////////////////////////////////////////
/// nets definition
////////////////////////////////////////////////////////////


/// fsm state reg
reg [3 - 1 : 0] state;

/// captured data
reg [BYTE_SIZE        - 1 : 0]       msg_len;
reg [BYTE_SIZE        - 1 : 0]       msg_opt;
reg [USEFUL_DATA_SIZE - 1 : 0]   useful_data;
reg [BYTE_SIZE        - 1 : 0] cur_data_byte;

/// general ctrl signals
wire init_en;
wire data_end; 
wire final_byte;

wire in_hshake;
wire next_b_valid;
wire last_of_byte;

reg  out_bit_ff;

/// interim data
wire [USEFUL_DATA_SIZE - 1 : 0] shifted_useful_data;
wire [BYTE_SIZE        - 1 : 0]            init_msg;
wire [BYTE_SIZE        - 1 : 0]           next_byte;
/// shift of long data for byte destribution
reg [SHIFT_VAL_SIZE - 1 : 0] shift_val;
wire final_data_shift;
wire final_csm_shift;

/// SMTH WRONG HERE
wire tx_byte_ready;
wire new_bit_valid;
wire in_byte_hshake;
/// SMTH WRONG HERE


/// CSM ctrl && data
wire csm_valid;
wire useful_bit;
wire csm_calc_en;

wire [CSM_SIZE  - 1 : 0] csm;
wire [CSM_SIZE  - 1 : 0] shifted_csm;
wire [BYTE_SIZE - 1 : 0] cur_csm_byte;


////////////////////////////////////////////////////////////
/// data input loading
////////////////////////////////////////////////////////////

assign ready  = (state == ST_NO_DATA);
assign in_hshake = ready && in_valid;

always @(posedge CLK)
if (RST) begin
    msg_len     <= 0;
    msg_opt     <= 0;
    useful_data <= 0;

end else if (in_hshake) begin
    msg_opt     <= full_data[FULL_DATA_SIZE - 0 * BYTE_SIZE - 1 -: BYTE_SIZE];
    msg_len     <= full_data[FULL_DATA_SIZE - 1 * BYTE_SIZE - 1 -: BYTE_SIZE];
    useful_data <= full_data[FULL_DATA_SIZE - 2 * BYTE_SIZE - 1  :         0];

end else begin
    msg_len     <= msg_len    ;    
    msg_opt     <= msg_opt    ;    
    useful_data <= useful_data;
end

////////////////////////////////////////////////////////////
/// general signals loading
////////////////////////////////////////////////////////////
assign init_en    = (state == ST_NO_DATA) && in_hshake;

assign init_msg   = {{(BYTE_SIZE - 1){1'b1}}, 1'b0};

assign data_end   = final_data_shift && in_byte_hshake;

assign final_byte = final_csm_shift && (state == ST_CSM) && in_byte_hshake;

assign frame_end  = (state == ST_WAIT_END) && tx_byte_ready;
////////////////////////////////////////////////////////////
/// shiting big data logic
////////////////////////////////////////////////////////////


assign final_data_shift = (shift_val == (msg_len - 1)) && (state == ST_DATA);

always @(posedge CLK)
if (RST)
    shift_val <= 0;

else if ((state == ST_OPT) || (state == ST_DATA))
    shift_val <= !in_byte_hshake   ? shift_val     :
                 !final_data_shift ? shift_val + 1 :                               
                                                 0 ;

else if ((state == ST_CSM) || (state == ST_WAIT_CSM))
    shift_val <= !in_byte_hshake   ? shift_val     :
                 !final_csm_shift  ? shift_val + 1 : 
                                                 0 ;
else
    shift_val <= 0;



////////////////////////////////////////////////////////////
/// next sent byte logic
////////////////////////////////////////////////////////////

//// -->> parallel mux
assign next_byte = ( state == ST_NO_DATA  )                        && in_hshake                   ? init_msg      :
                   ( state == ST_INIT     )                        && in_byte_hshake              ? msg_opt       :
                   ( state == ST_LEN      )                        && in_byte_hshake              ? msg_len       :
                   ((state == ST_OPT      ) || (state == ST_DATA)) && in_byte_hshake              ? cur_data_byte :
                   ( state == ST_WAIT_CSM ) || (state == ST_CSM )  && in_byte_hshake              ? cur_csm_byte  :
                                                                                               {BYTE_SIZE{1'b1}}  ;


// assign next_b_valid   = ((in_byte_hshake /*&& !data_end*/) || csm_valid) && (state != ST_NO_DATA) || in_hshake ;
assign next_b_valid = (state != ST_NO_DATA) && (state != ST_WAIT_CSM) || csm_valid || in_hshake; 
assign in_byte_hshake = tx_byte_ready && next_b_valid;


assign last_csm_bit = last_of_byte && (state == ST_WAIT_CSM);
uart_byte_tx
#(
    .BYTE_SIZE ( BYTE_SIZE )
)
uart_byte_tx
(
    .CLK        (      CLK      ),
    .RST        (      RST      ),
    .en         (       en      ),

    .init_en    ( init_en       ),  
    .in_data    ( next_byte     ),
    .in_valid   ( next_b_valid  ),
    .ready      ( tx_byte_ready ),

    .last_bit   ( last_of_byte  ),
    .out_useful ( useful_bit    ),
    .out_valid  ( new_bit_valid ),
    .o_bit      ( out_bit_slow  )
);

///delay caused by csm delay
always @(posedge CLK)
if (RST)
    out_bit_ff <= 1;
else 
    out_bit_ff <= out_bit_slow;


assign out_bit = ((state == ST_CSM) || (state == ST_WAIT_END)) ? out_bit_slow : out_bit_ff;



////////////////////////////////////////////////////////////
/// data state logic
////////////////////////////////////////////////////////////


assign shifted_useful_data = useful_data << (shift_val << 3); /// 3 = clog2(BYTE_SIZE)

always @(posedge CLK)
if (RST)
    cur_data_byte <= 0;

else if ((state == ST_OPT) || (state == ST_DATA))
    cur_data_byte <= shifted_useful_data[USEFUL_DATA_SIZE - 1 -: BYTE_SIZE] ;

else
    cur_data_byte <= cur_data_byte;



////////////////////////////////////////////////////////////
/// csm_logic
////////////////////////////////////////////////////////////


assign csm_calc_en = useful_bit && (state != ST_INIT) && (state != ST_CSM);

assign final_csm_shift = (state == ST_CSM) && (shift_val == CSM_BYTES - 1);

crc_32
#(
    .CRC_SIZE  ( CSM_SIZE     )
)
crc_32
(
    .CLK       ( CLK          ),
    .RST       ( RST          ),

    .in_valid  ( csm_calc_en  ),
    // .in_last   ( data_end     ),
    .in_last   ( last_csm_bit ),
    .in_bit    ( out_bit_slow ),

    .out_valid ( csm_valid    ),
    .o_crc     ( csm          )
);

assign shifted_csm  = csm << (shift_val << 3);
assign cur_csm_byte = shifted_csm[CSM_SIZE - 1 -: BYTE_SIZE]; 

always @(posedge CLK)
if (RST)
    csm_calculated <= 0;

else if (state == ST_CSM)
    csm_calculated <= csm_valid ? 1 : csm_calculated;

else
    csm_calculated <= 0;

reg csm_calculated; 
// wire csm_byte_valid;

// assign csm_byte_valid = !ban_csm || csm_valid;

assign wait_csm = (state == ST_CSM) && !(csm_calculated || csm_valid);

////////////////////////////////////////////////////////////
/// data transmition logic fsm
////////////////////////////////////////////////////////////

always @(posedge CLK) 
if (RST)
    state <= ST_NO_DATA;

else if (state == ST_NO_DATA)
    state <= in_valid ? ST_INIT : state;

else if (state == ST_INIT)
    state <= tx_byte_ready ? ST_LEN : state;

else if (state == ST_LEN)
    state <= tx_byte_ready ? ST_OPT : state;

else if (state == ST_OPT)
    state <= tx_byte_ready ? ST_DATA : state;    

else if (state == ST_DATA)
    state <= data_end ? ST_WAIT_CSM : state;    

else if (state == ST_WAIT_CSM)
    state <= csm_valid ? ST_CSM : state;    

else if (state == ST_CSM)
    state <= final_byte ? ST_WAIT_END : state;    

else if (state == ST_WAIT_END)
    state <= frame_end ? ST_NO_DATA : state;    
else 
    state <= state;










endmodule