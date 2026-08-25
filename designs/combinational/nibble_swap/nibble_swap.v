// A nibble swap, written as two part-select assignments to one signal.
//
// Every Muffin design in this corpus before this one was deliberately written
// with a single assignment per signal so that {signal, bit, type} names exactly
// one fault - counter_load, pipeline3 and param_counter all say so in comments.
// Ordinary RTL is not written that way. Here `y` has two fault locations, and
// the selector has to say which, using the record's `line`.
//
// The property under test is what `bit` is relative to. Muffin's location is
// the assignment, not the declared signal, so a location's width is the width
// of the part-select - 4, not 8 - and bit 0 of the y[7:4] assignment is the
// physical bit y[4]. Numbering against the declared signal instead would put it
// at y[0]: still valid RTL, still eight bits wide, and wrong.
//
// LINE NUMBERS ARE LOAD-BEARING. behavior.yaml selects the two locations by
// source line, so moving either assignment breaks the fixture. That is the only
// attribute that distinguishes them.
module nibble_swap(input [7:0] a, output reg [7:0] y);
  always @(*) begin
    y[7:4] = a[3:0];
    y[3:0] = a[7:4];
  end
endmodule
