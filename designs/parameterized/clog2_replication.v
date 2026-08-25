// $clog2 as the replication *count* - the idiomatic way to build a mask as
// wide as the address space a depth implies.
//
// Both halves work on their own. $clog2 in a port range and in an ordinary
// expression is param_clog2.v; a plain parameterised replication count is
// param_bitmask.v. It was the composition that aborted verilog2hif
// (hif-frontend#15), in HIFSemantics' handling of an iterated concatenation
// whose count is a symbolic call rather than a value.
//
// hif-frontend already requires the count to survive translation as a call,
// by inspecting the HIF it produced. What this fixture adds is the rest of the
// path: the call has to come back out of hif2verilog in a form verilog2hif
// will take again. Emitting it under its internal name is what
// hif-backend#19 did, and the reparse step here rejects that - measured, by
// feeding the internal spelling back in.
//
// What this pipeline does *not* claim is that the count is still symbolic: a
// backend that folded it to `{5{1'b1}}` would reparse and pass. That
// assertion belongs to hif-frontend's suite, which reads the tree; here the
// regenerated file was checked by hand and still reads `{$clog2(DEPTH){1'b1}}`.
//
// The ports are a fixed eight bits wide on purpose. That keeps $clog2 out of
// every position except the replication count, so a failure names that
// position, and it leaves the width relationship visible: with DEPTH = 32 the
// mask is five ones inside eight bits.
module clog2_replication #(parameter DEPTH = 32) (
    input  [7:0] d,
    output [7:0] mask,
    output [7:0] masked
);
  assign mask   = {$clog2(DEPTH){1'b1}};
  assign masked = d & {$clog2(DEPTH){1'b1}};
endmodule
