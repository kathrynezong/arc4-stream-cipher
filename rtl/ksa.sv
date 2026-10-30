module ksa(input logic clk, input logic rst_n,
           input logic en, output logic rdy,
           input logic [23:0] key,
           output logic [7:0] addr, input logic [7:0] rddata, output logic [7:0] wrdata, output logic wren);

typedef enum logic [3:0] {WAIT, READ_SI, WAIT_SI, COMPUTE_J, CAPTURE_SJ, READ_SJ, WRITE_SJ, ADV_SI, DONE} state_t;
state_t state;
logic [7:0] i, j, si, sj;

/* j = 0
for i = 0 to 255:
    j = (j + s[i] + key[i mod keylength]) mod 256   -- for us, keylength is 3
    swap values of s[i] and s[j] */

// key byte select based on i mod 3
logic [7:0] key_byte;
always_comb begin
    case (i % 3)
        2'd0: key_byte = key[23:16];
        2'd1: key_byte = key[15:8];
        2'd2: key_byte = key[7:0];
        default: key_byte = 8'd0;
    endcase
end

always_comb begin
    rdy = (state == WAIT);
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= WAIT;
        i <= 8'd0;
        j <= 8'd0;
        si <= 8'd0;
        sj <= 8'd0;
        addr <=8'd0;
        wrdata <= 8'd0;
        wren <= 1'b0;
    end
    else begin
        case (state)
            WAIT: begin
                wren <= 1'b0;
                if (en) begin
                    state <= READ_SI;
                    i <= 8'd0;
                    j <= 8'd0;
                end
                else begin
                    state <= WAIT;
                end
            end

            //address is i
            READ_SI: begin
                wren <= 1'b0;
                addr <= i;
                state <= WAIT_SI;
            end

            WAIT_SI: begin //wait one cycle for memory read
            wren  <= 1'b0;
            state <= COMPUTE_J;  
            end
            

            //s[i] on rddata, compute j, put s[j] address on addr bus (j)
            COMPUTE_J: begin
                si <= rddata; //capture s[i] in si before we overwrite it
                j <= rddata + j + key_byte;  // mod 256 is implicit with 8-bit
                addr <= rddata + j + key_byte; //recompute, need new value of j for address
                wren <= 1'b0; //no write yet, just wait for s[j]
                state <= READ_SJ;
            end

            READ_SJ: begin //wait one cycle
            wren  <= 1'b0;       // no write yet, just wait for s[j]
            state <= CAPTURE_SJ;
            end

            //s[j] on rddata, save it, write s[i]'s value to s[j]
            CAPTURE_SJ: begin
                sj <= rddata; // capture s[j] in sj before overwriting it
                //addr <= j
                wrdata <= si;
                wren <= 1'b1; //write s[i] to s[j]
                state <= WRITE_SJ;
            end

            //write s[j]'s OLD value to s[i]
            WRITE_SJ: begin
                addr <= i;
                wrdata <= sj;
                wren <= 1'b1;
                state <= ADV_SI;
            end

            //advance i
            ADV_SI:begin
                wren <= 1'b0;
                if (i == 8'd255)
                    state <= DONE;
                else begin
                    i <= i + 8'd1;
                    state <= READ_SI;
                end
            end

            DONE: begin
                wren <= 1'b0;
                state <= WAIT;
            end
        endcase
    end
end

endmodule: ksa
