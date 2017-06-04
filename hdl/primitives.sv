/////////////////////////////////////////////////////////////////////
////                                                             ////
////  Primitives                                                 ////
////  FPU Primitives                                             ////
////                                                             ////
////  Author: Rudolf Usselmann                                   ////
////          rudi@asics.ws                                      ////
////                                                             ////
/////////////////////////////////////////////////////////////////////
////                                                             ////
//// Copyright (C) 2000 Rudolf Usselmann                         ////
////                    rudi@asics.ws                            ////
////                                                             ////
//// This source file may be used and distributed without        ////
//// restriction provided that this copyright statement is not   ////
//// removed from the file and that any derivative work contains ////
//// the original copyright notice and the associated disclaimer.////
////                                                             ////
////     THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY     ////
//// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED   ////
//// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS   ////
//// FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL THE AUTHOR      ////
//// OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,         ////
//// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES    ////
//// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE   ////
//// GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR        ////
//// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF  ////
//// LIABILITY, WHETHER IN  CONTRACT, STRICT LIABILITY, OR TORT  ////
//// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT  ////
//// OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE         ////
//// POSSIBILITY OF SUCH DAMAGE.                                 ////
////                                                             ////
/////////////////////////////////////////////////////////////////////


//`timescale 1ns / 100ps


////////////////////////////////////////////////////////////////////////
//
// Add/Sub
//

module add_sub27(add, opa, opb, sum, co);
input		add;
input	[26:0]	opa, opb;
output	[26:0]	sum;
output		co;



assign {co, sum} = add ? (opa + opb) : (opa - opb);

endmodule

////////////////////////////////////////////////////////////////////////
//
// Multiply
//

module mul_r2(clk, reset, opa, opb, prod);
input		clk,reset;
input	[23:0]	opa, opb;
output	[47:0]	prod;

logic	[47:0]	prod1, prod;

always_ff @(posedge clk or posedge reset)
	if ( reset == 1'b1) prod1 <= 0;
	else prod1 <= /*#1*/ opa * opb;

always_ff @(posedge clk or posedge reset)
	if ( reset == 1'b1) prod <= 0;
	else prod <= /*#1*/ prod1;

endmodule

////////////////////////////////////////////////////////////////////////
//
// Divide
//

module div_r2(clk, reset, opa, opb, quo, rem);
input		clk, reset;
input	[49:0]	opa;
input	[23:0]	opb;
output	[49:0]	quo, rem;

logic	[49:0]	quo, rem, quo1, remainder;

always_ff @(posedge clk or posedge reset)
	if ( reset == 1'b1) quo1 <= 0;
	else quo1 <= /*#1*/ opa / opb;

always_ff @(posedge clk or posedge reset)
	if ( reset == 1'b1) quo <= 0;
	else quo <= /*#1*/ quo1;

always_ff @(posedge clk or posedge reset)
	if ( reset == 1'b1) remainder <= 0;
	else remainder <= /*#1*/ opa % opb;

always_ff @(posedge clk or posedge reset)
	if ( reset == 1'b1) rem <= 0;
	else rem <= /*#1*/ remainder;

endmodule


