// Map Yosys positive-enable latches to the Nangate45 high-transparent latch.
module \$_DLATCH_P_ (input E, input D, output Q);
  DLH_X1 _TECHMAP_REPLACE_ (.D(D), .G(E), .Q(Q));
endmodule
