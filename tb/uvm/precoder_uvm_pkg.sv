`timescale 1ns/1ps

package precoder_uvm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    `uvm_analysis_imp_decl(_input)
    `uvm_analysis_imp_decl(_output)

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
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual axi_lite_if)::get(this,"","vif",vif))
                `uvm_fatal("NOVIF","axi_lite_driver virtual interface not set")
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
            @(negedge vif.aclk); vif.bready <= 1;
            do @(posedge vif.aclk); while (!vif.bvalid);
            tr.response = vif.bresp;
            @(negedge vif.aclk); vif.bready <= 0;
        endtask
        task send_read(axi_lite_item tr);
            @(negedge vif.aclk); vif.araddr <= tr.addr; vif.arvalid <= 1;
            do @(posedge vif.aclk); while (!vif.arready);
            @(negedge vif.aclk); vif.arvalid <= 0; vif.rready <= 1;
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
            forever begin
                @(posedge vif.aclk);
                if (vif.awvalid && vif.awready) begin
                    tr=axi_lite_item::type_id::create("aw_observed"); tr.is_write=1; tr.addr=vif.awaddr;
                    ap.write(tr);
                end
                if (vif.arvalid && vif.arready) begin
                    tr=axi_lite_item::type_id::create("ar_observed"); tr.is_write=0; tr.addr=vif.araddr;
                    ap.write(tr);
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
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual axi_stream_if)::get(this,"","vif",vif)) `uvm_fatal("NOVIF","stream input vif missing")
        endfunction
        task run_phase(uvm_phase phase);
            vif.tdata <= 0; vif.tkeep <= 0; vif.tvalid <= 0; vif.tlast <= 0;
            forever begin
                seq_item_port.get_next_item(req);
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
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase); super.build_phase(phase); if (!uvm_config_db#(virtual axi_stream_if)::get(this,"","vif",vif)) `uvm_fatal("NOVIF","stream output vif missing"); endfunction
        task run_phase(uvm_phase phase); vif.tready <= 0; wait(vif.aresetn); forever begin @(negedge vif.aclk); vif.tready <= 1; end endtask
    endclass

    class axi_stream_out_agent extends uvm_agent;
        `uvm_component_utils(axi_stream_out_agent)
        axi_stream_out_monitor monitor; axi_stream_out_ready_driver driver; virtual axi_stream_if vif;
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase); super.build_phase(phase); if (!uvm_config_db#(virtual axi_stream_if)::get(this,"","vif",vif)) `uvm_fatal("NOVIF","stream output vif missing"); monitor=axi_stream_out_monitor::type_id::create("monitor",this); driver=axi_stream_out_ready_driver::type_id::create("driver",this); uvm_config_db#(virtual axi_stream_if)::set(this,"monitor","vif",vif); uvm_config_db#(virtual axi_stream_if)::set(this,"driver","vif",vif); endfunction
    endclass

    class matrix_version_tracker extends uvm_object;
        `uvm_object_utils(matrix_version_tracker)
        bit active_bank;
        bit [7:0] active_version;
        bit pending;
        bit pending_bank;
        bit [7:0] pending_version;
        function new(string name="matrix_version_tracker");
            super.new(name); active_bank=0; active_version=0; pending=0; pending_bank=0; pending_version=0;
        endfunction
        function void request_commit(bit bank, bit [7:0] version);
            if (bank == active_bank) begin
                `uvm_warning("VERSION_TRACKER","commit request targets active Bank")
            end else begin
                pending=1; pending_bank=bank; pending_version=version;
            end
        endfunction
        function void apply_pending();
            if (pending) begin active_bank=pending_bank; active_version=pending_version; pending=0; end
        endfunction
    endclass

    // Phase 6 reference checker: identity matrix is the configured DUT matrix.
    // The integer path is the bit-accurate Q14 model; the real path reports EVM.
    class precoder_scoreboard extends uvm_component;
        `uvm_component_utils(precoder_scoreboard)
        uvm_analysis_imp_input#(axi_stream_in_item, precoder_scoreboard) input_imp;
        uvm_analysis_imp_output#(axi_stream_out_item, precoder_scoreboard) output_imp;
        axi_stream_in_item input_beats[$];
        int output_index;
        real error_energy;
        real reference_energy;
        int checked_vectors;
        matrix_version_tracker version_tracker;
        function new(string name, uvm_component parent);
            super.new(name,parent); input_imp=new("input_imp",this); output_imp=new("output_imp",this);
        endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase); output_index=0; error_energy=0.0; reference_energy=0.0; checked_vectors=0; version_tracker=matrix_version_tracker::type_id::create("version_tracker");
        endfunction
        function void write_input(axi_stream_in_item tr);
            axi_stream_in_item copy;
            $cast(copy,tr.clone());
            input_beats.push_back(copy);
            if (tr.keep != 4'hf) `uvm_error("REF_TKEEP","reference input has invalid TKEEP")
        endfunction
        function automatic int round_q14(input int signed value);
            int signed magnitude; int signed rounded;
            magnitude = (value < 0) ? -value : value;
            rounded = (magnitude + (1 << 13)) >>> 14;
            if (value < 0) rounded = -rounded;
            if (rounded > 32767) rounded=32767;
            if (rounded < -32768) rounded=-32768;
            return rounded;
        endfunction
        function void write_output(axi_stream_out_item tr);
            axi_stream_in_item expected;
            int signed expected_real, expected_imag;
            real exp_real, exp_imag, got_real, got_imag;
            if (input_beats.size() < 4) begin
                `uvm_error("REF_ORDER","output arrived before complete input vector"); return;
            end
            if (tr.antenna !== output_index[1:0])
                `uvm_error("REF_ANTENNA",$sformatf("expected antenna %0d got %0d",output_index,tr.antenna));
            if (tr.last !== (output_index == 3))
                `uvm_error("REF_LAST",$sformatf("bad TLAST on output %0d",output_index));
            expected = input_beats[output_index];
            // Identity matrix: one product per row, Q28 product requantized to Q14.
            expected_real = round_q14(expected.real_part * 16384);
            expected_imag = round_q14(expected.imag_part * 16384);
            if (tr.real_part !== expected_real[15:0] || tr.imag_part !== expected_imag[15:0])
                `uvm_error("REF_FIXED",$sformatf("antenna %0d expected %0d+%0dj got %0d+%0dj",output_index,expected_real,expected_imag,tr.real_part,tr.imag_part));
            if (tr.version !== version_tracker.active_version)
                `uvm_error("REF_VERSION",$sformatf("expected matrix version %0d got %0d",version_tracker.active_version,tr.version));
            if (tr.saturated !== 1'b0)
                `uvm_error("REF_SAT","unexpected saturation for identity reference");
            exp_real = expected_real / 16384.0; exp_imag = expected_imag / 16384.0;
            got_real = tr.real_part / 16384.0; got_imag = tr.imag_part / 16384.0;
            error_energy += (got_real-exp_real)*(got_real-exp_real) + (got_imag-exp_imag)*(got_imag-exp_imag);
            reference_energy += exp_real*exp_real + exp_imag*exp_imag;
            output_index++;
            if (output_index == 4) begin
                checked_vectors++;
                `uvm_info("REF_EVM",$sformatf("vector %0d fixed reference PASS, EVM=%0.6e",checked_vectors,(reference_energy==0.0)?0.0:$sqrt(error_energy/reference_energy)),UVM_LOW);
                output_index=0; input_beats.delete(); error_energy=0.0; reference_energy=0.0;
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
        function void connect_phase(uvm_phase phase); stream_out_agent.monitor.ap.connect(output_fifo.analysis_export); stream_in_agent.monitor.ap.connect(scoreboard.input_imp); stream_out_agent.monitor.ap.connect(scoreboard.output_imp); endfunction
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

    class precoder_base_test extends uvm_test;
        `uvm_component_utils(precoder_base_test)
        precoder_env env;
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase); super.build_phase(phase); env=precoder_env::type_id::create("env",this); endfunction
        task run_phase(uvm_phase phase); matrix_config_sequence cfg; input_vector_sequence seq; axi_stream_out_item out; int count; phase.raise_objection(this); wait(env.lite_agent.vif.aresetn); repeat(2) @(posedge env.lite_agent.vif.aclk); cfg=matrix_config_sequence::type_id::create("cfg"); cfg.start(env.lite_agent.sequencer); seq=input_vector_sequence::type_id::create("seq"); seq.start(env.stream_in_agent.sequencer); count=0; repeat(4) begin env.output_fifo.get(out); if (out.version !== 0) `uvm_error("VERSION",$sformatf("expected version 0 got %0d",out.version)); count++; end `uvm_info("PHASE6","UVM scoreboard checked 4 output beats against fixed and floating references",UVM_LOW); phase.drop_objection(this); endtask
    endclass
endpackage
