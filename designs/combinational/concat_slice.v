// Concatenation and part-select, kept in separate assignments so each has its
// own fault location.
module concat_slice(input [3:0] a, input [3:0] b, output [7:0] joined, output [3:0] mixed, output [1:0] low);
  assign joined = {a, b};
  assign mixed  = {a[1:0], b[3:2]};
  assign low    = a[1:0];
endmodule
