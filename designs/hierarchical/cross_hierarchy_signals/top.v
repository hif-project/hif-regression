// A value and a flag are threaded from producer through to consumer, so both
// signals cross the hierarchy boundary twice.
module top(input [3:0] din, output [3:0] dout);
  wire [3:0] mid;
  wire mid_flag;
  producer u_prod(.din(din), .dout(mid), .flag(mid_flag));
  consumer u_cons(.din(mid), .flag(mid_flag), .dout(dout));
endmodule
