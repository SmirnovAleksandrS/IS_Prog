module uart_init_catcher
#(
    parameter INIT_WIDTH = 8
)
(

    input  wire                        CLK,
    input  wire                        RST,
    input  wire                        en,

    input  wire [INIT_WIDTH - 1 : 0]   ref_init,

    input  wire                        in_bit,
    output wire                        out_init

);


reg  [INIT_WIDTH - 1 : 0]     shift_reg;
wire [INIT_WIDTH - 1 : 0] new_shift_reg;

assign new_shift_reg = {shift_reg[INIT_WIDTH-1 - 1 : 0], in_bit};


always @(posedge CLK)
if (RST)
    shift_reg <= 0;

else
    shift_reg <= en ? new_shift_reg : shift_reg;


assign out_init = (new_shift_reg == ref_init);


endmodule