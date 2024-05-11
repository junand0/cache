`define WORD_SIZE 16    // data and address word size

`define EX_CTRL_SIZE 9 // EX stage control signal total size
// each EX control signal pointer
`define BRANCH_POINT 8
`define ALUSRCA_POINT 7
`define ALUSRCB_POINT 6
`define ALUOP_POINT 5
`define REGDST_POINT 1

`define MEM_CTRL_SIZE 2 // MEM stage control signal total size
// each MEM control signal pointer
`define MEMWRITE_POINT 1
`define MEMREAD_POINT 0

`define WB_CTRL_SIZE 4 // WB stage control signal total size
// each WB control signal pointer
`define ISHTL_POINT 3
`define ISWWD_POINT 2
`define MEMTOREG_POINT 1
`define REGWRITE_POINT 0

`include "opcodes.v"

// data latch size in each stage and pointer
// ID latch
`define ID_LATCH_SIZE 34
`define WAITING_ID_POINT 33 // to verify whether waiting for i_mem access
`define VALID_ID_POINT 32 // the inst in ID latch is valid?
`define PC1_ID_POINT 31 // pc+1 of IF/ID latch pointer
`define INST_ID_POINT 15 // inst of IF/ID latch pointer
// EX latch
`define EX_LATCH_SIZE 77
`define VALID_EX_POINT 76 // the inst in EX latch is valid?
`define PC1_EX_POINT 75 // pc+1 of ID/EX latch pointer
`define RF_RD1_EX_POINT 59 // rf_read_data1 of ID/EX latch pointer
`define RF_RD2_EX_POINT 43 // rf_read_data2 of ID/EX latch pointer
`define IMM_EX_POINT 27 // imm of ID/EX latch pointer
`define RT_EX_POINT 19 // rt of ID/EX latch pointer
`define RD_EX_POINT 17 // rd of ID/EX latch pointer
`define JMPTG_EX_POINT 15 // jmp target of ID/EX latch pointer
// MEM latch
`define MEM_LATCH_SIZE 51
`define VALID_MEM_POINT 50 // the inst in MEM latch is valid?
`define BRTG_MEM_POINT 49 // branch target of EX/MEM latch pointer
`define ALURES_MEM_POINT 33 // ALUresult of EX/MEM latch pointer
`define RF_RD2_MEM_POINT 17 // rf_read_data2 of EX/MEM latch pointer
`define DEST_MEM_POINT 1 // dest of EX/MEM latch pointer
// WB latch
`define WB_LATCH_SIZE 35
`define VALID_WB_POINT 34 // the inst in WB latch is valid?
`define MEM_RD_WB_POINT 33 // dcache_read_data of MEM/WB latch pointer
`define ALURES_WB_POINT 17 // ALUresult of MEM/WB latch pointer
`define DEST_WB_POINT 1 // dest of MEM/WB latch pointer

// control signal latch size in each stage
`define EX_CLATCH_SIZE 15
`define MEM_CLATCH_SIZE 6
`define WB_CLATCH_SIZE 4

