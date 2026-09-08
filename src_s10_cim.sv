`timescale 1ns / 1ps

module cim (
    input  logic clk,
    input  logic rst_n,
    output logic o_busy,
    // sim
    input  logic i_conv2_sim,
    input  logic i_conv3_sim,
    input  logic i_fc_sim,
    // clk domain
    input  integer               i_weight_addr,
    input  s10_pkg::select_t     i_weight_write_select,
    input  s10_pkg::cim_weight_t i_weight_write_data,
    input  integer               i_activation_addr,
    input  s10_pkg::select_t     i_activation_write_select,
    input  s10_pkg::activation_t i_activation_write_code,
    input  s10_pkg::select_t     i_activation_read_select,
    output s10_pkg::activation_t o_activation_read_code,
    // cim_clk domain
    input  logic             i_weight_load_en,
    input  s10_pkg::select_t i_weight_load_select,
    input  s10_pkg::select_t i_compute_select,
    output s10_pkg::result_t o_result,
    // interface s10
    input  logic       s10_clk,
    output logic [1:0] s10_select,
    output logic       s10_addr_out_en,
    output logic       s10_addr,
    output logic       s10_weight_out_en,
    output logic       s10_weight,
    output logic       s10_sram_write_en,
    output wor         s10_activation_out_en,
    output logic       s10_activation_out,
    output wor         s10_activation_in_en,
    input  logic       s10_activation_in,
    output wor         s10_compute_en,
    output logic       s10_compare_en,
    input  logic [3:0] s10_result,
    // interface tft
    input  logic             tft_clk,
    input  s10_pkg::select_t tft_select,
    input  integer           tft_addr,
    output logic [1:0]       tft_activation
);

    import s10_pkg::*;

    logic weight_busy, conv2_busy, conv3_busy, fc_busy;

    conv2_activation_t conv2_read_code;
    conv3_activation_t conv3_read_code;
    fc_activation_t    fc_read_code;

    select_t load_select, weight_select;

    logic    conv2_compute_en,     conv3_compute_en,     fc_compute_en;
    logic    conv2_activation_out, conv3_activation_out, fc_activation_out;

    logic [1:0] tft_conv2_code, tft_conv3_code, tft_fc_code;

    integer      sim_weight_addr;
    cim_weight_t sim_weight;
    logic        sim_activation_in;
    result_t     sim_result;

    cim_weight u_weight (
        .clk               (clk),
        .rst_n             (rst_n),
        .o_busy            (weight_busy),
        .i_addr            (i_weight_addr),
        .i_write_select    (i_weight_write_select),
        .i_write_data      (i_weight_write_data),
        .i_load_select     (load_select),
        .o_select          (weight_select),
        .i_sim_addr        (sim_weight_addr),
        .i_sim_select      (conv2_busy? CONV2:
                            conv3_busy? CONV3:
                            fc_busy   ? FC: NONE),
        .o_sim_weight      (sim_weight),
        .s10_clk           (s10_clk),
        .s10_addr_out_en   (s10_addr_out_en),
        .s10_addr          (s10_addr),
        .s10_weight_out_en (s10_weight_out_en),
        .s10_weight        (s10_weight),
        .s10_sram_write_en (s10_sram_write_en)
    );

    cim_sim u_sim (
        .s10_clk               (s10_clk),
        .rst_n                 (rst_n),
        .i_select              (conv2_busy? CONV2:
                                conv3_busy? CONV3:
                                fc_busy   ? FC: NONE),
        .o_weight_addr         (sim_weight_addr),
        .i_weight              (sim_weight),
        .s10_activation_in_en  (s10_activation_out_en),
        .s10_activation_in     (s10_activation_out),
        .s10_activation_out_en (s10_activation_in_en),
        .s10_activation_out    (sim_activation_in),
        .s10_result            (sim_result)
    );

    cim_convolve # (
        .WIDTH_IN     (size::ACTI1.WIDTH),
        .CHANNEL_OUT  (size::CONV2.CHANNEL_OUT),
        .CHANNEL_IN   (size::CONV2.CHANNEL_IN),
        .WIDTH_KERNEL (size::CONV2.WIDTH)
    ) u_conv2 (
        .clk                   (clk),
        .rst_n                 (rst_n),
        .o_busy                (conv2_busy),
        .i_addr                (i_activation_addr),
        .i_write_en            (i_activation_write_select == CONV2),
        .i_write_code          (i_activation_write_code[size::ACTI1.CHANNEL - 1 : 0]),
        .o_read_code           (conv2_read_code),
        .i_compute_en          (conv2_compute_en),
        .s10_clk               (s10_clk),
        .s10_activation_out_en (s10_activation_out_en),
        .s10_activation_out    (conv2_activation_out),
        .s10_compute_en        (s10_compute_en),
        .s10_activation_in_en  (s10_activation_in_en),
        .tft_clk               (tft_clk),
        .tft_addr              (tft_addr),
        .tft_activation        (tft_conv2_code)
    );

    logic [$clog2(size::ACTI2.WIDTH ** 2)-1:0] conv3_addr;
    logic                                      conv3_write_en;
    conv3_activation_t                         conv3_write_code;

    cim_max_pool # (
        .CHANNEL   (size::ACTI2.CHANNEL),
        .WIDTH_OUT (size::ACTI2.WIDTH)
    ) u_max_pool1 (
        .clk                  (clk),
        .rst_n                (rst_n),
        .o_addr               (conv3_addr),
        .o_activation_out_en  (conv3_write_en),
        .o_activation_out     (conv3_write_code),
        .s10_clk              (s10_clk),
        .s10_activation_in_en (conv2_busy & s10_activation_in_en),
        .s10_activation_in    (i_conv2_sim? sim_activation_in: s10_activation_in)
    );

    select_t d1_activation_read_select;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            d1_activation_read_select <= NONE;
        end else begin
            d1_activation_read_select <= i_activation_read_select;
        end
    end

    cim_convolve # (
        .WIDTH_IN     (size::ACTI2.WIDTH),
        .CHANNEL_OUT  (size::CONV3.CHANNEL_OUT),
        .CHANNEL_IN   (size::CONV3.CHANNEL_IN),
        .WIDTH_KERNEL (size::CONV3.WIDTH)
    ) u_conv3 (
        .clk                   (clk),
        .rst_n                 (rst_n),
        .o_busy                (conv3_busy),
        // 修正：将读地址选择与打拍后的 d1_activation_read_select 同步，保证回传 acti2 时寻址稳定
        .i_addr                ((i_activation_write_select == CONV3 || d1_activation_read_select == CONV3 || i_activation_read_select == CONV3)? i_activation_addr: conv3_addr),
        .i_write_en            (i_activation_write_select == CONV3 || conv3_write_en),
        .i_write_code          ((i_activation_write_select == CONV3)? i_activation_write_code[size::ACTI2.CHANNEL - 1 : 0]: conv3_write_code),
        .o_read_code           (conv3_read_code),
        .i_compute_en          (conv3_compute_en),
        .s10_clk               (s10_clk),
        .s10_activation_out_en (s10_activation_out_en),
        .s10_activation_out    (conv3_activation_out),
        .s10_compute_en        (s10_compute_en),
        .s10_activation_in_en  (s10_activation_in_en),
        .tft_clk               (tft_clk),
        .tft_addr              (tft_addr),
        .tft_activation        (tft_conv3_code)
    );

    logic [$clog2(size::ACTI3.WIDTH ** 2)-1:0] fc_addr;
    logic                                      fc_write_en;
    fc_activation_t                            fc_write_code;

    cim_max_pool # (
        .CHANNEL   (size::ACTI3.CHANNEL),
        .WIDTH_OUT (size::ACTI3.WIDTH)
    ) u_max_pool2 (
        .clk                  (clk),
        .rst_n                (rst_n),
        .o_addr               (fc_addr),
        .o_activation_out_en  (fc_write_en),
        .o_activation_out     (fc_write_code),
        .s10_clk              (s10_clk),
        .s10_activation_in_en (conv3_busy & s10_activation_in_en),
        .s10_activation_in    (i_conv3_sim? sim_activation_in: s10_activation_in)
    );

    result_t fc_result;

    cim_linear # (
        .WIDTH_WRITE (size::ACTI3.CHANNEL),
        .CHANNEL_OUT (size::FC.CHANNEL_OUT),
        .CHANNEL_IN  (size::FC.CHANNEL_IN)
    ) u_fc (
        .clk                   (clk),
        .rst_n                 (rst_n),
        .o_busy                (fc_busy),
        .i_addr                ((i_activation_write_select == FC || d1_activation_read_select == FC || i_activation_read_select == FC)? i_activation_addr: fc_addr),
        .i_write_en            (i_activation_write_select == FC || fc_write_en),
        .i_write_code          ((i_activation_write_select == FC)? i_activation_write_code[size::ACTI3.CHANNEL - 1 : 0]: fc_write_code),
        .o_read_code           (fc_read_code),
        .i_compute_en          (fc_compute_en),
        .o_result              (fc_result),
        .s10_clk               (s10_clk),
        .s10_activation_out_en (s10_activation_out_en),
        .s10_activation_out    (fc_activation_out),
        .s10_compute_en        (s10_compute_en),
        .s10_compare_en        (s10_compare_en),
        .s10_result            (s10_result),
        .tft_clk               (tft_clk),
        .tft_addr              (tft_addr),
        .tft_activation        (tft_fc_code)
    );

    enum logic [1:0] {
        IDLE,
        LOAD_WIGHT,
        COMPUTE,
        BUSY
    } state, last_state;

    localparam int COUNT = 3;
    logic [$clog2(COUNT)-1:0] count;

    always_ff @(negedge s10_clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            last_state <= IDLE;
            count      <= 'x;
        end else begin
            case (state)
                IDLE: begin
                    if (i_weight_load_en) begin
                        state <= LOAD_WIGHT;
                        count <= COUNT - 1;
                    end else if (i_weight_load_select == CONV2
                              || i_weight_load_select == CONV3
                              || i_weight_load_select == FC) begin
                        state <= BUSY;
                        count <= 0;
                    end else if (i_compute_select == ALL) begin
                        state <= COMPUTE;
                        count <= COUNT - 1;
                    end else if (i_compute_select == CONV2
                              || i_compute_select == CONV3
                              || i_compute_select == FC) begin
                        state <= BUSY;
                        count <= 0;
                    end
                end
                LOAD_WIGHT: begin
                    state      <= BUSY;
                    last_state <= LOAD_WIGHT;
                end
                COMPUTE: begin
                    state      <= BUSY;
                    last_state <= COMPUTE;
                end
                BUSY: begin
                    if (!(weight_busy | conv2_busy | conv3_busy | fc_busy)) begin
                        if (count == 0) begin
                            state      <= IDLE;
                            last_state <= IDLE;
                            count      <= 'x;
                        end else begin
                            state <= last_state;
                            count <= count - 1;
                        end
                    end
                end
            endcase
        end
    end

    assign o_busy = (state != IDLE) || conv2_busy || conv3_busy || fc_busy;

    assign o_activation_read_code = (d1_activation_read_select == CONV2)? conv2_read_code:
                                    (d1_activation_read_select == CONV3)? conv3_read_code:
                                    (d1_activation_read_select == FC)   ? fc_read_code   : 'x;

    assign load_select = (state == LOAD_WIGHT && count == 2)? CONV2:
                         (state == LOAD_WIGHT && count == 1)? CONV3:
                         (state == LOAD_WIGHT && count == 0)? FC   :
                         (state == IDLE)? i_weight_load_select: NONE;

    assign s10_select = conv2_busy? CONV2[1:0]:
                        conv3_busy? CONV3[1:0]:
                        fc_busy   ? FC[1:0]   : weight_select[1:0];

    // 优化计算使能：确保单层触发时，在 conv2_busy 拉起之前持续输出脉冲
    assign conv2_compute_en = (state == COMPUTE && count == 2) || ((state == IDLE || state == BUSY) && i_compute_select == CONV2 && !conv2_busy);
    assign conv3_compute_en = (state == COMPUTE && count == 1) || ((state == IDLE || state == BUSY) && i_compute_select == CONV3 && !conv3_busy);
    assign fc_compute_en    = (state == COMPUTE && count == 0) || ((state == IDLE || state == BUSY) && i_compute_select == FC && !fc_busy);

    assign s10_activation_out = conv2_busy? conv2_activation_out:
                                conv3_busy? conv3_activation_out:
                                fc_busy   ? fc_activation_out: 'x;

    assign tft_activation = (tft_select == CONV2)? DECODE[tft_conv2_code]:
                            (tft_select == CONV3)? DECODE[tft_conv3_code]:
                            (tft_select == FC)?    DECODE[tft_fc_code]: 'x;

    assign o_result = i_fc_sim? sim_result: fc_result;

endmodule
