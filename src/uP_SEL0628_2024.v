//Processador SEL0628-2024
//
//Autor: Turma 2024
//Responsável: Prof. Dr. Maximiliam Luppe
//

//Módulos básicos
//	Combinacionais
//		Decodificador 2x4
//		Multiplexador 2x1
//		Multiplexador 4x1
//		Somador/Subtrator
//	Sequenciais
//		Registrador paralelo com clock enable
//		Contador síncrono com reset assíncrono (clr_n), clock eneble (en) e leitura de dados (ld) síncrona
//
//Módulos integrados
//	Combinacional
//		Unidade Lógica-Aritmética
//	Sequencial
//		Banco de Registradores
//	Máquina de Estados Finitos
//		Unidade de Controle

//Módulos básicos

//	Decodificador 2x4
module decod24 #(parameter Size=8)(
	input [1:0] S,
	//input en,
	output [3:0] Y
);

	//wire Y_tmp;

	assign Y =	(S == 2'b00) ? 4'b0001 :
				(S == 2'b01) ? 4'b0010 :
				(S == 2'b10) ? 4'b0100 :
				 4'b1000;

	//assign Y = Y_tmp & {4{en}};
	
endmodule

//	Multiplexador 2x1
module mux21 #(parameter Size=8)(
	input S,
	input [Size-1:0] A0, A1,
	output [Size-1:0] Y
);

	assign Y = S ? A1 : A0;

endmodule

//	Multiplexador 4x1
module mux41 #(parameter Size=8)(
	input [1:0] S,
	input [Size-1:0] A0, A1, A2, A3,
	output [Size-1:0] Y
);

	assign Y =	(S == 2'b00) ? A0 :
				(S == 2'b01) ? A1 :
				(S == 2'b10) ? A2 :
				 A3;

endmodule

//	Somador/Subtrator
module adder #(parameter Size=8)(
	input mode,
	input [Size-1:0] A, B,
	output [Size-1:0] S,
	output Carry
);

	assign {Carry,S} = mode ? {1'b0,A} - {1'b0,B} : {1'b0,A} + {1'b0,B};

endmodule

//Módulos Sequenciais

//	Registrador paralelo com clock enable
module register #(parameter Size=8)(
	input clk, clr_n, en,
	input [Size-1:0] d,
	output reg [Size-1:0] q
);

	always @(posedge clk or negedge clr_n)
		if (~clr_n)
			q = {Size{1'b0}};
		else
			if (en)
				q = d;

endmodule

//	Contador síncrono com reset assíncrono (clr_n), clock eneble (en) e leitura de dados (ld) síncrona
module counter #(parameter Size=8)(
	input clk, clr_n, en, ld,
	input [Size-1:0] d,
	output reg [Size-1:0] q
);

	always @(posedge clk or negedge clr_n)
		if (~clr_n)
			q = {Size{1'b0}};
		else
			if (en)
				if (ld)
					q = d;
				else
					q = q + 1;

endmodule

//Módulos integrados

//	Unidade Lógica-Aritmética

module ula #(parameter Size=8)(
	input [1:0] funct,
	input [Size-1:0] A, B,
	output [Size-1:0] ALUOut,
	output Carry, Zero
);

	wire [Size-1:0] SumSub;
	
	adder #(Size) addsub (.mode(funct[0]), .A(A), .B(B), .S(SumSub), .Carry(Carry));

	assign ALUOut = (funct == 2'b00) ? SumSub :
					(funct == 2'b01) ? SumSub :
					(funct == 2'b10) ? A & B :
					A | B;
	
	assign Zero = (ALUOut == {Size{1'b0}}) ? 1'b1 : 1'b0 ;
	
endmodule

//	Banco de Registradores

module regbank #(parameter Size=8)(
	input clk, clr_n, we,
	input [1:0] a1, a2,
	input [Size-1:0] wd,
	output [Size-1:0] rd1, rd2
);

	wire [3:0] en;
	wire [Size-1:0] rfile [0:3];
	
	decod24 #(8) sel (.S(a1), .Y(en));

	register #(8) r0 (.clk(clk), .clr_n(clr_n), .en(en[0] & we), .d(wd), .q(rfile[0]));
	register #(8) r1 (.clk(clk), .clr_n(clr_n), .en(en[1] & we), .d(wd), .q(rfile[1]));
	register #(8) r2 (.clk(clk), .clr_n(clr_n), .en(en[2] & we), .d(wd), .q(rfile[2]));
	register #(8) r3 (.clk(clk), .clr_n(clr_n), .en(en[3] & we), .d(wd), .q(rfile[3]));

	mux41 #(Size) muxrd1 (.S(a1), .A0(rfile[0]), .A1(rfile[1]), .A2(rfile[2]), .A3(rfile[3]), .Y(rd1));
	mux41 #(Size) muxrd2 (.S(a2), .A0(rfile[0]), .A1(rfile[1]), .A2(rfile[2]), .A3(rfile[3]), .Y(rd2));

endmodule

//	Máquina de Estados Finitos

module fsm (
	input clk, clr_n, Zero,
	input [7:0] instr,
	output reg [12:0] ctrl	//PC_en,PC_ld,LdSt,we,IR_en,Wb,RF_we,a1,a2,ALU_Control
);
	// FSM states
	parameter Fetch = 0, Decode = 1, ExecALU = 3, ExecLD = 5, ExecST = 7, ExecJC = 2;
	// Instruction decode
	parameter LD = 2'b00, ST = 2'b01, ALU = 2'b10, JC = 2'b11;
	// Function decode
	
	reg [2:0] actual_state, next_state;
	reg ZF;
	
	wire [1:0] opcode, funct, a1, a2;
	
	assign opcode = instr[7:6];
	assign funct = instr[5:4];
	assign a1 = instr[3:2];
	assign a2 = instr[1:0];

	// State storage
	always @ (posedge clk or negedge clr_n)
		if (~clr_n)
			actual_state = Fetch;
		else
			actual_state = next_state;
	
	// State transition
	always @ (actual_state, opcode, funct, Zero) begin
		//default value
		next_state <= Fetch;
		//ZF <= Zero;
		case (actual_state)
			Fetch:									//00
				next_state <= Decode;
			Decode:									//01
				case (opcode)
					LD:
						next_state <= ExecLD;		//05
					ST:
						next_state <= ExecST;		//07
					JC: begin
							next_state <= ExecJC;	//02
						end
					ALU: begin
							next_state <= ExecALU;	//03
						end
				endcase
			//ExecJC:
				//ZF <= 1'b0;				//CF always reseted when JC
			ExecALU:
				ZF <= Zero;
		endcase
	end

	// Output generation
	// PC_en,PC_ld,LdSt,we,IR_en,Wb,RF_we,a1,a2,ALU_Control
	always @ (actual_state, a1, a2, funct, ZF) begin
		ctrl = 13'b0000000000000;
		case (actual_state)
			Fetch:									//PC_en	PC_ld	LdSt	we	IR_en	Wb	RF_we	a1	a2	ALU_Control
				ctrl = 13'b0000100000000;			//0		0		0		0	1		0	0		xx	xx	xx
			Decode: 
				ctrl = 13'b0000000000000;			//1		0		0		0	0		0	0		xx	xx	xx
			ExecALU: begin							//ff R1, R2 ->  R1 <= R1 ff R2
				ctrl = {7'b1000001,a1,a2,funct};	//0		0		0		0	0		0	1		a1	a2	funct
				//ZF = Zero;
			end
			ExecLD:									//ld aaaaaa -> R0 <- [aaaaaa]
				ctrl = 13'b1010011000000;			//0		0		1		0	0		1	1		00	xx	xx
			ExecST:									//st aaaaaa -> [aaaaaa] <- R0
				ctrl = 13'b1011000000000;			//0		0		1		1	0		0	0		xx	xx	xx
			ExecJC: begin							//jnz dddddd -> PC <- dddddd if ZF = 0
				if (~ZF)
					ctrl = 13'b1100000000000;		//0		1		0		0	0		0	0		xx	xx	xx
				else
					ctrl = 13'b1000000000000;		//0		0		0		0	0		0	0		xx	xx	xx
				//ZF = 1'b0;
			end
			default:
				ctrl = 13'b0000000000000;			//0		0		0		0	0		0	0		xx	xx	xx
		endcase
	end
endmodule

module uP_SEL0628_2024 (
	input clk, clr_n,
	input [7:0] data_in,
	output we,
	output [5:0] addr,
	output [7:0] data_out
);

	wire PC_en, PC_ld, LdSt, IR_en, Wb, RF_we, Carry;
	wire [1:0] a1, a2, ALU_Control;
	wire [5:0] PC_out;
	wire [7:0] IR_out, ALUOut, wd, rd1, rd2;

	counter #(6) PC (.clk(clk), .clr_n(clr_n), .en(PC_en), .ld(PC_ld), .d(IR_out[5:0]), .q(PC_out));
	
	mux21 #(6) MEM_ADR (.S(LdSt), .A0(PC_out), .A1(IR_out[5:0]), .Y(addr));
	
	register #(8) IR (.clk(clk), .clr_n(clr_n), .en(IR_en), .d(data_in), .q(IR_out));
	
	fsm UC (.clk(clk), .clr_n(clr_n), .instr(IR_out), .Zero(Zero), .ctrl({PC_en,PC_ld,LdSt,we,IR_en,Wb,RF_we,a1,a2,ALU_Control}));
	
	regbank #(8) REGFILE (.clk(clk), .clr_n(clr_n), .we(RF_we), .a1(a1), .a2(a2), .wd(wd), .rd1(rd1), .rd2(rd2));
	
	ula #(8) ALU (.funct(ALU_Control), .A(rd1), .B(rd2), .ALUOut(ALUOut), .Carry(Carry), .Zero(Zero));

	mux21 #(8) WR_BCK (.S(Wb), .A0(ALUOut), .A1(data_in), .Y(wd));
	
	assign data_out = rd2;
	
endmodule