// inst field value pointer
`define OPCODE_INST 15
`define RS_INST 11
`define RT_INST 9
`define RD_INST 7
`define FUNC_INST 5
`define IMM_INST 7
`define TA_INST 11

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

module datapath(
    //// cpu interface
    input clk,
    input reset_n,

    output [`WORD_SIZE-1:0] num_inst, 
    output [`WORD_SIZE-1:0] output_port,

    //// control interface
    // dependency code for forwarding
    input [`DEP_RS_CODE_SIZE-1:0] dep_code_rs,
    input [`DEP_RT_CODE_SIZE-1:0] dep_code_rt,
    input [`FLUSH_CODE_SIZE-1:0] flush_code,

    input [`EX_CTRL_SIZE-1:0] EX_ctrl,
    input [`MEM_CTRL_SIZE-1:0] MEM_ctrl,
    input [`WB_CTRL_SIZE-1:0] WB_ctrl,
    input [`PCSRC_SIZE-1:0] PCSrc,
    input isWWD,

    output [5:0] func_code,
    output [3:0] opcode,
    output [1:0] rs_ID,
    output [1:0] rt_ID,
    output [1:0] rd_EX,
    output [1:0] rt_EX,
    output [`WORD_SIZE-1:0] jmp_target,
    output [`WORD_SIZE-1:0] pc,
    output [`WORD_SIZE-1:0] pc_1_ID,
    output [`WORD_SIZE-1:0] BranchCond,
    output [`WORD_SIZE-1:0] br_target,
    output [`WORD_SIZE-1:0] fw_rf_read_data1,
    output isValid_inst_ID,
    output wbit_ID,

    // for dependency check in dep_detector
    output RegWrite_EX,
    output RegWrite_MEM,
    output RegWrite_WB,
    output [1:0] dest_EX,
    output [1:0] dest_WB,
    output [1:0] dest_MEM,
    output [1:0] RegDst_EX,
    output MemRead_EX,
    output MemRead_MEM,
    output valid_inst_EX,
    output valid_inst_MEM,
    output valid_inst_WB,

    // Icache interface
    output i_readC,
    output [`WORD_SIZE-1:0] i_addressC,
    input [`WORD_SIZE-1:0] i_dataC,
    output stall,
    // Dcache interface
    output d_readC,
    output d_writeC,
    output [`WORD_SIZE-1:0] d_addressC,
    inout [`WORD_SIZE-1:0] d_dataC,
    input dcache_write_done,

    output is_halted
);

//// Latches
    // data latches
    reg [`WORD_SIZE-1:0] pc_latch;
    reg [`ID_LATCH_SIZE-1:0] ID_latch;
    reg [`EX_LATCH_SIZE-1:0] EX_latch;
    reg [`MEM_LATCH_SIZE-1:0] MEM_latch;
    reg [`WB_LATCH_SIZE-1:0] WB_latch;
    // control latches
    reg [`EX_CLATCH_SIZE-1:0] EX_clatch;
    reg [`MEM_CLATCH_SIZE-1:0] MEM_clatch;
    reg [`WB_CLATCH_SIZE-1:0] WB_clatch;

