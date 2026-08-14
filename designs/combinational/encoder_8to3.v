// Binary encoder: assumes a one-hot input. Written as a case over the whole
// input vector so the whole encoding is visible at once.
module encoder_8to3(input [7:0] d, output reg [2:0] code);
  always @(d) begin
    case (d)
      8'b00000001: code = 3'd0;
      8'b00000010: code = 3'd1;
      8'b00000100: code = 3'd2;
      8'b00001000: code = 3'd3;
      8'b00010000: code = 3'd4;
      8'b00100000: code = 3'd5;
      8'b01000000: code = 3'd6;
      8'b10000000: code = 3'd7;
      default:     code = 3'd0;
    endcase
  end
endmodule
