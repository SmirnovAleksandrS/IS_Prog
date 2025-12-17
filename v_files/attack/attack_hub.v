module attack_hub
#(
    parameter NS_TO_CLK = 10,
    parameter BYTE_SIZE = 8,
    parameter MAX_SIZE  = 12,
    parameter PARALLEL  = 0
)
(
    input wire CLK,
    input wire RST,

    input  wire ear,
    output wire injection,

    input wire [3 : 0] trigger,

    input wire i_valid,

    input wire [BYTE_SIZE          - 1 : 0] type,
    input wire [BYTE_SIZE          - 1 : 0] len,
    input wire [MAX_SIZE*BYTE_SIZE - 1 : 0] message
);


generate if (PARALLEL)
begin: parallel

localparam ST_START    = 0;
localparam ST_OP_DEL   = 1;
localparam ST_POARCH   = 2;
localparam ST_PULSE    = 3;
localparam ST_WAIT     = 4;
localparam ST_WAIT_VAL = 5;

wire [BYTE_SIZE   - 1 : 0] start_tr_type;
wire [BYTE_SIZE   - 1 : 0] end_tr_type;
wire [2*BYTE_SIZE - 1 : 0] operation_delay;
wire [2*BYTE_SIZE - 1 : 0] victum_timer;
wire [2*BYTE_SIZE - 1 : 0] puls_ammount;
wire [2*BYTE_SIZE - 1 : 0] front_poarch;
wire [2*BYTE_SIZE - 1 : 0] injection_width;

reg [$clog2(2*BYTE_SIZE) : 0] op_del_cnt;
reg [$clog2(2*BYTE_SIZE) : 0] victum_cnt;
reg [$clog2(2*BYTE_SIZE) : 0] front_poarch_cnt;
reg [$clog2(2*BYTE_SIZE) : 0] inj_width_cnt;
reg [$clog2(2*BYTE_SIZE) : 0] puls_ammount_cnt;

reg [3 : 0] state;

reg injection_ff;

assign injection = injection_ff;


assign start_tr_type   = message[0 +: BYTE_SIZE];
assign end_tr_type     = message[BYTE_SIZE +: BYTE_SIZE];
assign operation_delay = message[2*BYTE_SIZE +: 2*BYTE_SIZE] >> 3;
assign victum_timer    = message[4*BYTE_SIZE +: 2*BYTE_SIZE] >> 3;
assign puls_ammount    = message[6*BYTE_SIZE +: 2*BYTE_SIZE];
assign front_poarch    = message[8*BYTE_SIZE +: 2*BYTE_SIZE] >> 3;
assign injection_width = message[10*BYTE_SIZE +: 2*BYTE_SIZE] >> 3;

always @(posedge CLK) begin
    if (RST) begin
        state <= ST_START;
    end else if (i_valid) begin
        state <= ST_OP_DEL;
    end else if (op_del_cnt == operation_delay || inj_width_cnt == injection_width - 1) begin
        state <= ST_POARCH;
    end else if (front_poarch_cnt == front_poarch) begin
        state <= ST_PULSE;
    end else if (puls_ammount_cnt == puls_ammount) begin
        state <= ST_WAIT;
    end else if (victum_cnt == victum_timer) begin
        state <= ST_WAIT_VAL;
    end else begin
        state <= state;
    end
end

wire neg_ear;
reg  ear_del;

reg [2 : 0] cnt;

always @(posedge CLK) begin
    if (RST) begin
        ear_del <= 0;
    end else begin
        ear_del <= ear;
    end
end

assign neg_ear = ~ear & ear_del;



    always @(posedge CLK) begin
        if (RST) begin
            op_del_cnt       <= 'd0;
            victum_cnt       <= 'd0;
            front_poarch_cnt <= 'd0;
            inj_width_cnt    <= 'd0;
            puls_ammount_cnt <= 'd0;
            injection_ff     <= 'd0;
        end else begin
            if (state == ST_OP_DEL) begin

                op_del_cnt <= (op_del_cnt == operation_delay) ? 'd0 : op_del_cnt + 1'b1;

            end else if (state == ST_POARCH) begin
                if (neg_ear) begin

                    injection_ff <= 1'b0;
                    front_poarch_cnt <= (front_poarch_cnt == front_poarch) ? 'd0 : front_poarch_cnt + 1'b1;
                    puls_ammount_cnt <= (puls_ammount_cnt == puls_ammount) ? 'd0 : puls_ammount_cnt + 1'b1;

                end
            end else if (state == ST_PULSE) begin

                injection_ff <= 1'b1;
                inj_width_cnt <= (inj_width_cnt == injection_width - 1) ? 'd0 : inj_width_cnt + 1'b1;

            end else if (state == ST_WAIT) begin

                victum_cnt <= (victum_cnt == victum_timer) ? 'd0 : victum_cnt + 1'b1;     

            end
        end
    end

end else begin

wire [BYTE_SIZE   - 1 : 0] start_tr_type;
wire [BYTE_SIZE   - 1 : 0] end_tr_type;
wire [2*BYTE_SIZE - 1 : 0] operation_delay;
wire [2*BYTE_SIZE - 1 : 0] victum_timer;
wire [2*BYTE_SIZE - 1 : 0] victum_clk;
wire [2*BYTE_SIZE - 1 : 0] inj_clk;
wire [2*BYTE_SIZE - 1 : 0] inj_time;