//// control unit interface
    assign func_code = {ID_latch[`INST_ID_POINT-`WORD_SIZE+`FUNC_INST+1 : `INST_ID_POINT-`WORD_SIZE+1]}; // function code of inst in ID latch
    assign opcode = ID_latch[`INST_ID_POINT : `INST_ID_POINT-3]; // opcode of inst in ID latch
    assign rs_ID = {ID_latch[`INST_ID_POINT-`WORD_SIZE+`RS_INST+1 : `INST_ID_POINT-`WORD_SIZE+`RS_INST]}; // rs of ID latch
    assign rt_ID = {ID_latch[`INST_ID_POINT-`WORD_SIZE+`RT_INST+1 : `INST_ID_POINT-`WORD_SIZE+`RT_INST]}; // rt of ID latch
    assign rd_EX = {EX_latch[`RD_EX_POINT:`RD_EX_POINT-1]}; // rd of EX latch
    assign rt_EX = {EX_latch[`RT_EX_POINT:`RT_EX_POINT-1]}; // rt of EX latch
    assign jmp_target = {pc_ID[`WORD_SIZE-1:`WORD_SIZE-4],
                        ID_latch[`INST_ID_POINT-`WORD_SIZE+`TA_INST+1 : `INST_ID_POINT-`WORD_SIZE+1]}; // jmp target
    assign pc_1_ID = ID_latch[`PC1_ID_POINT:`PC1_ID_POINT-`WORD_SIZE+1];

    wire [`WORD_SIZE-1:0] pc_ID;
    assign pc_ID = pc_1_ID - `WORD_SIZE'b1;

    assign isValid_inst_ID = ID_latch[`VALID_ID_POINT];

    assign wbit_ID = ID_latch[`WAITING_ID_POINT];

    // early branch resolution in ID stage
    assign br_target = $signed(ID_latch[`PC1_ID_POINT:`PC1_ID_POINT-`WORD_SIZE+1]) + 
                        $signed({{8{ID_latch[`INST_ID_POINT-`WORD_SIZE+`IMM_INST+1]}}, ID_latch[`INST_ID_POINT-`WORD_SIZE+`IMM_INST+1:0]});
    
    assign BranchCond = (!reset_n) ? 0 :
                        (opcode == `OPCODE_BEQ) ? (fw_rf_read_data1 == fw_rf_read_data2) :
                        (opcode == `OPCODE_BNE) ? (fw_rf_read_data1 != fw_rf_read_data2) :
                        (opcode == `OPCODE_BGZ) ? ((fw_rf_read_data1 != 0) && (fw_rf_read_data1[`WORD_SIZE-1] ==  0)) : 
                        (opcode == `OPCODE_BLZ) ? (fw_rf_read_data1[`WORD_SIZE-1] == 1) : 0;

    // for dependency check in dep_detector
    assign RegWrite_EX = EX_clatch[`REGWRITE_POINT+`EX_CTRL_SIZE+`MEM_CTRL_SIZE];
    assign RegWrite_MEM = MEM_clatch[`REGWRITE_POINT+`MEM_CTRL_SIZE];
    assign RegWrite_WB = WB_clatch[`REGWRITE_POINT];
    assign dest_EX = (EX_clatch[`REGDST_POINT:`REGDST_POINT-1] == 0) ? rt_EX :
                    (EX_clatch[`REGDST_POINT:`REGDST_POINT-1] == 2'b01) ? rd_EX : 2'b10;
    assign dest_MEM = MEM_latch[`DEST_MEM_POINT:`DEST_MEM_POINT-1];
    assign dest_WB = WB_latch[`DEST_WB_POINT:`DEST_WB_POINT-1];
    assign RegDst_EX = EX_clatch[`REGDST_POINT:`REGDST_POINT-1];
    wire MemRead_EX;
    assign MemRead_EX = EX_clatch[`EX_CTRL_SIZE + `MEMREAD_POINT];
    wire MemRead_MEM;
    assign MemRead_MEM = MEM_clatch[`MEMREAD_POINT];
    wire valid_inst_EX;
    wire valid_inst_MEM;
    wire valid_inst_WB;
    assign valid_inst_EX = EX_latch[`VALID_EX_POINT];
    assign valid_inst_MEM = MEM_latch[`VALID_MEM_POINT];
    assign valid_inst_WB = WB_latch[`VALID_WB_POINT];

//// write output port
    reg [`WORD_SIZE-1:0] output_port_reg;
    assign output_port = output_port_reg;
    wire test;
    assign test = WB_clatch[`ISWWD_POINT];
    wire [`WORD_SIZE-1:0] testalures;
    assign testalures = WB_latch[`ALURES_WB_POINT:`ALURES_WB_POINT-`WORD_SIZE+1];
    always @(posedge clk) begin
        if(reset_n && WB_clatch[`ISWWD_POINT] && WB_latch[`VALID_WB_POINT]) begin
            output_port_reg <= WB_latch[`ALURES_WB_POINT:`ALURES_WB_POINT-`WORD_SIZE+1];
        end
    end

//// halt operation
    reg is_halted_reg;
    assign is_halted = is_halted_reg;
    always @(posedge clk) begin
        if(reset_n && WB_clatch[`ISHTL_POINT] && WB_latch[`VALID_WB_POINT]) begin
            is_halted_reg <= 1;
        end
    end

//// ALU submodule interface
    ALU ALU (
    .A(ALUinA),
    .B(ALUinB),
    .OP(ALUOp),
    .C(ALUresult)
    );
    wire [`WORD_SIZE-1:0] ALUinA;
    assign ALUinA = EX_clatch[`ALUSRCA_POINT] ? 
                    EX_latch[`PC1_EX_POINT:`PC1_EX_POINT-`WORD_SIZE+1] :
                    EX_latch[`RF_RD1_EX_POINT:`RF_RD1_EX_POINT-`WORD_SIZE+1];
    wire [`WORD_SIZE-1:0] ALUinB;
    assign ALUinB = EX_clatch[`ALUSRCB_POINT] ?
                    {{8{EX_latch[`IMM_EX_POINT]}}, EX_latch[`IMM_EX_POINT:`IMM_EX_POINT-7]} :
                    EX_latch[`RF_RD2_EX_POINT:`RF_RD2_EX_POINT-`WORD_SIZE+1];
    wire [3:0] ALUOp;
    assign ALUOp = EX_clatch[`ALUOP_POINT:`ALUOP_POINT-3];
    wire [`WORD_SIZE-1:0] ALUresult;

