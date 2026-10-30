module init(input logic clk, input logic rst_n,
            input logic en, output logic rdy,
            output logic [7:0] addr, output logic [7:0] wrdata, output logic wren);

// State machine for ARC4 initialization
typedef enum logic [1:0] {WAIT, INIT, DONE} state_t;
state_t state;
logic [7:0] i;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= WAIT;
        i <= 8'd0;
        rdy <= 1'b1;
        addr <= 8'd0;
        wrdata <= 8'd0;
        wren <= 1'b0;
    end 
    else begin
        case (state)
            WAIT: begin
                rdy <= 1'b1;
                wren <= 1'b0;
                if (en) begin
                    state <= INIT;
                    i <= 8'd0;
                    rdy <= 1'b0;
                end
                else begin
                    state <= WAIT;
                end
            end
            INIT: begin
                addr <= i;
                wrdata <= i;
                wren <= 1'b1;
                rdy <= 1'b0;
                if (i == 8'd255) begin
                    state <= DONE;
                end else begin
                    i <= i + 8'd1;
                end
            end
            DONE: begin
                wren <= 1'b0;
                rdy <= 1'b1;
                state <= WAIT;
            end
        endcase
    end
end

endmodule: init
