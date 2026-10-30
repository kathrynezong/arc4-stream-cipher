`timescale 1ps / 1ps

module tb_syn_arc4();

    logic clk, rst_n, en, rdy;
    logic [23:0] key;
    logic [7:0] ct_addr, ct_rddata;
    logic [7:0] pt_addr, pt_rddata, pt_wrdata;
    logic pt_wren;
    logic checking_ct, checking_pt;
    logic [7:0] check_ct_addr, check_ct_data;
    logic check_ct_wren;
    logic [7:0] check_pt_addr, check_pt_data;
    logic check_pt_wren;
    logic [7:0] mem_ct_addr, mem_ct_data, mem_ct_q;
    logic mem_ct_wren;
    logic [7:0] mem_pt_addr, mem_pt_data, mem_pt_q;
    logic mem_pt_wren;

    always_comb begin
        mem_ct_addr = checking_ct ? check_ct_addr : ct_addr;
        mem_ct_data = checking_ct ? check_ct_data : 8'd0;
        mem_ct_wren = checking_ct ? check_ct_wren : 1'b0;
        ct_rddata = mem_ct_q;

        mem_pt_addr = checking_pt ? check_pt_addr : pt_addr;
        mem_pt_data = checking_pt ? check_pt_data : pt_wrdata;
        mem_pt_wren = checking_pt ? check_pt_wren : pt_wren;
        pt_rddata = mem_pt_q;
    end

    ct_mem ct(
        .address(mem_ct_addr),
        .clock(clk),
        .data(mem_ct_data),
        .wren(mem_ct_wren),
        .q(mem_ct_q)
    );

    pt_mem pt(
        .address(mem_pt_addr),
        .clock(clk),
        .data(mem_pt_data),
        .wren(mem_pt_wren),
        .q(mem_pt_q)
    );

    arc4 dut(
        .clk(clk),
        .rst_n(rst_n),
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

    logic [7:0] expected_pt [0:255];
    logic [7:0] ct_local [0:255];
    logic [7:0] s_ref [0:255];
    logic [7:0] pad_local [0:255];
    logic [7:0] key_byte;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic check_pt_value(input int addr, inout int errors, inout int correct);
        if (mem_pt_q !== expected_pt[addr]) begin
            $display("ERROR: pt_mem[%0h] = %0h, expected %0h", addr, mem_pt_q, expected_pt[addr]);
            errors++;
        end
        else begin
            $display("INFO: pt_mem[%0h] = %0h, expected %0h", addr, mem_pt_q, expected_pt[addr]);
            correct++;
        end
    endtask

    initial begin
        int correct;
        int errors;
        int last_addr;
        int timeout;
        logic [7:0] si_ref;
        logic [7:0] sj_ref;
        int i_idx;
        int j_idx;
        int length;
        correct = 0;
        errors = 0;
        last_addr = -1;
        key = 24'h000018;
        en = 1'b0;
        rst_n = 1'b0;
        checking_ct = 1'b0;
        checking_pt = 1'b0;
        check_ct_addr = 8'd0;
        check_ct_data = 8'd0;
        check_ct_wren = 1'b0;
        check_pt_addr = 8'd0;
        check_pt_data = 8'd0;
        check_pt_wren = 1'b0;

        $readmemh("../test_vectors/test2.memh", ct_local);
        for (int idx = 0; idx < 256; idx++) begin
            s_ref[idx] = idx[7:0];
            expected_pt[idx] = 8'd0;
            pad_local[idx] = 8'd0;
        end

        j_idx = 0;
        for (i_idx = 0; i_idx < 256; i_idx++) begin
            case (i_idx % 3)
                0: key_byte = key[23:16];
                1: key_byte = key[15:8];
                default: key_byte = key[7:0];
            endcase
            j_idx = (j_idx + s_ref[i_idx] + key_byte) % 256;
            {s_ref[i_idx], s_ref[j_idx]} = {s_ref[j_idx], s_ref[i_idx]};
        end

        length = ct_local[0];
        expected_pt[0] = ct_local[0];
        i_idx = 0;
        j_idx = 0;
        for (int k_idx = 1; k_idx <= length; k_idx++) begin
            i_idx = (i_idx + 1) % 256;
            j_idx = (j_idx + s_ref[i_idx]) % 256;
            si_ref = s_ref[i_idx];
            sj_ref = s_ref[j_idx];
            s_ref[i_idx] = sj_ref;
            s_ref[j_idx] = si_ref;
            pad_local[k_idx] = s_ref[(si_ref + sj_ref) % 256];
        end

        for (int k_idx = 1; k_idx <= length; k_idx++) begin
            expected_pt[k_idx] = ct_local[k_idx] ^ pad_local[k_idx];
        end

        checking_ct = 1'b1;
        for (int idx = 0; idx < 256; idx++) begin
            check_ct_addr = idx[7:0];
            check_ct_data = ct_local[idx];
            check_ct_wren = 1'b1;
            @(posedge clk);
        end
        check_ct_wren = 1'b0;
        checking_ct = 1'b0;

        checking_pt = 1'b1;
        for (int idx = 0; idx < 256; idx++) begin
            check_pt_addr = idx[7:0];
            check_pt_data = 8'd0;
            check_pt_wren = 1'b1;
            @(posedge clk);
        end
        check_pt_wren = 1'b0;
        checking_pt = 1'b0;

        repeat (2) @(posedge clk);
        rst_n = 1'b1;

        wait (rdy);
        en = 1'b1;
        @(posedge clk);
        en = 1'b0;

        @(negedge rdy);

        timeout = 0;
        while (!rdy && timeout < 6000) begin
            @(posedge clk);
            timeout++;
        end

        if (!rdy) begin
            $fatal(1, "ARC4 did not finish before timeout.");
        end

        checking_pt = 1'b1;
        check_pt_addr = 8'd0;
        @(posedge clk);
        last_addr = 8'd0;
        for (int idx = 1; idx <= expected_pt[0]; idx++) begin
            check_pt_addr = idx[7:0];
            @(posedge clk);
            check_pt_value(last_addr, errors, correct);
            last_addr = idx;
        end
        @(posedge clk);
        check_pt_value(last_addr, errors, correct);
        checking_pt = 1'b0;

        $display("Test completed. Correct: %0d, Errors: %0d", correct, errors);
        $finish;
    end
endmodule: tb_syn_arc4