//// RF submodule interface
    RF RF(
    .write(RegWrite_RF), // write enable
    .clk(clk), // clock
    .reset_n(reset_n), // reset
    .addr1(rf_read_Addr1), // read addr
    .addr2(rf_read_Addr2), // read addr
    .addr3(rf_write_Addr), // write addr
    .data1(rf_read_data1_ID), // addr1���� read�� data
    .data2(rf_read_data2_ID), // addr2���� read�� data
    .data3(rf_write_data) // addr3�� write�� data
    );

    assign RegWrite_RF = WB_latch[`VALID_WB_POINT] && WB_clatch[`REGWRITE_POINT]; // using valid bit to consider flush
    wire [1:0] rf_read_Addr1; // read addr
    assign rf_read_Addr1 = rs_ID;
    wire [1:0] rf_read_Addr2; // read addr
    assign rf_read_Addr2 = rt_ID;
    wire [1:0] rf_write_Addr; // write addr
    assign rf_write_Addr = WB_latch[`DEST_WB_POINT:`DEST_WB_POINT-1];
    wire [`WORD_SIZE-1:0] rf_write_data; // rf_write_Addr �� write�� data
    assign rf_write_data = WB_clatch[`MEMTOREG_POINT] ? WB_latch[`MEM_RD_WB_POINT:`MEM_RD_WB_POINT-`WORD_SIZE+1] :
                            WB_latch[`ALURES_WB_POINT:`ALURES_WB_POINT-`WORD_SIZE+1];
    wire [`WORD_SIZE-1:0] rf_read_data2_ID;
    wire [`WORD_SIZE-1:0] rf_read_data1_ID;

