# rz-lib
A collection of commonly used RTL and verification modules

- ```rtl/spi```: Single-clock SPI interface
- ```rtl/fifo```: Collection of FIFO designs  
    - ```axis_data_fifo_0```: AXI-Stream FIFO, configurable asynchronous or synchronous, RAM based
    - ```afifo```: Asynchronous FIFO, register based
    - ```sfifo```: Synchronous FIFO, register based
    - ```psync1```: One-way pulse synchronizer for single isolated pulses, ie. no handshake/ack
    - ```pipe```: Pipeline stage, configurable rigid or bubble collapsing
- ```rtl/bram```: Collection of inferrable RAM models for FPGA technologies 
    - ```dp_ram```: Dual-port RAM model, infers a BRAM (Xilinx) or EBR (Lattice) with BE (byte enable)
    - ```dp_ram_be```: Dual-port RAM model with byte enable, infers a BRAM (Xilinx) or EBR (Lattice)
