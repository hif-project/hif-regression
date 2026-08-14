// Highest set bit wins; valid goes low when no request is asserted. The
// if/else chain is the priority structure, and grant/valid interact - a fault
// on either is independently observable.
module priority_encoder(input [3:0] req, output reg [1:0] grant, output reg valid);
  always @(req) begin
    valid = 1'b1;
    if (req[3])      grant = 2'd3;
    else if (req[2]) grant = 2'd2;
    else if (req[1]) grant = 2'd1;
    else if (req[0]) grant = 2'd0;
    else begin
      grant = 2'd0;
      valid = 1'b0;
    end
  end
endmodule
