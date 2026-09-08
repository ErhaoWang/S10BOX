`timescale 1ns / 1ps
module s10 (
    input  logic clk,
    input  logic rst_n,
    output logic o_busy,
    output logic o_cip_busy,
    // clk domain
    input  logic                 i_exposure_write_en,
    input  s10_pkg::exposure_t   i_exposure_write_data,
    input  integer               i_image_addr,
    output s10_pkg::pixel_t      o_image_data,
    input  logic                 i_conv2_sim,
    input  logic                 i_conv3_sim,
    input  logic                 i_fc_sim,
    input  integer               i_weight_addr,
    input  s10_pkg::select_t     i_weight_write_select,
    input  s10_pkg::weight_t     i_weight_write_data,
    input  s10_pkg::select_t     i_weight_load_select,
    input  integer               i_activation_addr,
    input  s10_pkg::select_t     i_activation_write_select,
    input  s10_pkg::activation_t i_activation_write_code,
    input  s10_pkg::select_t     i_activation_read_select,
    output s10_pkg::activation_t o_activation_read_code,
    input  s10_pkg::select_t     i_compute_select,
    output s10_pkg::result_t     o_result,
    // interface s10
    input  logic       s10_cip_clk,
    input  logic       s10_cim_clk,
    output logic       s10_cip_rst,
    output logic       s10_cim_rst,
    output logic       s10_exposure_out_en,
    output logic       s10_exposure,
    input  logic       s10_frame,
    output logic       s10_weight_rst,
    output logic       s10_cip_weight_out_en,
    output logic       s10_cip_weight,
    output logic       s10_weight_down_shift_clk,
    output logic       s10_weight_right_shift_clk,
    output logic       s10_ccap_right_shift_clk,
    output logic [3:0] s10_row,
    output logic       s10_cip_activation_in_en,
    input  logic [1:0] s10_cip_activation_in,
    output logic       s10_mode,
    output logic       s10_precharge_n,
    output logic       s10_differential_en,
    output logic       s10_active_clk,
    output logic [1:0] s10_select,
    output logic       s10_addr_out_en,
    output logic       s10_addr,
    output logic       s10_cim_weight_out_en,
    output logic       s10_cim_weight,
    output logic       s10_sram_write_en,
    output logic       s10_activation_out_en,
    output logic       s10_activation_out,
    output logic       s10_cim_activation_in_en,
    input  logic       s10_cim_activation_in,
    output logic       s10_compute_en,
    output logic       s10_compare_en,
    input  logic [3:0] s10_result,
    // interface tft
    input  logic             tft_clk,
    input  logic             tft_motion_detect,
    input  s10_pkg::select_t tft_select,
    input  integer           tft_addr,
    output s10_pkg::pixel_t  tft_pixel,
    output logic [1:0]       tft_activation
);

import s10_pkg::*;

logic back_ground_en;
logic cip_weight_load_en, cim_weight_load_en;
logic cip_compute_en,     cim_compute_en;
logic img_busy, cim_busy;

integer            conv2_addr;
logic              conv2_write_en;
conv2_activation_t conv2_write_code;

select_t weight_load_select_synced;
select_t compute_select_synced;

img u_img (
    .clk                   (clk),
    .rst_n                 (rst_n),
    .o_busy                (img_busy),
    .i_exposure_write_en   (i_exposure_write_en),
    .i_exposure_write_data (i_exposure_write_data),
    .i_back_ground_en      (back_ground_en),
    .i_motion_detect       (tft_motion_detect),
    .i_addr                (i_image_addr),
    .o_read_data           (o_image_data),
    .s10_clk               (s10_cip_clk),
    .s10_exposure_out_en   (s10_exposure_out_en),
    .s10_exposure          (s10_exposure),
    .s10_frame             (s10_frame),
    .s10_mode              (s10_mode),
    .tft_clk               (tft_clk),
    .tft_addr              (tft_addr),
    .tft_pixel             (tft_pixel)
);

cip u_cip (
    .clk                        (clk),
    .rst_n                      (rst_n),
    .o_busy                     (o_cip_busy),
    .i_weight_channel           (i_weight_addr),
    .i_weight_write_en          (i_weight_write_select == CONV1),
    .i_weight_write_data        (i_weight_write_data[size::CONV1.WIDTH ** 2 - 1 : 0]),
    .o_conv2_addr               (conv2_addr),
    .o_conv2_write_en           (conv2_write_en),
    .o_conv2_write_code         (conv2_write_code),
    .i_weight_load_en           (cip_weight_load_en),
    .i_compute_en               (cip_compute_en || compute_select_synced == CONV1),
    .s10_clk                    (s10_cip_clk),
    .s10_weight_rst             (s10_weight_rst),
    .s10_weight_out_en          (s10_cip_weight_out_en),
    .s10_weight                 (s10_cip_weight),
    .s10_weight_down_shift_clk  (s10_weight_down_shift_clk),
    .s10_weight_right_shift_clk (s10_weight_right_shift_clk),
    .s10_ccap_right_shift_clk   (s10_ccap_right_shift_clk),
    .s10_row                    (s10_row),
    .s10_activation_in_en       (s10_cip_activation_in_en),
    .s10_activation_in          (s10_cip_activation_in),
    .s10_mode                   (s10_mode),
    .s10_precharge_n            (s10_precharge_n),
    .s10_differential_en        (s10_differential_en),
    .s10_active_clk             (s10_active_clk)
);

cim u_cim (
    .clk                       (clk),
    .rst_n                     (rst_n),
    .o_busy                    (cim_busy),
    .i_conv2_sim               (i_conv2_sim),
    .i_conv3_sim               (i_conv3_sim),
    .i_fc_sim                  (i_fc_sim),
    .i_weight_addr             (i_weight_addr),
    .i_weight_write_select     (i_weight_write_select),
    .i_weight_write_data       (i_weight_write_data),
    .i_activation_addr         ((conv2_write_en)? conv2_addr:       i_activation_addr),
    .i_activation_write_select ((conv2_write_en)? CONV2:            i_activation_write_select),
    .i_activation_write_code   ((conv2_write_en)? conv2_write_code: i_activation_write_code),
    .i_activation_read_select  (i_activation_read_select),
    .o_activation_read_code    (o_activation_read_code),
    .i_weight_load_en          (cim_weight_load_en),
    .i_weight_load_select      (weight_load_select_synced),
    .i_compute_select          (cim_compute_en? ALL: (compute_select_synced == CONV2)? CONV2:
                                                     (compute_select_synced == CONV3)? CONV3:
                                                     (compute_select_synced == FC)?    FC:    NONE),
    .o_result                  (o_result),
    .s10_clk                   (s10_cim_clk),
    .s10_select                (s10_select),
    .s10_addr_out_en           (s10_addr_out_en),
    .s10_addr                  (s10_addr),
    .s10_weight_out_en         (s10_cim_weight_out_en),
    .s10_weight                (s10_cim_weight),
    .s10_sram_write_en         (s10_sram_write_en),
    .s10_activation_out_en     (s10_activation_out_en),
    .s10_activation_out        (s10_activation_out),
    .s10_activation_in_en      (s10_cim_activation_in_en),
    .s10_activation_in         (s10_cim_activation_in),
    .s10_compute_en            (s10_compute_en),
    .s10_compare_en            (s10_compare_en),
    .s10_result                (s10_result),
    .tft_clk                   (tft_clk),
    .tft_select                (tft_select),
    .tft_addr                  (tft_addr),
    .tft_activation            (tft_activation)
);

fifo_async # (
    .BIT_WIDTH ($bits(select_t) * 2),
    .DEFAULT   ({NONE, NONE})
) u_fifo_async (
    .clk_write    (clk),
    .clk_read     (~s10_cip_clk),
    .rst_n        (rst_n),
    .i_write_en   (i_weight_load_select != NONE || i_compute_select != NONE),
    .i_write_data ({i_weight_load_select, i_compute_select}),
    .i_read_en    ('1),
    .o_read_data  ({weight_load_select_synced, compute_select_synced}),
    .o_empty      (),
    .o_full       ()
);

enum logic [2:0] {
    INIT,
    IDLE,
    PARALLEL,
    CIP_COMPUTE,
    CIM_COMPUTE,
    BUSY
} state;

logic compute_started;

always_ff @(negedge s10_cip_clk or negedge rst_n) begin
    if (!rst_n) begin
        state              <= INIT;
        back_ground_en     <= 1;
        cip_weight_load_en <= 1;
        cim_weight_load_en <= 1;
        cip_compute_en     <= 0;
        cim_compute_en     <= 0;
        compute_started    <= 0;
    end else begin
        case (state)
            INIT: begin
                if (cip_weight_load_en || cim_weight_load_en) begin
                    cip_weight_load_en <= 0;
                    cim_weight_load_en <= 0;
                end else if (!o_cip_busy && !cim_busy) begin
                    state          <= img_busy? INIT: IDLE;
                    back_ground_en <= 0;
                end
            end
            IDLE: begin
                compute_started <= 0;
                if (compute_select_synced == PIPLINE) begin
                    state          <= PARALLEL;
                    cip_compute_en <= 1;
                    cim_compute_en <= 1;
                end else if (compute_select_synced == ALL) begin
                    state          <= CIP_COMPUTE;
                    cip_compute_en <= 1;
                end else if (weight_load_select_synced != NONE) begin
                    state <= BUSY;
                end else if (compute_select_synced != NONE) begin
                    state <= BUSY;
                end
            end
            PARALLEL: begin
                if (cip_compute_en) begin
                    cip_compute_en <= 0;
                    cim_compute_en <= 0;
                end else if (!o_cip_busy && !cim_busy) begin
                    if (compute_select_synced != PIPLINE) begin
                        state <= IDLE;
                    end else begin
                        cip_compute_en <= 1;
                        cim_compute_en <= 1;
                    end
                end
            end
            CIP_COMPUTE: begin
                if (cip_compute_en) begin
                    cip_compute_en <= 0;
                end else if (!o_cip_busy) begin
                    state          <= CIM_COMPUTE;
                    cim_compute_en <= 1;
                end
            end
            CIM_COMPUTE: begin
                if (cim_compute_en) begin
                    cim_compute_en <= 0;
                end else if (!cim_busy) begin
                    state <= IDLE;
                end
            end
            BUSY: begin
                // 如果是单独触发 CONV2 / CONV3 / FC 计算，等待 cim_busy 拉起并完成
                if (compute_select_synced == CONV2 || compute_select_synced == CONV3 || compute_select_synced == FC) begin
                    if (cim_busy) begin
                        compute_started <= 1;
                    end else if (compute_started && !cim_busy) begin
                        state           <= IDLE;
                        compute_started <= 0;
                    end
                end else begin
                    // 原权重加载逻辑
                    if (!o_cip_busy && !cim_busy) begin
                        state <= IDLE;
                    end
                end
            end
            default: begin
                state              <= IDLE;
                back_ground_en     <= 0;
                cip_weight_load_en <= 0;
                cim_weight_load_en <= 0;
                cip_compute_en     <= 0;
                cim_compute_en     <= 0;
                compute_started    <= 0;
            end
        endcase
    end
end

assign o_busy = (state != IDLE);

assign s10_cip_rst = !rst_n;
assign s10_cim_rst = !rst_n;

endmodule
