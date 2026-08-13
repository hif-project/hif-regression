module decoder(input [1:0] sel, input en, output [3:0] out);
  assign out = en ? (4'b0001 << sel) : 4'b0000;
endmodule
