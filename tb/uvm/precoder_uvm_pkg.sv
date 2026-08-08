`timescale 1ns/1ps

package precoder_uvm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    `uvm_analysis_imp_decl(_input)
    `uvm_analysis_imp_decl(_output)
    `uvm_analysis_imp_decl(_lite)

    class axi_lite_item extends uvm_sequence_item;
        rand bit        is_write;
        rand bit [31:0] addr;
        rand bit [31:0] data;
        rand bit [3:0]  strb;
        rand bit        w_first;
        bit [31:0]      read_data;
        bit [1:0]       response;
        `uvm_object_utils_begin(axi_lite_item)
            `uvm_field_int(is_write, UVM_DEFAULT)
            `uvm_field_int(addr, UVM_DEFAULT)
            `uvm_field_int(data, UVM_DEFAULT)
            `uvm_field_int(strb, UVM_DEFAULT)
            `uvm_field_int(w_first, UVM_DEFAULT)
            `uvm_field_int(read_data, UVM_DEFAULT)
            `uvm_field_int(response, UVM_DEFAULT)
        `uvm_object_utils_end
        function new(string name="axi_lite_item"); super.new(name); endfunction
    endclass

    class axi_stream_in_item extends uvm_sequence_item;
        rand bit signed [15:0] real_part;
        rand bit signed [15:0] imag_part;
        rand bit [3:0] keep;
        rand bit [7:0] tid;
        rand bit last;
        `uvm_object_utils_begin(axi_stream_in_item)
            `uvm_field_int(real_part, UVM_DEFAULT)
            `uvm_field_int(imag_part, UVM_DEFAULT)
            `uvm_field_int(keep, UVM_DEFAULT)
            `uvm_field_int(tid, UVM_DEFAULT)
            `uvm_field_int(last, UVM_DEFAULT)
        `uvm_object_utils_end
        function new(string name="axi_stream_in_item"); super.new(name); endfunction
    endclass

    class axi_stream_out_item extends uvm_sequence_item;
        bit signed [15:0] real_part;
        bit signed [15:0] imag_part;
        bit [2:0] antenna;
        bit saturated;
        bit [7:0] version;
        bit [7:0] tid;
        bit last;
        `uvm_object_utils_begin(axi_stream_out_item)
            `uvm_field_int(real_part, UVM_DEFAULT)
            `uvm_field_int(imag_part, UVM_DEFAULT)
            `uvm_field_int(antenna, UVM_DEFAULT)
            `uvm_field_int(saturated, UVM_DEFAULT)
            `uvm_field_int(version, UVM_DEFAULT)
            `uvm_field_int(tid, UVM_DEFAULT)
            `uvm_field_int(last, UVM_DEFAULT)
        `uvm_object_utils_end
        function new(string name="axi_stream_out_item"); super.new(name); endfunction
    endclass

    class axi_lite_sequencer extends uvm_sequencer#(axi_lite_item);
        `uvm_component_utils(axi_lite_sequencer)
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
    endclass

    class axi_stream_in_sequencer extends uvm_sequencer#(axi_stream_in_item);
        `uvm_component_utils(axi_stream_in_sequencer)
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
    endclass

    class axi_lite_driver extends uvm_driver#(axi_lite_item);
        `uvm_component_utils(axi_lite_driver)
        virtual axi_lite_if vif;
        int response_stall_max;
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual axi_lite_if)::get(this,"","vif",vif))
                `uvm_fatal("NOVIF","axi_lite_driver virtual interface not set")
            if (!uvm_config_db#(int)::get(this,"","response_stall_max",response_stall_max))
                response_stall_max=0;
        endfunction
        task reset_signals();
            vif.awaddr <= '0; vif.awvalid <= 0; vif.wdata <= '0; vif.wstrb <= '0;
            vif.wvalid <= 0; vif.bready <= 0; vif.araddr <= '0; vif.arvalid <= 0; vif.rready <= 0;
        endtask
        task send_write(axi_lite_item tr);
            if (tr.w_first) begin
                @(negedge vif.aclk); vif.wdata <= tr.data; vif.wstrb <= tr.strb; vif.wvalid <= 1;
                do @(posedge vif.aclk); while (!vif.wready);
                @(negedge vif.aclk); vif.wvalid <= 0;
                @(negedge vif.aclk); vif.awaddr <= tr.addr; vif.awvalid <= 1;
                do @(posedge vif.aclk); while (!vif.awready);
                @(negedge vif.aclk); vif.awvalid <= 0;
            end else begin
                @(negedge vif.aclk); vif.awaddr <= tr.addr; vif.awvalid <= 1;
                do @(posedge vif.aclk); while (!vif.awready);
                @(negedge vif.aclk); vif.awvalid <= 0;
                @(negedge vif.aclk); vif.wdata <= tr.data; vif.wstrb <= tr.strb; vif.wvalid <= 1;
                do @(posedge vif.aclk); while (!vif.wready);
                @(negedge vif.aclk); vif.wvalid <= 0;
            end
            repeat ($urandom_range(response_stall_max)) @(posedge vif.aclk);
            @(negedge vif.aclk); vif.bready <= 1;
            do @(posedge vif.aclk); while (!vif.bvalid);
            tr.response = vif.bresp;
            @(negedge vif.aclk); vif.bready <= 0;
        endtask
        task send_read(axi_lite_item tr);
            @(negedge vif.aclk); vif.araddr <= tr.addr; vif.arvalid <= 1;
            do @(posedge vif.aclk); while (!vif.arready);
            @(negedge vif.aclk); vif.arvalid <= 0;
            repeat ($urandom_range(response_stall_max)) @(posedge vif.aclk);
            @(negedge vif.aclk); vif.rready <= 1;
            do @(posedge vif.aclk); while (!vif.rvalid);
            tr.read_data = vif.rdata; tr.response = vif.rresp;
            @(negedge vif.aclk); vif.rready <= 0;
        endtask
        task run_phase(uvm_phase phase);
            reset_signals();
            forever begin
                seq_item_port.get_next_item(req);
                if (req.is_write) send_write(req); else send_read(req);
                seq_item_port.item_done();
            end
        endtask
    endclass

    class axi_lite_monitor extends uvm_monitor;
        `uvm_component_utils(axi_lite_monitor)
        virtual axi_lite_if vif;
        uvm_analysis_port#(axi_lite_item) ap;
        function new(string name, uvm_component parent); super.new(name,parent); ap=new("ap",this); endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual axi_lite_if)::get(this,"","vif",vif))
                `uvm_fatal("NOVIF","axi_lite_monitor virtual interface not set")
        endfunction
        task run_phase(uvm_phase phase);
            axi_lite_item tr;
            bit aw_seen, w_seen, ar_seen;
            bit [31:0] observed_awaddr, observed_wdata, observed_araddr;
            bit [3:0] observed_wstrb;
            aw_seen=0; w_seen=0; ar_seen=0;
            forever begin
                @(posedge vif.aclk);
                if (vif.awvalid && vif.awready) begin
                    aw_seen=1; observed_awaddr=vif.awaddr;
                end
                if (vif.wvalid && vif.wready) begin
                    w_seen=1; observed_wdata=vif.wdata; observed_wstrb=vif.wstrb;
                end
                if (vif.bvalid && vif.bready) begin
                    if (!aw_seen || !w_seen) begin
                        `uvm_error("LITE_MON","write response observed without complete AW/W request")
                    end else begin
                        tr=axi_lite_item::type_id::create("write_observed");
                        tr.is_write=1; tr.addr=observed_awaddr; tr.data=observed_wdata;
                        tr.strb=observed_wstrb; tr.response=vif.bresp; ap.write(tr);
                    end
                    aw_seen=0; w_seen=0;
                end
                if (vif.arvalid && vif.arready) begin
                    ar_seen=1; observed_araddr=vif.araddr;
                end
                if (vif.rvalid && vif.rready) begin
                    if (!ar_seen) begin
                        `uvm_error("LITE_MON","read response observed without AR request")
                    end else begin
                        tr=axi_lite_item::type_id::create("read_observed");
                        tr.is_write=0; tr.addr=observed_araddr; tr.read_data=vif.rdata;
                        tr.response=vif.rresp; ap.write(tr);
                    end
                    ar_seen=0;
                end
            end
        endtask
    endclass

    class axi_lite_agent extends uvm_agent;
        `uvm_component_utils(axi_lite_agent)
        axi_lite_sequencer sequencer;
        axi_lite_driver driver;
        axi_lite_monitor monitor;
        virtual axi_lite_if vif;
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual axi_lite_if)::get(this,"","vif",vif)) `uvm_fatal("NOVIF","lite vif missing")
            sequencer=axi_lite_sequencer::type_id::create("sequencer",this);
            driver=axi_lite_driver::type_id::create("driver",this);
            monitor=axi_lite_monitor::type_id::create("monitor",this);
            uvm_config_db#(virtual axi_lite_if)::set(this,"driver","vif",vif);
            uvm_config_db#(virtual axi_lite_if)::set(this,"monitor","vif",vif);
        endfunction
        function void connect_phase(uvm_phase phase); driver.seq_item_port.connect(sequencer.seq_item_export); endfunction
    endclass

    class axi_stream_in_driver extends uvm_driver#(axi_stream_in_item);
        `uvm_component_utils(axi_stream_in_driver)
        virtual axi_stream_if vif;
        int gap_max;
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual axi_stream_if)::get(this,"","vif",vif)) `uvm_fatal("NOVIF","stream input vif missing")
            if (!uvm_config_db#(int)::get(this,"","gap_max",gap_max)) gap_max=0;
        endfunction
        task run_phase(uvm_phase phase);
            vif.tdata <= 0; vif.tkeep <= 0; vif.tid <= 0; vif.tvalid <= 0; vif.tlast <= 0;
            forever begin
                seq_item_port.get_next_item(req);
                repeat ($urandom_range(gap_max)) @(posedge vif.aclk);
                @(negedge vif.aclk); vif.tdata <= {req.real_part,req.imag_part}; vif.tkeep <= req.keep; vif.tid <= req.tid; vif.tlast <= req.last; vif.tvalid <= 1;
                do @(posedge vif.aclk); while (!vif.tready);
                @(negedge vif.aclk); vif.tvalid <= 0;
                seq_item_port.item_done();
            end
        endtask
    endclass

    class axi_stream_in_monitor extends uvm_monitor;
        `uvm_component_utils(axi_stream_in_monitor)
        virtual axi_stream_if vif;
        uvm_analysis_port#(axi_stream_in_item) ap;
        function new(string name, uvm_component parent); super.new(name,parent); ap=new("ap",this); endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual axi_stream_if)::get(this,"","vif",vif)) `uvm_fatal("NOVIF","stream input monitor vif missing")
        endfunction
        task run_phase(uvm_phase phase);
            axi_stream_in_item tr;
            forever begin
                @(posedge vif.aclk);
                if (vif.tvalid && vif.tready) begin
                    tr=axi_stream_in_item::type_id::create("input_observed");
                    tr.real_part=vif.tdata[31:16]; tr.imag_part=vif.tdata[15:0]; tr.keep=vif.tkeep; tr.tid=vif.tid; tr.last=vif.tlast; ap.write(tr);
                end
            end
        endtask
    endclass

    class axi_stream_in_agent extends uvm_agent;
        `uvm_component_utils(axi_stream_in_agent)
        axi_stream_in_sequencer sequencer; axi_stream_in_driver driver; axi_stream_in_monitor monitor; virtual axi_stream_if vif;
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase); if (!uvm_config_db#(virtual axi_stream_if)::get(this,"","vif",vif)) `uvm_fatal("NOVIF","stream input vif missing");
            sequencer=axi_stream_in_sequencer::type_id::create("sequencer",this); driver=axi_stream_in_driver::type_id::create("driver",this); monitor=axi_stream_in_monitor::type_id::create("monitor",this);
            uvm_config_db#(virtual axi_stream_if)::set(this,"driver","vif",vif); uvm_config_db#(virtual axi_stream_if)::set(this,"monitor","vif",vif);
        endfunction
        function void connect_phase(uvm_phase phase); driver.seq_item_port.connect(sequencer.seq_item_export); endfunction
    endclass

    class axi_stream_out_monitor extends uvm_monitor;
        `uvm_component_utils(axi_stream_out_monitor)
        virtual axi_stream_if vif; uvm_analysis_port#(axi_stream_out_item) ap;
        function new(string name, uvm_component parent); super.new(name,parent); ap=new("ap",this); endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase); if (!uvm_config_db#(virtual axi_stream_if)::get(this,"","vif",vif)) `uvm_fatal("NOVIF","stream output vif missing");
        endfunction
        task run_phase(uvm_phase phase);
            axi_stream_out_item tr;
            forever begin
                @(posedge vif.aclk);
                if (vif.tvalid && vif.tready) begin
                    tr=axi_stream_out_item::type_id::create("output_observed"); tr.real_part=vif.tdata[31:16]; tr.imag_part=vif.tdata[15:0]; tr.antenna={vif.tuser[11],vif.tuser[1:0]}; tr.saturated=vif.tuser[2]; tr.version=vif.tuser[10:3]; tr.tid=vif.tid; tr.last=vif.tlast; ap.write(tr);
                end
            end
        endtask
    endclass

    class axi_stream_out_ready_driver extends uvm_component;
        `uvm_component_utils(axi_stream_out_ready_driver)
        virtual axi_stream_if vif;
        int stall_percent;
        int periodic_stall_every;
        int stall_burst_cycles;
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase); super.build_phase(phase); if (!uvm_config_db#(virtual axi_stream_if)::get(this,"","vif",vif)) `uvm_fatal("NOVIF","stream output vif missing"); if (!uvm_config_db#(int)::get(this,"","stall_percent",stall_percent)) stall_percent=0; if (!uvm_config_db#(int)::get(this,"","periodic_stall_every",periodic_stall_every)) periodic_stall_every=0; if (!uvm_config_db#(int)::get(this,"","stall_burst_cycles",stall_burst_cycles)) stall_burst_cycles=0; endfunction
        task run_phase(uvm_phase phase); integer cycle, burst_remaining; bit previous_valid; cycle=0; burst_remaining=0; previous_valid=0; vif.tready <= 0; wait(vif.aresetn); forever begin @(negedge vif.aclk); cycle++; if ((burst_remaining == 0) && (stall_burst_cycles > 0) && vif.tvalid && !previous_valid) burst_remaining=stall_burst_cycles; if (burst_remaining > 0) begin vif.tready <= 0; burst_remaining--; end else if ((periodic_stall_every > 0) && ((cycle % periodic_stall_every) == 0)) vif.tready <= 0; else vif.tready <= ($urandom_range(99) >= stall_percent); previous_valid=vif.tvalid; end endtask
    endclass

    class axi_stream_out_agent extends uvm_agent;
        `uvm_component_utils(axi_stream_out_agent)
        axi_stream_out_monitor monitor; axi_stream_out_ready_driver driver; virtual axi_stream_if vif;
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase); super.build_phase(phase); if (!uvm_config_db#(virtual axi_stream_if)::get(this,"","vif",vif)) `uvm_fatal("NOVIF","stream output vif missing"); monitor=axi_stream_out_monitor::type_id::create("monitor",this); driver=axi_stream_out_ready_driver::type_id::create("driver",this); uvm_config_db#(virtual axi_stream_if)::set(this,"monitor","vif",vif); uvm_config_db#(virtual axi_stream_if)::set(this,"driver","vif",vif); endfunction
    endclass

    // The scoreboard mirrors both coefficient banks from completed AXI-Lite
    // writes. Mode, bank, and version are snapshotted at transaction start so
    // a busy commit or mode request cannot change an in-flight vector.
    class precoder_scoreboard extends uvm_component;
        `uvm_component_utils(precoder_scoreboard)
        uvm_analysis_imp_input#(axi_stream_in_item, precoder_scoreboard) input_imp;
        uvm_analysis_imp_output#(axi_stream_out_item, precoder_scoreboard) output_imp;
        uvm_analysis_imp_lite#(axi_lite_item, precoder_scoreboard) lite_imp;
        bit signed [15:0] matrix_real[0:1][0:7][0:7];
        bit signed [15:0] matrix_imag[0:1][0:7][0:7];
        bit signed [15:0] vector_real[0:7];
        bit signed [15:0] vector_imag[0:7];
        int signed expected_real[0:7];
        int signed expected_imag[0:7];
        bit expected_saturated[0:7];
        real floating_real[0:7];
        real floating_imag[0:7];
        int input_index;
        int output_index;
        bit vector_active;
        bit transaction_bank;
        bit [7:0] transaction_version;
        bit [7:0] transaction_tid;
        bit active_bank;
        bit [7:0] active_version;
        bit active_mode_8x8;
        bit active_format_12;
        bit active_truncate;
        bit active_wrap;
        bit transaction_mode_8x8;
        bit transaction_format_12;
        bit transaction_truncate;
        bit transaction_wrap;
        bit pending;
        bit pending_bank;
        bit [7:0] pending_version;
        // Track transaction IDs independently from the ordered numerical model.
        // IDs may be reused after completion, but never while outstanding.
        bit outstanding_tid[0:255];
        bit [7:0] last_completed_tid;
        bit last_completed_tid_valid;
        virtual axi_stream_if reset_vif;
        int accepted_id_count;
        int completed_id_count;
        int duplicate_accept_count;
        int unknown_output_count;
        int duplicate_completion_count;
        int tid_mismatch_count;
        real error_energy;
        real reference_energy;
        real last_evm;
        real max_evm;
        int checked_vectors;
        int busy_commit_count;
        int saturated_output_count;
        function new(string name, uvm_component parent);
            super.new(name,parent); input_imp=new("input_imp",this);
            output_imp=new("output_imp",this); lite_imp=new("lite_imp",this);
        endfunction
        function void build_phase(uvm_phase phase);
            integer bank, row, col, tid_index;
            super.build_phase(phase);
            if (!uvm_config_db#(virtual axi_stream_if)::get(this,"","reset_vif",reset_vif))
                reset_vif=null;
            input_index=0; output_index=0; vector_active=0;
            active_bank=0; active_version=0; active_mode_8x8=0; active_format_12=0;
            active_truncate=0; active_wrap=0; transaction_tid=0;
            transaction_mode_8x8=0; transaction_format_12=0;
            transaction_truncate=0; transaction_wrap=0; pending=0;
            error_energy=0.0; reference_energy=0.0; last_evm=0.0; max_evm=0.0;
            checked_vectors=0; busy_commit_count=0; saturated_output_count=0;
            accepted_id_count=0; completed_id_count=0;
            duplicate_accept_count=0; unknown_output_count=0;
            duplicate_completion_count=0; tid_mismatch_count=0;
            last_completed_tid=0; last_completed_tid_valid=0;
            for (tid_index=0; tid_index<256; tid_index=tid_index+1)
                outstanding_tid[tid_index]=0;
            for (bank=0; bank<2; bank=bank+1)
                for (row=0; row<8; row=row+1)
                    for (col=0; col<8; col=col+1) begin
                        matrix_real[bank][row][col]=0;
                        matrix_imag[bank][row][col]=0;
                    end
        endfunction
        function void reset_runtime_state();
            integer bank, row, col, tid_index;
            input_index=0; output_index=0; vector_active=0;
            active_bank=0; active_version=0; active_mode_8x8=0;
            active_format_12=0; active_truncate=0; active_wrap=0;
            transaction_tid=0; transaction_mode_8x8=0;
            transaction_format_12=0; transaction_truncate=0;
            transaction_wrap=0; pending=0; pending_bank=0;
            pending_version=0; error_energy=0.0; reference_energy=0.0;
            last_evm=0.0;
            last_completed_tid=0; last_completed_tid_valid=0;
            for (tid_index=0; tid_index<256; tid_index=tid_index+1)
                outstanding_tid[tid_index]=0;
            for (bank=0; bank<2; bank=bank+1)
                for (row=0; row<8; row=row+1)
                    for (col=0; col<8; col=col+1) begin
                        matrix_real[bank][row][col]=0;
                        matrix_imag[bank][row][col]=0;
                    end
            `uvm_info("TID_RESET","scoreboard transaction tracker cleared by reset",UVM_LOW)
        endfunction
        task run_phase(uvm_phase phase);
            if (reset_vif != null) begin
                forever begin
                    @(negedge reset_vif.aresetn);
                    reset_runtime_state();
                end
            end
        endtask
        function automatic int signed round_output(input longint signed value,
                                                    input bit format_12,
                                                    input bit truncate_mode,
                                                    input bit wrap_mode,
                                                    output bit saturated);
            longint signed magnitude; longint signed rounded;
            int signed shift, max_value, min_value;
            shift = format_12 ? 10 : 14;
            max_value = format_12 ? 2047 : 32767;
            min_value = format_12 ? -2048 : -32768;
            magnitude = (value < 0) ? -value : value;
            rounded = (magnitude + (truncate_mode ? 0 : (64'sd1 << (shift-1)))) >>> shift;
            if (value < 0) rounded = -rounded;
            saturated=0;
            if (!wrap_mode && (rounded > max_value)) begin rounded=max_value; saturated=1; end
            if (!wrap_mode && (rounded < min_value)) begin rounded=min_value; saturated=1; end
            if (wrap_mode) begin
                if (format_12) rounded = $signed(rounded[11:0]);
                else rounded = $signed(rounded[15:0]);
            end
            return rounded;
        endfunction
        function void calculate_expected();
            integer row, col, dimension;
            longint signed acc_real, acc_imag;
            bit sat_real, sat_imag;
            real scale;
            dimension = transaction_mode_8x8 ? 8 : 4;
            scale = transaction_format_12 ? 1024.0 : 16384.0;
            for (row=0; row<dimension; row=row+1) begin
                acc_real=0; acc_imag=0; floating_real[row]=0.0; floating_imag[row]=0.0;
                for (col=0; col<dimension; col=col+1) begin
                    acc_real += $signed(matrix_real[transaction_bank][row][col])
                              * $signed(vector_real[col])
                              - $signed(matrix_imag[transaction_bank][row][col])
                              * $signed(vector_imag[col]);
                    acc_imag += $signed(matrix_real[transaction_bank][row][col])
                              * $signed(vector_imag[col])
                              + $signed(matrix_imag[transaction_bank][row][col])
                              * $signed(vector_real[col]);
                    floating_real[row] +=
                        (matrix_real[transaction_bank][row][col] / scale)
                        * (vector_real[col] / scale)
                        - (matrix_imag[transaction_bank][row][col] / scale)
                        * (vector_imag[col] / scale);
                    floating_imag[row] +=
                        (matrix_real[transaction_bank][row][col] / scale)
                        * (vector_imag[col] / scale)
                        + (matrix_imag[transaction_bank][row][col] / scale)
                        * (vector_real[col] / scale);
                end
                expected_real[row]=round_output(acc_real,transaction_format_12,
                                                transaction_truncate,transaction_wrap,sat_real);
                expected_imag[row]=round_output(acc_imag,transaction_format_12,
                                                transaction_truncate,transaction_wrap,sat_imag);
                expected_saturated[row]=sat_real || sat_imag;
            end
        endfunction
        function void write_lite(axi_lite_item tr);
            int index, row, col, reset_bank, reset_row, reset_col;
            bit bank;
            if (!tr.is_write || tr.response != 2'b00) return;
            if (((tr.addr >= 32'h100) && (tr.addr <= (active_mode_8x8 ? 32'h1fc : 32'h13c)))
                    || ((tr.addr >= 32'h200) && (tr.addr <= (active_mode_8x8 ? 32'h2fc : 32'h23c)))) begin
                bank=(tr.addr >= 32'h200);
                index=(tr.addr & 32'hff) >> 2;
                row=active_mode_8x8 ? index/8 : index/4;
                col=active_mode_8x8 ? index%8 : index%4;
                matrix_real[bank][row][col]=tr.data[31:16];
                matrix_imag[bank][row][col]=tr.data[15:0];
            end else if ((tr.addr == 32'h44) && (tr.data[31:1] == 0)) begin
                active_format_12=tr.data[0];
                for (reset_bank=0; reset_bank<2; reset_bank=reset_bank+1)
                    for (reset_row=0; reset_row<8; reset_row=reset_row+1)
                        for (reset_col=0; reset_col<8; reset_col=reset_col+1) begin
                            matrix_real[reset_bank][reset_row][reset_col]=0;
                            matrix_imag[reset_bank][reset_row][reset_col]=0;
                        end
            end else if ((tr.addr == 32'h48) && (tr.data[31:2] == 0)) begin
                active_truncate=tr.data[0];
                active_wrap=tr.data[1];
            end else if ((tr.addr == 32'h40) && (tr.data[31:1] == 0)) begin
                active_mode_8x8=tr.data[0];
            end else if ((tr.addr == 32'h10) && tr.data[31]) begin
                if (vector_active) begin
                    pending=1; pending_bank=tr.data[0]; pending_version=tr.data[15:8];
                    busy_commit_count++;
                end else begin
                    active_bank=tr.data[0]; active_version=tr.data[15:8]; pending=0;
                end
            end
        endfunction
        function void write_input(axi_stream_in_item tr);
            if (tr.keep != 4'hf) `uvm_error("REF_TKEEP","reference input has invalid TKEEP")
            if (active_format_12
                    && ((tr.real_part[15:12] != {4{tr.real_part[11]}})
                     || (tr.imag_part[15:12] != {4{tr.imag_part[11]}})))
                `uvm_error("REF_FORMAT","12-bit input is not sign extended")
            if (tr.last !== (input_index == (active_mode_8x8 ? 7 : 3)))
                `uvm_error("REF_INPUT_LAST",$sformatf("bad input TLAST on beat %0d",input_index))
            if ((input_index != 0) && (tr.tid !== transaction_tid)) begin
                tid_mismatch_count++;
                `uvm_error("TID_INPUT_STABILITY",$sformatf("input TID changed within vector: expected %0d got %0d",transaction_tid,tr.tid));
            end
            vector_real[input_index]=tr.real_part;
            vector_imag[input_index]=tr.imag_part;
            if (input_index == 0)
                begin
                    transaction_mode_8x8=active_mode_8x8;
                    transaction_format_12=active_format_12;
                    transaction_truncate=active_truncate;
                    transaction_wrap=active_wrap;
                    transaction_tid=tr.tid;
                end
            if (input_index == (active_mode_8x8 ? 7 : 3)) begin
                transaction_bank=active_bank; transaction_version=active_version;
                if (outstanding_tid[tr.tid]) begin
                    duplicate_accept_count++;
                    `uvm_error("TID_DUP_ACCEPT",$sformatf("transaction TID %0d accepted while still outstanding",tr.tid));
                end else begin
                    outstanding_tid[tr.tid]=1;
                    accepted_id_count++;
                end
                vector_active=1; calculate_expected(); input_index=0;
            end else input_index++;
        endfunction
        function void write_output(axi_stream_out_item tr);
            real exp_real, exp_imag, got_real, got_imag, vector_evm;
            if (!outstanding_tid[tr.tid]) begin
                if (last_completed_tid_valid && (tr.tid === last_completed_tid)) begin
                    duplicate_completion_count++;
                    `uvm_error("TID_DUP_COMPLETE",$sformatf("duplicate completion observed for TID %0d",tr.tid));
                end else begin
                    unknown_output_count++;
                    `uvm_error("TID_UNKNOWN_OUTPUT",$sformatf("output observed for unknown TID %0d",tr.tid));
                end
            end
            if (!vector_active) begin
                `uvm_error("REF_ORDER","output arrived before complete input vector"); return;
            end
            if (tr.antenna !== output_index[2:0])
                `uvm_error("REF_ANTENNA",$sformatf("expected antenna %0d got %0d",output_index,tr.antenna));
            if (tr.last !== (output_index == (transaction_mode_8x8 ? 7 : 3)))
                `uvm_error("REF_LAST",$sformatf("bad TLAST on output %0d",output_index));
            if (tr.real_part !== expected_real[output_index][15:0]
                    || tr.imag_part !== expected_imag[output_index][15:0])
                `uvm_error("REF_FIXED",$sformatf("antenna %0d expected %0d+%0dj got %0d+%0dj",output_index,expected_real[output_index],expected_imag[output_index],tr.real_part,tr.imag_part));
            if (tr.version !== transaction_version)
                `uvm_error("REF_VERSION",$sformatf("expected matrix version %0d got %0d",transaction_version,tr.version));
            if (tr.tid !== transaction_tid)
                begin
                    tid_mismatch_count++;
                    `uvm_error("REF_TID",$sformatf("expected transaction TID %0d got %0d",transaction_tid,tr.tid));
                end
            if (tr.saturated !== expected_saturated[output_index])
                `uvm_error("REF_SAT",$sformatf("antenna %0d expected saturation %0d got %0d",output_index,expected_saturated[output_index],tr.saturated));
            if (tr.saturated) saturated_output_count++;
            exp_real = floating_real[output_index];
            exp_imag = floating_imag[output_index];
            got_real = tr.real_part / (transaction_format_12 ? 1024.0 : 16384.0);
            got_imag = tr.imag_part / (transaction_format_12 ? 1024.0 : 16384.0);
            error_energy += (got_real-exp_real)*(got_real-exp_real) + (got_imag-exp_imag)*(got_imag-exp_imag);
            reference_energy += exp_real*exp_real + exp_imag*exp_imag;
            output_index++;
            if (output_index == (transaction_mode_8x8 ? 8 : 4)) begin
                checked_vectors++;
                vector_evm=(reference_energy==0.0)?0.0:$sqrt(error_energy/reference_energy);
                last_evm=vector_evm;
                if (vector_evm > max_evm) max_evm=vector_evm;
                `uvm_info("REF_EVM",$sformatf("vector %0d fixed reference PASS, EVM=%0.6e",checked_vectors,vector_evm),UVM_LOW);
                output_index=0; vector_active=0; error_energy=0.0; reference_energy=0.0;
                if (outstanding_tid[transaction_tid]) begin
                    outstanding_tid[transaction_tid]=0;
                    completed_id_count++;
                    last_completed_tid=transaction_tid;
                    last_completed_tid_valid=1;
                end
                if (pending) begin
                    active_bank=pending_bank; active_version=pending_version; pending=0;
                end
            end
        endfunction
    endclass

    class precoder_performance_monitor extends uvm_component;
        `uvm_component_utils(precoder_performance_monitor)
        virtual performance_if vif;
        longint unsigned expected_cycle_count;
        longint unsigned expected_input_vector_count;
        longint unsigned expected_output_vector_count;
        longint unsigned expected_input_stall_count;
        longint unsigned expected_output_stall_count;
        longint unsigned expected_saturation_count;
        longint unsigned expected_cfg_write_count;
        longint unsigned expected_commit_count;
        longint unsigned wall_cycle;
        longint unsigned accept_cycles[$];
        longint unsigned predicted_base_cycles[$];
        longint unsigned active_output_stalls;
        longint unsigned first_accept_cycle;
        longint unsigned first_complete_cycle;
        longint unsigned last_complete_cycle;
        longint unsigned latency_sum;
        longint unsigned min_latency;
        longint unsigned max_latency;
        int completed_vectors;
        int clear_count;
        int counter_mismatch_count;
        int latency_mismatch_count;
        bit read_pending;
        bit [31:0] read_address;
        bit [31:0] read_expected;
        int checked_counter_reads;

        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual performance_if)::get(this,"","vif",vif))
                `uvm_fatal("NOVIF","performance monitor virtual interface not set")
            reset_model();
            wall_cycle=0; clear_count=0;
            counter_mismatch_count=0; latency_mismatch_count=0;
        endfunction
        function void reset_model();
            expected_cycle_count=0; expected_input_vector_count=0;
            expected_output_vector_count=0; expected_input_stall_count=0;
            expected_output_stall_count=0; expected_saturation_count=0;
            expected_cfg_write_count=0; expected_commit_count=0;
            accept_cycles.delete(); active_output_stalls=0;
            predicted_base_cycles.delete();
            first_accept_cycle=0; first_complete_cycle=0; last_complete_cycle=0;
            latency_sum=0; min_latency='1; max_latency=0; completed_vectors=0;
            read_pending=0; read_address=0; read_expected=0;
            checked_counter_reads=0;
        endfunction
        function automatic bit [31:0] expected_for_address(input bit [31:0] address);
            case (address)
                32'h20: return expected_cycle_count[31:0];
                32'h24: return expected_input_vector_count[31:0];
                32'h28: return expected_output_vector_count[31:0];
                32'h2c: return expected_input_stall_count[31:0];
                32'h30: return expected_output_stall_count[31:0];
                32'h34: return expected_saturation_count[31:0];
                32'h38: return expected_cfg_write_count[31:0];
                32'h3c: return expected_commit_count[31:0];
                default: return 32'd0;
            endcase
        endfunction
        function void compare_counter(input string name,
                                      input bit [31:0] actual,
                                      input longint unsigned expected);
            if (actual !== expected[31:0]) begin
                counter_mismatch_count++;
                `uvm_error("PERF_COUNTER",$sformatf("%s expected %0d got %0d",name,expected[31:0],actual))
            end
        endfunction
        task run_phase(uvm_phase phase);
            bit reset_sample, clear_sample;
            bit input_vector_sample, output_vector_sample;
            bit input_stall_sample, output_stall_sample;
            bit saturation_sample, cfg_write_sample, commit_sample;
            longint unsigned accept_cycle, latency, predicted_latency;
            forever begin
                @(posedge vif.aclk);
                reset_sample=!vif.aresetn; clear_sample=vif.clear_counters;
                input_vector_sample=vif.input_vector;
                output_vector_sample=vif.output_vector;
                input_stall_sample=vif.input_stall;
                output_stall_sample=vif.output_stall;
                saturation_sample=vif.saturation;
                cfg_write_sample=vif.cfg_write;
                commit_sample=vif.commit;

                if (!reset_sample) begin
                    wall_cycle++;
                    if (!clear_sample) begin
                        if (input_vector_sample) begin
                            accept_cycles.push_back(wall_cycle);
                            predicted_base_cycles.push_back(vif.mode_8x8 ? 26 : 9);
                            if (first_accept_cycle == 0) first_accept_cycle=wall_cycle;
                            active_output_stalls=0;
                        end
                        if (output_stall_sample && (accept_cycles.size() != 0))
                            active_output_stalls++;
                        if (output_vector_sample) begin
                            if (accept_cycles.size() == 0) begin
                                latency_mismatch_count++;
                                `uvm_error("PERF_LATENCY","output vector completed without accepted input")
                            end else begin
                                accept_cycle=accept_cycles.pop_front();
                                latency=wall_cycle-accept_cycle;
                                if (predicted_base_cycles.size() == 0) begin
                                    latency_mismatch_count++;
                                    `uvm_error("PERF_LATENCY","missing predicted latency for completed input")
                                    predicted_latency=0;
                                end else begin
                                    predicted_latency=predicted_base_cycles.pop_front()+active_output_stalls;
                                end
                                if (latency != predicted_latency) begin
                                    latency_mismatch_count++;
                                    `uvm_error("PERF_LATENCY",$sformatf("predicted %0d cycles got %0d",predicted_latency,latency))
                                end
                                latency_sum+=latency;
                                if (latency < min_latency) min_latency=latency;
                                if (latency > max_latency) max_latency=latency;
                                completed_vectors++;
                                if (first_complete_cycle == 0) first_complete_cycle=wall_cycle;
                                last_complete_cycle=wall_cycle;
                                active_output_stalls=0;
                            end
                        end
                    end

                    if (vif.arvalid && vif.arready
                            && (vif.araddr >= 32'h20) && (vif.araddr <= 32'h3c)) begin
                        if (read_pending)
                            `uvm_error("PERF_READ","new counter read accepted before prior response")
                        read_pending=1; read_address=vif.araddr;
                        read_expected=expected_for_address(vif.araddr);
                    end
                    if (vif.rvalid && vif.rready && read_pending) begin
                        if ((vif.rresp != 2'b00) || (vif.rdata !== read_expected)) begin
                            counter_mismatch_count++;
                            `uvm_error("PERF_READ",$sformatf("address 0x%08x expected %0d got %0d response %b",read_address,read_expected,vif.rdata,vif.rresp))
                        end
                        checked_counter_reads++;
                        read_pending=0;
                    end
                end

                @(negedge vif.aclk);
                if (reset_sample || clear_sample) begin
                    reset_model();
                    if (clear_sample) clear_count++;
                end else begin
                    expected_cycle_count++;
                    if (input_vector_sample) expected_input_vector_count++;
                    if (output_vector_sample) expected_output_vector_count++;
                    if (input_stall_sample) expected_input_stall_count++;
                    if (output_stall_sample) expected_output_stall_count++;
                    if (saturation_sample) expected_saturation_count++;
                    if (cfg_write_sample) expected_cfg_write_count++;
                    if (commit_sample) expected_commit_count++;
                end
                if (!reset_sample) begin
                    compare_counter("cycle_count",vif.cycle_count,expected_cycle_count);
                    compare_counter("input_vector_count",vif.input_vector_count,expected_input_vector_count);
                    compare_counter("output_vector_count",vif.output_vector_count,expected_output_vector_count);
                    compare_counter("input_stall_count",vif.input_stall_count,expected_input_stall_count);
                    compare_counter("output_stall_count",vif.output_stall_count,expected_output_stall_count);
                    compare_counter("saturation_count",vif.saturation_count,expected_saturation_count);
                    compare_counter("cfg_write_count",vif.cfg_write_count,expected_cfg_write_count);
                    compare_counter("commit_count",vif.commit_count,expected_commit_count);
                end
            end
        endtask
    endclass

    class precoder_env extends uvm_env;
        `uvm_component_utils(precoder_env)
        axi_lite_agent lite_agent; axi_stream_in_agent stream_in_agent; axi_stream_out_agent stream_out_agent;
        uvm_tlm_analysis_fifo#(axi_stream_out_item) output_fifo;
        precoder_scoreboard scoreboard;
        precoder_performance_monitor performance_monitor;
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase); super.build_phase(phase); lite_agent=axi_lite_agent::type_id::create("lite_agent",this); stream_in_agent=axi_stream_in_agent::type_id::create("stream_in_agent",this); stream_out_agent=axi_stream_out_agent::type_id::create("stream_out_agent",this); output_fifo=new("output_fifo",this); scoreboard=precoder_scoreboard::type_id::create("scoreboard",this); performance_monitor=precoder_performance_monitor::type_id::create("performance_monitor",this); endfunction
        function void connect_phase(uvm_phase phase); stream_out_agent.monitor.ap.connect(output_fifo.analysis_export); stream_in_agent.monitor.ap.connect(scoreboard.input_imp); stream_out_agent.monitor.ap.connect(scoreboard.output_imp); lite_agent.monitor.ap.connect(scoreboard.lite_imp); endfunction
    endclass

    class matrix_config_sequence extends uvm_sequence#(axi_lite_item);
        `uvm_object_utils(matrix_config_sequence)
        function new(string name="matrix_config_sequence"); super.new(name); endfunction
        task body(); axi_lite_item tr; integer i; for (i=0;i<16;i=i+1) begin tr=axi_lite_item::type_id::create($sformatf("cfg_%0d",i)); tr.is_write=1; tr.addr=32'h100+i*4; tr.data=((i/4)==(i%4)) ? 32'h4000_0000 : 32'd0; tr.strb=4'hf; tr.w_first=i[0]; start_item(tr); finish_item(tr); if (tr.response!=2'b00) `uvm_fatal("CFGFAIL",$sformatf("matrix write %0d response %b",i,tr.response)); end endtask
    endclass

    class input_vector_sequence extends uvm_sequence#(axi_stream_in_item);
        `uvm_object_utils(input_vector_sequence)
        function new(string name="input_vector_sequence"); super.new(name); endfunction
        task body(); axi_stream_in_item tr; integer i; bit signed [15:0] vals[0:3]; vals[0]=1000; vals[1]=-2000; vals[2]=3000; vals[3]=-4000; for(i=0;i<4;i=i+1) begin tr=axi_stream_in_item::type_id::create($sformatf("input_%0d",i)); tr.real_part=vals[i]; tr.imag_part=0; tr.keep=4'hf; tr.tid=8'h00; tr.last=(i==3); start_item(tr); finish_item(tr); end endtask
    endclass

    class programmable_matrix_sequence extends uvm_sequence#(axi_lite_item);
        `uvm_object_utils(programmable_matrix_sequence)
        bit bank;
        bit mode_8x8;
        bit signed [15:0] coeff_real[0:63];
        bit signed [15:0] coeff_imag[0:63];
        function new(string name="programmable_matrix_sequence"); super.new(name); endfunction
        task body();
            axi_lite_item tr; integer i;
            for (i=0;i<(mode_8x8 ? 64 : 16);i=i+1) begin
                tr=axi_lite_item::type_id::create($sformatf("matrix_b%0d_%0d",bank,i));
                tr.is_write=1; tr.addr=(bank ? 32'h200 : 32'h100)+i*4;
                tr.data={coeff_real[i],coeff_imag[i]}; tr.strb=4'hf;
                tr.w_first=$urandom_range(1); start_item(tr); finish_item(tr);
                if (tr.response != 2'b00)
                    `uvm_fatal("MATRIX_WRITE",$sformatf("Bank%0d coefficient %0d response %b",bank,i,tr.response))
            end
        endtask
    endclass

    class programmable_vector_sequence extends uvm_sequence#(axi_stream_in_item);
        `uvm_object_utils(programmable_vector_sequence)
        bit mode_8x8;
        bit [7:0] tid;
        bit signed [15:0] sample_real[0:7];
        bit signed [15:0] sample_imag[0:7];
        function new(string name="programmable_vector_sequence"); super.new(name); endfunction
        task body();
            axi_stream_in_item tr; integer i;
            for (i=0;i<(mode_8x8 ? 8 : 4);i=i+1) begin
                tr=axi_stream_in_item::type_id::create($sformatf("sample_%0d",i));
                tr.real_part=sample_real[i]; tr.imag_part=sample_imag[i];
                tr.keep=4'hf; tr.tid=tid; tr.last=(i==(mode_8x8 ? 7 : 3)); start_item(tr); finish_item(tr);
            end
        endtask
    endclass

    class mode_write_sequence extends uvm_sequence#(axi_lite_item);
        `uvm_object_utils(mode_write_sequence)
        bit mode_8x8;
        bit [1:0] response;
        function new(string name="mode_write_sequence"); super.new(name); endfunction
        task body();
            axi_lite_item tr=axi_lite_item::type_id::create("mode_write");
            tr.is_write=1; tr.addr=32'h40; tr.data={31'd0,mode_8x8};
            tr.strb=4'hf; tr.w_first=$urandom_range(1);
            start_item(tr); finish_item(tr); response=tr.response;
        endtask
    endclass

    class format_write_sequence extends uvm_sequence#(axi_lite_item);
        `uvm_object_utils(format_write_sequence)
        bit format_12;
        bit [1:0] response;
        function new(string name="format_write_sequence"); super.new(name); endfunction
        task body();
            axi_lite_item tr=axi_lite_item::type_id::create("format_write");
            tr.is_write=1; tr.addr=32'h44; tr.data={31'd0,format_12};
            tr.strb=4'hf; tr.w_first=$urandom_range(1);
            start_item(tr); finish_item(tr); response=tr.response;
        endtask
    endclass

    class quant_write_sequence extends uvm_sequence#(axi_lite_item);
        `uvm_object_utils(quant_write_sequence)
        bit truncate_mode;
        bit wrap_mode;
        bit [1:0] response;
        function new(string name="quant_write_sequence"); super.new(name); endfunction
        task body();
            axi_lite_item tr=axi_lite_item::type_id::create("quant_write");
            tr.is_write=1; tr.addr=32'h48;
            tr.data={30'd0,wrap_mode,truncate_mode}; tr.strb=4'hf;
            tr.w_first=$urandom_range(1);
            start_item(tr); finish_item(tr); response=tr.response;
        endtask
    endclass

    class matrix_commit_sequence extends uvm_sequence#(axi_lite_item);
        `uvm_object_utils(matrix_commit_sequence)
        bit bank; bit [7:0] version;
        function new(string name="matrix_commit_sequence"); super.new(name); endfunction
        task body();
            axi_lite_item tr=axi_lite_item::type_id::create("commit");
            tr.is_write=1; tr.addr=32'h10; tr.data={1'b1,15'd0,version,7'd0,bank};
            tr.strb=4'hf; tr.w_first=$urandom_range(1); start_item(tr); finish_item(tr);
            if (tr.response != 2'b00)
                `uvm_fatal("COMMIT",$sformatf("Bank%0d version %0d response %b",bank,version,tr.response))
        endtask
    endclass

    class axi_lite_read_sequence extends uvm_sequence#(axi_lite_item);
        `uvm_object_utils(axi_lite_read_sequence)
        bit [31:0] addr;
        bit [31:0] read_data;
        bit [1:0] response;
        function new(string name="axi_lite_read_sequence"); super.new(name); endfunction
        task body();
            axi_lite_item tr=axi_lite_item::type_id::create("read");
            tr.is_write=0; tr.addr=addr;
            start_item(tr); finish_item(tr);
            read_data=tr.read_data; response=tr.response;
        endtask
    endclass

    class axi_lite_write_sequence extends uvm_sequence#(axi_lite_item);
        `uvm_object_utils(axi_lite_write_sequence)
        bit [31:0] addr;
        bit [31:0] data;
        bit [3:0] strb=4'hf;
        bit w_first;
        bit [1:0] response;
        function new(string name="axi_lite_write_sequence"); super.new(name); endfunction
        task body();
            axi_lite_item tr=axi_lite_item::type_id::create("write");
            tr.is_write=1; tr.addr=addr; tr.data=data; tr.strb=strb;
            tr.w_first=w_first; start_item(tr); finish_item(tr);
            response=tr.response;
        endtask
    endclass

    class precoder_base_test extends uvm_test;
        `uvm_component_utils(precoder_base_test)
        precoder_env env;
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase); super.build_phase(phase); env=precoder_env::type_id::create("env",this); endfunction
        task run_phase(uvm_phase phase); matrix_config_sequence cfg; input_vector_sequence seq; axi_stream_out_item out; int count; phase.raise_objection(this); wait(env.lite_agent.vif.aresetn); repeat(2) @(posedge env.lite_agent.vif.aclk); cfg=matrix_config_sequence::type_id::create("cfg"); cfg.start(env.lite_agent.sequencer); seq=input_vector_sequence::type_id::create("seq"); seq.start(env.stream_in_agent.sequencer); count=0; repeat(4) begin env.output_fifo.get(out); if (out.version !== 0) `uvm_error("VERSION",$sformatf("expected version 0 got %0d",out.version)); count++; end `uvm_info("PHASE6","UVM scoreboard checked 4 output beats against fixed and floating references",UVM_LOW); phase.drop_objection(this); endtask
    endclass

    class precoder_random_test extends uvm_test;
        `uvm_component_utils(precoder_random_test)
        precoder_env env;
        int vector_count;
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!$value$plusargs("VECTORS=%d",vector_count)) vector_count=12;
            if (vector_count < 4) vector_count=4;
            uvm_config_db#(int)::set(this,"env.stream_in_agent.driver","gap_max",3);
            uvm_config_db#(int)::set(this,"env.stream_out_agent.driver","stall_percent",35);
            uvm_config_db#(int)::set(this,"env.lite_agent.driver","response_stall_max",3);
            env=precoder_env::type_id::create("env",this);
        endfunction
        function automatic bit signed [15:0] random_q14(input int limit);
            int value;
            value=$urandom_range(2*limit)-limit;
            return value;
        endfunction
        task program_random_bank(input bit bank, input int profile);
            programmable_matrix_sequence cfg;
            integer i;
            cfg=programmable_matrix_sequence::type_id::create($sformatf("cfg_bank%0d",bank));
            cfg.bank=bank;
            for (i=0;i<16;i=i+1) begin
                cfg.coeff_real[i]=random_q14(8192);
                cfg.coeff_imag[i]=random_q14(8192);
            end
            if (profile == 0) begin
                cfg.coeff_real[0]=16'sh4000; cfg.coeff_imag[0]=0;
                cfg.coeff_real[5]=-16'sh2000; cfg.coeff_imag[5]=16'sh1000;
            end else if (profile == 1) begin
                cfg.coeff_real[3]=16'sh7fff; cfg.coeff_imag[3]=-16'sh4000;
                cfg.coeff_real[12]=-16'sh7fff; cfg.coeff_imag[12]=16'sh7fff;
            end else begin
                cfg.coeff_real[0]=-16'sh6000; cfg.coeff_imag[0]=-16'sh2000;
                cfg.coeff_real[15]=16'sh7000; cfg.coeff_imag[15]=16'sh3000;
            end
            cfg.start(env.lite_agent.sequencer);
        endtask
        task send_random_vector(input int vector_id);
            programmable_vector_sequence seq;
            integer i;
            seq=programmable_vector_sequence::type_id::create($sformatf("vector_%0d",vector_id));
            for (i=0;i<4;i=i+1) begin
                seq.sample_real[i]=random_q14(32767);
                seq.sample_imag[i]=random_q14(32767);
            end
            if ((vector_id % 5) == 0) begin
                seq.sample_real[0]=16'sh7fff; seq.sample_imag[0]=-16'sh8000;
            end
            if ((vector_id % 7) == 0) begin
                seq.sample_real[3]=-16'sh8000; seq.sample_imag[3]=16'sh7fff;
            end
            seq.start(env.stream_in_agent.sequencer);
        endtask
        task commit_bank(input bit bank, input bit [7:0] version);
            matrix_commit_sequence commit;
            commit=matrix_commit_sequence::type_id::create($sformatf("commit_bank%0d",bank));
            commit.bank=bank; commit.version=version;
            commit.start(env.lite_agent.sequencer);
        endtask
        task wait_for_vector(input int expected_count);
            int timeout;
            timeout=0;
            while ((env.scoreboard.checked_vectors < expected_count) && (timeout < 5000)) begin
                @(posedge env.lite_agent.vif.aclk); timeout++;
            end
            if (env.scoreboard.checked_vectors < expected_count)
                `uvm_fatal("TIMEOUT",$sformatf("expected %0d checked vectors, got %0d",expected_count,env.scoreboard.checked_vectors))
        endtask
        task read_and_check_register(input bit [31:0] addr);
            axi_lite_read_sequence read_seq;
            read_seq=axi_lite_read_sequence::type_id::create($sformatf("read_%08x",addr));
            read_seq.addr=addr; read_seq.start(env.lite_agent.sequencer);
            if (read_seq.response != 2'b00)
                `uvm_fatal("AXIL_READ",$sformatf("read 0x%08x response %b",addr,read_seq.response))
        endtask
        task run_phase(uvm_phase phase);
            integer completed, i, first_bank_vectors, next_vector;
            phase.raise_objection(this);
            wait(env.lite_agent.vif.aresetn); repeat(2) @(posedge env.lite_agent.vif.aclk);
            program_random_bank(0,0); program_random_bank(1,1);
            completed=0; first_bank_vectors=vector_count/2;

            // The first commit is issued immediately after input acceptance,
            // while the Bank0 vector is still being computed or emitted.
            send_random_vector(0); commit_bank(1,8'h31);
            completed=1; next_vector=1;
            if (next_vector < first_bank_vectors) begin
                // Present the next vector while the core is busy. This creates
                // a legal AXI-Stream stall and checks source payload stability.
                send_random_vector(next_vector); completed++; next_vector++;
            end
            wait_for_vector(completed);
            for (i=next_vector;i<first_bank_vectors;i=i+1) begin
                send_random_vector(i); completed++; wait_for_vector(completed);
            end

            program_random_bank(0,2);
            send_random_vector(first_bank_vectors); commit_bank(0,8'ha2);
            completed++; next_vector=first_bank_vectors+1;
            if (next_vector < vector_count) begin
                send_random_vector(next_vector); completed++; next_vector++;
            end
            wait_for_vector(completed);
            for (i=next_vector;i<vector_count;i=i+1) begin
                send_random_vector(i); completed++; wait_for_vector(completed);
            end
            if (env.scoreboard.busy_commit_count < 2)
                `uvm_fatal("BUSY_COMMIT",$sformatf("expected two busy commits, observed %0d",env.scoreboard.busy_commit_count))
            read_and_check_register(32'h0000_000c);
            read_and_check_register(32'h0000_0014);
            read_and_check_register(32'h0000_0018);
            read_and_check_register(32'h0000_0028);
            `uvm_info("PHASE8",$sformatf("checked %0d vectors, %0d busy commits, %0d saturated outputs, max EVM=%0.6e",completed,env.scoreboard.busy_commit_count,env.scoreboard.saturated_output_count,env.scoreboard.max_evm),UVM_LOW)
            phase.drop_objection(this);
        endtask
    endclass

    class precoder_8x8_test extends uvm_test;
        `uvm_component_utils(precoder_8x8_test)
        precoder_env env;
        int vector_count;
        bit signed [15:0] expected_input_real[0:7];
        bit signed [15:0] expected_input_imag[0:7];

        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!$value$plusargs("VECTORS=%d",vector_count)) vector_count=6;
            if (vector_count < 2) vector_count=2;
            uvm_config_db#(int)::set(this,"env.stream_in_agent.driver","gap_max",2);
            uvm_config_db#(int)::set(this,"env.stream_out_agent.driver","stall_percent",30);
            uvm_config_db#(int)::set(this,"env.lite_agent.driver","response_stall_max",2);
            env=precoder_env::type_id::create("env",this);
        endfunction
        function automatic bit signed [15:0] random_q14(input int limit);
            return $signed($urandom_range(2*limit)-limit);
        endfunction
        task write_mode(input bit mode);
            mode_write_sequence seq=mode_write_sequence::type_id::create($sformatf("mode_%0d",mode));
            seq.mode_8x8=mode; seq.start(env.lite_agent.sequencer);
            if (seq.response != 2'b00)
                `uvm_fatal("MODE_WRITE",$sformatf("MODE=%0d response %b",mode,seq.response));
        endtask
        task program_bank8(input bit bank, input bit negate);
            programmable_matrix_sequence cfg;
            integer row, col, index;
            cfg=programmable_matrix_sequence::type_id::create($sformatf("bank8_%0d",bank));
            cfg.bank=bank; cfg.mode_8x8=1;
            for (row=0;row<8;row=row+1)
                for (col=0;col<8;col=col+1) begin
                    index=row*8+col;
                    cfg.coeff_real[index]=(row == col) ? (negate ? -16'sh3000 : 16'sh3000) : random_q14(2048);
                    cfg.coeff_imag[index]=(row == col) ? 0 : random_q14(2048);
                end
            cfg.start(env.lite_agent.sequencer);
        endtask
        task send_vector8(input int vector_id);
            programmable_vector_sequence seq;
            integer i;
            seq=programmable_vector_sequence::type_id::create($sformatf("vector8_%0d",vector_id));
            seq.mode_8x8=1; seq.tid=8'h81;
            for (i=0;i<8;i=i+1) begin
                expected_input_real[i]=random_q14(12000);
                expected_input_imag[i]=random_q14(12000);
                seq.sample_real[i]=expected_input_real[i];
                seq.sample_imag[i]=expected_input_imag[i];
            end
            seq.start(env.stream_in_agent.sequencer);
        endtask
        task wait_for_vectors(input int expected_count);
            int timeout=0;
            while ((env.scoreboard.checked_vectors < expected_count) && (timeout < 12000)) begin
                @(posedge env.lite_agent.vif.aclk); timeout++;
            end
            if (env.scoreboard.checked_vectors < expected_count)
                `uvm_fatal("8X8_TIMEOUT",$sformatf("expected %0d checked vectors got %0d",expected_count,env.scoreboard.checked_vectors));
        endtask
        task run_phase(uvm_phase phase);
            axi_stream_out_item out;
            axi_lite_write_sequence busy_mode_write;
            integer i;
            phase.raise_objection(this);
            wait(env.lite_agent.vif.aresetn); repeat(2) @(posedge env.lite_agent.vif.aclk);
            write_mode(1'b1);
            program_bank8(1'b0,1'b0); program_bank8(1'b1,1'b1);
            send_vector8(0);
            // This write overlaps the 8x8 transaction and must be rejected.
            busy_mode_write=axi_lite_write_sequence::type_id::create("busy_mode_write");
            busy_mode_write.addr=32'h40; busy_mode_write.data=32'd0; busy_mode_write.strb=4'hf;
            busy_mode_write.w_first=0; busy_mode_write.start(env.lite_agent.sequencer);
            if (busy_mode_write.response !== 2'b10)
                `uvm_fatal("MODE_BUSY",$sformatf("busy MODE write response %b",busy_mode_write.response));
            begin
                matrix_commit_sequence commit=matrix_commit_sequence::type_id::create("commit8");
                commit.bank=1; commit.version=8'h72; commit.start(env.lite_agent.sequencer);
            end
            for (i=0;i<8;i=i+1) begin
                env.output_fifo.get(out);
                if (out.antenna !== i[2:0] || out.last !== (i==7)
                        || out.version !== 8'd0)
                    `uvm_fatal("8X8_META",$sformatf("Bank0 output %0d antenna=%0d last=%0d version=%0d",i,out.antenna,out.last,out.version));
            end
            wait_for_vectors(1);
            send_vector8(1);
            wait_for_vectors(2);
            for (i=0;i<8;i=i+1) begin
                env.output_fifo.get(out);
                if (out.antenna !== i[2:0] || out.last !== (i==7)
                        || out.version !== 8'h72)
                    `uvm_fatal("8X8_META",$sformatf("Bank1 output %0d antenna=%0d last=%0d version=%0d",i,out.antenna,out.last,out.version));
            end
            if (env.scoreboard.checked_vectors != 2)
                `uvm_fatal("8X8_COUNT",$sformatf("expected 2 checked vectors got %0d",env.scoreboard.checked_vectors));
            write_mode(1'b0);
            `uvm_info("PHASE13",$sformatf("8x8 UVM reference checked %0d vectors, busy commit=%0d, max EVM=%0.6e",env.scoreboard.checked_vectors,env.scoreboard.busy_commit_count,env.scoreboard.max_evm),UVM_LOW);
            phase.drop_objection(this);
        endtask
    endclass

    class precoder_12bit_test extends uvm_test;
        `uvm_component_utils(precoder_12bit_test)
        precoder_env env;
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            uvm_config_db#(int)::set(this,"env.stream_in_agent.driver","gap_max",1);
            uvm_config_db#(int)::set(this,"env.stream_out_agent.driver","stall_percent",25);
            uvm_config_db#(int)::set(this,"env.lite_agent.driver","response_stall_max",2);
            env=precoder_env::type_id::create("env",this);
        endfunction
        function automatic bit signed [15:0] q10(input int signed value);
            return $signed({{4{value[11]}},value[11:0]});
        endfunction
        task write_format(input bit format_12, input bit expect_ok);
            format_write_sequence seq=format_write_sequence::type_id::create($sformatf("format_%0d",format_12));
            seq.format_12=format_12; seq.start(env.lite_agent.sequencer);
            if (expect_ok && (seq.response != 2'b00))
                `uvm_fatal("FORMAT_WRITE",$sformatf("FORMAT=%0d response %b",format_12,seq.response));
            if (!expect_ok && (seq.response != 2'b10))
                `uvm_fatal("FORMAT_BUSY",$sformatf("busy FORMAT response %b",seq.response));
        endtask
        task write_mode(input bit mode);
            mode_write_sequence seq=mode_write_sequence::type_id::create($sformatf("mode_%0d",mode));
            seq.mode_8x8=mode; seq.start(env.lite_agent.sequencer);
            if (seq.response != 2'b00)
                `uvm_fatal("MODE_WRITE",$sformatf("MODE=%0d response %b",mode,seq.response));
        endtask
        task program_bank8_12(input bit bank);
            programmable_matrix_sequence cfg;
            integer row, col, index;
            cfg=programmable_matrix_sequence::type_id::create($sformatf("bank8_12_%0d",bank));
            cfg.bank=bank; cfg.mode_8x8=1;
            for (row=0;row<8;row=row+1)
                for (col=0;col<8;col=col+1) begin
                    index=row*8+col;
                    cfg.coeff_real[index]=q10((row == col) ? 768 : ((row-col)*17));
                    cfg.coeff_imag[index]=q10((row == col) ? 0 : ((col-row)*9));
                end
            cfg.start(env.lite_agent.sequencer);
        endtask
        task send_vector8_12();
            programmable_vector_sequence seq;
            integer i;
            seq=programmable_vector_sequence::type_id::create("vector8_12");
            seq.mode_8x8=1; seq.tid=8'h91;
            for (i=0;i<8;i=i+1) begin
                seq.sample_real[i]=q10((i % 2) ? -(i+1)*93 : (i+1)*77);
                seq.sample_imag[i]=q10((i % 3) ? (i+1)*31 : -(i+1)*47);
            end
            seq.start(env.stream_in_agent.sequencer);
        endtask
        task run_phase(uvm_phase phase);
            axi_lite_read_sequence read_format;
            axi_lite_write_sequence busy_format;
            integer i;
            phase.raise_objection(this);
            wait(env.lite_agent.vif.aresetn); repeat(2) @(posedge env.lite_agent.vif.aclk);
            write_format(1'b1,1'b1);
            write_mode(1'b1);
            program_bank8_12(1'b0);
            read_format=axi_lite_read_sequence::type_id::create("read_format");
            read_format.addr=32'h44; read_format.start(env.lite_agent.sequencer);
            if ((read_format.response != 2'b00) || (read_format.read_data != 32'd1))
                `uvm_fatal("FORMAT_READ",$sformatf("FORMAT read response=%b data=%h",read_format.response,read_format.read_data));
            send_vector8_12();
            busy_format=axi_lite_write_sequence::type_id::create("busy_format");
            busy_format.addr=32'h44; busy_format.data=32'd0; busy_format.strb=4'hf;
            busy_format.w_first=0; busy_format.start(env.lite_agent.sequencer);
            if (busy_format.response != 2'b10)
                `uvm_fatal("FORMAT_BUSY",$sformatf("expected busy FORMAT SLVERR got %b",busy_format.response));
            wait(env.scoreboard.checked_vectors >= 1);
            if (env.scoreboard.checked_vectors != 1)
                `uvm_fatal("FORMAT_COUNT",$sformatf("expected one checked vector got %0d",env.scoreboard.checked_vectors));
            for (i=0;i<8;i=i+1) begin
                axi_stream_out_item out;
                env.output_fifo.get(out);
                if (out.antenna !== i[2:0] || out.last !== (i==7))
                    `uvm_fatal("FORMAT_META",$sformatf("antenna=%0d last=%0d",out.antenna,out.last));
            end
            `uvm_info("PHASE15",$sformatf("12-bit Q1.10 8x8 reference checked %0d vector, max EVM=%0.6e",env.scoreboard.checked_vectors,env.scoreboard.max_evm),UVM_LOW);
            phase.drop_objection(this);
        endtask
    endclass

    class precoder_quantization_test extends uvm_test;
        `uvm_component_utils(precoder_quantization_test)
        precoder_env env;
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            uvm_config_db#(int)::set(this,"env.stream_in_agent.driver","gap_max",0);
            uvm_config_db#(int)::set(this,"env.stream_out_agent.driver","stall_percent",0);
            uvm_config_db#(int)::set(this,"env.lite_agent.driver","response_stall_max",0);
            env=precoder_env::type_id::create("env",this);
        endfunction
        task configure_diagonal();
            programmable_matrix_sequence cfg;
            integer i;
            cfg=programmable_matrix_sequence::type_id::create("quant_matrix");
            cfg.bank=0; cfg.mode_8x8=0;
            for (i=0;i<16;i=i+1) begin
                cfg.coeff_real[i]=(i/4 == i%4) ? 16'sh7fff : 16'sd0;
                cfg.coeff_imag[i]=16'sd0;
            end
            cfg.start(env.lite_agent.sequencer);
        endtask
        task send_full_scale_vector();
            programmable_vector_sequence seq;
            integer i;
            seq=programmable_vector_sequence::type_id::create("quant_vector");
            seq.mode_8x8=0;
            for (i=0;i<4;i=i+1) begin
                seq.sample_real[i]=16'sh7fff;
                seq.sample_imag[i]=16'sd0;
            end
            seq.start(env.stream_in_agent.sequencer);
        endtask
        task wait_for_vector(input int expected_count);
            int timeout;
            timeout=0;
            while ((env.scoreboard.checked_vectors < expected_count) && (timeout < 5000)) begin
                @(posedge env.lite_agent.vif.aclk); timeout++;
            end
            if (env.scoreboard.checked_vectors < expected_count)
                `uvm_fatal("QUANT_TIMEOUT",$sformatf("expected %0d checked vectors got %0d",expected_count,env.scoreboard.checked_vectors));
        endtask
        task write_quant(input bit truncate_mode, input bit wrap_mode);
            quant_write_sequence seq;
            seq=quant_write_sequence::type_id::create($sformatf("quant_%0d_%0d",truncate_mode,wrap_mode));
            seq.truncate_mode=truncate_mode; seq.wrap_mode=wrap_mode;
            seq.start(env.lite_agent.sequencer);
            if (seq.response != 2'b00)
                `uvm_fatal("QUANT_WRITE",$sformatf("QUANT_CTRL response %b",seq.response));
        endtask
        task run_phase(uvm_phase phase);
            axi_lite_read_sequence read_quant;
            axi_lite_write_sequence busy_quant;
            phase.raise_objection(this);
            wait(env.lite_agent.vif.aresetn); repeat(2) @(posedge env.lite_agent.vif.aclk);
            configure_diagonal();
            write_quant(1'b0,1'b0);
            send_full_scale_vector();
            wait_for_vector(1);
            if (env.scoreboard.saturated_output_count != 4)
                `uvm_fatal("QUANT_SAT",$sformatf("expected four saturated outputs got %0d",env.scoreboard.saturated_output_count));
            write_quant(1'b1,1'b0);
            send_full_scale_vector();
            wait_for_vector(2);
            if (env.scoreboard.saturated_output_count != 8)
                `uvm_fatal("QUANT_TRUNC_SAT",$sformatf("truncation+saturation count=%0d",env.scoreboard.saturated_output_count));
            write_quant(1'b0,1'b1);
            send_full_scale_vector();
            wait_for_vector(3);
            if (env.scoreboard.saturated_output_count != 8)
                `uvm_fatal("QUANT_WRAP_SAT",$sformatf("wrap mode must suppress saturation, count=%0d",env.scoreboard.saturated_output_count));
            read_quant=axi_lite_read_sequence::type_id::create("read_quant");
            read_quant.addr=32'h48; read_quant.start(env.lite_agent.sequencer);
            if ((read_quant.response != 2'b00) || (read_quant.read_data != 32'h2))
                `uvm_fatal("QUANT_READ",$sformatf("QUANT_CTRL read response=%b data=%h",read_quant.response,read_quant.read_data));
            send_full_scale_vector();
            busy_quant=axi_lite_write_sequence::type_id::create("busy_quant");
            busy_quant.addr=32'h48; busy_quant.data=32'h1; busy_quant.strb=4'hf;
            busy_quant.w_first=0; busy_quant.start(env.lite_agent.sequencer);
            if (busy_quant.response != 2'b10)
                `uvm_fatal("QUANT_BUSY",$sformatf("expected busy QUANT_CTRL SLVERR got %b",busy_quant.response));
            wait_for_vector(4);
            `uvm_info("PHASE16",$sformatf("runtime quantization checked %0d vectors; saturations=%0d",env.scoreboard.checked_vectors,env.scoreboard.saturated_output_count),UVM_LOW);
            phase.drop_objection(this);
        endtask
    endclass

    class precoder_tid_test extends uvm_test;
        `uvm_component_utils(precoder_tid_test)
        precoder_env env;
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            uvm_config_db#(int)::set(this,"env.stream_in_agent.driver","gap_max",0);
            uvm_config_db#(int)::set(this,"env.stream_out_agent.driver","stall_percent",45);
            uvm_config_db#(int)::set(this,"env.lite_agent.driver","response_stall_max",1);
            env=precoder_env::type_id::create("env",this);
        endfunction
        task run_phase(uvm_phase phase);
            programmable_matrix_sequence cfg;
            programmable_vector_sequence seq;
            integer i, vector_id;
            phase.raise_objection(this);
            wait(env.lite_agent.vif.aresetn); repeat(2) @(posedge env.lite_agent.vif.aclk);
            cfg=programmable_matrix_sequence::type_id::create("tid_matrix"); cfg.bank=0; cfg.mode_8x8=0;
            for(i=0;i<16;i=i+1) begin cfg.coeff_real[i]=(i/4==i%4)?16'sh4000:0; cfg.coeff_imag[i]=0; end
            cfg.start(env.lite_agent.sequencer);
            for(vector_id=0; vector_id<3; vector_id=vector_id+1) begin
                seq=programmable_vector_sequence::type_id::create($sformatf("tid_vector_%0d",vector_id));
                seq.mode_8x8=0; seq.tid=8'h30+vector_id;
                for(i=0;i<4;i=i+1) begin seq.sample_real[i]=(i+1)*700; seq.sample_imag[i]=-(i+1)*90; end
                seq.start(env.stream_in_agent.sequencer);
                wait(env.scoreboard.checked_vectors >= vector_id+1);
            end
            if (env.scoreboard.checked_vectors != 3)
                `uvm_fatal("TID_COUNT",$sformatf("expected 3 checked vectors got %0d",env.scoreboard.checked_vectors));
            `uvm_info("PHASE17",$sformatf("TID end-to-end checked %0d vectors, max EVM=%0.6e",env.scoreboard.checked_vectors,env.scoreboard.max_evm),UVM_LOW);
            phase.drop_objection(this);
        endtask
    endclass

    class precoder_tid_scoreboard_test extends uvm_test;
        `uvm_component_utils(precoder_tid_scoreboard_test)
        precoder_env env;
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            uvm_config_db#(int)::set(this,"env.stream_in_agent.driver","gap_max",1);
            uvm_config_db#(int)::set(this,"env.stream_out_agent.driver","stall_percent",55);
            uvm_config_db#(int)::set(this,"env.lite_agent.driver","response_stall_max",2);
            env=precoder_env::type_id::create("env",this);
        endfunction
        task run_phase(uvm_phase phase);
            programmable_matrix_sequence cfg;
            programmable_vector_sequence seq;
            integer i, vector_id;
            phase.raise_objection(this);
            wait(env.lite_agent.vif.aresetn); repeat(2) @(posedge env.lite_agent.vif.aclk);
            cfg=programmable_matrix_sequence::type_id::create("tid_tracker_matrix");
            cfg.bank=0; cfg.mode_8x8=0;
            for (i=0;i<16;i=i+1) begin
                cfg.coeff_real[i]=(i/4==i%4)?16'sh4000:0;
                cfg.coeff_imag[i]=0;
            end
            cfg.start(env.lite_agent.sequencer);
            for (vector_id=0; vector_id<4; vector_id=vector_id+1) begin
                seq=programmable_vector_sequence::type_id::create($sformatf("tid_tracker_vector_%0d",vector_id));
                seq.mode_8x8=0; seq.tid=8'ha0+vector_id;
                for (i=0;i<4;i=i+1) begin
                    seq.sample_real[i]=(i+1)*(vector_id+1)*511;
                    seq.sample_imag[i]=-(i+1)*(vector_id+1)*73;
                end
                seq.start(env.stream_in_agent.sequencer);
                wait(env.scoreboard.checked_vectors >= vector_id+1);
            end
            if (env.scoreboard.accepted_id_count != 4
                    || env.scoreboard.completed_id_count != 4)
                `uvm_fatal("TID_TRACK_COUNT",$sformatf("expected accepted=4 completed=4 got accepted=%0d completed=%0d",env.scoreboard.accepted_id_count,env.scoreboard.completed_id_count));
            if ((env.scoreboard.duplicate_accept_count != 0)
                    || (env.scoreboard.unknown_output_count != 0)
                    || (env.scoreboard.duplicate_completion_count != 0)
                    || (env.scoreboard.tid_mismatch_count != 0))
                `uvm_fatal("TID_TRACK_ERROR",$sformatf("duplicate_accept=%0d unknown_output=%0d duplicate_completion=%0d tid_mismatch=%0d",env.scoreboard.duplicate_accept_count,env.scoreboard.unknown_output_count,env.scoreboard.duplicate_completion_count,env.scoreboard.tid_mismatch_count));
            for (i=0;i<256;i=i+1)
                if (env.scoreboard.outstanding_tid[i])
                    `uvm_fatal("TID_TRACK_LEAK",$sformatf("TID %0d remains outstanding",i));
            `uvm_info("PHASE18",$sformatf("ID scoreboard matched %0d accepted and %0d completed transactions; no duplicate, unknown, or leaked IDs",env.scoreboard.accepted_id_count,env.scoreboard.completed_id_count),UVM_LOW);
            phase.drop_objection(this);
        endtask
    endclass

    class precoder_numeric_worst_test extends uvm_test;
        `uvm_component_utils(precoder_numeric_worst_test)
        precoder_env env;
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            uvm_config_db#(int)::set(this,"env.stream_out_agent.driver","stall_percent",50);
            env=precoder_env::type_id::create("env",this);
        endfunction
        task run_phase(uvm_phase phase);
            programmable_matrix_sequence cfg;
            programmable_vector_sequence seq;
            axi_stream_out_item out;
            int signed expected_real[0:3];
            int signed expected_imag[0:3];
            bit expected_saturated[0:3];
            integer i;
            phase.raise_objection(this);
            wait(env.lite_agent.vif.aresetn); repeat(2) @(posedge env.lite_agent.vif.aclk);

            // Feedback search seed 20260808: maximum accumulator/absolute-error case.
            cfg=programmable_matrix_sequence::type_id::create("numeric_worst_matrix");
            cfg.bank=0;
            cfg.coeff_real[0]=32742;   cfg.coeff_imag[0]=32767;
            cfg.coeff_real[1]=-32768;  cfg.coeff_imag[1]=32767;
            cfg.coeff_real[2]=-32730;  cfg.coeff_imag[2]=32767;
            cfg.coeff_real[3]=-32768;  cfg.coeff_imag[3]=-32765;
            cfg.coeff_real[4]=-2762;   cfg.coeff_imag[4]=-14753;
            cfg.coeff_real[5]=32767;   cfg.coeff_imag[5]=-4554;
            cfg.coeff_real[6]=30522;   cfg.coeff_imag[6]=19766;
            cfg.coeff_real[7]=-19094;  cfg.coeff_imag[7]=30282;
            cfg.coeff_real[8]=-26954;  cfg.coeff_imag[8]=4544;
            cfg.coeff_real[9]=-29814;  cfg.coeff_imag[9]=-18705;
            cfg.coeff_real[10]=-5125;  cfg.coeff_imag[10]=-29603;
            cfg.coeff_real[11]=-32740; cfg.coeff_imag[11]=585;
            cfg.coeff_real[12]=32767;  cfg.coeff_imag[12]=-3617;
            cfg.coeff_real[13]=-4693;  cfg.coeff_imag[13]=-19495;
            cfg.coeff_real[14]=32642;  cfg.coeff_imag[14]=-32768;
            cfg.coeff_real[15]=-19644; cfg.coeff_imag[15]=-20931;
            cfg.start(env.lite_agent.sequencer);

            seq=programmable_vector_sequence::type_id::create("numeric_worst_vector");
            seq.sample_real[0]=32738;  seq.sample_imag[0]=-32768;
            seq.sample_real[1]=-32768; seq.sample_imag[1]=-32768;
            seq.sample_real[2]=-32768; seq.sample_imag[2]=-32768;
            seq.sample_real[3]=-32768; seq.sample_imag[3]=32767;
            seq.start(env.stream_in_agent.sequencer);

            expected_real[0]=32767;  expected_imag[0]=-86;
            expected_real[1]=-32768; expected_imag[1]=-32768;
            expected_real[2]=-7199;  expected_imag[2]=32767;
            expected_real[3]=-21035; expected_imag[3]=-21558;
            expected_saturated[0]=1; expected_saturated[1]=1;
            expected_saturated[2]=1; expected_saturated[3]=0;
            for (i=0;i<4;i=i+1) begin
                env.output_fifo.get(out);
                if (($signed(out.real_part) != expected_real[i])
                        || ($signed(out.imag_part) != expected_imag[i]))
                    `uvm_fatal("NUMERIC_WORST",$sformatf("antenna %0d expected %0d+%0dj got %0d+%0dj",i,expected_real[i],expected_imag[i],out.real_part,out.imag_part))
                if (out.saturated !== expected_saturated[i])
                    `uvm_fatal("NUMERIC_WORST",$sformatf("antenna %0d expected saturation %0d got %0d",i,expected_saturated[i],out.saturated))
                if (out.version != 0)
                    `uvm_fatal("NUMERIC_WORST",$sformatf("antenna %0d expected version 0 got %0d",i,out.version))
            end
            if (env.scoreboard.saturated_output_count != 3)
                `uvm_fatal("NUMERIC_WORST",$sformatf("expected 3 saturated outputs, got %0d",env.scoreboard.saturated_output_count))
            `uvm_info("PHASE10","worst numeric case matched 4 bit-exact RTL outputs and saturation flags",UVM_LOW)
            phase.drop_objection(this);
        endtask
    endclass

    class precoder_python_golden_test extends uvm_test;
        `uvm_component_utils(precoder_python_golden_test)
        precoder_env env;
        string golden_file;
        int dataset_index;
        int requested_vectors;
        int signed matrix_real[0:1][0:15];
        int signed matrix_imag[0:1][0:15];
        int signed sample_real[0:3];
        int signed sample_imag[0:3];
        int signed python_expected_real[0:3];
        int signed python_expected_imag[0:3];
        int python_expected_saturated[0:3];
        int vector_record_index;
        int vector_record_bank;
        int vector_record_version;
        real python_implementation_evm;
        real python_end_to_end_evm;
        int python_checked_vectors;
        int python_mismatch_count;
        real max_python_implementation_evm;
        real max_python_end_to_end_evm;

        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!$value$plusargs("GOLDEN_FILE=%s",golden_file))
                golden_file="tb/vectors/stage12_golden_vectors.txt";
            if (!$value$plusargs("DATASET_INDEX=%d",dataset_index)) dataset_index=0;
            if (!$value$plusargs("VECTORS=%d",requested_vectors)) requested_vectors=50;
            uvm_config_db#(int)::set(this,"env.stream_in_agent.driver","gap_max",3);
            uvm_config_db#(int)::set(this,"env.stream_out_agent.driver","stall_percent",35);
            uvm_config_db#(int)::set(this,"env.lite_agent.driver","response_stall_max",3);
            env=precoder_env::type_id::create("env",this);
        endfunction

        task read_bank(input integer fd, input integer expected_bank);
            string marker;
            integer parsed_bank, index, rc;
            rc=$fscanf(fd,"%s %d",marker,parsed_bank);
            if ((rc != 2) || (marker != "BANK") || (parsed_bank != expected_bank))
                `uvm_fatal("PY_FORMAT",$sformatf("expected BANK %0d, marker=%s bank=%0d rc=%0d",expected_bank,marker,parsed_bank,rc))
            for (index=0;index<16;index=index+1) begin
                rc=$fscanf(fd,"%d %d",matrix_real[parsed_bank][index],matrix_imag[parsed_bank][index]);
                if (rc != 2)
                    `uvm_fatal("PY_FORMAT",$sformatf("Bank%0d coefficient %0d is incomplete",parsed_bank,index))
            end
        endtask

        task read_vector(input integer fd);
            string marker;
            integer index, rc;
            rc=$fscanf(fd,"%s %d %d %d",marker,vector_record_index,
                       vector_record_bank,vector_record_version);
            if ((rc != 4) || (marker != "VECTOR"))
                `uvm_fatal("PY_FORMAT",$sformatf("expected VECTOR record, marker=%s rc=%0d",marker,rc))
            for (index=0;index<4;index=index+1) begin
                rc=$fscanf(fd,"%d %d",sample_real[index],sample_imag[index]);
                if (rc != 2)
                    `uvm_fatal("PY_FORMAT",$sformatf("vector %0d input %0d is incomplete",vector_record_index,index))
            end
            for (index=0;index<4;index=index+1) begin
                rc=$fscanf(fd,"%d %d %d",python_expected_real[index],
                           python_expected_imag[index],python_expected_saturated[index]);
                if (rc != 3)
                    `uvm_fatal("PY_FORMAT",$sformatf("vector %0d output %0d is incomplete",vector_record_index,index))
            end
            rc=$fscanf(fd,"%f %f",python_implementation_evm,python_end_to_end_evm);
            if (rc != 2)
                `uvm_fatal("PY_FORMAT",$sformatf("vector %0d EVM fields are incomplete",vector_record_index))
        endtask

        task program_python_bank(input integer bank);
            programmable_matrix_sequence cfg;
            integer index;
            cfg=programmable_matrix_sequence::type_id::create($sformatf("python_bank%0d",bank));
            cfg.bank=bank[0];
            for (index=0;index<16;index=index+1) begin
                cfg.coeff_real[index]=matrix_real[bank][index];
                cfg.coeff_imag[index]=matrix_imag[bank][index];
            end
            cfg.start(env.lite_agent.sequencer);
        endtask

        task send_python_vector();
            programmable_vector_sequence seq;
            integer index;
            seq=programmable_vector_sequence::type_id::create(
                $sformatf("python_vector_%0d",vector_record_index));
            for (index=0;index<4;index=index+1) begin
                seq.sample_real[index]=sample_real[index];
                seq.sample_imag[index]=sample_imag[index];
            end
            seq.start(env.stream_in_agent.sequencer);
        endtask

        task commit_python_bank1(input integer version);
            matrix_commit_sequence commit;
            commit=matrix_commit_sequence::type_id::create("python_commit_bank1");
            commit.bank=1; commit.version=version[7:0];
            commit.start(env.lite_agent.sequencer);
        endtask

        task check_python_outputs();
            axi_stream_out_item out;
            integer antenna, timeout;
            real evm_delta;
            for (antenna=0;antenna<4;antenna=antenna+1) begin
                env.output_fifo.get(out);
                if (out.antenna !== antenna[2:0]) begin
                    python_mismatch_count++;
                    `uvm_error("PY_ANTENNA",$sformatf("vector %0d expected antenna %0d got %0d",vector_record_index,antenna,out.antenna))
                end
                if (out.last !== (antenna == 3)) begin
                    python_mismatch_count++;
                    `uvm_error("PY_LAST",$sformatf("vector %0d antenna %0d TLAST=%0d",vector_record_index,antenna,out.last))
                end
                if (($signed(out.real_part) != python_expected_real[antenna])
                        || ($signed(out.imag_part) != python_expected_imag[antenna])) begin
                    python_mismatch_count++;
                    `uvm_error("PY_FIXED",$sformatf("vector %0d antenna %0d Python expected %0d+%0dj got %0d+%0dj",vector_record_index,antenna,python_expected_real[antenna],python_expected_imag[antenna],out.real_part,out.imag_part))
                end
                if (out.saturated !== python_expected_saturated[antenna][0]) begin
                    python_mismatch_count++;
                    `uvm_error("PY_SAT",$sformatf("vector %0d antenna %0d Python saturation=%0d got %0d",vector_record_index,antenna,python_expected_saturated[antenna],out.saturated))
                end
                if (out.version !== vector_record_version[7:0]) begin
                    python_mismatch_count++;
                    `uvm_error("PY_VERSION",$sformatf("vector %0d Python version=%0d got %0d",vector_record_index,vector_record_version,out.version))
                end
            end

            timeout=0;
            while ((env.scoreboard.checked_vectors < (python_checked_vectors+1))
                    && (timeout < 1000)) begin
                @(posedge env.lite_agent.vif.aclk); timeout++;
            end
            if (env.scoreboard.checked_vectors != (python_checked_vectors+1))
                `uvm_fatal("PY_SCOREBOARD",$sformatf("expected scoreboard vector %0d got %0d",python_checked_vectors+1,env.scoreboard.checked_vectors))
            evm_delta=env.scoreboard.last_evm-python_implementation_evm;
            if (evm_delta < 0.0) evm_delta=-evm_delta;
            if (evm_delta > 1.0e-9) begin
                python_mismatch_count++;
                `uvm_error("PY_EVM",$sformatf("vector %0d Python implementation EVM=%0.12e scoreboard=%0.12e delta=%0.12e",vector_record_index,python_implementation_evm,env.scoreboard.last_evm,evm_delta))
            end
            if (python_implementation_evm > max_python_implementation_evm)
                max_python_implementation_evm=python_implementation_evm;
            if (python_end_to_end_evm > max_python_end_to_end_evm)
                max_python_end_to_end_evm=python_end_to_end_evm;
            python_checked_vectors++;
        endtask

        task run_phase(uvm_phase phase);
            integer fd, rc, format_version, block_count, vectors_per_block;
            integer base_seed, block_loop, parsed_block, data_seed, qam_order;
            integer bank1_version, switch_index, vector_loop;
            integer selected_data_seed, selected_qam, selected_version;
            string marker;
            bit found;

            phase.raise_objection(this);
            wait(env.lite_agent.vif.aresetn); repeat(2) @(posedge env.lite_agent.vif.aclk);
            fd=$fopen(golden_file,"r");
            if (fd == 0)
                `uvm_fatal("PY_FILE",$sformatf("cannot open Python golden file %s",golden_file))
            rc=$fscanf(fd,"%s %d %d %d %d",marker,format_version,block_count,
                       vectors_per_block,base_seed);
            if ((rc != 5) || (marker != "STAGE12") || (format_version != 1))
                `uvm_fatal("PY_FORMAT",$sformatf("bad STAGE12 header in %s",golden_file))
            if ((dataset_index < 0) || (dataset_index >= block_count))
                `uvm_fatal("PY_DATASET",$sformatf("DATASET_INDEX=%0d outside 0..%0d",dataset_index,block_count-1))
            if (requested_vectors != vectors_per_block)
                `uvm_fatal("PY_VECTORS",$sformatf("VECTORS=%0d but file contains %0d per block",requested_vectors,vectors_per_block))

            found=0; python_checked_vectors=0; python_mismatch_count=0;
            max_python_implementation_evm=0.0; max_python_end_to_end_evm=0.0;
            for (block_loop=0;block_loop<block_count;block_loop=block_loop+1) begin
                rc=$fscanf(fd,"%s %d %d %d %d %d",marker,parsed_block,data_seed,
                           qam_order,bank1_version,switch_index);
                if ((rc != 6) || (marker != "BLOCK") || (parsed_block != block_loop))
                    `uvm_fatal("PY_FORMAT",$sformatf("bad BLOCK record at index %0d",block_loop))
                read_bank(fd,0); read_bank(fd,1);
                if (parsed_block == dataset_index) begin
                    selected_data_seed=data_seed; selected_qam=qam_order;
                    selected_version=bank1_version;
                    program_python_bank(0); program_python_bank(1);
                end

                for (vector_loop=0;vector_loop<vectors_per_block;vector_loop=vector_loop+1) begin
                    read_vector(fd);
                    if (parsed_block == dataset_index) begin
                        if ((vector_record_index != vector_loop)
                                || (vector_record_bank != (vector_loop >= switch_index))
                                || (vector_record_version != ((vector_loop >= switch_index) ? bank1_version : 0)))
                            `uvm_fatal("PY_FORMAT",$sformatf("vector %0d has inconsistent index/bank/version",vector_loop))
                        send_python_vector();
                        if (vector_loop == (switch_index-1))
                            commit_python_bank1(bank1_version);
                        check_python_outputs();
                    end
                end
                rc=$fscanf(fd,"%s",marker);
                if ((rc != 1) || (marker != "END_BLOCK"))
                    `uvm_fatal("PY_FORMAT",$sformatf("missing END_BLOCK for block %0d",block_loop))
                if (parsed_block == dataset_index) begin found=1; break; end
            end
            $fclose(fd);

            if (!found) `uvm_fatal("PY_DATASET","selected Python dataset was not found")
            if ((python_checked_vectors != vectors_per_block)
                    || (env.scoreboard.checked_vectors != vectors_per_block))
                `uvm_fatal("PY_COUNT",$sformatf("expected %0d vectors, Python=%0d scoreboard=%0d",vectors_per_block,python_checked_vectors,env.scoreboard.checked_vectors))
            if (env.scoreboard.busy_commit_count != 1)
                `uvm_fatal("PY_COMMIT",$sformatf("expected one busy Bank commit got %0d",env.scoreboard.busy_commit_count))
            if (python_mismatch_count != 0)
                `uvm_fatal("PY_MISMATCH",$sformatf("observed %0d Python golden mismatches",python_mismatch_count))
            `uvm_info("PHASE12",$sformatf("block=%0d data_seed=%0d qam=%0d vectors=%0d python_checked=%0d busy_commits=%0d bank1_version=%0d max_impl_evm=%0.6e max_end_to_end_evm=%0.6e",dataset_index,selected_data_seed,selected_qam,vectors_per_block,python_checked_vectors,env.scoreboard.busy_commit_count,selected_version,max_python_implementation_evm,max_python_end_to_end_evm),UVM_LOW)
            phase.drop_objection(this);
        endtask
    endclass

    class precoder_performance_test extends uvm_test;
        `uvm_component_utils(precoder_performance_test)
        precoder_env env;
        int vector_count;
        int stall_percent;
        int periodic_stall_every;
        int stall_burst_cycles;
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!$value$plusargs("VECTORS=%d",vector_count)) vector_count=12;
            if (vector_count < 6) vector_count=6;
            if (!$value$plusargs("STALL_PERCENT=%d",stall_percent)) stall_percent=35;
            if (!$value$plusargs("PERIODIC_STALL_EVERY=%d",periodic_stall_every)) periodic_stall_every=3;
            if (!$value$plusargs("STALL_BURST_CYCLES=%d",stall_burst_cycles)) stall_burst_cycles=0;
            uvm_config_db#(int)::set(this,"env.stream_in_agent.driver","gap_max",1);
            uvm_config_db#(int)::set(this,"env.stream_out_agent.driver","stall_percent",stall_percent);
            uvm_config_db#(int)::set(this,"env.stream_out_agent.driver","periodic_stall_every",periodic_stall_every);
            uvm_config_db#(int)::set(this,"env.stream_out_agent.driver","stall_burst_cycles",stall_burst_cycles);
            uvm_config_db#(int)::set(this,"env.lite_agent.driver","response_stall_max",2);
            env=precoder_env::type_id::create("env",this);
        endfunction
        task program_performance_bank(input bit bank);
            programmable_matrix_sequence cfg;
            integer i;
            cfg=programmable_matrix_sequence::type_id::create($sformatf("perf_bank%0d",bank));
            cfg.bank=bank;
            for (i=0;i<16;i=i+1) begin
                cfg.coeff_real[i]=16'sd12288;
                cfg.coeff_imag[i]=16'sd0;
            end
            cfg.start(env.lite_agent.sequencer);
        endtask
        task send_performance_vector(input int vector_id);
            programmable_vector_sequence seq;
            integer i;
            seq=programmable_vector_sequence::type_id::create($sformatf("perf_vector%0d",vector_id));
            for (i=0;i<4;i=i+1) begin
                seq.sample_real[i]=16'sd16384;
                seq.sample_imag[i]=16'sd0;
            end
            seq.start(env.stream_in_agent.sequencer);
        endtask
        task write_register(input bit [31:0] address, input bit [31:0] data);
            axi_lite_write_sequence write_seq;
            write_seq=axi_lite_write_sequence::type_id::create($sformatf("write_%08x",address));
            write_seq.addr=address; write_seq.data=data;
            write_seq.w_first=$urandom_range(1);
            write_seq.start(env.lite_agent.sequencer);
            if (write_seq.response != 2'b00)
                `uvm_fatal("PERF_WRITE",$sformatf("address 0x%08x response %b",address,write_seq.response))
        endtask
        task read_counter(input bit [31:0] address, output bit [31:0] data);
            axi_lite_read_sequence read_seq;
            read_seq=axi_lite_read_sequence::type_id::create($sformatf("counter_%08x",address));
            read_seq.addr=address; read_seq.start(env.lite_agent.sequencer);
            if (read_seq.response != 2'b00)
                `uvm_fatal("PERF_READ",$sformatf("address 0x%08x response %b",address,read_seq.response))
            data=read_seq.read_data;
        endtask
        task run_phase(uvm_phase phase);
            matrix_commit_sequence commit;
            bit [31:0] cycle_value, input_vectors, output_vectors;
            bit [31:0] input_stalls, output_stalls, saturations;
            bit [31:0] cfg_writes, commits;
            real average_latency, throughput_vectors_per_second;
            integer i, timeout;
            phase.raise_objection(this);
            wait(env.lite_agent.vif.aresetn); repeat(2) @(posedge env.lite_agent.vif.aclk);
            program_performance_bank(0); program_performance_bank(1);

            write_register(32'h0000_0008,32'h0000_0001);
            repeat(2) @(posedge env.lite_agent.vif.aclk);
            // Generate one post-clear configuration event without changing data.
            write_register(32'h0000_0100,{16'sd12288,16'sd0});
            commit=matrix_commit_sequence::type_id::create("perf_commit_bank1");
            commit.bank=1; commit.version=8'h51; commit.start(env.lite_agent.sequencer);

            send_performance_vector(0);
            commit=matrix_commit_sequence::type_id::create("perf_commit_bank0");
            commit.bank=0; commit.version=8'ha4; commit.start(env.lite_agent.sequencer);
            for (i=1;i<vector_count;i=i+1)
                send_performance_vector(i);

            timeout=0;
            while ((env.performance_monitor.completed_vectors < vector_count) && (timeout < 10000)) begin
                @(posedge env.lite_agent.vif.aclk); timeout++;
            end
            if (env.performance_monitor.completed_vectors != vector_count)
                `uvm_fatal("PERF_TIMEOUT",$sformatf("expected %0d completed vectors got %0d",vector_count,env.performance_monitor.completed_vectors))
            repeat(2) @(posedge env.lite_agent.vif.aclk);

            read_counter(32'h20,cycle_value);
            read_counter(32'h24,input_vectors);
            read_counter(32'h28,output_vectors);
            read_counter(32'h2c,input_stalls);
            read_counter(32'h30,output_stalls);
            read_counter(32'h34,saturations);
            read_counter(32'h38,cfg_writes);
            read_counter(32'h3c,commits);
            repeat(2) @(posedge env.lite_agent.vif.aclk);

            if ((input_vectors != vector_count) || (output_vectors != vector_count))
                `uvm_fatal("PERF_VECTOR_COUNT",$sformatf("expected %0d vectors, input=%0d output=%0d",vector_count,input_vectors,output_vectors))
            if (input_stalls == 0)
                `uvm_fatal("PERF_STALL_COUNT","expected nonzero input stalls")
            if ((stall_percent == 0) && (periodic_stall_every == 0)
                    && (stall_burst_cycles == 0) && (output_stalls != 0))
                `uvm_fatal("PERF_STALL_COUNT",$sformatf("ideal profile expected zero output stalls got %0d",output_stalls))
            if (((stall_percent != 0) || (periodic_stall_every != 0)
                    || (stall_burst_cycles != 0)) && (output_stalls == 0))
                `uvm_fatal("PERF_STALL_COUNT","backpressure profile observed no output stalls")
            if (saturations != 4*vector_count)
                `uvm_fatal("PERF_SAT_COUNT",$sformatf("expected %0d saturated beats got %0d",4*vector_count,saturations))
            if ((cfg_writes != 1) || (commits != 2))
                `uvm_fatal("PERF_CFG_COUNT",$sformatf("expected cfg=1 commit=2 got cfg=%0d commit=%0d",cfg_writes,commits))
            if ((cycle_value == 0) || (env.performance_monitor.checked_counter_reads != 8))
                `uvm_fatal("PERF_READ_COUNT",$sformatf("cycle=%0d checked counter reads=%0d",cycle_value,env.performance_monitor.checked_counter_reads))
            if ((env.performance_monitor.counter_mismatch_count != 0)
                    || (env.performance_monitor.latency_mismatch_count != 0))
                `uvm_fatal("PERF_MODEL",$sformatf("counter mismatches=%0d latency mismatches=%0d",env.performance_monitor.counter_mismatch_count,env.performance_monitor.latency_mismatch_count))
            if ((output_stalls == 0) && ((env.performance_monitor.min_latency != 9)
                    || (env.performance_monitor.max_latency != 9)))
                `uvm_fatal("PERF_IDEAL_LATENCY",$sformatf("ideal latency expected 9 cycles, min=%0d max=%0d",env.performance_monitor.min_latency,env.performance_monitor.max_latency))

            average_latency=env.performance_monitor.latency_sum*1.0/vector_count;
            if (vector_count > 1)
                throughput_vectors_per_second=(vector_count-1)*100000000.0
                    /(env.performance_monitor.last_complete_cycle
                      - env.performance_monitor.first_complete_cycle);
            else throughput_vectors_per_second=0.0;
            `uvm_info("PHASE11",$sformatf("vectors=%0d min_latency=%0d avg_latency=%0.3f max_latency=%0d input_stalls=%0d output_stalls=%0d throughput_at_100MHz=%0.3f_vectors_per_s stall_percent=%0d periodic=%0d burst=%0d",vector_count,env.performance_monitor.min_latency,average_latency,env.performance_monitor.max_latency,input_stalls,output_stalls,throughput_vectors_per_second,stall_percent,periodic_stall_every,stall_burst_cycles),UVM_LOW)
            phase.drop_objection(this);
        endtask
    endclass
endpackage
