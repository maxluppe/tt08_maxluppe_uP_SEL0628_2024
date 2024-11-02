/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_maxluppe_uP0628_24 (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // All output pins must be assigned. If not used, assign to 0.
    assign uo_out[7]  = 1'b0;
    assign uio_oe  = 1;

// List all unused inputs to prevent warnings
	wire _unused = &{ena, uio_in, 1'b0};

    	uP_SEL0628_2024 cpu (
		.clk(clk),
		.clr_n(rst_n),
	    	.data_in(ui_in),	//Transformar em bidirecional
            	.we(uo_out[6]),
          	.addr(uo_out[5:0]),
            	.data_out(uio_out)
	);

endmodule
