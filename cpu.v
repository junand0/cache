`timescale 1ns/1ns
`define WORD_SIZE 16    // data and address word size

`include "opcodes.v"

`define EX_CTRL_SIZE 9 // EX stage control signal total size
// each EX control signal pointer
`define BRANCH_POINT 8
`define ALUSRCA_POINT 7
`define ALUSRCB_POINT 6
`define ALUOP_POINT 5
`define REGDST_POINT 1

`define MEM_CTRL_SIZE 2
`define MEMWRITE_POINT 1
`define MEMREAD_POINT 0

`define WB_CTRL_SIZE 4
`define ISHTL_POINT 3
`define ISWWD_POINT 2
`define MEMTOREG_POINT 1
`define REGWRITE_POINT 0

// flush code
`define FLUSH_CODE_SIZE 3
`define NICE_PRED 0
`define JMP_FLUSH 1
`define BR_FLUSH 2
`define NBR_FLUSH 3
`define JR_FLUSH 4

// PCSrc control signal
`define PCSRC_SIZE 3
`define PCSRC_BTB 3'd0
`define PCSRC_BR 3'd1
`define PCSRC_JMP 3'd2
`define PCSRC_RS 3'd3
`define PCSRC_NBR 3'd4

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

`define BLOCK_SIZE 64

module cpu(
    input Clk, 
    input Reset_N, 

	// Instruction memory interface
    output i_readM, 
    output i_writeM, 
    output [`WORD_SIZE-1:0] i_address, 
    inout [`BLOCK_SIZE-1:0] i_data,

	// Data memory interface
    output d_readM, 
    output d_writeM, 
    output [`WORD_SIZE-1:0] d_address, 
    inout [`BLOCK_SIZE-1:0] d_data, 

    output [`WORD_SIZE-1:0] num_inst, 
    output [`WORD_SIZE-1:0] output_port, 
    output is_halted
);

	// TODO : Implement your pipelined CPU!