reg [2*BYTE_SIZE  : 0] op_del_cnt;
reg [2*BYTE_SIZE  : 0] victum_cnt;
reg [2*BYTE_SIZE  : 0] victum_clk_cnt;
reg [2*BYTE_SIZE  : 0] inj_clk_cnt;
reg [2*BYTE_SIZE  : 0] inj_time_cnt;

assign start_tr_type   = message[0 +: BYTE_SIZE];
assign end_tr_type     = message[BYTE_SIZE +: BYTE_SIZE];
assign operation_delay = message[2*BYTE_SIZE +: 2*BYTE_SIZE];
assign victum_timer    = message[4*BYTE_SIZE +: 2*BYTE_SIZE];
assign victum_clk      = message[6*BYTE_SIZE +: 2*BYTE_SIZE];
assign inj_clk         = message[8*BYTE_SIZE +: 2*BYTE_SIZE];
assign inj_time        = message[10*BYTE_SIZE +: 2*BYTE_SIZE];


wire neg_check;
wire neg_trig;
reg  neg_trig_del;

assign neg_trig = (end_tr_type == 0) ? trigger[0] :
                  (end_tr_type == 1) ? trigger[1] :
                  (end_tr_type == 2) ? trigger[2] :
                  (end_tr_type == 3) ? trigger[3] : 0;

always @(posedge CLK) begin
    if (RST) begin
        neg_trig_del <= 0;
    end else begin
        case(end_tr_type)
            0: neg_trig_del <= trigger[0];
            1: neg_trig_del <= trigger[1];
            2: neg_trig_del <= trigger[2];
            3: neg_trig_del <= trigger[3];
        endcase
    end
end

assign neg_check = ~neg_trig & neg_trig_del;


wire pos_check;
wire pos_trig;
reg  pos_trig_del;

assign pos_trig = (start_tr_type == 0) ? trigger[0] :
                  (start_tr_type == 1) ? trigger[1] :
                  (start_tr_type == 2) ? trigger[2] :
                  (start_tr_type == 3) ? trigger[3] : 0;

always @(posedge CLK) begin
    if (RST) begin
        pos_trig_del <= 0;
    end else begin
        case(start_tr_type)
            0: pos_trig_del <= trigger[0];
            1: pos_trig_del <= trigger[1];
            2: pos_trig_del <= trigger[2];
            3: pos_trig_del <= trigger[3];
        endcase
    end
end

assign pos_check = pos_trig & ~pos_trig_del;

reg [3 : 0] state;

localparam ST_START     = 0;
localparam ST_WAIT_TRIG = 1;
localparam ST_DELAY     = 2;
localparam ST_WORK      = 3;
localparam ST_RESULT    = 4;


always @(posedge CLK) begin
    if (RST) begin

        state <= ST_START;

    end else if (i_valid && (state == ST_START)) begin

        state <= ST_WAIT_TRIG;

    end else if (pos_check && (state == ST_WAIT_TRIG)) begin

        state <= ST_DELAY;

    end else if ((op_del_cnt == operation_delay) && (state == ST_DELAY)) begin

        state <= ST_WORK;

    end else if ((inj_time_cnt == inj_time) && (state == ST_WORK)) begin

        state <= ST_RESULT;

    end else if (((victum_cnt == victum_clk) || neg_check)) begin
        
        state <= ST_START;

    end else begin
        
        state <= state;

    end
end

reg injection_ff_nwork;
reg injection_ff_work;

assign injection = (state == ST_WORK) ? injection_ff_work : injection_ff_nwork;

always @(posedge CLK) begin
    if (RST) begin
        injection_ff_nwork <= 'd1;
        injection_ff_work  <= 'd1;
        op_del_cnt         <= 'd0;
        victum_cnt         <= 'd0;
        victum_clk_cnt     <= 'd0;
        inj_clk_cnt        <= 'd0;
        inj_time_cnt       <= 'd0;

    end else begin

        if (state != (ST_WORK)) begin

            inj_clk_cnt  <= 'd0;
            if (victum_clk == 0) begin

                injection_ff_nwork <= 'd0;
                
            end else if (victum_clk_cnt == (victum_clk >> 1)) begin

                injection_ff_nwork <= ~injection_ff_nwork;      
                victum_clk_cnt <= 'd0;

            end else victum_clk_cnt <= victum_clk_cnt + 1'b1;

        end else victum_clk_cnt <= 1'd0;


        if (state == ST_DELAY) begin

            op_del_cnt <= (op_del_cnt == operation_delay) ? 'd0 : op_del_cnt + 1'b1;

        end else if (state == ST_WORK) begin

            if (inj_clk_cnt == (inj_clk >> 1)) begin

                injection_ff_work <= ~injection_ff_work;
                inj_clk_cnt  <= 'd0;

            end else inj_clk_cnt <= inj_clk_cnt + 1'b1; 

            inj_time_cnt <= (inj_time_cnt == inj_time) ? 'd0 : inj_time_cnt + 1'b1;

        end else if (state == ST_RESULT) begin

            if ((victum_cnt == victum_clk) || neg_check)

                victum_cnt <= 'd0;

            else victum_cnt <= victum_cnt + 1'b1; 

        end

    end
end

end
endgenerate


endmodule