// An ordinary user-defined Verilog function: declaration, arguments, a body
// with more than one statement, and a returned value read back at two call
// sites.
//
// Two defects met here. hif-frontend#14 folded a function call out of the
// scope that declares the function when it appeared in a continuous
// assignment, so the call lost the declaration that resolved it; both calls
// below are continuous assignments, which is that shape. hif-backend#57 then
// emitted the function's header and dropped its body, which produces a module
// that still parses and still has both outputs - and returns nothing.
//
// The body assigns the implicit return variable and then reads it back to
// decide whether to clamp. That is the point of the second statement: a
// lowering that treats the return as a single one-shot expression rather than
// a variable cannot express it, and the cap silently stops applying.
//
// The function is called twice, with different actuals, so it has to be
// emitted once and resolved at both sites rather than inlined at whichever one
// came first.
//
// It declares no local variable. That is not a simplification: hif2verilog
// emits a function-local as a declaration assignment inside the function body,
// which does not parse (hif-backend#83). function_local_variable.v is the same
// function with the local put back, and is red on that issue.
module user_function(input [3:0] a, input [3:0] b, output [4:0] capped_ab, output [4:0] capped_aa);

  // x + y, never above 20. The sum is five bits wide, so it is not the
  // arguments' width - a return truncated to the argument width shows up as a
  // wrong value, not as a compile error.
  function [4:0] capped_sum;
    input [3:0] x;
    input [3:0] y;
    begin
      capped_sum = {1'b0, x} + {1'b0, y};
      if (capped_sum > 5'd20) capped_sum = 5'd20;
    end
  endfunction

  assign capped_ab = capped_sum(a, b);
  assign capped_aa = capped_sum(a, a);
endmodule
