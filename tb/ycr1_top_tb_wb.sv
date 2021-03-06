/// @file       <ycr1_top_tb_ahb.sv>
/// @brief      YCR1 top testbench Wishbone
///

`include "ycr1_arch_description.svh"
`include "ycr1_ahb.svh"
`ifdef YCR1_IPIC_EN
`include "ycr1_ipic.svh"
`endif // YCR1_IPIC_EN

`include "uprj_netlists.v"
`include "ycr1_memory_tb_wb.sv"
`include "sky130_sram_2kbyte_1rw1r_32x512_8.v"

localparam [31:0]      YCR1_SIM_EXIT_ADDR      = 32'h0000_00F8;
localparam [31:0]      YCR1_SIM_PRINT_ADDR     = 32'hF000_0000;
localparam [31:0]      YCR1_SIM_EXT_IRQ_ADDR   = 32'hF000_0100;
localparam [31:0]      YCR1_SIM_SOFT_IRQ_ADDR  = 32'hF000_0200;

module ycr1_top_tb_wb (
`ifdef VERILATOR
    input logic clk
`endif // VERILATOR
);

//-------------------------------------------------------------------------------
// Local parameters
//-------------------------------------------------------------------------------
localparam                          YCR1_MEM_SIZE       = 1024*1024;

//-------------------------------------------------------------------------------
// Local signal declaration
//-------------------------------------------------------------------------------
logic                                   rst_n;
`ifndef VERILATOR
logic                                   clk         = 1'b0;
`endif // VERILATOR
logic                                   rtc_clk     = 1'b0;
`ifdef YCR1_IPIC_EN
logic [YCR1_IRQ_LINES_NUM-1:0]          irq_lines;
`else // YCR1_IPIC_EN
logic                                   ext_irq;
`endif // YCR1_IPIC_EN
logic                                   soft_irq;
logic [31:0]                            fuse_mhartid;
integer                                 imem_req_ack_stall;
integer                                 dmem_req_ack_stall;

logic                                   test_mode   = 1'b0;
`ifdef YCR1_DBG_EN
logic                                   trst_n;
logic                                   tck;
logic                                   tms;
logic                                   tdi;
logic                                   tdo;
logic                                   tdo_en;
`endif // YCR1_DBG_EN
logic                                   wb_rst_n;       // Wish bone reset
logic                                   wb_clk = 1'b0;  // wish bone clock
// Instruction Memory Interface
logic                                   wbd_imem_stb_o; // strobe/request
logic   [YCR1_WB_WIDTH-1:0]             wbd_imem_adr_o; // address
logic                                   wbd_imem_we_o;  // write
logic   [YCR1_WB_WIDTH-1:0]             wbd_imem_dat_o; // data output
logic   [3:0]                           wbd_imem_sel_o; // byte enable
logic   [YCR1_WB_WIDTH-1:0]             wbd_imem_dat_i; // data input
logic                                   wbd_imem_ack_i; // acknowlegement
logic                                   wbd_imem_err_i;  // error

// Data Memory Interface
logic                                   wbd_dmem_stb_o; // strobe/request
logic   [YCR1_WB_WIDTH-1:0]             wbd_dmem_adr_o; // address
logic                                   wbd_dmem_we_o;  // write
logic   [YCR1_WB_WIDTH-1:0]             wbd_dmem_dat_o; // data output
logic   [3:0]                           wbd_dmem_sel_o; // byte enable
logic   [YCR1_WB_WIDTH-1:0]             wbd_dmem_dat_i; // data input
logic                                   wbd_dmem_ack_i; // acknowlegement
logic                                   wbd_dmem_err_i; // error

`ifndef SCR1_TCM_MEM
// SRAM-0 PORT-0 - DMEM I/F
wire                                    sram0_clk0    ; // CLK
wire                                    sram0_csb0    ; // CS#
wire                                    sram0_web0    ; // WE#
wire   [8:0]                            sram0_addr0   ; // Address
wire   [3:0]                            sram0_wmask0  ; // WMASK#
wire   [31:0]                           sram0_din0    ; // Write Data
wire   [31:0]                           sram0_dout0   ; // Read Data

