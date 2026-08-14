// Same function as mux4, expressed with a case statement instead of nested
// conditionals - the pair exists so the two routes into HIF can be compared.
module mux4_case(input [3:0] d, input [1:0] sel, output reg y);
  always @(d or sel) begin
    case (sel)
      2'b00:   y = d[0];
      2'b01:   y = d[1];
      2'b10:   y = d[2];
      default: y = d[3];
    endcase
  end
endmodule
