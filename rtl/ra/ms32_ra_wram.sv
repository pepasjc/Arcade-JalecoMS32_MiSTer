// SPDX-License-Identifier: GPL-3.0-or-later
//
// MS32 work RAM (0x20000 bytes, 32-bit, V70 byte order: byte lane i = bits
// 8i+7:8i = byte address 4n+i) with a second, read-only port for the
// RetroAchievements RAM mirror (rtl/ra/ra_mirror_gather.v).
//
// Port A (clk_a = clk_cpu) is the V70 bus port, exactly as the inferred RAM
// it replaces in ms32_cpu_sys: registered address, byte-lane writes, read
// data one clock later. Port B (clk_b = clk_sys) only reads.
//
// Synthesis instantiates altsyncram, as dpram_dc.sv does and for the same
// reason: inferred from behavioural code, a second read port makes Quartus
// build two simple-dual-port copies of the array (128 more M10K, which the
// device does not have). One BIDIR_DUAL_PORT altsyncram with two clocks and
// byte enables is the same 128 M10K as the single-port RAM.
module ms32_ra_wram (
	input  logic        clk_a,
	input  logic [14:0] a_addr,
	input  logic [3:0]  a_be,       // write enables per byte lane
	input  logic [31:0] a_wdata,
	output logic [31:0] a_rdata,

	input  logic        clk_b,
	input  logic [14:0] b_addr,
	output logic [31:0] b_rdata
);

`ifndef ALTERA_RESERVED_QIS
	logic [31:0] mem [0:32767];
	always_ff @(posedge clk_a) begin
		for (int i = 0; i < 4; i++) if (a_be[i]) mem[a_addr][8*i +: 8] <= a_wdata[8*i +: 8];
		a_rdata <= mem[a_addr];
	end
	always_ff @(posedge clk_b) b_rdata <= mem[b_addr];
`else
	altsyncram #(
		.operation_mode("BIDIR_DUAL_PORT"),
		.ram_block_type("M10K"),
		.intended_device_family("Cyclone V"),
		.lpm_type("altsyncram"),
		.numwords_a(32768), .widthad_a(15), .width_a(32),
		.numwords_b(32768), .widthad_b(15), .width_b(32),
		.width_byteena_a(4), .byte_size(8),
		.width_byteena_b(1),
		.outdata_reg_a("UNREGISTERED"), .outdata_reg_b("UNREGISTERED"),
		.address_reg_b("CLOCK1"), .indata_reg_b("CLOCK1"), .wrcontrol_wraddress_reg_b("CLOCK1"),
		.clock_enable_input_a("BYPASS"), .clock_enable_output_a("BYPASS"),
		.clock_enable_input_b("BYPASS"), .clock_enable_output_b("BYPASS"),
		.outdata_aclr_a("NONE"), .outdata_aclr_b("NONE"),
		.read_during_write_mode_mixed_ports("DONT_CARE"),
		.read_during_write_mode_port_a("NEW_DATA_NO_NBE_READ"),
		.read_during_write_mode_port_b("NEW_DATA_NO_NBE_READ"),
		.power_up_uninitialized("FALSE")
	) u_ram (
		.clock0(clk_a), .address_a(a_addr), .data_a(a_wdata), .wren_a(|a_be), .byteena_a(a_be), .q_a(a_rdata),
		.clock1(clk_b), .address_b(b_addr), .data_b(32'd0), .wren_b(1'b0), .q_b(b_rdata),
		.aclr0(1'b0), .aclr1(1'b0), .addressstall_a(1'b0), .addressstall_b(1'b0), .byteena_b(1'b1),
		.clocken0(1'b1), .clocken1(1'b1), .clocken2(1'b1), .clocken3(1'b1), .rden_a(1'b1), .rden_b(1'b1), .eccstatus()
	);
`endif

endmodule