// SRAM-0 PORT-1, IMEM I/F
wire                                    sram0_clk1    ; // CLK
wire                                    sram0_csb1    ; // CS#
wire  [8:0]                             sram0_addr1   ; // Address
wire  [31:0]                            sram0_dout1   ; // Read Data

// SRAM-1 PORT-0 - DMEM I/F
wire                                    sram1_clk0    ; // CLK
wire                                    sram1_csb0    ; // CS#
wire                                    sram1_web0    ; // WE#
wire   [8:0]                            sram1_addr0   ; // Address
wire   [3:0]                            sram1_wmask0  ; // WMASK#
wire   [31:0]                           sram1_din0    ; // Write Data
wire   [31:0]                           sram1_dout0   ; // Read Data

// SRAM-1 PORT-1, IMEM I/F
wire                                    sram1_clk1    ; // CLK
wire                                    sram1_csb1    ; // CS#
wire  [8:0]                             sram1_addr1   ; // Address
wire  [31:0]                            sram1_dout1   ; // Read Data
`endif

int unsigned                            f_results     ;
int unsigned                            f_info        ;

string                                  s_results     ;
string                                  s_info        ;
`ifdef SIGNATURE_OUT
string                                  s_testname    ;
bit                                     b_single_run_flag;
`endif  //  SIGNATURE_OUT
`ifdef VERILATOR
logic [255:0]                           test_file     ;
logic [255:0]                           test_ram_file;
`else // VERILATOR
string                                  test_file     ;
string                                  test_ram_file;
`endif // VERILATOR

bit                                     test_running  ;
int unsigned                            tests_passed  ;
int unsigned                            tests_total   ;

bit [1:0]                               rst_cnt       ;
bit                                     rst_init      ;
logic [31:0] riscv_dmem_req_cnt; // cnt dmem req
event	                                reinit_event;
logic  [31:0]                           tem_mem[0:1047];


`ifdef VERILATOR
function bit is_compliance (logic [255:0] testname);
    bit res;
    logic [79:0] pattern;
begin
    pattern = 80'h636f6d706c69616e6365; // compliance
    res = 0;
    for (int i = 0; i<= 176; i++) begin
        if(testname[i+:80] == pattern) begin
            return ~res;
        end
    end
    `ifdef SIGNATURE_OUT
        return ~res;
    `else
        return res;
    `endif
end
endfunction : is_compliance

function logic [255:0] get_filename (logic [255:0] testname);
logic [255:0] res;
int i, j;
begin
    testname[7:0] = 8'h66;
    testname[15:8] = 8'h6C;
    testname[23:16] = 8'h65;

    for (i = 0; i <= 248; i += 8) begin
        if (testname[i+:8] == 0) begin
            break;
        end
    end
    i -= 8;
    for (j = 255; i >= 0;i -= 8) begin
        res[j-:8] = testname[i+:8];
        j -= 8;
    end
    for (; j >= 0;j -= 8) begin
        res[j-:8] = 0;
    end

    return res;
end
endfunction : get_filename

function logic [255:0] get_ref_filename (logic [255:0] testname);
logic [255:0] res;
int i, j;
logic [79:0] pattern;
begin
    pattern = 80'h636f6d706c69616e6365; // compliance

    for(int i = 0; i <= 176; i++) begin
        if(testname[i+:80] == pattern) begin
            testname[(i-8)+:88] = 0;
            break;
        end
    end

    for(i = 32; i <= 248; i += 8) begin
        if(testname[i+:8] == 0) break;
    end
    i -= 8;
    for(j = 255; i > 24; i -= 8) begin
        res[j-:8] = testname[i+:8];
        j -= 8;
    end
    for(; j >=0;j -= 8) begin
        res[j-:8] = 0;
    end

    return res;
end
endfunction : get_ref_filename

