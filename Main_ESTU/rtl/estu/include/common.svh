`ifndef COMMON_SVH
`define COMMON_SVH

function automatic integer clogb2(input integer depth);
    begin
        clogb2 = 0;
        while (depth > 0) begin
            depth = depth >> 1;
            clogb2 = clogb2 + 1;
        end
    end
endfunction

`endif
