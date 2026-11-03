// FPnew (CVFPU) FP16 FMA behind the MACW port list, for the complete-MAC comparison (Table 7 flow).
// INREG = 1: a, b, c registered first, as in our MACs (48 FFs); INREG = 0: as fpnew_mac16.sv.
// Combinational FMA, round-to-nearest-even, FP16 result registered in sumout[15:0].
module MACW #(parameter int INREG = 1) (
  input  logic [15:0] a, b, c,
  input  logic        clk, n_rst,
  output logic [31:0] sumout
);
  logic [15:0] a1, b1, c1, res;
  if (INREG) begin : g_in
    always_ff @(posedge clk) begin
      if (!n_rst) begin a1 <= '0; b1 <= '0; c1 <= '0; end
      else        begin a1 <= a;  b1 <= b;  c1 <= c;  end
    end
  end else begin : g_noin
    assign a1 = a; assign b1 = b; assign c1 = c;
  end
  fpnew_fma #(
    .FpFormat    (fpnew_pkg::FP16),
    .NumPipeRegs (0),
    .PipeConfig  (fpnew_pkg::BEFORE)
  ) i_fma (
    .clk_i (clk), .rst_ni (n_rst),
    .operands_i ({c1, b1, a1}), .is_boxed_i (3'b111),
    .rnd_mode_i (fpnew_pkg::RNE), .op_i (fpnew_pkg::FMADD), .op_mod_i (1'b0),
    .tag_i (1'b0), .mask_i (1'b0), .aux_i (1'b0),
    .in_valid_i (1'b1), .in_ready_o (), .flush_i (1'b0),
    .result_o (res), .status_o (), .extension_bit_o (), .tag_o (), .mask_o (), .aux_o (),
    .out_valid_o (), .out_ready_i (1'b1), .busy_o (), .reg_ena_i (1'b0), .early_out_valid_o ()
  );
  always_ff @(posedge clk) begin
    if (!n_rst) sumout <= '0;
    else        sumout <= {16'b0, res};
  end
endmodule
