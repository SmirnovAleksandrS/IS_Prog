
module sram_dualport #(
    parameter WIDTH             = 8,
    parameter DEPTH             = 8,
    parameter ADDR_W            = $clog2(DEPTH),

    // verilator lint_off UNUSEDPARAM
    parameter [63:0] INSTANCE_N = 0,
    parameter [63:0] INSTANCE_D = 0
    // verilator lint_on UNUSEDPARAM
) (
    input  wire              CLK,
    input  wire              RST,
    input  wire              i_wen,
    input  wire              i_ren,
    input  wire [ADDR_W-1:0] i_waddr,
    input  wire [ADDR_W-1:0] i_raddr,
    input  wire [WIDTH-1:0]  i_wdata,
    output reg  [WIDTH-1:0]  o_rdata,
    output reg               o_valid
);

    // initial begin
    //     $display("%m: my id is (%0d, %0d)", INSTANCE_N, INSTANCE_D);
    // end

    // This should be SRAM
    (* rw_addr_collision = "yes" *)
    reg [WIDTH-1:0] sram [DEPTH-1:0];

    // Write to SRAM
    always @(posedge CLK) begin
        if (i_wen) begin
            sram[i_waddr] <= i_wdata;

            `ifndef SYNTHESIS
                // verilator lint_off WIDTHEXPAND
                if (i_waddr > DEPTH) begin
                // verilator lint_on WIDTHEXPAND
                    $display("address out of range: %0d / %0d", i_waddr, DEPTH);
                    $finish;
                end
            `endif
        end
    end

    // Read from SRAM
    always @(posedge CLK) begin
        if (i_ren) begin
            o_rdata <= sram[i_raddr];
        end
    end

    always @(posedge CLK) begin
        if (RST) begin
            o_valid <= 1'b0;
        end else if (i_ren) begin
            o_valid <= 1'b1;
        end else begin
            o_valid <= 1'b0;
        end
    end

endmodule
