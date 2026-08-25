// Part-select assignment targets: `q[7:5] <= top` rather than a single bit.
//
// A Slice target is a different HIF node from the Member that
// procedural_bit_select uses, and a different one again from the partial driver
// a continuous bit-select assignment becomes - hif-frontend#9's fix had to
// unwrap both through getTerminalPrefix, which is why the two shapes belong to
// separate designs rather than to one that happens to contain both.
//
// The bounds are deliberately not the two halves of the register. A three-bit
// field above a five-bit one means an off-by-one in either bound moves bits
// between the two fields, where 7:4 and 3:0 would let a symmetric error land
// back on itself.
module part_select_lhs(input clk, input [2:0] top, input [4:0] bot, output reg [7:0] q);
  always @(posedge clk) begin
    q[7:5] <= top;
    q[4:0] <= bot;
  end
endmodule
