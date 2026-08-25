// A four-word register file: an unpacked array with a clocked indexed write
// and a combinational indexed read. The smallest useful memory there is.
//
// *** THIS DESIGN CURRENTLY FAILS, DELIBERATELY. ***
//
// hif2verilog regenerates `reg [7:0] mem [0:3]` as
//
//   reg [3:0] mem = 08'bxxxxxxxx18'bxxxxxxxx28'bxxxxxxxx38'bxxxxxxxx;
//
// taking the array *range* as the vector width, discarding the element width,
// and printing the default as four run-together index/value pairs. The result
// does not parse - hif-backend#87.
//
// The corpus has no memory of any kind, and cannot have one until that is
// fixed. This design is what says so, and what will go green when it is.
module reg_array_sync_write(
    input clk,
    input we,
    input [1:0] waddr,
    input [7:0] wdata,
    input [1:0] raddr,
    output [7:0] rdata
);
  reg [7:0] mem [0:3];

  always @(posedge clk) begin
    if (we) mem[waddr] <= wdata;
  end

  assign rdata = mem[raddr];
endmodule
