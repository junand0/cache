`define WORD_SIZE 16    // data and address word size

// flush code
`define FLUSH_CODE_SIZE 3
`define NICE_PRED 3'd0
`define JMP_FLUSH 3'd1
`define BR_FLUSH 3'd2
`define NBR_FLUSH 3'd3
`define JR_FLUSH 3'd4


module mispred_detector(
    input reset_n,
    input [`WORD_SIZE-1:0] jmp_target,
    input [`WORD_SIZE-1:0] pc,
    input [`WORD_SIZE-1:0] pc_1_ID,
    input IsJtype,
    input [`WORD_SIZE-1:0] BranchCond,
    input [`WORD_SIZE-1:0] br_target,
    input Branch,
    input [`WORD_SIZE-1:0] fw_rf_read_data1,
    input JPRorJRL,
    input isValid_inst_ID,
    input wbit_ID,

    output [`FLUSH_CODE_SIZE-1:0] flush_code
    // 000 : correct prediction
    // 001 : the inst is Jtype but not jumped
    // 010 : the inst is branch and condition is satisfied but not branched
    // 011 : the inst is branch and condition is not satisfied but branched
    // 100 : the inst is JPL or JPR but not jumped
);

    assign flush_code = !isValid_inst_ID && !wbit_ID ? `NICE_PRED :
                        ((IsJtype) && (jmp_target != pc)) ? `JMP_FLUSH : // the inst is Jtype but not jumped
                        ((Branch) && (br_target != pc) && (BranchCond)) ? `BR_FLUSH : // the inst is branch and condition is satisfied but not branched
                        (Branch && (pc != pc_1_ID) && (!BranchCond)) ? `NBR_FLUSH : // the inst is branch and condition is not satisfied but branched
                        (JPRorJRL && (fw_rf_read_data1 != pc)) ? `JR_FLUSH // the inst is JPR or JRL but not jumped
                        : `NICE_PRED; 


endmodule