`default_nettype none

module tt_um_bms (
    input  wire [7:0] ui_in,    // Dedicated inputs: 8-bit Data Bus from External ADC
    output wire [7:0] uo_out,   // Dedicated outputs: BMS Control & Bypass Signals
    input  wire [7:0] uio_in,   // IOs: Input path (Channel Select & Load Enable)
    output wire [7:0] uio_out,  // IOs: Output path (Unused, tied to 0)
    output wire [7:0] uio_oe,   // IOs: Enable path (0 = all configured as Inputs)
    input  wire       ena,      // Design enable (always 1 when powered)
    input  wire       clk,      // System clock
    input  wire       rst_n     // Active-low reset
);

    // Configure all 8 bidirectional pins (uio) strictly as Inputs
    assign uio_oe  = 8'b0000_0000;
    assign uio_out = 8'b0000_0000;

    // Control signals from uio_in
    wire [2:0] ch_sel  = uio_in[2:0]; // Channel address (0 to 6)
    wire       load_en = uio_in[3];   // Write/Latch enable strobe

    // Internal registers to hold 8-bit values for each sensor channel
    reg [7:0] cell1_reg, cell2_reg, cell3_reg, cell4_reg;
    reg [7:0] srp_reg, srn_reg, ts1_reg;

    // Latch incoming 8-bit ADC data into the selected channel register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Safe nominal startup values (~3.7V per cell, normal current & temp)
            cell1_reg <= 8'd200;
            cell2_reg <= 8'd200;
            cell3_reg <= 8'd200;
            cell4_reg <= 8'd200;
            srp_reg   <= 8'd10;
            srn_reg   <= 8'd10;
            ts1_reg   <= 8'd50;
        end else if (ena && load_en) begin
            case (ch_sel)
                3'd0: cell1_reg <= ui_in;
                3'd1: cell2_reg <= ui_in;
                3'd2: cell3_reg <= ui_in;
                3'd3: cell4_reg <= ui_in;
                3'd4: srp_reg   <= ui_in;
                3'd5: srn_reg   <= ui_in;
                3'd6: ts1_reg   <= ui_in;
                default: ;
            endcase
        end
    end

    // Internal wires from BMS Master Core
    wire byp1, byp2, byp3, byp4;
    wire chg_en, dsg_en, alert_led;

    // Instantiate the verified 285-gate BMS Master Core
    bms_master_core core_inst (
        .vcc       (ena),
        .gnd       (1'b0),
        .clk       (clk),
        .rst_n     (rst_n),
        .cell1_vol (cell1_reg),
        .cell2_vol (cell2_reg),
        .cell3_vol (cell3_reg),
        .cell4_vol (cell4_reg),
        .srp       (srp_reg),
        .srn       (srn_reg),
        .ts1       (ts1_reg),
        .byp1      (byp1),
        .byp2      (byp2),
        .byp3      (byp3),
        .byp4      (byp4),
        .chg_en    (chg_en),
        .dsg_en    (dsg_en),
        .alert_led (alert_led)
    );

    // Map BMS outputs to Tiny Tapeout Dedicated Output Pins (uo_out[7:0])
    assign uo_out[0] = byp1;       // Cell 1 Bypass MOSFET
    assign uo_out[1] = byp2;       // Cell 2 Bypass MOSFET
    assign uo_out[2] = byp3;       // Cell 3 Bypass MOSFET
    assign uo_out[3] = byp4;       // Cell 4 Bypass MOSFET
    assign uo_out[4] = chg_en;     // Main Charge MOSFET Enable
    assign uo_out[5] = dsg_en;     // Main Discharge MOSFET Enable
    assign uo_out[6] = alert_led;  // Fault Alert LED / Buzzer Trigger
    assign uo_out[7] = 1'b0;       // Reserved output (tied low)

    // Tie off unused upper bits of uio_in to prevent OpenLane linter warnings
    wire _unused = &{uio_in[7:4], 1'b0};

endmodule

`default_nettype wire