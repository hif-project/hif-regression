module top(input a, input b, input sel, output result);
  wire and_out, or_out;
  and_or u_and_or(.a(a), .b(b), .and_out(and_out), .or_out(or_out));
  select2 u_select2(.x(and_out), .y(or_out), .sel(sel), .z(result));
endmodule
