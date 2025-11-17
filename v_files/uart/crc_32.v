module crc_32
#(
    parameter CRC_SIZE = 32
)
(

    input  wire                          CLK,
    input  wire                          RST,

    input  wire                     in_valid,
    input  wire                      in_last,
    input  wire                       in_bit,

    output wire                    out_valid,
    output wire [CRC_SIZE - 1 : 0]     o_crc


);


reg  [CRC_SIZE - 1 : 0] crc_ff;
wire [CRC_SIZE - 1 : 0] polynom = 32'hEDB88320;
wire [CRC_SIZE - 1 : 0] max_val = 32'hffffffff;

wire [CRC_SIZE - 1 : 0] next_crc_1;
wire [CRC_SIZE - 1 : 0] next_crc_2;

wire   xor_bit;
assign xor_bit = crc_ff[31] ^ in_bit;

assign next_crc_1 = {crc_ff[30:0], 1'b0} ^ polynom;
assign next_crc_2 = {crc_ff[30:0], 1'b0};

always @(posedge CLK) 
if (RST) 
    crc_ff <= 32'hFFFFFFFF;

else if (in_valid) 
    crc_ff <= xor_bit ? next_crc_1 : next_crc_2;
    

reg in_last_ff;

always @(posedge CLK)
if (RST)
    in_last_ff <= 0;
else
    in_last_ff <= in_last && in_valid;


assign out_valid =           in_last_ff;
assign o_crc     =     crc_ff ^ max_val;


endmodule