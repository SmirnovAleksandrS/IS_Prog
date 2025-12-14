module imp_long
#(
    parameter COEF       = 16
)
(
    input  wire                           CLK,
    input  wire                           RST,

    input  wire                           imp, 
    output wire                           long_imp

);

localparam CNT_SIZE = $clog2(COEF);


assign long_imp = imp || (cnt != 1);

reg [CNT_SIZE - 1 : 0] cnt;
wire last_tact;
assign last_tact = (cnt == COEF);


always @(posedge CLK)
if (RST)
    cnt <= 1;

else if ((cnt == 1) && !imp ) 
    cnt <= cnt;

else 
    cnt <= last_tact ? 1 : cnt + 1 ; 

endmodule