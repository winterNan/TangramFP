// FPnew (CVFPU) FP16 fused multiply-add behind the port list of our MAC, for a like-for-like
// comparison: combinational FMA (no pipeline registers), registered result, round-to-nearest-even.
module MAC (
  input  logic [15:0] a, b, c,
  input  logic        clk, n_rst,
  output logic [31:0] sumout
);
  logic [15:0] res;
  fpnew_fma #(
    .FpFormat    (fpnew_pkg::FP16),
    .NumPipeRegs (0),
    .PipeConfig  (fpnew_pkg::BEFORE)
  ) i_fma (
    .clk_i (clk), .rst_ni (n_rst),
    .operands_i ({c, b, a}), .is_boxed_i (3'b111),
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
