`define WORD_SIZE 16    // data and address word size

// EX stage control signals
`define EX_CTRL_SIZE 9 
`define BRANCH_POINT 8
`define ALUSRCA_POINT 7
`define ALUSRCB_POINT 6
`define ALUOP_POINT 5
`define REGDST_POINT 1
// MEM stage control signals
`define MEM_CTRL_SIZE 2
`define MEMWRITE_POINT 1
`define MEMREAD_POINT 0
// WB stage control signals
`define WB_CTRL_SIZE 4
`define ISHTL_POINT 3
`define ISWWD_POINT 2
`define MEMTOREG_POINT 1
`define REGWRITE_POINT 0

// PCSrc control signal
`define PCSRC_SIZE 3
`define PCSRC_BTB 3'd0
`define PCSRC_BR 3'd1
`define PCSRC_JMP 3'd2
`define PCSRC_RS 3'd3
`define PCSRC_NBR 3'd4

// flush code
`define FLUSH_CODE_SIZE 3
`define NICE_PRED 3'd0
`define JMP_FLUSH 3'd1
`define BR_FLUSH 3'd2
`define NBR_FLUSH 3'd3
`define JR_FLUSH 3'd4

//// dependency code for forwarding

//// dependency code with rs for forwarding
`define DEP_RS_CODE_SIZE 6
`define DEP_NONE_RS 0
`define DEP_ALURES_EX_RS 1
`define DEP_ALURES_MEM_RS 2
`define DEP_MEMRD_EX_RS 3
`define DEP_MEMRD_MEM_RS 4
`define DEP_WB_RS 5

//// dependency code with rt for forwarding
`define DEP_RT_CODE_SIZE 6
`define DEP_NONE_RT 0
`define DEP_ALURES_EX_RT 1
`define DEP_ALURES_MEM_RT 2
`define DEP_MEMRD_EX_RT 3
`define DEP_MEMRD_MEM_RT 4
`define DEP_WB_RT 5

`include "opcodes.v"

