`define WORD_SIZE 16    // data and address word size
`define TAG_SIZE 6 // tag size

// flush code
`define FLUSH_CODE_SIZE 3
`define NICE_PRED 0
`define JMP_FLUSH 1
`define BR_FLUSH 2
`define NBR_FLUSH 3
`define JR_FLUSH 4

module BTB(
    input clk,
    input reset_n,
    input [`WORD_SIZE-1:0] pc,
    input [`WORD_SIZE-1:0] pc_1_ID,
    input [`FLUSH_CODE_SIZE-1:0] flush_code,
    input [`WORD_SIZE-1:0] jmp_target,
    input [`WORD_SIZE-1:0] br_target,
    input [`WORD_SIZE-1:0] fw_rf_read_data1,

    output [`WORD_SIZE-1:0] btb
);

wire [`TAG_SIZE-1:0] tag;
assign tag = pc[`WORD_SIZE-1:`WORD_SIZE-`TAG_SIZE];
wire [`WORD_SIZE-`TAG_SIZE-1:0] idx;
assign idx = pc[`WORD_SIZE-`TAG_SIZE-1:0];

reg [`TAG_SIZE+`WORD_SIZE-1:0] BTB [0:2**(`WORD_SIZE-`TAG_SIZE)-1];

reg [`WORD_SIZE-1:0] btb_reg;
assign btb = btb_reg;

// reset
integer i;
always @(*) begin
    if(!reset_n) begin
        for(i=0; i < 2**(`WORD_SIZE-`TAG_SIZE)-1; i = i+1) begin
            BTB[i] = `TAG_SIZE+`WORD_SIZE'bz;
        end
    end
end

always @(*) begin
    if(tag == BTB[idx][`TAG_SIZE+`WORD_SIZE-1:`WORD_SIZE]) begin
        btb_reg = BTB[idx][`WORD_SIZE-1:0];
    end
    else begin
        btb_reg = pc + 1;
    end
end

wire [`WORD_SIZE-1:0] pc_ID;
assign pc_ID = pc_1_ID - `WORD_SIZE'd1;
wire [`TAG_SIZE-1:0] tag_ID;
assign tag_ID = pc_ID[`WORD_SIZE-1:`WORD_SIZE-`TAG_SIZE];
wire [`WORD_SIZE-`TAG_SIZE-1:0] idx_ID;
assign idx_ID = pc_ID[`WORD_SIZE-`TAG_SIZE-1:0];

wire [`WORD_SIZE-1:0] test;
always @(posedge clk) begin
    case(flush_code)
        `JMP_FLUSH : begin
            BTB[idx_ID][`TAG_SIZE+`WORD_SIZE-1:`WORD_SIZE] = tag_ID;
            BTB[idx_ID][`WORD_SIZE-1:0] = jmp_target;
        end
        `BR_FLUSH : begin
            BTB[idx_ID][`TAG_SIZE+`WORD_SIZE-1:`WORD_SIZE] = tag_ID;
            BTB[idx_ID][`WORD_SIZE-1:0] = br_target;
        end
        `JR_FLUSH : begin
            BTB[idx_ID][`TAG_SIZE+`WORD_SIZE-1:`WORD_SIZE] = tag_ID;
            BTB[idx_ID][`WORD_SIZE-1:0] = fw_rf_read_data1;
        end
    endcase
end

endmodule
