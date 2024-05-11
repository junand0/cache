`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/03/09 19:08:01
// Design Name: 
// Module Name: ALU
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`define	OP_ADD  4'b0000
`define	OP_SUB  4'b0001
`define OP_AND  4'b0010
`define OP_ORR  4'b0011
`define OP_NOT  4'b0100
`define OP_TCP  4'b0101
`define OP_SHL  4'b0110
`define OP_SHR  4'b0111
`define OP_ORI  4'b1000
`define OP_LHI  4'b1001
`define OP_GTZ  4'b1010
`define OP_ID   4'b1011
`define OP_EQ   4'b1100
`define OP_NEQ  4'b1101
`define OP_LTZ  4'b1110

module ALU(
    input [15:0] A,
    input [15:0] B,
    input [3:0] OP,
    output reg [15:0] C
    );
    reg Cout;
    always @(*) begin
         case(OP)
            `OP_ADD: begin
                {Cout, C} = $signed(A) + $signed(B); // allocate MSB to Cout to allocate 1 to Cout when overflow
            end
            `OP_SUB: begin
                {Cout, C} = $signed(A) - $signed(B); // allocate MSB to Cout to allocate 1 to Cout when underflow
            end
            `OP_ID: begin
                C = A;
            end
            `OP_NOT: begin
                C = ~A;
            end
            `OP_AND: begin
                C = A & B;
            end
            `OP_ORR: begin
                C = A | B;
            end
            `OP_TCP: begin
                C = ~A + 1;
            end
            `OP_SHL: begin
                C = {A[14:0], 1'b0};
            end
            `OP_SHR: begin
                C = {A[15], A[15:1]};
            end
            `OP_ORI: begin
                C = A | {{8{1'b0}}, B[7:0]};
            end
            `OP_LHI: begin
                C = {B[7:0], {8{1'b0}}};
            end
            `OP_GTZ: begin
                C = (A != 0 && A[15] == 0) ? 1 : 0;
            end
            `OP_LTZ: begin
                C = A[15] == 1 ? 1 : 0;
            end
            `OP_ORI: begin
                C = A | B;
            end
            `OP_EQ: begin
                C = (A == B);
            end
            `OP_NEQ: begin
                C = (A != B);
            end
        endcase 
    end
endmodule

