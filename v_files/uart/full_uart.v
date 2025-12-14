module full_uart
#(
    parameter BYTE_SIZE      = 8,
    parameter MAX_MSG_LEN    = (1 << BYTE_SIZE) - 1,
    parameter OUT_DATA_SIZE  = $clog2(MAX_MSG_LEN) * BYTE_SIZE,
    parameter FULL_DATA_SIZE = MAX_MSG_LEN,
)
(
    input  wire                           CLK,
    input  wire                           RST,

    

);




endmodule