/*
 * Copyright (c) 2024 Aayan Rahman
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module spi_peripheral (
    input  wire       clk,      // clock
    input  wire       rst_n,    // reset_n - low to reset
    input  wire       sclk,     // SPI clock
    input  wire       copi,     // Controller Out Peripheral In (MOSI)
    input  wire       ncs,      // Chip Select (active low)
    
    // Output registers to control the PWM peripheral
    output reg [7:0]  en_reg_out_7_0,
    output reg [7:0]  en_reg_out_15_8,
    output reg [7:0]  en_reg_pwm_7_0,
    output reg [7:0]  en_reg_pwm_15_8,
    output reg [7:0]  pwm_duty_cycle
);

    // SPI registers
    reg [2:0] bit_counter;
    reg [7:0] shift_reg;
    reg [1:0] addr;
    
    // Synchronize SPI inputs to system clock domain
    reg [2:0] sclk_sync, ncs_sync, copi_sync;
    always @(posedge clk) begin
        sclk_sync <= {sclk_sync[1:0], sclk};
        ncs_sync <= {ncs_sync[1:0], ncs};
        copi_sync <= {copi_sync[1:0], copi};
    end
    
    wire sclk_rising = (sclk_sync[2:1] == 2'b01);
    wire sclk_falling = (sclk_sync[2:1] == 2'b10);
    wire ncs_rising = (ncs_sync[2:1] == 2'b01);
    wire ncs_falling = (ncs_sync[2:1] == 2'b10);
    wire copi_value = copi_sync[1];
    
    // SPI state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_counter <= 3'b000;
            shift_reg <= 8'h00;
            addr <= 2'b00;
            en_reg_out_7_0 <= 8'h00;
            en_reg_out_15_8 <= 8'h00;
            en_reg_pwm_7_0 <= 8'h00;
            en_reg_pwm_15_8 <= 8'h00;
            pwm_duty_cycle <= 8'h00;
        end else begin
            // Handle chip select going active (falling edge)
            if (ncs_falling) begin
                bit_counter <= 3'b000;
                shift_reg <= 8'h00;
            end
            
            // Handle chip select going inactive (rising edge)
            if (ncs_rising) begin
                // Process the received data based on address
                case (addr)
                    2'b00: en_reg_out_7_0 <= shift_reg;
                    2'b01: en_reg_out_15_8 <= shift_reg;
                    2'b10: begin
                        en_reg_pwm_7_0 <= shift_reg[3:0];
                        en_reg_pwm_15_8 <= shift_reg[7:4];
                    end
                    2'b11: pwm_duty_cycle <= shift_reg;
                endcase
            end
            
            // Process data on SCLK rising edge when CS is active (low)
            if (sclk_rising && !ncs_sync[1]) begin
                // Shift in data
                shift_reg <= {shift_reg[6:0], copi_value};
                bit_counter <= bit_counter + 3'b001;
                
                // First two bits determine the address
                if (bit_counter < 2) begin
                    addr[1-bit_counter] <= copi_value;
                end
            end
        end
    end

endmodule