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

module Dcache (
    input clk,
    input reset_n,
    input d_readC,
    input d_writeC,
    input [`WORD_SIZE-1:0] d_addressC,

    inout [`WORD_SIZE-1:0] d_dataC,
    inout [`BLOCK_SIZE-1:0] d_data,

    output d_readM,
    output d_writeM,
    output [`WORD_SIZE-1:0] d_address,
    output dcache_write_done
);
    
    reg [`CACHE_DIRTYB_SIZE+`CACHE_TAG_SIZE+`CACHE_SIZE-1:0] dcache [0:2**(`CACHE_IDX_SIZE) - 1];

//// reset cache
    integer i;
    always @(*) begin
        if(!reset_n) begin
            for(i=0; i<2**(`CACHE_IDX_SIZE)-1; i=i+1) begin
                dcache[i][`CACHE_DIRTYB_SIZE+`CACHE_TAG_SIZE+`CACHE_SIZE-1] = 0;
                dcache[i][`CACHE_TAG_SIZE+`CACHE_SIZE-1:0] = `CACHE_TAG_SIZE+`CACHE_SIZE'bz;
            end
        end
    end

//// hit or miss resolution
    // tag from d_addressC
    wire [`CACHE_TAG_SIZE-1:0] input_tag;
    assign input_tag = d_addressC[`WORD_SIZE-1:`CACHE_IDX_SIZE+`CACHE_OFFSET_SIZE];
    // idx from d_addressC
    wire [`CACHE_IDX_SIZE-1:0] input_idx;
    assign input_idx = d_addressC[`CACHE_IDX_SIZE+`CACHE_OFFSET_SIZE-1:`CACHE_OFFSET_SIZE];
    // tag from cache at input idx
    wire [`CACHE_TAG_SIZE-1:0] cache_tag;
    assign cache_tag = dcache[input_idx][`CACHE_TAG_SIZE+`CACHE_SIZE-1:`CACHE_SIZE];
    // offset from d_addressC
    wire [`CACHE_OFFSET_SIZE-1:0] input_offset;
    assign input_offset = d_addressC[`CACHE_OFFSET_SIZE-1:0];
    // dcache hit or miss?
    wire dcache_hit;
    assign dcache_hit = (d_readC || d_writeC) && (input_tag === cache_tag);

//// Dcache miss service

    // read enable signal for loading data from memory to dcache
    reg d_readM_reg;
    assign d_readM = reset_n ? d_readM_reg : 0;
    assign d_address = d_readM ? d_addressC
                        : d_writeM ? {cache_tag, input_idx, input_offset} : d_address;
    always @(posedge clk) begin
        if(reset_n && d_readC && !dcache_hit && !dirty) begin
            d_readM_reg <= 1;
        end
        if(reset_n && d_writeC && !dcache_hit && !dirty) begin
            d_readM_reg <= 1;
        end
        if(reset_n && d_writeM && !dcache_hit) begin
            d_readM_reg <= 1;
        end
        if(reset_n && !(d_data === `BLOCK_SIZE'bz) && d_readM) begin
            d_readM_reg <= 0;
        end
    end
    always @(*)begin
        if(!reset_n) begin
            d_readM_reg = 0;
        end
    end

    // Loading data from memory to dcache
    always @(posedge clk) begin
        if(reset_n && !(d_data === `BLOCK_SIZE'bz) && d_readM) begin
            dcache[input_idx][`CACHE_DIRTYB_SIZE+`CACHE_TAG_SIZE+`CACHE_SIZE-1] = 0; // set dirty bit 0
            dcache[input_idx][`CACHE_TAG_SIZE+`CACHE_SIZE-1:`CACHE_SIZE] = input_tag; // load tag
            dcache[input_idx][`CACHE_SIZE-1:0] = d_data; // load cache block
        end
    end
//// write back to memory
    wire dirty;
    assign dirty = (d_writeC || d_readC) && (dcache[input_idx][`CACHE_DIRTYB_SIZE+`CACHE_TAG_SIZE+`CACHE_SIZE-1] === 1);
    assign d_writeM = reset_n && !dcache_hit && dirty && !dwrite_latency;
    assign d_data = d_writeM ? dcache[input_idx][`BLOCK_SIZE-1:0] : `BLOCK_SIZE'bz;

    // data write latency calculation
    reg [2:0] dwrite_latency_cnt; // # of memory write latency

    wire dwrite_latency; // waiting for accessing memory to write data
    assign dwrite_latency = (dwrite_latency_cnt != 0) ? 1 : 0;

    always @(*) begin
        if(!reset_n) begin
            dwrite_latency_cnt = 3'd4;
        end
    end

	always @(posedge clk) begin
		if(reset_n) begin
			if(dwrite_latency_cnt && dirty && !dcache_hit) begin
				dwrite_latency_cnt <= dwrite_latency_cnt -1;
			end
			else if(!dwrite_latency_cnt) begin
				dwrite_latency_cnt <= 3'd4;
			end
		end
	end

//// dcache data read
    reg [`WORD_SIZE-1:0] d_dataC_reg;
    assign d_dataC = d_readC && dcache_hit ? d_dataC_reg : `WORD_SIZE'bz;
    always @(*) begin
        if(reset_n) begin
            if(d_readC && dcache_hit) begin
                case(input_offset)
                    2'b00 : begin
                        d_dataC_reg = dcache[input_idx][`FIRST_BLOCK_POINT-1:`SECOND_BLOCK_POINT];
                    end
                    2'b01 : begin
                        d_dataC_reg = dcache[input_idx][`SECOND_BLOCK_POINT-1:`THIRD_BLOCK_POINT];
                    end
                    2'b10 : begin
                        d_dataC_reg = dcache[input_idx][`THIRD_BLOCK_POINT-1:`FOURTH_BLOCK_POINT];
                    end
                    2'b11 : begin
                        d_dataC_reg = dcache[input_idx][`FOURTH_BLOCK_POINT-1:0];
                    end
                endcase
            end
        end
    end

//// write data to Dcache

    assign dcache_write_done = d_writeC && dcache_hit && dirty; // inform to cpu that cache write is done

    always @(negedge clk) begin
        if(reset_n) begin
            if(d_writeC && dcache_hit) begin
                dcache[input_idx][`CACHE_DIRTYB_SIZE+`CACHE_TAG_SIZE+`CACHE_SIZE-1] = 1; // set dirty bit 1
                case(input_offset)
                    2'b00 : begin
                        dcache[input_idx][`FIRST_BLOCK_POINT-1:`SECOND_BLOCK_POINT] = d_dataC;
                    end
                    2'b01 : begin
                        dcache[input_idx][`SECOND_BLOCK_POINT-1:`THIRD_BLOCK_POINT] = d_dataC;
                    end
                    2'b10 : begin
                        dcache[input_idx][`THIRD_BLOCK_POINT-1:`FOURTH_BLOCK_POINT] = d_dataC;
                    end
                    2'b11 : begin
                        dcache[input_idx][`FOURTH_BLOCK_POINT-1:0] = d_dataC;
                    end
                endcase
            end
        end
    end

//// calculating # of dcache hit and access
    reg [`WORD_SIZE-1:0] dcache_hit_cnt;
    reg [`WORD_SIZE-1:0] dcache_access_cnt;
    always @(*) begin
        if(!reset_n) begin
            dcache_hit_cnt = 0;
            dcache_access_cnt = 0;
        end
    end
    always @(posedge clk) begin
        if((d_readC || d_writeC) && !d_readM && (dwrite_latency_cnt == 3'd4)) begin
            dcache_access_cnt <= dcache_access_cnt + 1; // count access after miss
        end
        if(dcache_hit) begin
            dcache_hit_cnt = dcache_hit_cnt + 1; // count hit after miss
        end
    end

endmodule