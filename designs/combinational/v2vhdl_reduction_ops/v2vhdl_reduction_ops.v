// Verilog reduction operators carried toward VHDL. Covers hif-backend#92.
//
// hif2vhdl aborts on all three - "This operator should be managed in
// refinement steps", VHDLPrinter.cpp:556, exit 134, no .vhd written at all.
// hif2verilog prints every one of them correctly from the same HIF, so the
// operators are represented fine and the gap is in the VHDL backend.
//
// The three are one defect, not three: ORRD, ANDRD and XORRD hit the same
// missing refinement pass at the same abort site. The pipeline stops at the
// first non-PASS, so today only the first operator is actually reached - what
// this fixture currently proves is that the class is unhandled. Once #92
// lands it becomes a behavioral check of all three through VHDL and back,
// which is why all three are here rather than only the one that aborts.
//
// Distinct from combinational/reduction_ops, which uses the same operators to
// give Muffin literal-forced and bit-masked fault locations in one module. Its
// question is fault instrumentation on the Verilog path; this one is whether
// the operators can be expressed in VHDL at all.
module v2vhdl_reduction_ops(
    input  [3:0] a,
    output any_one,
    output all_ones,
    output parity
);
  assign any_one  = |a;
  assign all_ones = &a;
  assign parity   = ^a;
endmodule
