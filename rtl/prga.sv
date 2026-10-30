module prga(input logic clk, input logic rst_n,
            input logic en, output logic rdy,
            input logic [23:0] key,
            output logic [7:0] s_addr, input logic [7:0] s_rddata, output logic [7:0] s_wrdata, output logic s_wren,
            output logic [7:0] ct_addr, input logic [7:0] ct_rddata,
            output logic [7:0] pt_addr, input logic [7:0] pt_rddata, output logic [7:0] pt_wrdata, output logic pt_wren);

    logic [7:0] i, j, k;
    logic [7:0] si, sj;
    logic [7:0] pad;
    logic [7:0] message_length;
    logic [7:0] pad_index;

    typedef enum logic [4:0] {
        WAIT,
        READ_LEN,
        CAPTURE_LEN,
        WRITE_LEN,
        READ_SI,
        WAIT_SI,
        CAPTURE_SI,
        READ_SJ,
        CAPTURE_SJ,
        SWAP_I,
        SWAP_J,
        READ_PAD,
        WAIT_PAD,
        CAPTURE_PAD,
        READ_CT,
        WRITE_PT,
        CHECK_DONE,
        DONE
    } state_t;
    state_t state;

    always_comb begin
        rdy = (state == WAIT);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= WAIT;
            i <= 8'd0;
            j <= 8'd0;
            k <= 8'd1;
            si <= 8'd0;
            sj <= 8'd0;
            pad <= 8'd0;
            message_length <= 8'd0;
            pad_index <= 8'd0;
            s_addr <= 8'd0;
            s_wrdata <= 8'd0;
            s_wren <= 1'b0;
            ct_addr <= 8'd0;
            pt_addr <= 8'd0;
            pt_wrdata <= 8'd0;
            pt_wren <= 1'b0;
        end
        else begin
            case (state)
                WAIT: begin
                    s_wren <= 1'b0;
                    pt_wren <= 1'b0;
                    if (en) begin
                        i <= 8'd0;
                        j <= 8'd0;
                        k <= 8'd1;
                        ct_addr <= 8'd0;
                        state <= READ_LEN;
                    end
                    else begin
                        state <= WAIT;
                    end
                end

                READ_LEN: begin
                    // wait one cycle for ciphertext[0] to appear on ct_rddata
                    s_wren <= 1'b0;
                    pt_wren <= 1'b0;
                    state <= CAPTURE_LEN;
                end

                CAPTURE_LEN: begin
                    // capture the length byte and copy to plaintext[0]
                    message_length <= ct_rddata;
                    pt_addr <= 8'd0;
                    pt_wrdata <= ct_rddata;
                    state <= WRITE_LEN;
                end

                WRITE_LEN: begin
                    pt_wren <= 1'b1;
                    if (message_length == 8'd0) begin
                        state <= DONE;
                    end
                    else begin
                        state <= READ_SI;
                    end
                end

                READ_SI: begin
                    // increment i mod 256 and get S[i] from memory
                    // because i is 8 bits, overflow is dropped automatically
                    pt_wren <= 1'b0;
                    s_wren <= 1'b0;
                    i <= i + 8'd1;
                    s_addr <= i + 8'd1;
                    state <= WAIT_SI;
                end

                WAIT_SI: begin
                    // wait one cycle for S[i] to appear on s_rddata
                    state <= CAPTURE_SI;
                end

                CAPTURE_SI: begin
                    // capture S[i], update j mod 256, and get S[j]
                    // because j is 8 bits, the addition wraps around automatically
                    si <= s_rddata;
                    j <= j + s_rddata;
                    s_addr <= j + s_rddata;
                    state <= READ_SJ;
                end

                READ_SJ: begin
                    state <= CAPTURE_SJ;
                end

                CAPTURE_SJ: begin
                    // capture S[j] so S[i] and S[j] can be swapped
                    sj <= s_rddata;
                    state <= SWAP_I;
                end

                SWAP_I: begin
                    s_addr <= i;
                    s_wrdata <= sj;
                    s_wren <= 1'b1;
                    state <= SWAP_J;
                end

                SWAP_J: begin
                    // finish swap, then request S[S[i] + S[j]] for the pad byte.
                    // pad_index is 8 bits, so si + sj is implicitly mod 256.
                    s_addr <= j;
                    s_wrdata <= si;
                    s_wren <= 1'b1;
                    pad_index <= si + sj;
                    state <= READ_PAD;
                end

                READ_PAD: begin
                    // request S[S[i] + S[j]] for the pad byte
                    s_wren <= 1'b0;
                    s_addr <= pad_index;
                    state <= WAIT_PAD;
                end

                WAIT_PAD: begin
                    // wait one cycle for the pad byte to appear on s_rddata
                    state <= CAPTURE_PAD;
                end

                CAPTURE_PAD: begin
                    // capture the keystream byte and request ciphertext[k]
                    pad <= s_rddata;
                    ct_addr <= k;
                    state <= READ_CT;
                end

                READ_CT: begin
                    state <= WRITE_PT;
                end

                WRITE_PT: begin
                    // decrypt one byte: plaintext[k] = ciphertext[k] xor pad
                    pt_addr <= k;
                    pt_wrdata <= pad ^ ct_rddata;
                    pt_wren <= 1'b1;
                    state <= CHECK_DONE;
                end

                CHECK_DONE: begin
                    pt_wren <= 1'b0;
                    if (k == message_length) begin
                        state <= DONE;
                    end
                    else begin
                        k <= k + 8'd1;
                        state <= READ_SI;
                    end
                end

                DONE: begin
                    s_wren <= 1'b0;
                    pt_wren <= 1'b0;
                    state <= WAIT;
                end

                default: begin
                    state <= WAIT;
                end
            endcase
        end
    end

endmodule: prga

/**
i = 0, j = 0
message_length = ciphertext[0]
for k = 1 to message_length:
    i = (i+1) mod 256
    j = (j+s[i]) mod 256
    swap values of s[i] and s[j]
    pad[k] = s[(s[i]+s[j]) mod 256]

plaintext[0] = message_length
for k = 1 to message_length:
    plaintext[k] = pad[k] xor ciphertext[k]
*/