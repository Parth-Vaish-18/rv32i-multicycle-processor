`timescale 1ns/1ps

module riscv_testbench;

    reg clk;
    reg reset;
    
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wmask;
    wire [31:0] mem_rdata;
    wire        mem_rstrb;
    reg         mem_rbusy;
    reg         mem_wbusy;
    
    reg [31:0] memory [0:4095];
    
    integer test_num;
    integer passed_tests;
    integer total_tests;
    integer cycle_count;
    integer i;
    
    riscv_processor #(
        .RESET_ADDR(32'h00000000),
        .ADDR_WIDTH(32)
    ) uut (
        .clk(clk),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wmask(mem_wmask),
        .mem_rdata(mem_rdata),
        .mem_rstrb(mem_rstrb),
        .mem_rbusy(mem_rbusy),
        .mem_wbusy(mem_wbusy),
        .reset(reset)
    );
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    reg [31:0] read_data;
    
    always @(posedge clk) begin
        if (mem_rstrb) begin
            read_data <= memory[mem_addr[31:2]];
        end
    end
    
    assign mem_rdata = read_data;
    
    always @(posedge clk) begin
        if (mem_wmask != 4'b0000) begin
            if (mem_wmask[0]) memory[mem_addr[31:2]][7:0]   <= mem_wdata[7:0];
            if (mem_wmask[1]) memory[mem_addr[31:2]][15:8]  <= mem_wdata[15:8];
            if (mem_wmask[2]) memory[mem_addr[31:2]][23:16] <= mem_wdata[23:16];
            if (mem_wmask[3]) memory[mem_addr[31:2]][31:24] <= mem_wdata[31:24];
        end
    end
    
    always @(*) begin
        mem_rbusy = 0;
        mem_wbusy = 0;
    end
    
    always @(posedge clk) begin
        if (!reset)
            cycle_count <= 0;
        else
            cycle_count <= cycle_count + 1;
    end
    
    task init_memory;
        begin
            for (i = 0; i < 4096; i = i + 1) begin
                memory[i] = 32'h00000013;
            end
        end
    endtask
    
    task reset_processor;
        begin
            reset = 0;
            @(posedge clk);
            @(posedge clk);
            reset = 1;
            cycle_count = 0;
        end
    endtask
    
    task run_cycles;
        input integer num_cycles;
        integer k;
        begin
            for (k = 0; k < num_cycles; k = k + 1) begin
                @(posedge clk);
            end
        end
    endtask
    
    task wait_for_pc;
        input [31:0] target_pc;
        input integer max_cycles;
        integer j;
        begin
            for (j = 0; j < max_cycles; j = j + 1) begin
                @(posedge clk);
                if (mem_addr == target_pc && mem_rstrb) begin
                    j = max_cycles;
                end
            end
        end
    endtask
    
    task check_result;
        input [31:0] addr;
        input [31:0] expected;
        input [200*8:1] test_name;
        begin
            total_tests = total_tests + 1;
            if (memory[addr[31:2]] === expected) begin
                $display("[PASS] Test %0d: %s", test_num, test_name);
                $display("       Expected: 0x%08h, Got: 0x%08h", expected, memory[addr[31:2]]);
                passed_tests = passed_tests + 1;
            end else begin
                $display("[FAIL] Test %0d: %s", test_num, test_name);
                $display("       Expected: 0x%08h, Got: 0x%08h", expected, memory[addr[31:2]]);
            end
        end
    endtask
    
    // Test 1: Basic Arithmetic
    task test_basic_arithmetic;
        begin
            test_num = 1;
            $display("\n========================================");
            $display("Test 1: Basic Arithmetic Operations");
            $display("========================================");
            
            init_memory();
            
            memory[0] = 32'h00A00093;  // ADDI x1, x0, 10
            memory[1] = 32'h00400113;  // ADDI x2, x0, 4
            memory[2] = 32'h002081B3;  // ADD x3, x1, x2
            memory[3] = 32'h40208233;  // SUB x4, x1, x2
            memory[4] = 32'h00302023;  // SW x3, 0(x0)
            memory[5] = 32'h00402223;  // SW x4, 4(x0)
            memory[6] = 32'h0180006F;  // JAL x0, 24 (halt)
            
            reset_processor();
            wait_for_pc(32'd24, 200);
            
            check_result(32'h00000000, 32'h0000000E, "ADD result (10+4=14)");
            check_result(32'h00000004, 32'h00000006, "SUB result (10-4=6)");
        end
    endtask
    
    // Test 2: Logical Operations
    task test_logical_operations;
        begin
            test_num = 2;
            $display("\n========================================");
            $display("Test 2: Logical Operations");
            $display("========================================");
            
            init_memory();
            
            memory[0] = 32'h0AA00093;  // ADDI x1, x0, 0x0AA
            memory[1] = 32'h05500113;  // ADDI x2, x0, 0x055
            memory[2] = 32'h0020F1B3;  // AND x3, x1, x2 (Corrected from buggy original)
            memory[3] = 32'h0020E233;  // OR x4, x1, x2
            memory[4] = 32'h0020C2B3;  // XOR x5, x1, x2
            memory[5] = 32'h00302023;  // SW x3, 0(x0)
            memory[6] = 32'h00402223;  // SW x4, 4(x0)
            memory[7] = 32'h00502423;  // SW x5, 8(x0)
            memory[8] = 32'h0200006F;  // JAL x0, 32 (halt)
            
            reset_processor();
            wait_for_pc(32'd32, 200);
            
            check_result(32'h00000000, 32'h00000000, "AND result");
            check_result(32'h00000004, 32'h000000FF, "OR result");
            check_result(32'h00000008, 32'h000000FF, "XOR result");
        end
    endtask
    
    // Test 3: Load and Store
    task test_load_store;
        begin
            test_num = 3;
            $display("\n========================================");
            $display("Test 3: Load and Store Operations");
            $display("========================================");
            
            init_memory();
            
            memory[256] = 32'h11223344;
            memory[257] = 32'h55667788;
            
            memory[0] = 32'h40000093;  // ADDI x1, x0, 1024
            memory[1] = 32'h0000A103;  // LW x2, 0(x1)
            memory[2] = 32'h0040A183;  // LW x3, 4(x1)
            memory[3] = 32'h003101B3;  // ADD x3, x2, x3
            memory[4] = 32'h00302023;  // SW x3, 0(x0)
            memory[5] = 32'h00202223;  // SW x2, 4(x0)
            memory[6] = 32'h0180006F;  // JAL x0, 24 (halt)
            
            reset_processor();
            wait_for_pc(32'd24, 200);
            
            check_result(32'h00000000, 32'h6688AACC, "ADD after loads");
            check_result(32'h00000004, 32'h11223344, "Loaded value stored");
        end
    endtask
    
    // Test 4: Branches
    task test_branches;
        begin
            test_num = 4;
            $display("\n========================================");
            $display("Test 4: Branch Instructions");
            $display("========================================");
            
            init_memory();
            
            memory[0]  = 32'h00A00093;  // ADDI x1, x0, 10
            memory[1]  = 32'h00A00113;  // ADDI x2, x0, 10
            memory[2]  = 32'h00200193;  // ADDI x3, x0, 2
            memory[3]  = 32'h00208463;  // BEQ x1, x2, 8 (branches)
            memory[4]  = 32'h06300213;  // ADDI x4, x0, 99
            memory[5]  = 32'h06300213;  // ADDI x4, x0, 99
            memory[6]  = 32'h04D00213;  // ADDI x4, x0, 77
            memory[7]  = 32'h00309463;  // BNE x1, x3, 8 (branches)
            memory[8]  = 32'h06300293;  // ADDI x5, x0, 99
            memory[9]  = 32'h06300293;  // ADDI x5, x0, 99
            memory[10] = 32'h05800293;  // ADDI x5, x0, 88
            memory[11] = 32'h0030C463;  // BLT x1, x3, 8 (10 < 2 = False, DOES NOT branch)
            memory[12] = 32'h02100313;  // ADDI x6, x0, 33 (executes)
            memory[13] = 32'h00402023;  // SW x4, 0(x0)
            memory[14] = 32'h00502223;  // SW x5, 4(x0)
            memory[15] = 32'h00602423;  // SW x6, 8(x0)
            memory[16] = 32'h0400006F;  // JAL x0, 64 (halt)
            
            reset_processor();
            wait_for_pc(32'd64, 300);
            
            check_result(32'h00000000, 32'h0000004D, "BEQ branch taken (77)");
            check_result(32'h00000004, 32'h00000058, "BNE branch taken (88)");
            check_result(32'h00000008, 32'h00000021, "BLT not taken (33)");
        end
    endtask
    
    // Test 5: JAL and JALR
    task test_jumps;
        begin
            test_num = 5;
            $display("\n========================================");
            $display("Test 5: Jump Instructions (JAL, JALR)");
            $display("========================================");
            
            init_memory();
            
            memory[0] = 32'h00C000EF;  // JAL x1, 12
            memory[1] = 32'h00000013;  // NOP
            memory[2] = 32'h00000013;  // NOP
            memory[3] = 32'h00F00093;  // ADDI x1, x0, 15
            memory[4] = 32'h01900113;  // ADDI x2, x0, 25
            memory[5] = 32'h00208133;  // ADD x2, x1, x2
            memory[6] = 32'h00202023;  // SW x2, 0(x0)
            memory[7] = 32'h0200006F;  // JAL x0, 32 (halt)
            
            reset_processor();
            wait_for_pc(32'd32, 200);
            
            check_result(32'h00000000, 32'h00000028, "JAL and arithmetic (40)");
        end
    endtask
    
    // Test 6: LUI and AUIPC
    task test_upper_imm;
        begin
            test_num = 6;
            $display("\n========================================");
            $display("Test 6: Upper Immediate (LUI, AUIPC)");
            $display("========================================");
            
            init_memory();
            
            memory[0] = 32'hABCDE0B7;  // LUI x1, 0xABCDE
            memory[1] = 32'h12308093;  // ADDI x1, x1, 0x123 (Corrected from buggy original)
            memory[2] = 32'h00102023;  // SW x1, 0(x0)
            memory[3] = 32'h0100006F;  // JAL x0, 16 (halt)
            
            reset_processor();
            wait_for_pc(32'd16, 200);
            
            check_result(32'h00000000, 32'hABCDE123, "LUI with ADDI");
        end
    endtask
    
    // Test 7: Shifts
    task test_shifts;
        begin
            test_num = 7;
            $display("\n========================================");
            $display("Test 7: Shift Operations");
            $display("========================================");
            
            init_memory();
            
            memory[0] = 32'h01000093;  // ADDI x1, x0, 16
            memory[1] = 32'h00300113;  // ADDI x2, x0, 3
            memory[2] = 32'h002091B3;  // SLL x3, x1, x2 (16 << 3 = 128)
            memory[3] = 32'h0020D233;  // SRL x4, x1, x2 (16 >> 3 = 2)
            memory[4] = 32'h00302023;  // SW x3, 0(x0)
            memory[5] = 32'h00402223;  // SW x4, 4(x0)
            memory[6] = 32'h0180006F;  // JAL x0, 24 (halt)
            
            reset_processor();
            wait_for_pc(32'd24, 400); 
            
            check_result(32'h00000000, 32'h00000080, "SLL result (128)");
            check_result(32'h00000004, 32'h00000002, "SRL result (2)");
        end
    endtask
    
    // Test 8: Simple Loop
    task test_loop;
        begin
            test_num = 8;
            $display("\n========================================");
            $display("Test 8: Loop - Sum from 1 to 4");
            $display("========================================");
            
            init_memory();
            
            memory[0] = 32'h00000093;  // ADDI x1, x0, 0
            memory[1] = 32'h00100113;  // ADDI x2, x0, 1
            memory[2] = 32'h00500193;  // ADDI x3, x0, 5
            memory[3] = 32'h002080B3;  // loop: ADD x1, x1, x2
            memory[4] = 32'h00110113;  // ADDI x2, x2, 1
            memory[5] = 32'hFE314CE3;  // BLT x2, x3, -8
            memory[6] = 32'h00102023;  // SW x1, 0(x0)
            memory[7] = 32'h01C0006F;  // JAL x0, 28 (halt)
            
            reset_processor();
            wait_for_pc(32'd28, 500);
            
            check_result(32'h00000000, 32'h0000000A, "Sum 1 to 4 = 10");
        end
    endtask
    
    // Test 9: Byte and Halfword
    task test_byte_halfword;
        begin
            test_num = 9;
            $display("\n========================================");
            $display("Test 9: Byte and Halfword Access");
            $display("========================================");
            
            init_memory();
            
            memory[256] = 32'h00000000;
            
            memory[0] = 32'h40000093;  // ADDI x1, x0, 1024
            memory[1] = 32'h0CD00113;  // ADDI x2, x0, 0xCD
            memory[2] = 32'h00208023;  // SB x2, 0(x1)
            memory[3] = 32'h45600113;  // ADDI x2, x0, 0x456
            memory[4] = 32'h00209123;  // SH x2, 2(x1)
            memory[5] = 32'h0000A183;  // LW x3, 0(x1)
            memory[6] = 32'h00302023;  // SW x3, 0(x0)
            memory[7] = 32'h01C0006F;  // JAL x0, 28 (halt)
            
            reset_processor();
            wait_for_pc(32'd28, 200);
            
            check_result(32'h00000000, 32'h045600CD, "Byte and halfword store");
        end
    endtask
    
    // Test 10: Set Less Than
    task test_slt;
        begin
            test_num = 10;
            $display("\n========================================");
            $display("Test 10: Set Less Than");
            $display("========================================");
            
            init_memory();
            
            memory[0] = 32'h00F00093;  // ADDI x1, x0, 15
            memory[1] = 32'h01900113;  // ADDI x2, x0, 25
            memory[2] = 32'h0020A1B3;  // SLT x3, x1, x2 (15 < 25 = 1)
            memory[3] = 32'h00112233;  // SLT x4, x2, x1 (25 < 15 = 0)
            memory[4] = 32'h0190A293;  // SLTI x5, x1, 25 (15 < 25 = 1)
            memory[5] = 32'h00302023;  // SW x3, 0(x0)
            memory[6] = 32'h00402223;  // SW x4, 4(x0)
            memory[7] = 32'h00502423;  // SW x5, 8(x0)
            memory[8] = 32'h0200006F;  // JAL x0, 32 (halt)
            
            reset_processor();
            wait_for_pc(32'd32, 200);
            
            check_result(32'h00000000, 32'h00000001, "SLT (15<25=1)");
            check_result(32'h00000004, 32'h00000000, "SLT (25<15=0)");
            check_result(32'h00000008, 32'h00000001, "SLTI (15<25=1)");
        end
    endtask
    
    initial begin
        $display("========================================");
        $display("RISC-V Processor Testbench");
        $display("========================================");
        
        passed_tests = 0;
        total_tests = 0;
        test_num = 0;
        
        mem_rbusy = 0;
        mem_wbusy = 0;
        
        test_basic_arithmetic();
        test_logical_operations();
        test_load_store();
        test_branches();
        test_jumps();
        test_upper_imm();
        test_shifts();
        test_loop();
        test_byte_halfword();
        test_slt();
        
        $display("\n========================================");
        $display("TEST SUMMARY");
        $display("========================================");
        $display("Passed: %0d/%0d tests", passed_tests, total_tests);
        $display("Score: %0d%%", (passed_tests * 100) / total_tests);
        $display("========================================\n");
        
        if (passed_tests == total_tests) begin
            $display("*** ALL TESTS PASSED ***");
        end else begin
            $display("*** SOME TESTS FAILED ***");
        end
        
        $finish;
    end
    
    initial begin
        #500000;
        $display("\n[ERROR] Simulation timeout - processor may be stuck");
        $display("Passed: %0d/%0d tests before timeout", passed_tests, total_tests);
        $finish;
    end

endmodule