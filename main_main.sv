`timescale 1ns / 1ps

module main (
    input logic clk,
    input logic rst_n,
    input logic i_busy,
    input logic i_cip_busy,
    // s10 control
        output logic                 o_exposure_write_en,
        output s10_pkg::exposure_t   o_exposure_write_data,
        output integer               o_image_addr,
        input  s10_pkg::pixel_t      i_image_data,
        output integer               o_weight_addr,
        output s10_pkg::select_t     o_weight_write_select,
        output s10_pkg::weight_t     o_weight_write_data,
        output s10_pkg::select_t     o_weight_load_select,
        output integer               o_activation_addr,
        output s10_pkg::select_t     o_activation_write_select,
        output s10_pkg::activation_t o_activation_write_code,
        output s10_pkg::select_t     o_activation_read_select,
        input  s10_pkg::activation_t i_activation_read_code,
        output s10_pkg::select_t     o_compute_select,
        input  s10_pkg::result_t     i_result,
    output tft_pkg::message_t o_message,
    input  logic              i_uart_rx_fifo_empty,
    output logic              o_uart_read_en,
    input  logic [7:0]        i_uart_read_data,
    output logic              o_uart_write_en,
    output logic [7:0]        o_uart_write_data
);

    import s10_pkg::*;

    logic d1_busy, done;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            d1_busy <= 0;
            done    <= 0;
        end else begin
            d1_busy <= i_busy;
            done    <= d1_busy && !i_busy;
        end
    end

    logic d1_cip_busy, cip_done;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            d1_cip_busy <= 0;
            cip_done    <= 0;
        end else begin
            d1_cip_busy <= i_cip_busy;
            cip_done    <= d1_cip_busy && !i_cip_busy;
        end
    end

  
    enum logic [3:0] {
        IDLE,
        RX,
        TRAIN_COMPUTE,
        TRAIN_TX,
        UPDATE_SELECT,
        UPDATE_WEIGHT,
        UPDATE_LOAD,
        TEST_COMPUTE,
        TEST_TX_CONV1,   // send CONV1 active
        TEST_TX_CONV2,   // send CONV2 active
        TEST_TX_CONV3,   // send CONV3 active
        PIPLINE_COMPUTE,
        PIPLINE_TX
    } state;

    integer  count;
    select_t update_select;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state                     <= IDLE;
            count                     <= 'x;
            update_select             <= NONE;
            o_exposure_write_en       <= 0;
            o_exposure_write_data     <= 'x;
            o_image_addr              <= 'x;
            o_weight_addr             <= 'x;
            o_weight_write_select     <= NONE;
            o_weight_write_data       <= 'x;
            o_weight_load_select      <= NONE;
            o_activation_addr         <= 'x;
            o_activation_write_select <= NONE;
            o_activation_write_code   <= 'x;
            o_activation_read_select  <= NONE;
            o_compute_select          <= NONE;
            o_message                 <= "";
            o_uart_read_en            <= 0;
            o_uart_write_en           <= 0;
            o_uart_write_data         <= 'x;
        end else begin
            case (state)
                IDLE: begin
                    if (!i_uart_rx_fifo_empty) begin
                        state          <= RX;
                        o_uart_read_en <= 1;
                    end
                    o_uart_write_en   <= 0;
                    o_uart_write_data <= 'x;
                end
                RX: begin
                    if (i_uart_read_data == "1") begin
                        state            <= TRAIN_COMPUTE;
                        o_compute_select <= CONV1;
                        o_message        <= "train: compute conv1";
                    end else if (i_uart_read_data == "2") begin
                        state     <= UPDATE_SELECT;
                        count     <= 0;
                        o_message <= "update: weight      ";
                    end else if (i_uart_read_data == "3") begin
                        state            <= TEST_COMPUTE;
                        o_compute_select <= ALL;
                        o_message        <= "test: compute all";
                    end else if (i_uart_read_data == "4") begin
                        state            <= PIPLINE_COMPUTE;
                        o_compute_select <= PIPLINE;
                        o_message        <= "pipline: 000,000";
                    end
                    o_uart_read_en <= 0;
                end
                TRAIN_COMPUTE: begin
                    if (done) begin
                        state                    <= TRAIN_TX;
                        count                    <= 0;
                        o_activation_read_select <= CONV2;
                        o_activation_addr        <= 0;
                        o_message                <= "transmit conv1 activation (000/000)";
                        o_message[3]             <= size::ACTI1.WIDTH ** 2 / 100     + "0";
                        o_message[2]             <= size::ACTI1.WIDTH ** 2 / 10 % 10 + "0";
                        o_message[1]             <= size::ACTI1.WIDTH ** 2 % 10      + "0";
                    end
                    o_compute_select <= NONE;
                end
                TRAIN_TX: begin
                    if (count == 0) begin
                        count        <= count + 1;
                        o_message[7] <= o_activation_addr / 100                                 + "0";
                        o_message[6] <= o_activation_addr / 10 - (o_activation_addr / 100 * 10) + "0";
                        o_message[5] <= o_activation_addr      - (o_activation_addr / 10  * 10) + "0";
                    end else if (count <= 1 + size::ACTI1.CHANNEL-1) begin
                        count             <= count + 1;
                        o_uart_write_en   <= 1;
                        o_uart_write_data <= (i_activation_read_code[count - 1] == ENCODE[2'b01])? "+":
                                             (i_activation_read_code[count - 1] == ENCODE[2'b00])? "0":
                                             (i_activation_read_code[count - 1] == ENCODE[2'b11])? "-": "x";
                    end else if (count == 1 + size::ACTI1.CHANNEL-1 + 1) begin
                        count             <= count + 1;
                        o_uart_write_en   <= 1;
                        o_uart_write_data <= "\n";
                    end else if (count == 1 + size::ACTI1.CHANNEL-1 + 2) begin
                        count             <= count + 1;
                        o_uart_write_en   <= 0;
                        o_uart_write_data <= 'x;
                    end else if (done) begin
                        if (o_activation_addr == size::ACTI1.WIDTH ** 2 - 1) begin
                            state                    <= IDLE;
                            count                    <= 'x;
                            o_activation_addr        <= 'x;
                            o_activation_read_select <= NONE;
                            o_message                <= "";
                        end else begin
                            count             <= 0;
                            o_activation_addr <= o_activation_addr + 1;
                        end
                    end
                end
                UPDATE_SELECT: begin
                    if (count == 0) begin
                        if (!i_uart_rx_fifo_empty) begin
                            count          <= count + 1;
                            o_uart_read_en <= 1;
                        end
                    end else begin
                        state          <= UPDATE_WEIGHT;
                        count          <= 0;
                        o_uart_read_en <= 0;
                        update_select  <= (i_uart_read_data == "2")? CONV2:
                                          (i_uart_read_data == "3")? CONV3: FC;
                        o_weight_addr  <= (i_uart_read_data == "2")? (size::CONV2.WIDTH ** 2 * size::CONV2.CHANNEL_IN - 1):
                                          (i_uart_read_data == "3")? (size::CONV3.WIDTH ** 2 * size::CONV3.CHANNEL_IN - 1): (size::FC.CHANNEL_IN - 1);
                        o_message[4:0] <= (i_uart_read_data == "2")? "CONV2":
                                          (i_uart_read_data == "3")? "CONV3": "FC   ";
                    end
                end
                UPDATE_WEIGHT: begin
                    if (count == 0 || count == 2 || count == 4 || count == 6) begin
                        if (!i_uart_rx_fifo_empty) begin
                            count          <= count + 1;
                            o_uart_read_en <= 1;
                        end
                    end else if (count == 1) begin
                        count               <= count + 1;
                        o_uart_read_en      <= 0;
                        o_weight_write_data <= i_uart_read_data;
                    end else if (count == 3 || count == 5) begin
                        count               <= count + 1;
                        o_uart_read_en      <= 0;
                        o_weight_write_data <= (o_weight_write_data << 8) | i_uart_read_data;
                    end else if (count == 7) begin
                        count                 <= count + 1;
                        o_uart_read_en        <= 0;
                        o_weight_write_data   <= (o_weight_write_data << 8) | i_uart_read_data;
                        o_weight_write_select <= update_select;
                    end else begin
                        if (o_weight_addr == 0) begin
                            state         <= UPDATE_LOAD;
                            o_weight_addr <= 'x;
                        end else begin
                            o_weight_addr <= o_weight_addr - 1;
                        end
                        count                 <= 0;
                        o_weight_write_select <= NONE;
                    end
                end
                UPDATE_LOAD: begin
                    if (count == 0) begin
                        count                <= count + 1;
                        o_weight_load_select <= update_select;
                    end else if (done) begin
                        state         <= IDLE;
                        count         <= 'x;
                        update_select <= NONE;
                        o_message     <= "";
                    end else begin
                        o_weight_load_select <= NONE;
                    end
                end
                TEST_COMPUTE: begin
                    if (done) begin
                        state             <= IDLE;
                        o_uart_write_en   <= 1;
                        o_uart_write_data <= i_result + "0";
                        o_message         <= "";
                    end
                    o_compute_select <= NONE;
                end
                TEST_TX_CONV1: begin
                if (count <= size::ACTI1.CHANNEL - 1) begin
                    count             <= count + 1;
                    o_uart_write_en   <= 1;
                    o_uart_write_data <= (i_activation_read_code[count] == ENCODE[2'b01])? "+":
                                         (i_activation_read_code[count] == ENCODE[2'b00])? "0":
                                         (i_activation_read_code[count] == ENCODE[2'b11])? "-": "x";
                end else if (count == size::ACTI1.CHANNEL) begin
                    count             <= count + 1;
                    o_uart_write_en   <= 1;
                    o_uart_write_data <= "\n";
                end else if (count == size::ACTI1.CHANNEL + 1) begin
                    count             <= count + 1;
                    o_uart_write_en   <= 0;
                    o_uart_write_data <= 'x;
                end else if (done) begin // wait UART hand
                    if (o_activation_addr == size::ACTI1.WIDTH ** 2 - 1) begin
                        // switch to CONV2
                        state                    <= TEST_TX_CONV2;
                        count                    <= 0;
                        o_activation_read_select <= CONV3; // CONV3 corresponding to ACTI2
                        o_activation_addr        <= 0;
                        o_message                <= "transmit conv2 activation";
                    end else begin
                        count             <= 0;
                        o_activation_addr <= o_activation_addr + 1;
                    end
                end
            end
            TEST_TX_CONV2: begin
                if (count <= size::ACTI2.CHANNEL - 1) begin
                    count             <= count + 1;
                    o_uart_write_en   <= 1;
                    o_uart_write_data <= (i_activation_read_code[count] == ENCODE[2'b01])? "+":
                                         (i_activation_read_code[count] == ENCODE[2'b00])? "0":
                                         (i_activation_read_code[count] == ENCODE[2'b11])? "-": "x";
                end else if (count == size::ACTI2.CHANNEL) begin
                    count             <= count + 1;
                    o_uart_write_en   <= 1;
                    o_uart_write_data <= "\n";
                end else if (count == size::ACTI2.CHANNEL + 1) begin
                    count             <= count + 1;
                    o_uart_write_en   <= 0;
                    o_uart_write_data <= 'x;
                end else if (done) begin
                    if (o_activation_addr == size::ACTI2.WIDTH ** 2 - 1) begin
                        // CONV2 读完，切换到 CONV3
                        state                    <= TEST_TX_CONV3;
                        count                    <= 0;
                        o_activation_read_select <= FC;    // FC 输入存储区对应 ACTI3
                        o_activation_addr        <= 0;
                        o_message                <= "transmit conv3 activation";
                    end else begin
                        count             <= 0;
                        o_activation_addr <= o_activation_addr + 1;
                    end
                end
            end
                TEST_TX_CONV3: begin
                if (count <= size::ACTI3.CHANNEL - 1) begin
                    count             <= count + 1;
                    o_uart_write_en   <= 1;
                    o_uart_write_data <= (i_activation_read_code[count] == ENCODE[2'b01])? "+":
                                         (i_activation_read_code[count] == ENCODE[2'b00])? "0":
                                         (i_activation_read_code[count] == ENCODE[2'b11])? "-": "x";
                end else if (count == size::ACTI3.CHANNEL) begin
                    count             <= count + 1;
                    o_uart_write_en   <= 1;
                    o_uart_write_data <= "\n";
                end else if (count == size::ACTI3.CHANNEL + 1) begin
                    count             <= count + 1;
                    o_uart_write_en   <= 0;
                    o_uart_write_data <= 'x;
                end else if (done) begin
                    if (o_activation_addr == size::ACTI3.WIDTH ** 2 - 1) begin
                        // 全部特征图发送完成，最后发送单个分类结果与回车
                        state                    <= IDLE;
                        count                    <= 'x;
                        o_activation_addr        <= 'x;
                        o_activation_read_select <= NONE;
                        o_uart_write_en          <= 1;
                        o_uart_write_data        <= i_result + "0";
                        o_message                <= "";
                    end else begin
                        count             <= 0;
                        o_activation_addr <= o_activation_addr + 1;
                    end
                end
            end
                PIPLINE_COMPUTE: begin
                    if (!i_uart_rx_fifo_empty) begin
                        state            <= PIPLINE_TX;
                        count            <= 21;
                        o_compute_select <= NONE;
                        o_uart_read_en   <= 1;
                    end else if (cip_done) begin
                        o_uart_write_en   <= 1;
                        o_uart_write_data <= i_result + "0";
                        if (o_message[0] == "9") begin o_message[0] <= "0";
                        if (o_message[1] == "9") begin o_message[1] <= "0";
                        if (o_message[2] == "9") begin o_message[2] <= "0";
                        if (o_message[4] == "9") begin o_message[4] <= "0";
                        if (o_message[5] == "9") begin o_message[5] <= "0";
                        if (o_message[6] == "9") begin o_message[6] <= "0";
                        end else o_message[6] <= o_message[6] + 1;
                        end else o_message[5] <= o_message[5] + 1;
                        end else o_message[4] <= o_message[4] + 1;
                        end else o_message[2] <= o_message[2] + 1;
                        end else o_message[1] <= o_message[1] + 1;
                        end else o_message[0] <= o_message[0] + 1;
                    end else begin
                        o_uart_write_en <= 0;
                    end
                end
                PIPLINE_TX: begin
                    if (count == 16) begin
                        count             <= count - 1;
                        o_uart_read_en    <= 0;
                        o_uart_write_en   <= 1;
                        o_uart_write_data <= "\n";
                    end else if (count == -1) begin
                        state             <= IDLE;
                        count             <= 'x;
                        o_uart_write_en   <= 0;
                        o_uart_write_data <= 'x;
                    end else begin
                        count             <= count - 1;
                        o_uart_write_data <= o_message[count];
                    end
                end
                default: begin
                    state                     <= IDLE;
                    count                     <= 'x;
                    update_select             <= NONE;
                    o_exposure_write_en       <= 0;
                    o_exposure_write_data     <= 'x;
                    o_image_addr              <= 'x;
                    o_weight_addr             <= 'x;
                    o_weight_write_select     <= NONE;
                    o_weight_write_data       <= 'x;
                    o_weight_load_select      <= NONE;
                    o_activation_addr         <= 'x;
                    o_activation_write_select <= NONE;
                    o_activation_write_code   <= 'x;
                    o_activation_read_select  <= NONE;
                    o_compute_select          <= NONE;
                    o_message                 <= "";
                    o_uart_read_en            <= 0;
                    o_uart_write_en           <= 0;
                    o_uart_write_data         <= 'x;
                end
            endcase
        end
    end

endmodule
