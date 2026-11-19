// Nets driven by continuous assigns whose index is not an integer literal.
//
//   partial_gen   a for generate that drives bits 0 to 2 of a 4-bit net and leaves bit 3
//                 alone: bit 3 is z, as in the source (hif-backend#104).
//   shared_gen    a for generate drives every bit, bit-by-bit and released when not
//                 enabled, and one more assign drives bit 1 again: the net is resolved
//                 (hif-backend#88).
//   shared_param  the same two drivers on one bit, one of them indexed by a parameter.
//
// Once a for generate is expanded its index is a bit string, and a parameter is a name;
// neither was read as the constant it is, so these nets were lowered to processes and
// lost resolution and the z of an undriven bit.
module generate_and_parameter_nets #(parameter K = 1) (
    input  [3:0] en,
    input  [3:0] a,
    input  en2,
    input  b,
    input  ae,
    input  be,
    output [3:0] partial_gen,
    output [3:0] shared_gen,
    output [3:0] shared_param
);
  genvar g;
  generate
    for (g = 0; g < 3; g = g + 1) begin : pg
      assign partial_gen[g] = a[g];
    end
  endgenerate
  generate
    for (g = 0; g < 4; g = g + 1) begin : sg
      assign shared_gen[g] = en[g] ? a[g] : 1'bz;
    end
  endgenerate
  assign shared_gen[1] = en2 ? b : 1'bz;

  assign shared_param[K] = ae ? a[0] : 1'bz;
  assign shared_param[1] = be ? b : 1'bz;
  assign shared_param[0] = a[1];
  assign shared_param[2] = a[2];
  assign shared_param[3] = a[3];
endmodule
