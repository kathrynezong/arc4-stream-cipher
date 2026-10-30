`include "../rtl/init.sv"
`include "../rtl/ksa.sv"

module arc4(input logic clk, input logic rst_n,
            input logic en, output logic rdy,
            input logic [23:0] key,
            output logic [7:0] ct_addr, input logic [7:0] ct_rddata,
            output logic [7:0] pt_addr, input logic [7:0] pt_rddata, output logic [7:0] pt_wrdata, output logic pt_wren);

    logic init_en, init_rdy;
    logic [7:0] init_addr, init_wrdata;
    logic init_wren;

    logic ksa_en, ksa_rdy;
    logic [7:0] ksa_addr, ksa_rddata, ksa_wrdata;
    logic ksa_wren;

    logic prga_en, prga_rdy;
    logic [7:0] prga_s_addr, prga_s_rddata, prga_s_wrdata;
    logic prga_s_wren;

    logic [7:0] s_addr, s_wrdata, s_rddata;
    logic s_wren;

    typedef enum logic [2:0] {
        WAIT,
        START_INIT,
        RUN_INIT,
        START_KSA,
        RUN_KSA,
        START_PRGA,
        RUN_PRGA
    } state_t;
    state_t state;

    always_comb begin
        rdy = (state == WAIT);
    end

    s_mem s( 
        .address(s_addr),
        .clock(clk),
        .data(s_wrdata),
        .wren(s_wren),
        .q(s_rddata)
     );

    init i( 
        .clk(clk),
        .rst_n(rst_n),
        .en(init_en),
        .rdy(init_rdy),
        .addr(init_addr),
        .wrdata(init_wrdata),
        .wren(init_wren)
     );
    ksa k( 
        .clk(clk),
        .rst_n(rst_n),
        .en(ksa_en),
        .rdy(ksa_rdy),
        .key(key),
        .addr(ksa_addr),
        .rddata(ksa_rddata),
        .wrdata(ksa_wrdata),
        .wren(ksa_wren)
     );
    prga p( 
        .clk(clk),
        .rst_n(rst_n),
        .en(prga_en),
        .rdy(prga_rdy),
        .key(key),
        .s_addr(prga_s_addr),
        .s_rddata(prga_s_rddata),
        .s_wrdata(prga_s_wrdata),
        .s_wren(prga_s_wren),
        .ct_addr(ct_addr),
        .ct_rddata(ct_rddata),
        .pt_addr(pt_addr),
        .pt_rddata(pt_rddata),
        .pt_wrdata(pt_wrdata),
        .pt_wren(pt_wren)
     );

    assign ksa_rddata = s_rddata;
    assign prga_s_rddata = s_rddata;

    always_comb begin
        init_en = 1'b0;
        ksa_en = 1'b0;
        prga_en = 1'b0;

        s_addr = 8'd0;
        s_wrdata = 8'd0;
        s_wren = 1'b0;

        case (state)
            START_INIT, RUN_INIT: begin
                init_en = (state == START_INIT);
                s_addr = init_addr;
                s_wrdata = init_wrdata;
                s_wren = init_wren;
            end
            START_KSA, RUN_KSA: begin
                ksa_en = (state == START_KSA);
                s_addr = ksa_addr;
                s_wrdata = ksa_wrdata;
                s_wren = ksa_wren;
            end
            START_PRGA, RUN_PRGA: begin
                prga_en = (state == START_PRGA);
                s_addr = prga_s_addr;
                s_wrdata = prga_s_wrdata;
                s_wren = prga_s_wren;
            end
            default: begin
            end
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= WAIT;
        end
        else begin
            case (state)
                WAIT: begin
                    if (en) begin
                        state <= START_INIT;
                    end
                    else begin
                        state <= WAIT;
                    end
                end

                START_INIT: begin
                    state <= RUN_INIT;
                end

                RUN_INIT: begin
                    if (init_rdy) begin
                        state <= START_KSA;
                    end
                end

                START_KSA: begin
                    state <= RUN_KSA;
                end

                RUN_KSA: begin
                    if (ksa_rdy) begin
                        state <= START_PRGA;
                    end
                end

                START_PRGA: begin
                    state <= RUN_PRGA;
                end

                RUN_PRGA: begin
                    if (prga_rdy) begin
                        state <= WAIT;
                    end
                end

                default: begin
                    state <= WAIT;
                end
            endcase
        end
    end

endmodule: arc4
