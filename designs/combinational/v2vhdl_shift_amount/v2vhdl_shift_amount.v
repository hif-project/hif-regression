// Verilog logical shifts carried toward VHDL. Covers hif-backend#94.
//
// hif2vhdl used to lower each shift through to_integer, which threw away the
// vector nature of the operand, and then had to apply `sll` to the integer that
// came back:
//
//   y <= std_logic_vector(to_signed(to_integer(to_unsigned(a)) sll
//                                  to_integer(to_unsigned(n)), 8));
//
// Two things there were not VHDL. `to_unsigned(a)` called numeric_std's
// to_unsigned - which is (natural, natural) - with a single std_logic_vector;
// the conversion meant is the cast `unsigned(a)`. And `sll` is defined on array
// types, not on integers. vhdl2hif accepted the file anyway, and hif2verilog
// then could not resolve the call and aborted. It now writes
//
//   y <= std_logic_vector(unsigned(a) sll to_integer(unsigned(n)));
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
