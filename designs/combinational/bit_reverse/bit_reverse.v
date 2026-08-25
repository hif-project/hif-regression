// A four-bit reverser, written the way one is written: a bit at a time.
//
// Each statement assigns a single bit of `y`, so `y` carries four fault
// locations of width 1 - not one location of width 4. That distinction is the
// property under test, and it changes how an injection is expressed: a width-1
// location is replaced by a literal, where a wider one is masked
// (rhs | (1 << N), rhs & ~(1 << N)). combinational/reduction_ops covers both
// forms already, but its width-1 location is a scalar output with no siblings.
// Here the literal has to land on one bit of a four-bit vector and leave the
// other three carrying their real values.
//
// A location that replaced the whole vector rather than the assigned bit would
// still be valid RTL - and is a defect Muffin has had before, in the
// parameterized case (hif-muffin#9).
//
// LINE NUMBERS ARE LOAD-BEARING. All four locations share {signal, bit, type}
// because each is one bit wide and therefore reports bit 0; `line` is the only
// attribute that tells them apart.
module bit_reverse(input [3:0] a, output reg [3:0] y);
  always @(*) begin
    y[0] = a[3];
    y[1] = a[2];
    y[2] = a[1];
    y[3] = a[0];
  end
endmodule
