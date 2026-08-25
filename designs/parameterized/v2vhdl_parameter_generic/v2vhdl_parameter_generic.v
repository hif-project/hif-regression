// A width-generic Verilog module carried toward VHDL. Covers hif-backend#93.
//
// hif2vhdl encodes the parameter as a 32-bit `signed` generic with a bit-string
// literal default - `W: signed(31 downto 0) := "00000000000000000000000000000101"`
// - and every port bound that used it becomes `to_integer(W - "0000...0001")`.
// vhdl2hif accepts that, and hif2verilog then aborts on the port bound with
// "Unable to get type of value" in sortParameters. Hand-written VHDL saying
// `generic (W : integer := 5)` round-trips through the same two tools cleanly,
// which is what puts the defect in hif2vhdl rather than in hif2verilog.
//
// W is 5 so a width silently replaced by a power of two, or by the 8 that
// parameterized_width.v happens to use, is a different number. `top` reads
// a[W-1], so the parameter has to survive into the body and not only into the
// port declaration - once #93 lands that is what the behavioral check tests.
//
// Distinct from parameterized/parameterized_width.v, which is a bare .v on
// plain_roundtrip: that asks whether the Verilog reparses after regeneration
// and never simulates. This asks whether the parameter can be expressed in
// VHDL at all.
module v2vhdl_parameter_generic #(parameter W = 5) (
    input  [W-1:0] a,
    output [W-1:0] y,
    output top
);
  assign y   = ~a;
  assign top = a[W-1];
endmodule
