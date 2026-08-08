`timescale 1ns/1ps

package precoder_uvm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

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

    class precoder_env extends uvm_env;
        `uvm_component_utils(precoder_env)
        axi_lite_agent lite_agent; axi_stream_in_agent stream_in_agent; axi_stream_out_agent stream_out_agent;
        uvm_tlm_analysis_fifo#(axi_stream_out_item) output_fifo;
        function new(string name, uvm_component parent); super.new(name,parent); endfunction
        function void build_phase(uvm_phase phase); super.build_phase(phase); lite_agent=axi_lite_agent::type_id::create("lite_agent",this); stream_in_agent=axi_stream_in_agent::type_id::create("stream_in_agent",this); stream_out_agent=axi_stream_out_agent::type_id::create("stream_out_agent",this); output_fifo=new("output_fifo",this); endfunction
        function void connect_phase(uvm_phase phase); stream_out_agent.monitor.ap.connect(output_fifo.analysis_export); endfunction
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
        task run_phase(uvm_phase phase); matrix_config_sequence cfg; input_vector_sequence seq; axi_stream_out_item out; int count; phase.raise_objection(this); wait(env.lite_agent.vif.aresetn); repeat(2) @(posedge env.lite_agent.vif.aclk); cfg=matrix_config_sequence::type_id::create("cfg"); cfg.start(env.lite_agent.sequencer); seq=input_vector_sequence::type_id::create("seq"); seq.start(env.stream_in_agent.sequencer); count=0; repeat(4) begin env.output_fifo.get(out); if (out.antenna !== count[1:0]) `uvm_error("META",$sformatf("expected antenna %0d got %0d",count,out.antenna)); if (out.last !== (count==3)) `uvm_error("LAST",$sformatf("bad TLAST on output %0d",count)); if (out.version !== 0) `uvm_error("VERSION",$sformatf("expected version 0 got %0d",out.version)); count++; end `uvm_info("PHASE5","UVM AXI smoke test received 4 output beats",UVM_LOW); phase.drop_objection(this); endtask
    endclass
endpackage
