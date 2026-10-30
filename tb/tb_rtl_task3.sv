`timescale 1ps / 1ps

module tb_rtl_task3();

    logic CLOCK_50;
    logic [3:0] KEY;
    logic [9:0] SW;
    logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    logic [9:0] LEDR;

    logic [7:0] expected_pt [0:255];
    logic [7:0] ct_local [0:255];
    logic [7:0] s_ref [0:255];
    logic [7:0] pad_local [0:255];
    logic [7:0] key_byte;

    task3 dut(
        .CLOCK_50(CLOCK_50),
        .KEY(KEY),
        .SW(SW),
        .HEX0(HEX0),
        .HEX1(HEX1),
        .HEX2(HEX2),
        .HEX3(HEX3),
        .HEX4(HEX4),
        .HEX5(HEX5),
        .LEDR(LEDR)
    );

    initial CLOCK_50 = 1'b0;
    always #5 CLOCK_50 = ~CLOCK_50;

    initial begin
        int correct;
        int errors;
        int timeout;
        logic [7:0] si_ref;
        logic [7:0] sj_ref;
        int i_idx;
        int j_idx;
        int length;
        correct = 0;
        errors = 0;
        KEY = 4'b1111;
        SW = 10'h018;

        $readmemh("../test_vectors/test2.memh", ct_local);
        for (int idx = 0; idx < 256; idx++) begin
            s_ref[idx] = idx[7:0];
            expected_pt[idx] = 8'd0;
            pad_local[idx] = 8'd0;
        end

        j_idx = 0;
        for (i_idx = 0; i_idx < 256; i_idx++) begin
            case (i_idx % 3)
                0: key_byte = 8'h00;
                1: key_byte = 8'h00;
                default: key_byte = 8'h18;
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

        $readmemh("../test_vectors/test2.memh", dut.ct.altsyncram_component.m_default.altsyncram_inst.mem_data);
        for (int idx = 0; idx < 256; idx++) begin
            dut.pt.altsyncram_component.m_default.altsyncram_inst.mem_data[idx] = 8'd0;
        end

        KEY[3] = 1'b0;
        repeat (2) @(posedge CLOCK_50);
        KEY[3] = 1'b1;

        @(negedge LEDR[0]);

        timeout = 0;
        while (!LEDR[0] && timeout < 6000) begin
            @(posedge CLOCK_50);
            timeout++;
        end

        if (!LEDR[0]) begin
            $fatal(1, "task3 did not finish before timeout.");
        end

        for (int idx = 0; idx <= expected_pt[0]; idx++) begin
            logic [7:0] mem_val;
            mem_val = dut.pt.altsyncram_component.m_default.altsyncram_inst.mem_data[idx];
            if (mem_val !== expected_pt[idx]) begin
                $display("ERROR: pt_mem[%0h] = %0h, expected %0h",
                    idx,
                    mem_val,
                    expected_pt[idx]);
                errors++;
            end
            else begin
                $display("INFO: pt_mem[%0h] = %0h, expected %0h",
                    idx,
                    mem_val,
                    expected_pt[idx]);
                correct++;
            end
        end

        $display("Test completed. Correct: %0d, Errors: %0d", correct, errors);
        if (errors == 0) begin
            $display("task3 test passed.");
        end
        else begin
            $fatal(1, "task3 test failed with %0d mismatches.", errors);
        end
        $finish;
    end

endmodule: tb_rtl_task3
