module task3(input logic CLOCK_50, input logic [3:0] KEY, input logic [9:0] SW,
             output logic [6:0] HEX0, output logic [6:0] HEX1, output logic [6:0] HEX2,
             output logic [6:0] HEX3, output logic [6:0] HEX4, output logic [6:0] HEX5,
             output logic [9:0] LEDR);

    logic [7:0] ct_addr, pt_addr;
    logic [7:0] ct_rddata, pt_rddata, pt_wrdata;
    logic pt_wren;
    logic rdy;
    logic en;
    logic started;
    logic [23:0] key;

    // For task 3, the top 14 key bits are hardwired to 0 and SW drives key[9:0].
    assign key = {14'b0, SW[9:0]};

    ct_mem ct( 
        .address(ct_addr),
        .clock(CLOCK_50),
        .data(8'd0),
        .wren(1'b0),
        .q(ct_rddata)
     );

    pt_mem pt( 
        .address(pt_addr),
        .clock(CLOCK_50),
        .data(pt_wrdata),
        .wren(pt_wren),
        .q(pt_rddata)
    
     );
    arc4 a4( 
        .clk(CLOCK_50),
        .rst_n(KEY[3]),
        .en(en),
        .rdy(rdy),
        .key(key),
        .ct_addr(ct_addr),
        .ct_rddata(ct_rddata),
        .pt_addr(pt_addr),
        .pt_rddata(pt_rddata),
        .pt_wrdata(pt_wrdata),
        .pt_wren(pt_wren)
     );

    always_ff @(posedge CLOCK_50 or negedge KEY[3]) begin
        if (!KEY[3]) begin
            en <= 1'b0;
            started <= 1'b0;
        end
        else begin
            en <= 1'b0;
            // Pulse en once after reset so arc4 runs exactly one decryption pass.
            if (!started && rdy) begin
                en <= 1'b1;
                started <= 1'b1;
            end
            else begin
                en <= 1'b0;
            end
        end
    end

    // Show when arc4 is idle / finished.
    assign LEDR[0] = rdy;

endmodule: task3
