`default_nettype none

module fifo_ram #(
    parameter        WIDTH      = 8,
    parameter        DEPTH      = 8,

    parameter [63:0] INSTANCE_N = 0,
    parameter [63:0] INSTANCE_D = 0
) (
    input  wire             CLK,
    input  wire             RST,
    // verilator lint_off UNUSEDSIGNAL
    input  wire             EN,
    // verilator lint_on UNUSEDSIGNAL
    input  wire             i_peek,
    input  wire             i_wr_en,
    input  wire             i_rd_en,
    input  wire [WIDTH-1:0] i_data,
    output wire [WIDTH-1:0] o_data,
    output wire             o_empty,
    output wire             o_full
);

    localparam W_PTR               = $clog2(DEPTH);
    // Max width of RHS migth be bigger because of Verilog context
    // verilator lint_off WIDTHTRUNC
    localparam [W_PTR-1:0] MAX_PTR = DEPTH - 1;
    // verilator lint_on WIDTHTRUNC

    wire push  = i_wr_en && ~o_full;
    wire pop   = i_rd_en && ~o_empty;
    wire shift = o_full  && i_wr_en && i_rd_en;

    wire [WIDTH-1:0] mem_out;

    reg  [W_PTR-1:0] wr_ptr;
    reg  [W_PTR-1:0] rd_ptr;
    reg              wr_circle_odd;
    reg              rd_circle_odd;

    reg              cache_valid;
    reg  [WIDTH-1:0] cache_data;

    reg              last_peek;
    reg              cache_before_peek;

    // Load the next element on read, that way next element is on output
    // and can be read on the same cycle with pop being asserted
    wire [W_PTR-1:0] read_next = (rd_ptr == MAX_PTR) ? (0) : (rd_ptr + 1'b1);

    wire almost_empty  = wr_ptr == read_next;

    // Read from bypass cache after the first write to empty FIFO or if bypass
    // cache is valid and we do push and pop simultaneously (basically
    // swapping the value in cache)
    wire enable_bypass = push && (o_empty || (almost_empty && pop));
    wire restore_cache = almost_empty && i_peek;

    // Don't read from memory when almost empty, because we already have the
    // last element on output
    wire ren           = (pop && ~almost_empty) || i_peek;
    wire wen           = push || shift;


    sram_dualport #(
        .WIDTH      ( WIDTH      ),
        .DEPTH      ( DEPTH      ),
        .INSTANCE_N ( INSTANCE_N ),
        .INSTANCE_D ( INSTANCE_D )
    ) i_sram (
        .CLK     ( CLK       ),
        .RST     ( RST       ),
        .i_wen   ( wen       ),
        .i_ren   ( ren       ),
        .i_waddr ( wr_ptr    ),
        .i_raddr ( read_next ),
        .i_wdata ( i_data    ),
        .o_rdata ( mem_out   ),
        // verilator lint_off PINCONNECTEMPTY
        .o_valid (           )
        // verilator lint_on PINCONNECTEMPTY
    );

    always @(posedge CLK) begin
        if (RST) begin
            last_peek <= 1'b0;
        end else begin
            last_peek <= i_peek;
        end
    end

    always @(posedge CLK) begin
        if (RST) begin
            cache_before_peek <= 1'b0;
        end else if (~last_peek && i_peek) begin
            cache_before_peek <= cache_valid;
        end
    end

    always @(posedge CLK) begin
        if (RST) begin
            cache_valid <= 1'b0;
        end else if (enable_bypass) begin
            cache_valid <= 1'b1;
        end else if (restore_cache) begin
            cache_valid <= cache_before_peek;
        end else if (pop || i_peek) begin
            cache_valid <= 1'b0;
        end
    end

    always @(posedge CLK) begin
        if (enable_bypass) begin
            cache_data <= i_data;
        end
    end

    always @(posedge CLK) begin
        if (RST) begin
            wr_ptr        <= 0;
            wr_circle_odd <= 0;
        end else if (push || shift) begin
            if (wr_ptr == MAX_PTR) begin
                wr_ptr        <= 0;
                wr_circle_odd <= ~wr_circle_odd;
            end else begin
                wr_ptr <= wr_ptr + 1'b1;
            end
        end
    end

    always @(posedge CLK) begin
        if (RST) begin
            rd_ptr        <= 0;
            rd_circle_odd <= 0;
        end else if (pop || i_peek || shift) begin
            if (rd_ptr == MAX_PTR) begin
                rd_ptr        <= 0;
                if (~i_peek) begin
                    rd_circle_odd <= ~rd_circle_odd;
                end
            end else begin
                rd_ptr <= rd_ptr + 1'b1;
            end
        end
    end

    assign o_empty = (wr_ptr == rd_ptr) && (wr_circle_odd == rd_circle_odd);
    assign o_full  = (wr_ptr == rd_ptr) && (wr_circle_odd != rd_circle_odd);

    // Hide memory latency by choosing between mem and flip-flop
    assign o_data  = cache_valid ? cache_data : mem_out;

    `ifdef FORMAL
        always @(posedge CLK) begin
            if (~RST) begin
                f_full:     cover (o_full);
                f_empty:    cover (o_empty);
                f_notfull:  cover (~o_full);
                f_notempty: cover (~o_empty);

                f_full_empty: assert (!(o_full && o_empty));

                if (pop) begin
                    f_pop_empty: assert (~o_empty);
                end

                if (push) begin
                    f_push_full: assert (~o_full);
                end
            end
        end
    `endif

endmodule
