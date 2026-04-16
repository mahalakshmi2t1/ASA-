module fec_fsm #(
    parameter K = 214,  // message size
    parameter N = 216,   // total codeword size
    parameter NUM_BLK = 3
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [8:0] data_in,
    input  wire data_valid,

    // RS encoder interface
    input  wire [8:0] parity_in,
    input  wire parity_valid,

    // TX output
    output reg [8:0] tx_data,
    output reg tx_valid,
    output reg fec_done
);

localparam PARITY = N - K;
    
parameter  IDLE = 3'h0;
parameter  DATA = 3'h1;
parameter  WAIT_PARITY = 3'h2;
parameter  PARITY = 3'h3;
parameter  NEXT_BLK = 3'h4;
parameter  DONE = 3'h5;

reg [2:0] state, next_state;
integer data_cnt;
integer parity_cnt;
integer blk_cnt;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state <= IDLE;
    else
        state <= next_state;
end

always @(*) begin
    next_state = state;
    case (state)
    IDLE:
        if (data_valid)
            next_state = DATA;
    DATA:
        if (data_cnt == K-1)
            next_state = WAIT_PARITY;
    WAIT_PARITY:
        if (parity_valid)
            next_state = PARITY;
    PARITY:
        if (parity_cnt == PARITY-1)
            next_state = NEXT_BLK;
   NEXT_BLK:
        if (blk_cnt == NUM_BLK-1)
            next_state = DONE;
        else
            next_state = DATA;    
    DONE:
        next_state = IDLE;
    endcase
end

// Counters
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data_cnt   <= 0;
        parity_cnt <= 0;
        blk_cnt <= 0;
    end else begin
        case (state)
        IDLE: begin
            data_cnt   <= 0;
            parity_cnt <= 0;
            blk_cnt <= 0;
        end
        DATA: begin
            if (data_valid)
                data_cnt <= data_cnt + 1;
        end
        PARITY: begin
            if (parity_valid)
                parity_cnt <= parity_cnt + 1;
        end
        NEXT_BLK: begin
            blk_cnt    <= blk_cnt + 1;
            data_cnt   <= 0;
            parity_cnt <= 0;
        end
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tx_data        <= 0;
        tx_valid       <= 0;
        fec_done       <= 0;
    end else begin
        tx_valid      <= 0;
        frame_end     <= 0;
        case (state)
        DATA: begin
            if (data_valid) begin
                tx_data    <= data_in;
                tx_valid   <= 1;
            end
        end
        PARITY: begin
            if (parity_valid) begin
                tx_data       <= parity_in;
                tx_valid      <= 1;
            end
        end
        DONE: begin
            fec_done         <= 1;
        end
        endcase
    end
end
endmodule
