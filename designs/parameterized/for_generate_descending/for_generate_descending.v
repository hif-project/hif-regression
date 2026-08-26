// A `for generate` that counts down with `i > 0`, marking every place where the
// bus changes value between adjacent bits. Counting down is how the loop reads
// when the pair is named by its upper bit, and `i > 0` is the ordinary way to
// stop before running off the bottom. Every output bit is driven exactly once,
// so nothing here depends on how a floating bit reads.
//
// The step is one, deliberately. hif-core#24 was reported as a non-unit-step
// defect, and the `op_gt` half of the same arithmetic was wrong at *every*
// step: the expansion range started at the condition bound rather than at the
// lowest value the index reaches, so this loop - which runs i = 7 down to 1 -
// elaborated as i = 6 down to 0. `dout[6]` would then be driven by nobody,
// since only i = 7 drives it, and the remaining lanes would each read one bit
// too low. Fixed in hif-core 5603a2a.
//
// for_generate_strided cannot stand in for this: its step is two, and this half
// of the defect needs no stride at all.
module for_generate_descending (input [7:0] din, output wire [6:0] dout);
  genvar i;
  generate
    for (i = 7; i > 0; i = i - 1) begin : transition
      assign dout[i - 1] = din[i] ^ din[i - 1];
    end
  endgenerate
endmodule
