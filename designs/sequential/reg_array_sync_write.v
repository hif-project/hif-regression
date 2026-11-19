// A four-word register file: an unpacked array with a clocked indexed write
// and a combinational indexed read. The smallest useful memory there is.
//
// This used to fail, on hif-backend#87: hif2verilog regenerated
// `reg [7:0] mem [0:3]` as
//
//   reg [3:0] mem = 08'bxxxxxxxx18'bxxxxxxxx28'bxxxxxxxx38'bxxxxxxxx;
//
// taking the array *range* as the vector width, discarding the element width,
// and printing the default as four run-together index/value pairs. That did
// not parse. It now prints `reg [7:0] mem [0:3];` with no initializer, and the
// process that reads the memory is sensitive to `@(*)`, since Verilog rejects a
// memory in an event list.
//
// The corpus had no memory of any kind until this was fixed. This design is
// what records that it now has one. Its pipeline is structural: it checks the
// regenerated file reparses, not what the memory reads back.
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