//// BTB submodule interface
    BTB BTB(
        .reset_n(reset_n),
        .clk(clk),
        .pc(pc),
        .pc_1_ID(pc_1_ID),
        .flush_code(flush_code),
        .jmp_target(jmp_target),
        .br_target(br_target),
        .fw_rf_read_data1(fw_rf_read_data1),

        .btb(btb)
    );
    assign pc = pc_latch;
    wire [`WORD_SIZE-1:0] btb;

//// Dcache access
    wire dcache_latency; // latency with accessing to memory to read data
    assign dcache_latency = d_readC && (d_dataC === `WORD_SIZE'bz);

    // Dcache Read
    assign d_readC = MEM_latch[`VALID_MEM_POINT] && MEM_clatch[`MEMREAD_POINT];
    wire [`WORD_SIZE-1:0] dcache_read_data;
    assign dcache_read_data = d_readC ? d_dataC : `WORD_SIZE'bz;
    assign d_addressC = MEM_latch[`ALURES_MEM_POINT:`ALURES_MEM_POINT-`WORD_SIZE+1];
    
    // Dcache Write
    assign d_writeC = MEM_latch[`VALID_MEM_POINT] && MEM_clatch[`MEMWRITE_POINT]; // using valid bit to consider flush
    assign d_dataC = d_writeC ? MEM_latch[`RF_RD2_MEM_POINT:`RF_RD2_MEM_POINT-`WORD_SIZE+1] : `WORD_SIZE'bz;
    assign dwrite_latency = d_writeC && !dcache_write_done;

//// inst fetch operation
    wire [`WORD_SIZE-1:0] inst;
    wire icache_latency; // inst read latency from memory

    // Icache read access
    wire is_halted_ID;
    assign is_halted_ID = WB_ctrl[`ISHTL_POINT] && ID_latch[`VALID_ID_POINT]; // whether the inst in ID stage is HLT
    assign i_readC = (!reset_n) || dcache_latency || dwrite_latency || is_halted_ID ? 0 : 1;
    assign i_addressC = pc;
    assign inst = i_dataC;

    // Icache read miss
    assign icache_latency = i_readC && (i_dataC === `WORD_SIZE'bz); // latency with accessing to memory to fetch inst

//// reset
    always @(*) begin
        if(!reset_n) begin
            num_inst_reg = 0;
            pc_latch = 0;
            ID_latch = 0;
            EX_latch = 0;
            MEM_latch = 0;
            WB_latch = 0;
            EX_clatch = 0;
            MEM_clatch = 0;
            WB_clatch = 0;
        end
    end

//// num_inst update
    reg [`WORD_SIZE-1:0] num_inst_reg;
    assign num_inst = num_inst_reg;
    always @(posedge clk) begin
        if(reset_n) begin
            if(WB_latch[`VALID_WB_POINT]) begin
                num_inst_reg <= num_inst + 1;
            end
        end
    end

//// control signal transfer btw latches
    assign stall = (dep_code_rs == `DEP_MEMRD_EX_RS) || (dep_code_rt == `DEP_MEMRD_EX_RT);
    always @(posedge clk) begin
        if(reset_n && !dcache_latency && !dwrite_latency) begin
            if(!stall) begin
                EX_clatch <= {WB_ctrl, MEM_ctrl, EX_ctrl};
            end
            else begin
                EX_clatch <= 0;
            end
            MEM_clatch <= EX_clatch[`EX_CLATCH_SIZE-1:`EX_CTRL_SIZE];
            WB_clatch <= MEM_clatch[`MEM_CLATCH_SIZE-1:`MEM_CTRL_SIZE];
        end
    end

//// data forwarding
    wire [`WORD_SIZE-1:0] fw_rf_read_data1;
    wire [`WORD_SIZE-1:0] fw_rf_read_data2;
    assign fw_rf_read_data1 = (dep_code_rs == `DEP_ALURES_EX_RS) ? ALUresult :
                                (dep_code_rs == `DEP_ALURES_MEM_RS) ? MEM_latch[`ALURES_MEM_POINT:`ALURES_MEM_POINT-`WORD_SIZE+1] :
                                (dep_code_rs == `DEP_MEMRD_MEM_RS) ? dcache_read_data :
                                (dep_code_rs == `DEP_WB_RS) ? rf_write_data :
                                (dep_code_rs == `DEP_NONE_RS) ? rf_read_data1_ID
                                : fw_rf_read_data1;
    assign fw_rf_read_data2 = (dep_code_rt == `DEP_ALURES_EX_RT) ? ALUresult :
                                (dep_code_rt == `DEP_ALURES_MEM_RT) ? MEM_latch[`ALURES_MEM_POINT:`ALURES_MEM_POINT-`WORD_SIZE+1] :
                                (dep_code_rt == `DEP_MEMRD_MEM_RT) ? dcache_read_data :
                                (dep_code_rt == `DEP_WB_RT) ? rf_write_data :
                                (dep_code_rt == `DEP_NONE_RT) ? rf_read_data2_ID
                                : fw_rf_read_data2;

//// update latch

    // data flow to pc latch
    always @(posedge clk) begin
        if(reset_n && !dcache_latency && !dwrite_latency && !icache_latency && !stall) begin
            pc_latch <= nextpc;
        end
    end

    // data flow to ID latch
    always @(posedge clk) begin
        if(!dcache_latency && !dwrite_latency && !stall) begin
            if(!icache_latency) begin
                ID_latch[`WAITING_ID_POINT] <= 0;
                if(reset_n && (flush_code == `NICE_PRED)) begin
                    ID_latch[`PC1_ID_POINT:`PC1_ID_POINT-`WORD_SIZE+1] <= pc_latch + 1;
                    ID_latch[`INST_ID_POINT:`INST_ID_POINT-`WORD_SIZE+1] <= inst;
                    ID_latch[`VALID_ID_POINT] <= 1;
                end
                if(reset_n && (flush_code != `NICE_PRED)) begin
                    ID_latch[`VALID_ID_POINT] <= 0;
                end
            end
            else if(icache_latency) begin
                ID_latch[`VALID_ID_POINT] <= 0;
                ID_latch[`WAITING_ID_POINT] <= 1;
            end
        end
    end

    // data flow to EX latch
    always @(posedge clk) begin
        if(reset_n && !dcache_latency && !dwrite_latency) begin
            if(stall) begin
                EX_latch <= 0;
            end
            else begin
                EX_latch[`VALID_EX_POINT] <= ID_latch[`VALID_ID_POINT];
                EX_latch[`PC1_EX_POINT:`PC1_EX_POINT-`WORD_SIZE+1] <= pc_1_ID; // pc+1
                EX_latch[`JMPTG_EX_POINT:`JMPTG_EX_POINT-`WORD_SIZE+1] <= jmp_target; // jump target
                EX_latch[`IMM_EX_POINT:`IMM_EX_POINT-7] <= ID_latch[`INST_ID_POINT-`WORD_SIZE+`IMM_INST+1:`INST_ID_POINT-`WORD_SIZE+1]; // imm
                EX_latch[`RT_EX_POINT:`RT_EX_POINT-1] <= rt_ID;
                EX_latch[`RD_EX_POINT:`RD_EX_POINT-1] <= ID_latch[`INST_ID_POINT-`WORD_SIZE+`RD_INST+1 : `INST_ID_POINT-`WORD_SIZE+`RD_INST]; // rd
                // data forwarding
                EX_latch[`RF_RD1_EX_POINT:`RF_RD1_EX_POINT-`WORD_SIZE+1] <= fw_rf_read_data1;
                EX_latch[`RF_RD2_EX_POINT:`RF_RD2_EX_POINT-`WORD_SIZE+1] <= fw_rf_read_data2;
            end
        end
    end

    // data flow to MEM latch
    wire [`WORD_SIZE-1:0] rf_read_data2_EX;
    assign rf_read_data2_EX = EX_latch[`RF_RD2_EX_POINT:`RF_RD2_EX_POINT-`WORD_SIZE+1];

    always @(posedge clk) begin
        if(reset_n && !dcache_latency && !dwrite_latency) begin
            MEM_latch[`VALID_MEM_POINT] <= EX_latch[`VALID_EX_POINT];
            MEM_latch[`ALURES_MEM_POINT:`ALURES_MEM_POINT-`WORD_SIZE+1] <= ALUresult;
            MEM_latch[`RF_RD2_MEM_POINT:`RF_RD2_MEM_POINT-`WORD_SIZE+1] <= rf_read_data2_EX;
            MEM_latch[`DEST_MEM_POINT:`DEST_MEM_POINT-1] <= dest_EX;
            MEM_latch[`BRTG_MEM_POINT:`BRTG_MEM_POINT-`WORD_SIZE+1] <= br_target;
        end
    end

    // data flow to WB latch
    always @(posedge clk) begin
        if(reset_n) begin
            if(dcache_latency || dwrite_latency) begin
                WB_latch[`VALID_WB_POINT] <= 0;
            end
            else begin
                WB_latch[`VALID_WB_POINT] <= MEM_latch[`VALID_MEM_POINT];
                WB_latch[`MEM_RD_WB_POINT:`MEM_RD_WB_POINT-`WORD_SIZE+1] <= dcache_read_data;
                WB_latch[`ALURES_WB_POINT:`ALURES_WB_POINT-`WORD_SIZE+1] <= MEM_latch[`ALURES_MEM_POINT:`ALURES_MEM_POINT-`WORD_SIZE+1];
                WB_latch[`DEST_WB_POINT:`DEST_WB_POINT-1] <= dest_MEM;
            end
        end
    end

//// update nextpc
    wire [`WORD_SIZE-1:0] nextpc;

    assign nextpc = !reset_n ? 0 :
                    (dcache_latency || dwrite_latency || icache_latency) ? nextpc :
                    (PCSrc == `PCSRC_BTB) ? btb :
                    (PCSrc == `PCSRC_BR) ? br_target :
                    (PCSrc == `PCSRC_JMP) ? jmp_target :
                    (PCSrc == `PCSRC_NBR) ? pc_1_ID : fw_rf_read_data1;
endmodule