//// datapath instantiation
    datapath datapath(
        .clk(Clk),
        .reset_n(Reset_N),
        .num_inst(num_inst),
        .output_port(output_port),
        .is_halted(is_halted),

        //// control interface
        .dep_code_rs(dep_code_rs),
        .dep_code_rt(dep_code_rt),
        .flush_code(flush_code),

        .EX_ctrl(EX_ctrl),
        .MEM_ctrl(MEM_ctrl),
        .WB_ctrl(WB_ctrl),
        .PCSrc(PCSrc),
        .isWWD(isWWD),

        .func_code(func_code),
        .opcode(opcode),
        .rs_ID(rs_ID),
        .rt_ID(rt_ID),
        .rd_EX(rd_EX),
        .rt_EX(rt_EX),
        .jmp_target(jmp_target),
        .pc(pc),
        .pc_1_ID(pc_1_ID),
        .BranchCond(BranchCond),
        .br_target(br_target),
        .fw_rf_read_data1(fw_rf_read_data1),
        .isValid_inst_ID(isValid_inst_ID),
        .wbit_ID(wbit_ID),

        .RegWrite_EX(RegWrite_EX),
        .RegWrite_MEM(RegWrite_MEM),
        .RegWrite_WB(RegWrite_WB),
        .dest_EX(dest_EX),
        .dest_WB(dest_WB),
        .dest_MEM(dest_MEM),
        .RegDst_EX(RegDst_EX),
        .MemRead_EX(MemRead_EX),
        .MemRead_MEM(MemRead_MEM),
        .valid_inst_EX(valid_inst_EX),
        .valid_inst_MEM(valid_inst_MEM),
        .valid_inst_WB(valid_inst_WB),

        // Icache interface
        .i_addressC(i_addressC),
        .i_readC(i_readC),
        .i_dataC(i_dataC),
        .stall(stall),

        // Dcache interface
        .d_readC(d_readC),
        .d_writeC(d_writeC),
        .d_addressC(d_addressC),
        .d_dataC(d_dataC),
        .dcache_write_done(dcache_write_done)
    );
    
    // Icache interface
    wire i_readC;
    wire [`WORD_SIZE-1:0] i_addressC;
    wire [`WORD_SIZE-1:0] i_dataC;
    wire stall;

    // Dcache interface
    wire d_readC;
    wire d_writeC;
    wire [`WORD_SIZE-1:0] d_addressC;
    wire [`WORD_SIZE-1:0] d_dataC;
    wire dcache_write_done;

    // control unit interface
    wire [`DEP_RS_CODE_SIZE-1:0] dep_code_rs;
    wire [`DEP_RT_CODE_SIZE-1:0] dep_code_rt;
    wire [`FLUSH_CODE_SIZE-1:0] flush_code;

    wire [`EX_CTRL_SIZE-1:0] EX_ctrl;
    wire [`MEM_CTRL_SIZE-1:0] MEM_ctrl;
    wire [`WB_CTRL_SIZE-1:0] WB_ctrl;
    wire [`PCSRC_SIZE-1:0] PCSrc;
    wire isWWD;

    wire [5:0] func_code;
    wire [3:0] opcode;
    wire [1:0] rs_ID;
    wire [1:0] rt_ID;
    wire [1:0] rd_EX;
    wire [1:0] rt_EX;
    wire [`WORD_SIZE-1:0] jmp_target;
    wire [`WORD_SIZE-1:0] pc;
    wire [`WORD_SIZE-1:0] pc_1_ID;
    wire [`WORD_SIZE-1:0] BranchCond;
    wire [`WORD_SIZE-1:0] br_target;
    wire [`WORD_SIZE-1:0] fw_rf_read_data1;
    wire isValid_inst_ID;
    wire wbit_ID;

    // for dependency check
    wire RegWrite_EX;
    wire RegWrite_MEM;
    wire RegWrite_WB;
    wire [1:0] dest_EX;
    wire [1:0] dest_WB;
    wire [1:0] dest_MEM;
    wire [1:0] RegDst_EX;
    wire valid_inst_EX;
    wire valid_inst_MEM;
    wire valid_inst_WB;

//// control unit instantiation
    control control(
        .reset_n(Reset_N),
        .clk(Clk),
        /// datapath interface
        .opcode(opcode),
        .func_code(func_code),
        .rs_ID(rs_ID),
        .rt_ID(rt_ID),
        .rd_EX(rd_EX),
        .rt_EX(rt_EX),
        .jmp_target(jmp_target),
        .pc(pc),
        .pc_1_ID(pc_1_ID),
        .BranchCond(BranchCond),
        .br_target(br_target),
        .fw_rf_read_data1(fw_rf_read_data1),
        .isValid_inst_ID(isValid_inst_ID),
        .wbit_ID(wbit_ID),

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

        // hazard informations
        .dep_code_rs(dep_code_rs),
        .dep_code_rt(dep_code_rt),
        .flush_code(flush_code),
        // control signals
        .EX_ctrl(EX_ctrl),
        .MEM_ctrl(MEM_ctrl),
        .WB_ctrl(WB_ctrl),
        .PCSrc(PCSrc),

        .isWWD(isWWD)
    );

//// Icache instantiation
    Icache Icache(
        .clk(Clk),
        .reset_n(Reset_N),
        .i_readC(i_readC),
        .i_writeC(i_writeC),
        .i_addressC(i_addressC),
        .i_dataC(i_dataC),
        .i_data(i_data),
        .i_readM(i_readM),
        .i_address(i_address),
        .stall(stall)
    );

//// Dcache instantiation
    Dcache Dcache(
        .clk(Clk),
        .reset_n(Reset_N),
        .d_readC(d_readC),
        .d_writeC(d_writeC),
        .d_addressC(d_addressC),

        .d_dataC(d_dataC),
        .d_data(d_data),

        .d_readM(d_readM),
        .d_writeM(d_writeM),
        .d_address(d_address),
        .dcache_write_done(dcache_write_done)
    );

endmodule
