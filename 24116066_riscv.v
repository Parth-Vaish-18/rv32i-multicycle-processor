module riscv_processor #(
    parameter RESET_ADDR=32'h00000000,
    parameter ADDR_WIDTH=32
)(
    input clk,
    output reg [31:0] mem_addr,
    output reg [31:0] mem_wdata,
    output reg [3:0] mem_wmask,
    input [31:0] mem_rdata,
    output reg mem_rstrb,
    input mem_rbusy,
    input mem_wbusy,
    input reset
);
    reg [31:0] pc;
    reg [31:0] registers [0:31];
    reg [31:0] instr;
    reg [3:0] state;

    wire [6:0] opcode =instr[6:0];
    wire [4:0] rd =instr[11:7];
    wire [2:0] funct3 =instr[14:12];
    wire [4:0] rs1 =instr[19:15];
    wire [4:0] rs2 =instr[24:20];
    wire [6:0] funct7 =instr[31:25];

    wire [31:0] imm_I ={{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_S ={{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] imm_B ={{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [31:0] imm_J ={{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
    wire [31:0] imm_U ={instr[31:12], 12'b0};

    wire [31:0] load_addr =registers[rs1]+ imm_I;
    wire [31:0] store_addr =registers[rs1]+ imm_S;
    wire [1:0] load_align =load_addr[1:0];
    wire [1:0] store_align =store_addr[1:0];
    
    wire [31:0] load_shift_data =mem_rdata>> {load_align, 3'b000};
    reg [31:0] formatted_load_data;
    
    always @(*) begin
        case (funct3)
            3'b000: formatted_load_data ={{24{load_shift_data[7]}}, load_shift_data[7:0]};
            3'b001: formatted_load_data ={{16{load_shift_data[15]}}, load_shift_data[15:0]};
            3'b010: formatted_load_data =load_shift_data;
            3'b100: formatted_load_data ={24'd0, load_shift_data[7:0]};
            3'b101: formatted_load_data ={16'd0, load_shift_data[15:0]};
            default: formatted_load_data =load_shift_data;
        endcase
    end
  
    integer i;
      always @(posedge clk) begin
        if (!reset) begin
            pc <=RESET_ADDR;
            state <=0;
            mem_rstrb <=0;
            mem_wmask <=0;
            for(i=0;i<32;i=i+1) registers[i] <=0;
        end else begin
            case (state)
                0: begin
                    mem_addr <=pc;
                    mem_rstrb <=1;
                    state <=1;
                end  
                1: begin
                    if (!mem_rbusy) state <=2;
                end                
                2: begin
                    instr <=mem_rdata;
                    mem_rstrb <=0;
                    state <=3;
                end                
                3: begin
                    case (opcode)
                        7'b0110111: begin
                            if (rd!=0) registers[rd] <=imm_U;
                            pc <=pc+4; state <=0;
                        end
                        7'b0010111: begin
                            if (rd!=0) registers[rd] <=pc+imm_U;
                            pc <=pc+4; state <=0;
                        end
                        7'b1101111: begin
                            if (rd!=0) registers[rd] <=pc+4;
                            pc <=pc+imm_J; state <=0;
                        end
                        7'b1100111: begin
                            if (rd!=0) registers[rd] <=pc+4;
                            pc <=(registers[rs1]+imm_I) & 32'hFFFFFFFE; state <=0;
                        end
                        7'b1100011: begin
                            case (funct3)
                                3'b000: if (registers[rs1] ==registers[rs2]) pc <=pc+imm_B; else pc <=pc+4;
                                3'b001: if (registers[rs1] !=registers[rs2]) pc <=pc+imm_B; else pc <=pc+4;
                                3'b100: if ($signed(registers[rs1]) <$signed(registers[rs2])) pc <=pc+imm_B; else pc <=pc+4;
                                3'b101: if ($signed(registers[rs1]) >=$signed(registers[rs2])) pc <=pc+imm_B; else pc <=pc+4;
                                3'b110: if (registers[rs1] <registers[rs2]) pc <=pc+imm_B; else pc <=pc+4;
                                3'b111: if (registers[rs1] >=registers[rs2]) pc <=pc+imm_B; else pc <=pc+4;
                                default: pc <=pc+4;
                            endcase
                            state <=0;
                        end
                        7'b0000011: begin
                            mem_addr <={load_addr[31:2], 2'b00};
                            mem_rstrb <=1;
                            state <=4; 
                        end
                        7'b0100011: begin
                            mem_addr <={store_addr[31:2], 2'b00};
                            case (funct3)
                                3'b000: begin
                                    mem_wdata <=registers[rs2] <<{store_align, 3'b000};
                                    mem_wmask <=4'b0001 <<store_align;
                                end
                                3'b001: begin
                                    mem_wdata <=registers[rs2] <<{store_align, 3'b000};
                                    mem_wmask <=4'b0011 <<store_align;
                                end
                                3'b010: begin
                                    mem_wdata <=registers[rs2];
                                    mem_wmask <=4'b1111;
                                end
                            endcase
                            state <=6; 
                        end
                        7'b0010011: begin
                            if (rd!=0) begin
                                case (funct3)
                                  3'b000: registers[rd] <=registers[rs1]+imm_I;
                                  3'b010: registers[rd] <=($signed(registers[rs1])<$signed(imm_I))?1:0;
                                    3'b011: registers[rd] <=(registers[rs1]<imm_I)?1:0;
                                    3'b100: registers[rd] <=registers[rs1]^imm_I;
                                    3'b110: registers[rd] <=registers[rs1]|imm_I;
                                    3'b111: registers[rd] <=registers[rs1]&imm_I;
                                    3'b001: registers[rd] <=registers[rs1]<<imm_I[4:0];
                                    3'b101: registers[rd] <=(funct7[5])?($signed(registers[rs1])>>>imm_I[4:0]):(registers[rs1]>>imm_I[4:0]);
                                endcase
                            end
                            pc <=pc+4; state <=0;
                        end
                        7'b0110011: begin
                            if (rd!=0) begin
                                case (funct3)
                                    3'b000: registers[rd] <=(funct7[5])?(registers[rs1]-registers[rs2]):(registers[rs1]+registers[rs2]);
                                    3'b001: registers[rd] <=registers[rs1]<<registers[rs2][4:0];
                                    3'b010: registers[rd] <=($signed(registers[rs1])<$signed(registers[rs2]))?1:0;
                                    3'b011: registers[rd] <=(registers[rs1]<registers[rs2])?1:0;
                                    3'b100: registers[rd] <=registers[rs1]^registers[rs2];
                                    3'b101: registers[rd] <=(funct7[5])?($signed(registers[rs1])>>>registers[rs2][4:0]): (registers[rs1]>>registers[rs2][4:0]);
                                    3'b110: registers[rd] <=registers[rs1]|registers[rs2];
                                    3'b111: registers[rd] <=registers[rs1]&registers[rs2];
                                endcase
                            end
                            pc <=pc+4; state <=0;
                        end
                        default: begin
                            pc <=pc+4; state <=0;
                        end
                    endcase
                end                
                4: begin
                    if (!mem_rbusy) state <=5;
                end                
                5: begin
                    if (rd!=0) registers[rd]<=formatted_load_data;
                    mem_rstrb <=0;
                    pc <= pc+4;
                    state <=0;
                end
                6: begin
                    if (!mem_wbusy) state <=7;
                end                
                7: begin
                    mem_wmask <=0;
                    pc <=pc+4;
                    state <=0;
                end
            endcase
        end
    end
endmodule
/* ============================================================================
   Code Explanation:

   # Core Design:
   It is a 32-bit RV32I RISC-V processor. I made it as an 8-state Multi-cycle Finite State Machine. 
   It is used to handle the memory interface requirements (mem_rbusy and mem_wbusy). 
   This design safely pauses the execution to wait for memory reads/writes to finish without skipping instructions.

   # FSM States:
   - States 0-2 (Fetch): Requests the PC address and waits for memory to reply.
   - State 3 (Execute): Decodes the instruction, runs the ALU, and resolves branches.
   - States 4-5 (Load): Waits for memory read and saves data to the register.
   - States 6-7 (Store): Waits for memory write to finish and clears the mask.

   # Key Features:
   - Instruction Decoding: Opcode, registers, and immediates are extracted dynamically.
   - Uses bit-shifting based on the address's bottom 2 bits to cleanly handle byte (SB/LB) and halfword (SH/LH) memory access.
   - Standard RV32I base integer instructions including R-type, I-type, loads, stores, branches, and jumps.
   ============================================================================ */