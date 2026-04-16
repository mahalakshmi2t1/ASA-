module fec_fsm #(
    parameter DATA_WIDTH = 8,
    parameter K = 214,  // message size
    parameter N = 240   // total codeword size
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [DATA_WIDTH-1:0]    data_in,
    input  wire data_valid,

    // RS encoder interface
    input  wire [DATA_WIDTH-1:0] parity_in,
    input  wire parity_valid,
    output reg  enc_enable,
    output reg  select_parity,

    // TX output
    output reg [DATA_WIDTH-1:0]     tx_data,
    output reg tx_valid,
    output reg frame_start,
    output reg frame_end
);

localparam PARITY = N - K;

parameter  S_IDLE = 3’h0;
parameter  S_DATA = 3’h1;
parameter  S_WAIT_PARITY = 3’h2;
parameter  S_PARITY = 3’h3;
parameter  S_DONE = 3’h4;

reg [2:0] state, next_state;
integer    data_cnt;
integer    parity_cnt;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state <= S_IDLE;
    else
        state <= next_state;
end


always @(*) begin
    next_state = state;

    case (state)

    S_IDLE:
        if (data_valid)
            next_state = S_DATA;

    S_DATA:
        if (data_cnt == K-1)
            next_state = S_WAIT_PARITY;

    S_WAIT_PARITY:
        if (parity_valid)
            next_state = S_PARITY;

    S_PARITY:
        if (parity_cnt == PARITY-1)
            next_state = S_DONE;

    S_DONE:
        next_state = S_IDLE;

    endcase
end

///////////////////////
// Counters
///////////////////////
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data_cnt   <= 0;
        parity_cnt <= 0;
    end else begin
        case (state)

        S_IDLE: begin
            data_cnt   <= 0;
            parity_cnt <= 0;
        end


        S_DATA: begin
            if (data_valid)
                data_cnt <= data_cnt + 1;
        end

        S_PARITY: begin
            if (parity_valid)
                parity_cnt <= parity_cnt + 1;
        end

        endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tx_data        <= 0;
        tx_valid       <= 0;
        frame_start    <= 0;
        frame_end      <= 0;
        enc_enable     <= 0;
        select_parity  <= 0;
    end else begin
        // Default
        tx_valid      <= 0;
        frame_start   <= 0;
        frame_end     <= 0;

        case (state)

        S_IDLE: begin
            if (data_valid)
                frame_start <= 1;
        end

        S_DATA: begin
            if (data_valid) begin
                tx_data    <= data_in;
                tx_valid   <= 1;
                enc_enable <= 1;
            end
        end

        S_WAIT_PARITY: begin
            enc_enable <= 0; // stop feeding encoder
        end

        S_PARITY: begin
            if (parity_valid) begin
                tx_data       <= parity_in;
                tx_valid      <= 1;
                select_parity <= 1;
            end
        end

        S_DONE: begin
            frame_end     <= 1;
            select_parity <= 0;
        end

        endcase
    end
end

endmodule
