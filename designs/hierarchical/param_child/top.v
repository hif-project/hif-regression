// The same parameterized child at two widths, so the elaborated hierarchy
// contains two distinct instantiations of one module.
module top(input [3:0] narrow_in, input [7:0] wide_in,
           output [3:0] narrow_out, output [7:0] wide_out);
  scaler #(.WIDTH(4)) u_narrow(.din(narrow_in), .dout(narrow_out));
  scaler #(.WIDTH(8)) u_wide  (.din(wide_in),   .dout(wide_out));
endmodule
