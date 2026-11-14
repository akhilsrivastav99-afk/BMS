module bms_master_core (
    input  wire        vcc, gnd, clk, rst_n,
    
    // 4-Cell Voltage inputs (Digital converted values from external ADC)
    input  wire [7:0]  cell1_vol, cell2_vol, cell3_vol, cell4_vol,
    input  wire [7:0]  srp, srn, ts1,
    
    // Control, Bypass & Fault Indicator Outputs
    output wire        byp1, byp2, byp3, byp4,
    output reg         chg_en, dsg_en, alert_led
);

    // Thresholds
    localparam [7:0] OV_THRESHOLD   = 8'd217; 
    localparam [7:0] UV_THRESHOLD   = 8'd138; 
    localparam [7:0] DEAD_THRESHOLD = 8'd51;  
    localparam [7:0] OT_THRESHOLD   = 8'd200; 
    localparam [7:0] OC_THRESHOLD   = 8'd100; 

    // Dead cell detection for all 4 cells
    wire is_dead1 = (cell1_vol < DEAD_THRESHOLD);
    wire is_dead2 = (cell2_vol < DEAD_THRESHOLD);
    wire is_dead3 = (cell3_vol < DEAD_THRESHOLD);
    wire is_dead4 = (cell4_vol < DEAD_THRESHOLD);
    
    wire [2:0] dead_count = is_dead1 + is_dead2 + is_dead3 + is_dead4;
    wire fatal_fault = (dead_count >= 2); 
    
    wire [7:0] current_val = (srp > srn) ? (srp - srn) : (srn - srp);
    
    wire ov_fault = (cell1_vol > OV_THRESHOLD) || (cell2_vol > OV_THRESHOLD) ||
                    (cell3_vol > OV_THRESHOLD) || (cell4_vol > OV_THRESHOLD);
    
    wire uv_fault = (cell1_vol < UV_THRESHOLD && !is_dead1) || 
                    (cell2_vol < UV_THRESHOLD && !is_dead2) ||
                    (cell3_vol < UV_THRESHOLD && !is_dead3) || 
                    (cell4_vol < UV_THRESHOLD && !is_dead4);
                    
    wire ot_fault = (ts1 > OT_THRESHOLD);
    wire oc_fault = (current_val > OC_THRESHOLD);

    // Single Cell Dead Bypass Logic
    assign byp1 = fatal_fault ? 1'b0 : is_dead1;
    assign byp2 = fatal_fault ? 1'b0 : is_dead2;
    assign byp3 = fatal_fault ? 1'b0 : is_dead3;
    assign byp4 = fatal_fault ? 1'b0 : is_dead4;

    wire any_fault = (fatal_fault | ot_fault | oc_fault | uv_fault | ov_fault);

    // Main Protection & Fault Indicator State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            chg_en <= 1'b1; 
            dsg_en <= 1'b1; 
            alert_led <= 1'b0;
        end else if (vcc == 1'b1 && gnd == 1'b0) begin
            // Fault Alert LED / Buzzer Trigger
            alert_led <= any_fault;

            // Protection Enforcement
            if (fatal_fault || ot_fault || oc_fault) begin
                chg_en <= 1'b0; 
                dsg_en <= 1'b0; 
            end else begin
                if (uv_fault) dsg_en <= 1'b0; else dsg_en <= 1'b1;
                if (ov_fault) chg_en <= 1'b0; else chg_en <= 1'b1;
            end
        end
    end

endmodule