module control (
    input reset_n,
    input clk,
/// datapath interface
    input [3:0] opcode,
    input [5:0] func_code,
    input [1:0] rs_ID,
    input [1:0] rt_ID,
    input [1:0] rd_EX,
    input [1:0] rt_EX,
    input [`WORD_SIZE-1:0] jmp_target,
    input [`WORD_SIZE-1:0] pc,
    input [`WORD_SIZE-1:0] pc_1_ID,
    input [`WORD_SIZE-1:0] BranchCond,
    input [`WORD_SIZE-1:0] br_target,
    input [`WORD_SIZE-1:0] fw_rf_read_data1,
    input isValid_inst_ID,
    input wbit_ID,

    input RegWrite_EX,
    input RegWrite_MEM,
    input RegWrite_WB,
    input [1:0] dest_WB,
    input [1:0] dest_MEM,
    input [1:0] RegDst_EX,
    input MemRead_EX,
    input MemRead_MEM,
    input valid_inst_EX,
    input valid_inst_MEM,
    input valid_inst_WB,

    // hazard informations
    output [`DEP_RS_CODE_SIZE-1:0] dep_code_rs,
    output [`DEP_RT_CODE_SIZE-1:0] dep_code_rt,
    output [`FLUSH_CODE_SIZE-1:0] flush_code,
    // control signals
    output [`EX_CTRL_SIZE-1:0] EX_ctrl,
    output [`MEM_CTRL_SIZE-1:0] MEM_ctrl,
    output [`WB_CTRL_SIZE-1:0] WB_ctrl,
    output [`PCSRC_SIZE-1:0] PCSrc,

    output isWWD
);

//// bundle of control signals for latches of datapath
    assign EX_ctrl[`BRANCH_POINT] = (!reset_n) ? 0 : Branch;
    assign EX_ctrl[`ALUSRCA_POINT] = (!reset_n) ? 0 : ALUSrcA_reg;
    assign EX_ctrl[`ALUSRCB_POINT] = (!reset_n) ? 0 : ALUSrcB_reg;
    assign EX_ctrl[`ALUOP_POINT:`ALUOP_POINT-3] = (!reset_n) ? 0 : ALUOp_reg;
    assign EX_ctrl[`REGDST_POINT:`REGDST_POINT-1] = (!reset_n) ? 0 : RegDst_reg;

    assign MEM_ctrl[`MEMWRITE_POINT] = (!reset_n) ? 0 : MemWrite_reg;
    assign MEM_ctrl[`MEMREAD_POINT] = (!reset_n) ? 0 : MemRead_reg;

    assign WB_ctrl[`ISHTL_POINT] = (!reset_n) ? 0 :
                                    (opcode == `OPCODE_Rtype) && (func_code == `FUNC_HLT) ? 1 : 0;
    assign WB_ctrl[`ISWWD_POINT] = (!reset_n) ? 0 : isWWD;
    assign WB_ctrl[`MEMTOREG_POINT] = (!reset_n) ? 0 : MemtoReg_reg;
    assign WB_ctrl[`REGWRITE_POINT] = (!reset_n) ? 0 : RegWrite_reg;

    assign isWWD = (!reset_n) ? 0 :
                    (func_code == `FUNC_WWD) ? 1 : 0;

//// dependency detector submodule interface
    dep_detector dep_detector(
        .reset_n(reset_n),
        .rs_ID(rs_ID),
        .rt_ID(rt_ID),
        .rd_EX(rd_EX),
        .rt_EX(rt_EX),
        .opcode(opcode),
        .func_code(func_code),

        .RegWrite_EX(RegWrite_EX),
        .RegWrite_MEM(RegWrite_MEM),
        .RegWrite_WB(RegWrite_WB),
        .dest_WB(dest_WB),
        .dest_MEM(dest_MEM),
        .RegDst_EX(RegDst_EX),
        .MemRead_EX(MemRead_EX),
        .MemRead_MEM(MemRead_MEM),
        .valid_inst_EX(valid_inst_EX),
        .valid_inst_MEM(valid_inst_MEM),
        .valid_inst_WB(valid_inst_WB),

        .dep_code_rs(dep_code_rs),
        .dep_code_rt(dep_code_rt)
    );

//// misprediction detector submodule interface
    mispred_detector mispred_detector(
        .reset_n(reset_n),
        .jmp_target(jmp_target),
        .pc(pc),
        .pc_1_ID(pc_1_ID),
        .IsJtype(IsJtype),
        .BranchCond(BranchCond),
        .br_target(br_target),
        .Branch(Branch),
        .fw_rf_read_data1(fw_rf_read_data1),
        .JPRorJRL(JPRorJRL),
        .isValid_inst_ID(isValid_inst_ID),
        .wbit_ID(wbit_ID),

        .flush_code(flush_code)
    );

    wire JPRorJRL;
    assign JPRorJRL = (opcode == `OPCODE_Rtype) && ((func_code == `FUNC_JPR) || (func_code == `FUNC_JRL));

    wire IsJtype;
    assign IsJtype = (opcode == `OPCODE_JMP) || (opcode == `OPCODE_JAL);

    wire Branch;
    assign Branch = (!reset_n) ? 0 :
                    (0 <= opcode) && (opcode <= 4'b0011) ? 1 : 0;

    wire IsItype;
    assign IsItype = (!reset_n) ? 0 :
                    (0 <= opcode) && (opcode <= 4'b1000);

//// control signal generation in ID stage of datapath
    reg ALUSrcA_reg;
    reg ALUSrcB_reg;
    reg [3:0] ALUOp_reg;
    reg [1:0] RegDst_reg;
    reg MemWrite_reg;
    reg MemRead_reg;
    reg MemtoReg_reg;
    reg RegWrite_reg;

    always @(*) begin
        if(!reset_n) begin
            ALUSrcA_reg = 0;
            ALUSrcB_reg = 0;
            ALUOp_reg = 0;
            RegDst_reg = 0;
            MemWrite_reg = 0;
            MemRead_reg = 0;
            MemtoReg_reg = 0;
            RegWrite_reg = 0;
        end
        if(reset_n) begin
            if((opcode == `OPCODE_Rtype) && (func_code != `FUNC_JPR) && (func_code != `FUNC_JRL) && (!isWWD)) begin
                ALUSrcA_reg = 0;
                ALUSrcB_reg = 0;
                ALUOp_reg = func_code[3:0];
                RegDst_reg = 2'b01;
                MemWrite_reg = 0;
                MemRead_reg = 0;
                MemtoReg_reg = 0;
                RegWrite_reg = 1;
            end
            else if(IsItype && (opcode != `OPCODE_LWD) && (opcode != `OPCODE_SWD) && (!Branch)) begin
                ALUSrcA_reg = 0;
                ALUSrcB_reg = 1;
                case(opcode)
                    `OPCODE_ADI : begin
                        ALUOp_reg <= 0; // ADI
                    end
                    `OPCODE_ORI : begin
                        ALUOp_reg <= 4'b1000; // ORI
                    end
                    `OPCODE_LHI : begin
                        ALUOp_reg <= 4'b1001; // LHI
                    end
                endcase
                RegDst_reg = 0;
                MemWrite_reg = 0;
                MemRead_reg = 0;
                MemtoReg_reg = 0;
                RegWrite_reg = 1;
            end
            else if(func_code == `FUNC_WWD) begin
                ALUSrcA_reg = 0;
                ALUOp_reg = 4'b1011; // ALUOp : Identity
                MemWrite_reg = 0;
                MemRead_reg = 0;
                RegWrite_reg = 0;
            end
            else if(opcode == `OPCODE_LWD) begin
                ALUSrcA_reg = 0;
                ALUSrcB_reg = 1;
                ALUOp_reg = 0; // ADD
                RegDst_reg = 0;
                MemWrite_reg = 0;
                MemRead_reg = 1;
                MemtoReg_reg = 1;
                RegWrite_reg = 1;
            end
            else if(opcode == `OPCODE_SWD) begin
                ALUSrcA_reg = 0;
                ALUSrcB_reg = 1;
                ALUOp_reg = 0; // ADD
                MemWrite_reg = 1;
                MemRead_reg = 0;
                RegWrite_reg = 0;
            end
            else if(Branch) begin
                ALUSrcA_reg = 0;
                ALUSrcB_reg = 0;
                case(opcode)
                    `OPCODE_BEQ : begin
                        ALUOp_reg <= 4'b1100; // operation of A == B ?
                    end
                    `OPCODE_BNE : begin
                        ALUOp_reg <= 4'b1101; // operation of A != B ?
                    end
                    `OPCODE_BGZ : begin
                        ALUOp_reg <= 4'b1010; // operation of A > 0 ?
                    end
                    `OPCODE_BLZ : begin
                        ALUOp_reg <= 4'b1110; // operation of A < 0 ?
                    end
                endcase
                MemWrite_reg = 0;
                MemRead_reg = 0;
                RegWrite_reg = 0;
            end
            else if(opcode == `OPCODE_JMP) begin
                MemWrite_reg = 0;
                MemRead_reg = 0;
                RegWrite_reg = 0;
            end
            else if(opcode == `OPCODE_JAL) begin
                RegDst_reg = 2'b10;
                ALUSrcA_reg = 1;
                ALUOp_reg = 4'b1011; // ID
                MemWrite_reg = 0;
                MemRead_reg = 0;
                RegWrite_reg = 1;
                MemtoReg_reg = 0;
            end
            else if(func_code == `FUNC_JPR) begin
                MemWrite_reg = 0;
                MemRead_reg = 0;
                RegWrite_reg = 0;
            end
            else if(func_code == `FUNC_JRL) begin
                ALUSrcA_reg = 1;
                ALUOp_reg = 4'b1011; // ID
                RegDst_reg = 2'b10;
                MemWrite_reg = 0;
                MemRead_reg = 0;
                RegWrite_reg = 1;
                MemtoReg_reg = 0;
            end
        end
        
    end

//// PCSrc generation
    assign PCSrc = (flush_code == `NICE_PRED) ? `PCSRC_BTB :
                    (flush_code == `JMP_FLUSH) ? `PCSRC_JMP :
                    (flush_code == `BR_FLUSH) ? `PCSRC_BR :
                    (flush_code == `NBR_FLUSH) ? `PCSRC_NBR : `PCSRC_RS; 

endmodule

