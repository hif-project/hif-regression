// A function with a local variable - the ordinary shape of any function doing
// more than returning a single expression.
//
// *** THIS DESIGN CURRENTLY FAILS, DELIBERATELY. ***
//
// hif2verilog emits the local as `reg [4:0] wide = 5'bxxxxx;` *inside* the
// function body. A declaration assignment is only legal at module level in
// Verilog, so the regenerated file does not parse - not by verilog2hif and not
// by iverilog. The initialiser is synthesised by the emitter; the source
// declares no initial value. A task-local is hoisted to module level and does
// not hit this, so it is specific to functions - hif-backend#83.
//
// user_function.v is the same construct without the local, and passes. It was
// written that way, which is exactly why this design exists: routing around
// the defect made the corpus stop asking, and the question is a fair one.
module function_local_variable(input [3:0] a, input [3:0] b, output [4:0] y);
  function [4:0] add5;
    input [3:0] x;
    input [3:0] z;
    reg [4:0] wide;
    begin
      wide = {1'b0, x} + {1'b0, z};
      add5 = wide;
    end
  endfunction

  assign y = add5(a, b);
endmodule