function logic [2047:0] remove_trailing_whitespaces (logic [2047:0] str);
int i;
begin
    for (i = 0; i <= 2040; i += 8) begin
        if (str[i+:8] != 8'h20) begin
            break;
        end
    end
    str = str >> i;
    return str;
end
endfunction: remove_trailing_whitespaces

`else // VERILATOR
function bit is_compliance (string testname);
begin
    return (testname.substr(0, 9) == "compliance");
end
endfunction : is_compliance

function string get_filename (string testname);
int length;
begin
    length = testname.len();
    testname[length-1] = "f";
    testname[length-2] = "l";
    testname[length-3] = "e";

    return testname;
end
endfunction : get_filename

function string get_ref_filename (string testname);
begin
    return testname.substr(11, testname.len() - 5);
end
endfunction : get_ref_filename

`endif // VERILATOR

`ifndef VERILATOR
always #5   clk     = ~clk;         // 100 MHz
always #5   wb_clk  = ~wb_clk;      // 100 MHz
always #500 rtc_clk = ~rtc_clk;     // 1 MHz
`endif // VERILATOR

// Reset logic
assign rst_n = &rst_cnt;

always_ff @(posedge clk) begin
     if (rst_init)       begin
	rst_cnt <= '0;
	-> reinit_event;
    end
    else if (~&rst_cnt) rst_cnt <= rst_cnt + 1'b1;
end


`ifdef YCR1_DBG_EN
initial begin
    trst_n  = 1'b0;
    tck     = 1'b0;
    tdi     = 1'b0;
    #900ns trst_n   = 1'b1;
    #500ns tms      = 1'b1;
    #800ns tms      = 1'b0;
    #500ns trst_n   = 1'b0;
    #100ns tms      = 1'b1;
end
`endif // YCR1_DBG_EN


always @reinit_event
begin
   // Initialize the SPI memory with hex content
   // Wait for reset removal
   //wait (rst_n == 1);
   // some of the RISCV test need SRAM area for specific
   // instruction execution like fence
   //$sformat(test_ram_file, "%s.ram",test_file);
   //// Load the RAM content to local temp memory
   //$readmemh(test_ram_file,tem_mem);
   //// Split the Temp memory content to two sram file
   //$readmemh(test_ram_file,tem_mem);
   //$writememh("sram0.hex",tem_mem,0,511);
   //$writememh("sram1.hex",tem_mem,512,1023);
   //// Load the SRAM0/SRAM1 with 2KB data
   //$write("\033[0;34m---Initializing the u_tsram0_2kb Memory with Hexfile: sram0.hex\033[0m\n");
   //$readmemh("sram0.hex",u_tsram0_2kb.mem);
   //$write("\033[0;34m---Initializing the u_tsram1_2kb Memory with Hexfile: sram1.hex\033[0m\n");
   //$readmemh("sram1.hex",u_tsram1_2kb.mem);
   
   //for(i =32'h00; i < 32'h100; i = i+1)
   //    $display("Location: %x, Data: %x", i, u_tsram0_2kb.mem[i]);
end

//-------------------------------------------------------------------------------
// Run tests
//-------------------------------------------------------------------------------

`include "ycr1_top_tb_runtests.sv"
//-------------------------------------------------------------------------------
// Core instance
//-------------------------------------------------------------------------------
ycr1_top_wb i_top (
    // Reset
    .pwrup_rst_n            (rst_n                  ),
    .rst_n                  (rst_n                  ),
    .cpu_rst_n              (rst_n                  ),
`ifdef YCR1_DBG_EN
    .sys_rst_n_o            (                       ),
    .sys_rdc_qlfy_o         (                       ),
`endif // YCR1_DBG_EN

    // Clock
    .core_clk               (clk                    ),
    .rtc_clk                (rtc_clk                ),
    .riscv_debug            (                       ),

    // Fuses
    .fuse_mhartid           (fuse_mhartid           ),
`ifdef YCR1_DBG_EN
    .fuse_idcode            (`YCR1_TAP_IDCODE       ),
`endif // YCR1_DBG_EN

    // IRQ
`ifdef YCR1_IPIC_EN
    .irq_lines              (irq_lines              ),
`else // YCR1_IPIC_EN
    .ext_irq                (ext_irq                ),
`endif // YCR1_IPIC_EN
    .soft_irq               (soft_irq               ),

    // DFT
    //.test_mode              (1'b0                   ),
    //.test_rst_n             (1'b1                   ),

`ifdef YCR1_DBG_EN
    // JTAG
    .trst_n                 (trst_n                 ),
    .tck                    (tck                    ),
    .tms                    (tms                    ),
    .tdi                    (tdi                    ),
    .tdo                    (tdo                    ),
    .tdo_en                 (tdo_en                 ),
`endif // YCR1_DBG_EN

`ifndef SCR1_TCM_MEM
    // SRAM-0 PORT-0
    .sram0_clk0             (sram0_clk0                ),
    .sram0_csb0             (sram0_csb0                ),
    .sram0_web0             (sram0_web0                ),
    .sram0_addr0            (sram0_addr0               ),
    .sram0_wmask0           (sram0_wmask0              ),
    .sram0_din0             (sram0_din0                ),
    .sram0_dout0            (sram0_dout0               ),
    
    // SRAM-0 PORT-0
    .sram0_clk1             (sram0_clk1                ),
    .sram0_csb1             (sram0_csb1                ),
    .sram0_addr1            (sram0_addr1               ),
    .sram0_dout1            (sram0_dout1               ),

    // SRAM-1 PORT-0
    .sram1_clk0             (sram1_clk0                ),
    .sram1_csb0             (sram1_csb0                ),
    .sram1_web0             (sram1_web0                ),
    .sram1_addr0            (sram1_addr0               ),
    .sram1_wmask0           (sram1_wmask0              ),
    .sram1_din0             (sram1_din0                ),
    .sram1_dout0            (sram1_dout0               ),
    
    // SRAM PORT-0
    .sram1_clk1             (sram1_clk1                ),
    .sram1_csb1             (sram1_csb1                ),
    .sram1_addr1            (sram1_addr1               ),
    .sram1_dout1            (sram1_dout1               ),
`endif

    .wb_rst_n               (rst_n                  ),
    .wb_clk                 (clk                    ),

    .wbd_imem_stb_o         (wbd_imem_stb_o         ),
    .wbd_imem_adr_o         (wbd_imem_adr_o         ),
    .wbd_imem_we_o          (wbd_imem_we_o          ),
    .wbd_imem_dat_o         (wbd_imem_dat_o         ),
    .wbd_imem_sel_o         (wbd_imem_sel_o         ),
    .wbd_imem_dat_i         (wbd_imem_dat_i         ),
    .wbd_imem_ack_i         (wbd_imem_ack_i         ),
    .wbd_imem_err_i         (wbd_imem_err_i         ),

    .wbd_dmem_stb_o         (wbd_dmem_stb_o         ),
    .wbd_dmem_adr_o         (wbd_dmem_adr_o         ),
    .wbd_dmem_we_o          (wbd_dmem_we_o          ),
    .wbd_dmem_dat_o         (wbd_dmem_dat_o         ),
    .wbd_dmem_sel_o         (wbd_dmem_sel_o         ),
    .wbd_dmem_dat_i         (wbd_dmem_dat_i         ),
    .wbd_dmem_ack_i         (wbd_dmem_ack_i         ),
    .wbd_dmem_err_i         (wbd_dmem_err_i         )

);

//-------------------------------------------------------------------------------
// Memory instance
//-------------------------------------------------------------------------------
ycr1_memory_tb_wb #(
    .YCR1_MEM_POWER_SIZE    ($clog2(YCR1_MEM_SIZE))
) i_memory_tb (
    // Control
    .rst_n                  (rst_n                  ),
    .clk                    (clk                    ),
`ifdef YCR1_IPIC_EN
    .irq_lines              (irq_lines              ),
`else // YCR1_IPIC_EN
    .ext_irq                (ext_irq                ),
`endif // YCR1_IPIC_EN
    .soft_irq               (soft_irq               ),
    .imem_req_ack_stall_in  (imem_req_ack_stall     ),
    .dmem_req_ack_stall_in  (dmem_req_ack_stall     ),

    .wbd_imem_stb_i         (wbd_imem_stb_o         ),
    .wbd_imem_adr_i         (wbd_imem_adr_o         ),
    .wbd_imem_we_i          (wbd_imem_we_o          ),
    .wbd_imem_dat_i         (wbd_imem_dat_o         ),
    .wbd_imem_sel_i         (wbd_imem_sel_o         ),
    .wbd_imem_dat_o         (wbd_imem_dat_i         ),
    .wbd_imem_ack_o         (wbd_imem_ack_i         ),
    .wbd_imem_err_o         (wbd_imem_err_i         ),

    .wbd_dmem_stb_i         (wbd_dmem_stb_o         ),
    .wbd_dmem_adr_i         (wbd_dmem_adr_o         ),
    .wbd_dmem_we_i          (wbd_dmem_we_o          ),
    .wbd_dmem_dat_i         (wbd_dmem_dat_o         ),
    .wbd_dmem_sel_i         (wbd_dmem_sel_o         ),
    .wbd_dmem_dat_o         (wbd_dmem_dat_i         ),
    .wbd_dmem_ack_o         (wbd_dmem_ack_i         ),
    .wbd_dmem_err_o         (wbd_dmem_err_i         )

);


wire  dmem_req =  i_top.core_dmem_req & i_top.core_dmem_req_ack;


`ifndef SCR1_TCM_MEM
sky130_sram_2kbyte_1rw1r_32x512_8 u_tsram0_2kb(
`ifdef USE_POWER_PINS
    .vccd1 (vccd1),// User area 1 1.8V supply
    .vssd1 (vssd1),// User area 1 digital ground
`endif
// Port 0: RW
    .clk0     (sram0_clk0),
    .csb0     (sram0_csb0),
    .web0     (sram0_web0),
    .wmask0   (sram0_wmask0),
    .addr0    (sram0_addr0),
    .din0     (sram0_din0),
    .dout0    (sram0_dout0),
// Port 1: R
    .clk1     (sram0_clk1),
    .csb1     (sram0_csb1),
    .addr1    (sram0_addr1),
    .dout1    (sram0_dout1)
  );

  sky130_sram_2kbyte_1rw1r_32x512_8 u_tsram1_2kb(
`ifdef USE_POWER_PINS
    .vccd1 (vccd1),// User area 1 1.8V supply
    .vssd1 (vssd1),// User area 1 digital ground
`endif
// Port 0: RW
    .clk0     (sram1_clk0),
    .csb0     (sram1_csb0),
    .web0     (sram1_web0),
    .wmask0   (sram1_wmask0),
    .addr0    (sram1_addr0),
    .din0     (sram1_din0),
    .dout0    (sram1_dout0),
// Port 1: R
    .clk1     (sram1_clk1),
    .csb1     (sram1_csb1),
    .addr1    (sram1_addr1),
    .dout1    (sram1_dout1)
  );
`endif

initial begin
   riscv_dmem_req_cnt = 0;

end

always @(posedge dmem_req)
begin
    riscv_dmem_req_cnt = riscv_dmem_req_cnt+1;
    if((riscv_dmem_req_cnt %200) == 0)
        $display("STATUS: Total DMEM Req: %d",riscv_dmem_req_cnt);
end

`ifdef WFDUMP
initial
begin
   $dumpfile("simx.vcd");
   //$dumpvars(0,ycr1_top_tb_wb);
   //$dumpvars(0,ycr1_top_tb_wb.i_top);
   $dumpvars(0,ycr1_top_tb_wb.i_top.i_core_top.i_pipe_top.i_pipe_mprf);
end
`endif



endmodule : ycr1_top_tb_wb

