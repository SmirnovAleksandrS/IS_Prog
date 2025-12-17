 
module imp_gen
#(
    parameter COEF = 1000
)
(
input clk, 
output reg pulse);
  reg [$clog2(COEF) - 1:0] cnt;
  always @(posedge clk) begin
    {pulse,cnt} <= (cnt==COEF - 1) ? {1'b1,10'd0} : {1'b0,cnt+10'd1};
  end
endmodule