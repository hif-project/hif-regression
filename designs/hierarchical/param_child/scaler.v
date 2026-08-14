// A parameterized child, instantiated at two different widths by the parent.
//
// The shift amount is a sized constant: an unsized `din << 1` widens the
// expression to 32 bits and currently regenerates as unparsable Verilog - see
// https://github.com/hif-project/hif-backend/issues/18.
module scaler #(parameter WIDTH = 4) (input [WIDTH-1:0] din, output [WIDTH-1:0] dout);
  assign dout = din << 1'b1;
endmodule
