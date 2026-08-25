// Population count of each nibble, computed by one function called twice.
//
// No Muffin design in this corpus contains a function at all, and a function
// introduces a fault location of a kind none of the others has: the return
// value is a single location shared by every call site. A fault there is not
// equivalent to a fault at any one call - it reaches both.
//
// That is the property under test, and it needs two call sites to state. With a
// single call, a fault on the function's result and a fault on the assignment
// that receives it are indistinguishable; with two, the first moves both
// outputs and the second moves one. An instrumentation that injected at the
// call sites instead of inside the function would emit valid RTL in which the
// shared location does not exist.
module nibble_popcount(input [7:0] a, output [2:0] lo, output [2:0] hi);
  function [2:0] popcount4;
    input [3:0] v;
    popcount4 = v[0] + v[1] + v[2] + v[3];
  endfunction

  assign lo = popcount4(a[3:0]);
  assign hi = popcount4(a[7:4]);
endmodule
