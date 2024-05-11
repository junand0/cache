`define WORD_SIZE 16    // data and address word size
`include "opcodes.v"

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


module dep_detector (
    input reset_n,
    input [1:0] rs_ID,
    input [1:0] rt_ID,
    input [1:0] rd_EX,
    input [1:0] rt_EX,
    input [3:0] opcode,
    input [5:0] func_code,

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

    output [`DEP_RS_CODE_SIZE-1:0] dep_code_rs,
    output [`DEP_RT_CODE_SIZE-1:0] dep_code_rt
);

    wire use_rs;
    wire use_rt;

    wire IsItype;
    assign IsItype = (0 <= opcode) && (opcode <= 4'b1000);

    assign use_rs = ((opcode == `OPCODE_Rtype) && (opcode != `FUNC_HLT)) // will the inst in ID stage use rs value?
                    || (IsItype && (opcode != `OPCODE_LHI)) ? 1: 0; 
    assign use_rt = (opcode == `OPCODE_BNE) // will the inst in ID stage use rt value?
                    || (opcode == `OPCODE_BEQ)
                    || (opcode == `OPCODE_SWD)
                    || (func_code == `FUNC_ADD)
                    || (func_code == `FUNC_SUB)
                    || (func_code == `FUNC_AND)
                    || (func_code == `FUNC_ORR) ? 1 : 0;

    assign dep_code_rs = (!reset_n) ? 0
                        : (((rs_ID == rd_EX) && use_rs && RegWrite_EX && (RegDst_EX == 2'b01))
                        || ((rs_ID == rt_EX) && use_rs && RegWrite_EX && (RegDst_EX == 0))
                        || ((rs_ID == 2'b10) && use_rs && RegWrite_EX && (RegDst_EX == 2'b10)))
                        && (MemRead_EX) 
                        && (valid_inst_EX) ? `DEP_MEMRD_EX_RS // dep btw rs and memread data of inst in ex stage
                        : (((rs_ID == rd_EX) && use_rs && RegWrite_EX && (RegDst_EX == 2'b01))
                        || ((rs_ID == rt_EX) && use_rs && RegWrite_EX && (RegDst_EX == 0))
                        || ((rs_ID == 2'b10) && use_rs && RegWrite_EX && (RegDst_EX == 2'b10)))
                        && (!MemRead_EX) 
                        && (valid_inst_EX) ? `DEP_ALURES_EX_RS // dependency btw rs and ALUresult of ex stage
                        : ((rs_ID == dest_MEM) && use_rs && RegWrite_MEM)
                        && (!MemRead_MEM) 
                        && (valid_inst_MEM) ? `DEP_ALURES_MEM_RS // dep btw rs and ALUresult of mem stage
                        : ((rs_ID == dest_MEM) && use_rs && RegWrite_MEM)
                        && (MemRead_MEM)
                        && (valid_inst_MEM) ? `DEP_MEMRD_MEM_RS // dep btw rs and memread data of inst in mem stage
                        : ((rs_ID == dest_WB) && use_rs && RegWrite_WB)
                        && (valid_inst_WB) ? `DEP_WB_RS // dep btw rs and register write value of wb stage
                        : `DEP_NONE_RS;

    assign dep_code_rt = (!reset_n) ? 0
                        : (((rt_ID == rd_EX) && use_rt && RegWrite_EX && (RegDst_EX == 2'b01))
                        || ((rt_ID == rt_EX) && use_rt && RegWrite_EX && (RegDst_EX == 0))
                        || ((rt_ID == 2'b10) && use_rt && RegWrite_EX && (RegDst_EX == 2'b10)))
                        && (MemRead_EX)
                        && (valid_inst_EX) ? `DEP_MEMRD_EX_RT // dep btw rt and memread data of inst in ex stage
                        : (((rt_ID == rd_EX) && use_rt && RegWrite_EX && (RegDst_EX == 2'b01))
                        || ((rt_ID == rt_EX) && use_rt && RegWrite_EX && (RegDst_EX == 0))
                        || ((rt_ID == 2'b10) && use_rt && RegWrite_EX && (RegDst_EX == 2'b10)))
                        && (!MemRead_EX)
                        && (valid_inst_EX) ? `DEP_ALURES_EX_RT // dep btw rt and ALUresult of ex stage
                        : ((rt_ID == dest_MEM) && use_rt && RegWrite_MEM)
                        && (!MemRead_MEM) 
                        && (valid_inst_MEM) ? `DEP_ALURES_MEM_RT // dep btw rt and ALUresult of mem stage
                        : ((rt_ID == dest_MEM) && use_rt && RegWrite_MEM)
                        && (MemRead_MEM)
                        && (valid_inst_MEM) ? `DEP_MEMRD_MEM_RT // dep btw rt and memread data of inst in mem stage
                        : ((rt_ID == dest_WB) && use_rt && RegWrite_WB)
                        && (valid_inst_WB) ? `DEP_WB_RT // dep btw rt and register write value of wb stage
                        : `DEP_NONE_RT; // no dependency

endmodule