param([string]$VivadoRoot='./local_inputs/2023.2')
$ErrorActionPreference='Stop'
Push-Location $PSScriptRoot
try {
    function Invoke-Checked([string]$Executable,[string[]]$Arguments) {
        & $Executable @Arguments
        if ($LASTEXITCODE -ne 0) { throw "Tool failed: $Executable" }
    }
    $xvlog=Join-Path $VivadoRoot 'bin/xvlog.bat'
    $xelab=Join-Path $VivadoRoot 'bin/xelab.bat'
    $xsim=Join-Path $VivadoRoot 'bin/xsim.bat'
    $xpm=Join-Path $VivadoRoot 'data/ip/xpm'
    Invoke-Checked $xvlog @('-sv',"$xpm/xpm_cdc/hdl/xpm_cdc.sv","$xpm/xpm_memory/hdl/xpm_memory.sv","$xpm/xpm_fifo/hdl/xpm_fifo.sv",'-log','xpm_compile.log')
    $reference=@('reset_sync','level_sync','cdc_mailbox','ads62p24_init','ram256x16_8k') | ForEach-Object { "reference/$_.v" }
    $rtl=@('trigger_geometry','ads62p24_pack_runtime','mig_write_runtime','adc_capture_runtime','ddr_block_reader','adc_record_store','fmc_record_link') | ForEach-Object { "rtl/$_.v" }
    Invoke-Checked $xvlog ($reference+$rtl+@('-log','verilog2001_compile.log'))
    Invoke-Checked $xvlog @('-sv','sim/simulation_support.v','sim/tb_trigger_capture.sv','sim/tb_fmc_trigger_protocol.sv','sim/tb_trigger_geometry.sv',"$VivadoRoot/data/verilog/src/glbl.v",'-log','testbench_compile.log')
    $tests=@(
        @('tb_trigger_geometry','geometry_test','geometry_simulation.log','ALL 3535 GEOMETRY TESTS PASSED'),
        @('tb_fmc_trigger_protocol','protocol_test','protocol_simulation.log','ALL FMC TRIGGER PROTOCOL TESTS PASSED'),
        @('tb_trigger_capture','trigger_test','simulation.log','ALL TRIGGER CAPTURE TESTS PASSED')
    )
    foreach($test in $tests) {
        Invoke-Checked $xelab @($test[0],'glbl','-L','unisims_ver','-L','secureip','-s',$test[1],'-log',"$($test[1])_elaborate.log")
        Invoke-Checked $xsim @($test[1],'-runall','-log',$test[2])
        $result=[IO.File]::ReadAllText((Join-Path $PSScriptRoot $test[2]))
        if(!$result.Contains($test[3]) -or $result.Contains('Fatal:')) {throw "Test did not pass: $($test[0])"}
    }
    Write-Output 'ALL THREE REGRESSION SUITES PASSED'
} finally { Pop-Location }
