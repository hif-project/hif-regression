// Verilog logical shifts carried toward VHDL. Covers hif-backend#94.
//
// hif2vhdl lowers each shift through to_integer, which throws away the vector
// nature of the operand, and then has to apply `sll` to the integer that comes
// back:
//
//   y <= std_logic_vector(to_signed(to_integer(to_unsigned(a)) sll
//                                  to_integer(to_unsigned(n)), 8));
//
// Two things there are not VHDL. `to_unsigned(a)` calls numeric_std's
// to_unsigned - which is (natural, natural) - with a single std_logic_vector;
// the conversion meant is the cast `unsigned(a)`. And `sll` is defined on array
// types, not on integers. vhdl2hif accepts the file anyway, and hif2verilog
// then cannot resolve the call and aborts.
//
// Both directions are here because they are one defect in one lowering, not
// two. hif2verilog prints the same HIF operators natively as `a << n` and
// `a >> n`, so SLL and SRL are represented fine.
//
// Distinct from combinational/shifter.v, a bare .v on plain_roundtrip that asks
// whether regenerated Verilog reparses and carries a fixed-amount shift for
// contrast with hif-backend#18. This asks whether a shift can be expressed in
// VHDL at all.
module v2vhdl_shift_amount(
    input  [7:0] a,
    input  [2:0] n,
    output [7:0] l,
    output [7:0] r
);
  assign l = a << n;
  assign r = a >> n;
endmodule
