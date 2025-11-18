module uart_byte_rx
#(
    parameter BYTE_SIZE = 8
)
(

    input  wire                        CLK,
    input  wire                        RST,
    input  wire                         en,

    input  wire                        in_bit,
    input  wire                        init_frame,

    output wire                        last_bit,
    output wire                        useful_in_bit,
    output wire                        msg_err,
    output reg                         out_valid,
    output wire [BYTE_SIZE - 1 : 0]    out_data

);

localparam ST_NO_DATA = 0;
localparam ST_START   = 1;
localparam ST_DATA    = 2;

localparam CNT_SIZE = $clog2(BYTE_SIZE);


reg [2 - 1 : 0] state;

// wire last_bit;
wire start_correct = (in_bit == 1'b0) && (state == ST_START);

reg  [BYTE_SIZE - 1 : 0] shift_reg;
wire [BYTE_SIZE - 1 : 0] data;
reg  [CNT_SIZE  - 1 : 0] cnt;


assign useful_in_bit = (state == ST_DATA);

////////////////////////////////////////////////////////////
/// data load
////////////////////////////////////////////////////////////

always @(posedge CLK)
if (RST)
    cnt <= 0;

else if (!en)
    cnt <= 0;

else if (state == ST_DATA)
    cnt <= last_bit ? 0 : cnt + 1;

else 
    cnt <= cnt;

assign last_bit = (cnt == BYTE_SIZE - 1);


always @(posedge CLK)
if (RST)
    shift_reg <= 0;

else 
    shift_reg <= {shift_reg[BYTE_SIZE-1 - 1 : 0], in_bit};


////////////////////////////////////////////////////////////
/// data receiving logic fsm
////////////////////////////////////////////////////////////

always @(posedge CLK)
if (RST)
    state <= ST_NO_DATA;

else if (!en)
    state <= ST_NO_DATA;

else if (state == ST_NO_DATA)
    state <= init_frame ? ST_START : state;

else if (state == ST_START)
    state <= start_correct ? ST_DATA : ST_NO_DATA ;

else if (state == ST_DATA)
    state <= last_bit ? ST_START : state ;

else 
    state <= state;



////////////////////////////////////////////////////////////
/// error processing
////////////////////////////////////////////////////////////

// assign msg_err = (in_bit == 1'b1) && (state == ST_START); 

assign msg_err = 1'b0;

wire high_bit =  (in_bit == 1'b1);
wire start_st =  (state == ST_START);


reg err;

always @(posedge CLK)
if (RST)
    err <= 0;
else
    err <= msg_err    ? 1'b1 :
           init_frame ? 1'b0 :
                        err  ;


////////////////////////////////////////////////////////////
/// out data & valid
////////////////////////////////////////////////////////////

assign out_data = shift_reg;

always @(posedge CLK)
if (RST) 
    out_valid <= 0;
else
    out_valid <= en && last_bit && (state == ST_DATA);


endmodule