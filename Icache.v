`define CACHE_SIZE 64
`define CACHE_TAG_SIZE 12
`define CACHE_IDX_SIZE 2
`define CACHE_OFFSET_SIZE 2
`define CACHE_DIRTYB_SIZE 1
`define WORD_SIZE 16
`define BLOCK_SIZE 64
`define FIRST_BLOCK_POINT 64
`define SECOND_BLOCK_POINT 48
`define THIRD_BLOCK_POINT 32
`define FOURTH_BLOCK_POINT 16


module Icache (
    input clk,
    input reset_n,
    input i_readC,
    input i_writeC,
    input [`WORD_SIZE-1:0] i_addressC,
    input [`BLOCK_SIZE-1:0] i_data,
    input stall,

    output [`WORD_SIZE-1:0] i_dataC,
    output i_readM,
    output [`WORD_SIZE-1:0] i_address
);

    reg [`CACHE_DIRTYB_SIZE+`CACHE_TAG_SIZE+`CACHE_SIZE-1:0] icache [0:2**(`CACHE_IDX_SIZE) - 1];

//// reset cache
    integer i;
    always @(*) begin
        if(!reset_n) begin
            for(i=0; i<2**(`CACHE_IDX_SIZE)-1; i=i+1) begin
                icache[i] = `CACHE_DIRTYB_SIZE+`CACHE_TAG_SIZE+`CACHE_SIZE'bz;
            end
        end
    end

//// hit or miss resolution
    // tag from i_addressC
    wire [`CACHE_TAG_SIZE-1:0] input_tag;
    assign input_tag = i_addressC[`WORD_SIZE-1:`CACHE_IDX_SIZE+`CACHE_OFFSET_SIZE];
    // idx from i_addressC
    wire [`CACHE_IDX_SIZE-1:0] input_idx;
    assign input_idx = i_addressC[`CACHE_IDX_SIZE+`CACHE_OFFSET_SIZE-1:`CACHE_OFFSET_SIZE];
    // tag from cache at input idx
    wire [`CACHE_TAG_SIZE-1:0] cache_tag;
    assign cache_tag = icache[input_idx][`CACHE_TAG_SIZE+`CACHE_SIZE-1:`CACHE_SIZE];
    // offset from i_addressC
    wire [`CACHE_OFFSET_SIZE-1:0] input_offset;
    assign input_offset = i_addressC[`CACHE_OFFSET_SIZE-1:0];
    // Icache hit or miss?
    wire icache_hit;
    assign icache_hit = i_readC && (input_tag === cache_tag);

//// Icache miss service

    // memory access to load inst
    reg i_readM_reg;
    assign i_readM = reset_n ? i_readM_reg : 0;
    assign i_address = i_addressC;
    always @(posedge clk) begin
        if(reset_n && i_readC && !icache_hit) begin
            i_readM_reg <= 1;
        end
        if(reset_n && i_data) begin
            i_readM_reg <= 0;
        end
    end
    always @(*)begin
        if(!reset_n) begin
            i_readM_reg = 0;
        end
    end

    wire i_mem_latency;
    assign i_mem_latency = i_readM && (i_data === `BLOCK_SIZE'bz);

    // Loading inst from memory to Icache
    always @(posedge clk) begin
        if(reset_n && !i_mem_latency && i_readM) begin
            icache[input_idx][`CACHE_DIRTYB_SIZE+`CACHE_TAG_SIZE+`CACHE_SIZE-1] = 0; // set dirty bit 0
            icache[input_idx][`CACHE_TAG_SIZE+`CACHE_SIZE-1:`CACHE_SIZE] = input_tag; // load tag
            icache[input_idx][`CACHE_SIZE-1:0] = i_data; // load cache block
        end
    end

//// Icache read ; inst fetch
    reg [`WORD_SIZE-1:0] i_dataC_reg;
    assign i_dataC = i_readC && icache_hit ? i_dataC_reg : `WORD_SIZE'bz;
    always @(*) begin
        if(reset_n) begin
            if(i_readC && icache_hit) begin
                case(input_offset)
                    2'b00 : begin
                        i_dataC_reg <= icache[input_idx][`FIRST_BLOCK_POINT-1:`SECOND_BLOCK_POINT];
                    end
                    2'b01 : begin
                        i_dataC_reg <= icache[input_idx][`SECOND_BLOCK_POINT-1:`THIRD_BLOCK_POINT];
                    end
                    2'b10 : begin
                        i_dataC_reg <= icache[input_idx][`THIRD_BLOCK_POINT-1:`FOURTH_BLOCK_POINT];
                    end
                    2'b11 : begin
                        i_dataC_reg <= icache[input_idx][`FOURTH_BLOCK_POINT-1:0];
                    end
                endcase
            end
        end
    end

//// calculating # of icache hit and access
    reg [`WORD_SIZE-1:0] icache_hit_cnt;
    reg [`WORD_SIZE-1:0] icache_access_cnt;
    always @(*) begin
        if(!reset_n) begin
            icache_hit_cnt = 0;
            icache_access_cnt = 0;
        end
    end
    always @(posedge clk) begin
        if(i_readC && !i_readM && !stall) begin
            icache_access_cnt <= icache_access_cnt + 1; // count access after miss
        end
        if(icache_hit && !stall) begin
            icache_hit_cnt = icache_hit_cnt + 1; // count hit after miss
        end
    end

endmodule