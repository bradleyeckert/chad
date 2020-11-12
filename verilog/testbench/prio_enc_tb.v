`timescale 1ns / 100 ps

module prio_enc_tb();

parameter WIDTH=4;

reg [(1<<WIDTH)-1:0] a = 0;
wire [WIDTH-1:0] y;
wire on = (y != 0);

prio_enc #(4) pe0 (.a(a), .y(y));

initial
begin
    $dumpfile("bench.vcd");
    $dumpvars(0,priority_tb);
    repeat (1<<WIDTH) begin
        #10;
        $display("a=%x, y=%x, on=%d", a, y, on);
        a <= (a << 1) + 1;
    end
    repeat (1<<WIDTH) begin
        #10;
        $display("a=%x, y=%x, on=%d", a, y, on);
        a <= a << 1;
    end
    #10
    $display("a=%x, y=%x, on=%d", a, y, on);
    a <= 1;
    repeat (1<<WIDTH) begin
        #10;
        $display("a=%x, y=%x, on=%d", a, y, on);
        a <= a << 1;
    end

    $display("finished OK!");
end

endmodule