`define UNIT_DELAY #0.1

`ifdef GL
       `include "libs.ref/sky130_fd_sc_hd/verilog/primitives.v"
       `include "libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v"
       `include "libs.ref/sky130_fd_sc_hvl/verilog/primitives.v"
       `include "libs.ref/sky130_fd_sc_hvl/verilog/sky130_fd_sc_hvl.v"
       `include "libs.ref//sky130_fd_sc_hd/verilog/sky130_ef_sc_hd__fakediode_2.v"
       `include "netlist/ycr1_top_wb.gv"
`else
     `include "core/pipeline/ycr1_pipe_hdu.sv"
     `include "core/pipeline/ycr1_pipe_tdu.sv"
     `include "core/pipeline/ycr1_ipic.sv"
     `include "core/pipeline/ycr1_pipe_csr.sv"
     `include "core/pipeline/ycr1_pipe_exu.sv"
     `include "core/pipeline/ycr1_pipe_ialu.sv"
     `include "core/pipeline/ycr1_pipe_idu.sv"
     `include "core/pipeline/ycr1_pipe_ifu.sv"
     `include "core/pipeline/ycr1_pipe_lsu.sv"
     `include "core/pipeline/ycr1_pipe_mprf.sv"
     `include "core/pipeline/ycr1_pipe_mul.sv"
     `include "core/pipeline/ycr1_pipe_div.sv"
     `include "core/pipeline/ycr1_pipe_top.sv"
     `include "core/primitives/ycr1_reset_cells.sv"
     `include "core/primitives/ycr1_cg.sv"
     `include "core/ycr1_clk_ctrl.sv"
     `include "core/ycr1_tapc_shift_reg.sv"
     `include "core/ycr1_tapc.sv"
     `include "core/ycr1_tapc_synchronizer.sv"
     `include "core/ycr1_core_top.sv"
     `include "core/ycr1_dm.sv"
     `include "core/ycr1_dmi.sv"
     `include "core/ycr1_scu.sv"
     `include "core/pipeline/ycr1_tracelog.sv"
     `include "top/ycr1_dmem_router.sv"
     `include "top/ycr1_dp_memory.sv"
     `include "top/ycr1_tcm.sv"
     `include "top/ycr1_timer.sv"
     `include "top/ycr1_dmem_wb.sv"
     `include "top/ycr1_imem_wb.sv"
     `include "top/ycr1_top_wb.sv"
     `include "top/ycr1_intf.sv"
     `include "top/ycr1_imem_router.sv"
     `include "lib/sync_fifo.sv"
     `include "lib/async_fifo.sv"
     `include "lib/clk_skew_adjust.gv"
     `include "lib/ctech_cells.sv"
`endif
