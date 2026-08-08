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
        rand bit last;
        `uvm_object_utils_begin(axi_stream_in_item)
            `uvm_field_int(real_part, UVM_DEFAULT)
            `uvm_field_int(imag_part, UVM_DEFAULT)
            `uvm_field_int(keep, UVM_DEFAULT)
            `uvm_field_int(last, UVM_DEFAULT)
        `uvm_object_utils_end
        function new(string name="axi_stream_in_item"); super.new(name); endfunction
    endclass

    class axi_stream_out_item extends uvm_sequence_item;
        bit signed [15:0] real_part;
        bit signed [15:0] imag_part;
        bit [1:0] antenna;
        bit saturated;
        bit [7:0] version;
        bit last;
        `uvm_object_utils_begin(axi_stream_out_item)
            `uvm_field_int(real_part, UVM_DEFAULT)
            `uvm_field_int(imag_part, UVM_DEFAULT)
            `uvm_field_int(antenna, UVM_DEFAULT)
            `uvm_field_int(saturated, UVM_DEFAULT)
            `uvm_field_int(version, UVM_DEFAULT)
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
            vif.tdata <= 0; vif.tkeep <= 0; vif.tvalid <= 0; vif.tlast <= 0;
            forever begin
                seq_item_port.get_next_item(req);
                repeat ($urandom_range(gap_max)) @(posedge vif.aclk);
                @(negedge vif.aclk); vif.tdata <= {req.real_part,req.imag_part}; vif.tkeep <= req.keep; vif.tlast <= req.last; vif.tvalid <= 1;
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
                    tr.real_part=vif.tdata[31:16]; tr.imag_part=vif.tdata[15:0]; tr.keep=vif.tkeep; tr.last=vif.tlast; ap.write(tr);
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
                    tr=axi_stream_out_item::type_id::create("output_observed"); tr.real_part=vif.tdata[31:16]; tr.imag_part=vif.tdata[15:0]; tr.antenna=vif.tuser[1:0]; tr.saturated=vif.tuser[2]; tr.version=vif.tuser[10:3]; tr.last=vif.tlast; ap.write(tr);
                end
            end
        endtask
    endclass

    class axi_stream_out_ready_driver extends uvm_component;
        `uvm_component_utils(axi_stream_out_ready_driver)
        virtual axi_stream_if vif;
        int stall_percent;
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase); super.build_phase(phase); if (!uvm_config_db#(virtual axi_stream_if)::get(this,"","vif",vif)) `uvm_fatal("NOVIF","stream output vif missing"); if (!uvm_config_db#(int)::get(this,"","stall_percent",stall_percent)) stall_percent=0; endfunction
        task run_phase(uvm_phase phase); vif.tready <= 0; wait(vif.aresetn); forever begin @(negedge vif.aclk); vif.tready <= ($urandom_range(99) >= stall_percent); end endtask
    endclass

    class axi_stream_out_agent extends uvm_agent;
        `uvm_component_utils(axi_stream_out_agent)
        axi_stream_out_monitor monitor; axi_stream_out_ready_driver driver; virtual axi_stream_if vif;
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase); super.build_phase(phase); if (!uvm_config_db#(virtual axi_stream_if)::get(this,"","vif",vif)) `uvm_fatal("NOVIF","stream output vif missing"); monitor=axi_stream_out_monitor::type_id::create("monitor",this); driver=axi_stream_out_ready_driver::type_id::create("driver",this); uvm_config_db#(virtual axi_stream_if)::set(this,"monitor","vif",vif); uvm_config_db#(virtual axi_stream_if)::set(this,"driver","vif",vif); endfunction
    endclass

    // The scoreboard mirrors both coefficient banks from completed AXI-Lite
    // writes. A matrix/version snapshot is taken when the fourth input beat is
    // accepted, so a busy commit cannot change an in-flight vector.
    class precoder_scoreboard extends uvm_component;
        `uvm_component_utils(precoder_scoreboard)
        uvm_analysis_imp_input#(axi_stream_in_item, precoder_scoreboard) input_imp;
        uvm_analysis_imp_output#(axi_stream_out_item, precoder_scoreboard) output_imp;
        uvm_analysis_imp_lite#(axi_lite_item, precoder_scoreboard) lite_imp;
        bit signed [15:0] matrix_real[0:1][0:3][0:3];
        bit signed [15:0] matrix_imag[0:1][0:3][0:3];
        bit signed [15:0] vector_real[0:3];
        bit signed [15:0] vector_imag[0:3];
        int signed expected_real[0:3];
        int signed expected_imag[0:3];
        bit expected_saturated[0:3];
        real floating_real[0:3];
        real floating_imag[0:3];
        int input_index;
        int output_index;
        bit vector_active;
        bit transaction_bank;
        bit [7:0] transaction_version;
        bit active_bank;
        bit [7:0] active_version;
        bit pending;
        bit pending_bank;
        bit [7:0] pending_version;
        real error_energy;
        real reference_energy;
        real max_evm;
        int checked_vectors;
        int busy_commit_count;
        int saturated_output_count;
        function new(string name, uvm_component parent);
            super.new(name,parent); input_imp=new("input_imp",this);
            output_imp=new("output_imp",this); lite_imp=new("lite_imp",this);
        endfunction
        function void build_phase(uvm_phase phase);
            integer bank, row, col;
            super.build_phase(phase);
            input_index=0; output_index=0; vector_active=0;
            active_bank=0; active_version=0; pending=0;
            error_energy=0.0; reference_energy=0.0; max_evm=0.0;
            checked_vectors=0; busy_commit_count=0; saturated_output_count=0;
            for (bank=0; bank<2; bank=bank+1)
                for (row=0; row<4; row=row+1)
                    for (col=0; col<4; col=col+1) begin
                        matrix_real[bank][row][col]=0;
                        matrix_imag[bank][row][col]=0;
                    end
        endfunction
        function automatic int signed round_q14(input longint signed value,
                                                  output bit saturated);
            longint signed magnitude; longint signed rounded;
            magnitude = (value < 0) ? -value : value;
            rounded = (magnitude + (64'sd1 << 13)) >>> 14;
            if (value < 0) rounded = -rounded;
            saturated=0;
            if (rounded > 32767) begin rounded=32767; saturated=1; end
            if (rounded < -32768) begin rounded=-32768; saturated=1; end
            return rounded;
        endfunction
        function void calculate_expected();
            integer row, col;
            longint signed acc_real, acc_imag;
            bit sat_real, sat_imag;
            for (row=0; row<4; row=row+1) begin
                acc_real=0; acc_imag=0; floating_real[row]=0.0; floating_imag[row]=0.0;
                for (col=0; col<4; col=col+1) begin
                    acc_real += $signed(matrix_real[transaction_bank][row][col])
                              * $signed(vector_real[col])
                              - $signed(matrix_imag[transaction_bank][row][col])
                              * $signed(vector_imag[col]);
                    acc_imag += $signed(matrix_real[transaction_bank][row][col])
                              * $signed(vector_imag[col])
                              + $signed(matrix_imag[transaction_bank][row][col])
                              * $signed(vector_real[col]);
                    floating_real[row] +=
                        (matrix_real[transaction_bank][row][col] / 16384.0)
                        * (vector_real[col] / 16384.0)
                        - (matrix_imag[transaction_bank][row][col] / 16384.0)
                        * (vector_imag[col] / 16384.0);
                    floating_imag[row] +=
                        (matrix_real[transaction_bank][row][col] / 16384.0)
                        * (vector_imag[col] / 16384.0)
                        + (matrix_imag[transaction_bank][row][col] / 16384.0)
                        * (vector_real[col] / 16384.0);
                end
                expected_real[row]=round_q14(acc_real,sat_real);
                expected_imag[row]=round_q14(acc_imag,sat_imag);
                expected_saturated[row]=sat_real || sat_imag;
            end
        endfunction
        function void write_lite(axi_lite_item tr);
            int index, row, col;
            bit bank;
            if (!tr.is_write || tr.response != 2'b00) return;
            if (((tr.addr >= 32'h100) && (tr.addr <= 32'h13c))
                    || ((tr.addr >= 32'h200) && (tr.addr <= 32'h23c))) begin
                bank=(tr.addr >= 32'h200);
                index=(tr.addr & 32'h3f) >> 2; row=index/4; col=index%4;
                matrix_real[bank][row][col]=tr.data[31:16];
                matrix_imag[bank][row][col]=tr.data[15:0];
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
            if (tr.last !== (input_index == 3))
                `uvm_error("REF_INPUT_LAST",$sformatf("bad input TLAST on beat %0d",input_index))
            vector_real[input_index]=tr.real_part;
            vector_imag[input_index]=tr.imag_part;
            if (input_index == 3) begin
                transaction_bank=active_bank; transaction_version=active_version;
                vector_active=1; calculate_expected(); input_index=0;
            end else input_index++;
        endfunction
        function void write_output(axi_stream_out_item tr);
            real exp_real, exp_imag, got_real, got_imag, vector_evm;
            if (!vector_active) begin
                `uvm_error("REF_ORDER","output arrived before complete input vector"); return;
            end
            if (tr.antenna !== output_index[1:0])
                `uvm_error("REF_ANTENNA",$sformatf("expected antenna %0d got %0d",output_index,tr.antenna));
            if (tr.last !== (output_index == 3))
                `uvm_error("REF_LAST",$sformatf("bad TLAST on output %0d",output_index));
            if (tr.real_part !== expected_real[output_index][15:0]
                    || tr.imag_part !== expected_imag[output_index][15:0])
                `uvm_error("REF_FIXED",$sformatf("antenna %0d expected %0d+%0dj got %0d+%0dj",output_index,expected_real[output_index],expected_imag[output_index],tr.real_part,tr.imag_part));
            if (tr.version !== transaction_version)
                `uvm_error("REF_VERSION",$sformatf("expected matrix version %0d got %0d",transaction_version,tr.version));
            if (tr.saturated !== expected_saturated[output_index])
                `uvm_error("REF_SAT",$sformatf("antenna %0d expected saturation %0d got %0d",output_index,expected_saturated[output_index],tr.saturated));
            if (tr.saturated) saturated_output_count++;
            exp_real = floating_real[output_index];
            exp_imag = floating_imag[output_index];
            got_real = tr.real_part / 16384.0; got_imag = tr.imag_part / 16384.0;
            error_energy += (got_real-exp_real)*(got_real-exp_real) + (got_imag-exp_imag)*(got_imag-exp_imag);
            reference_energy += exp_real*exp_real + exp_imag*exp_imag;
            output_index++;
            if (output_index == 4) begin
                checked_vectors++;
                vector_evm=(reference_energy==0.0)?0.0:$sqrt(error_energy/reference_energy);
                if (vector_evm > max_evm) max_evm=vector_evm;
                `uvm_info("REF_EVM",$sformatf("vector %0d fixed reference PASS, EVM=%0.6e",checked_vectors,vector_evm),UVM_LOW);
                output_index=0; vector_active=0; error_energy=0.0; reference_energy=0.0;
                if (pending) begin
                    active_bank=pending_bank; active_version=pending_version; pending=0;
                end
            end
        endfunction
    endclass

    class precoder_env extends uvm_env;
        `uvm_component_utils(precoder_env)
        axi_lite_agent lite_agent; axi_stream_in_agent stream_in_agent; axi_stream_out_agent stream_out_agent;
        uvm_tlm_analysis_fifo#(axi_stream_out_item) output_fifo;
        precoder_scoreboard scoreboard;
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase); super.build_phase(phase); lite_agent=axi_lite_agent::type_id::create("lite_agent",this); stream_in_agent=axi_stream_in_agent::type_id::create("stream_in_agent",this); stream_out_agent=axi_stream_out_agent::type_id::create("stream_out_agent",this); output_fifo=new("output_fifo",this); scoreboard=precoder_scoreboard::type_id::create("scoreboard",this); endfunction
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
        task body(); axi_stream_in_item tr; integer i; bit signed [15:0] vals[0:3]; vals[0]=1000; vals[1]=-2000; vals[2]=3000; vals[3]=-4000; for(i=0;i<4;i=i+1) begin tr=axi_stream_in_item::type_id::create($sformatf("input_%0d",i)); tr.real_part=vals[i]; tr.imag_part=0; tr.keep=4'hf; tr.last=(i==3); start_item(tr); finish_item(tr); end endtask
    endclass

    class programmable_matrix_sequence extends uvm_sequence#(axi_lite_item);
        `uvm_object_utils(programmable_matrix_sequence)
        bit bank;
        bit signed [15:0] coeff_real[0:15];
        bit signed [15:0] coeff_imag[0:15];
        function new(string name="programmable_matrix_sequence"); super.new(name); endfunction
        task body();
            axi_lite_item tr; integer i;
            for (i=0;i<16;i=i+1) begin
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
        bit signed [15:0] sample_real[0:3];
        bit signed [15:0] sample_imag[0:3];
        function new(string name="programmable_vector_sequence"); super.new(name); endfunction
        task body();
            axi_stream_in_item tr; integer i;
            for (i=0;i<4;i=i+1) begin
                tr=axi_stream_in_item::type_id::create($sformatf("sample_%0d",i));
                tr.real_part=sample_real[i]; tr.imag_part=sample_imag[i];
                tr.keep=4'hf; tr.last=(i==3); start_item(tr); finish_item(tr);
            end
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
endpackage
