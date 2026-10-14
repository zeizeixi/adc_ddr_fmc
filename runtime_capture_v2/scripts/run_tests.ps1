param(
    [string]$VivadoBin='./local_inputs/bin',
    [Parameter(Mandatory=$true)][string]$WorkDir,
    [switch]$ReuseGeneratedIP
)
$ErrorActionPreference='Stop'
$packageRoot=Split-Path -Parent $PSScriptRoot
if(Test-Path -LiteralPath $WorkDir){
    if(!$ReuseGeneratedIP){throw 'Use a fresh test directory, or explicitly reuse its generated IP'}
}else{New-Item -ItemType Directory -Path $WorkDir | Out-Null}
$testRoot=(Resolve-Path -LiteralPath $WorkDir).Path
function Run-Checked([string]$toolName,[string[]]$toolArgs){
    & (Join-Path $VivadoBin $toolName) @toolArgs
    if($LASTEXITCODE -ne 0){throw "$toolName failed: $LASTEXITCODE"}
}
Push-Location -LiteralPath $testRoot
try{
    $ipProject=(Join-Path $testRoot 'ip_project').Replace('\','/')
    $genScript=(Join-Path $PSScriptRoot 'create_sim_ip.tcl').Replace('\','/')
    if(!$ReuseGeneratedIP){Run-Checked 'vivado.bat' @('-mode','batch','-notrace','-source',$genScript,'-tclargs',$ipProject)}
    $vivadoRoot=(Split-Path -Parent $VivadoBin).Replace('\','/')
    $lines=@()
    # Use Vivado's read-only precompiled XPM library (-L xpm), like the FIFO model.
    # Do not compile into library xpm: xsim.ini maps it to the installation folder.
    foreach($f in Get-ChildItem -LiteralPath (Join-Path $packageRoot 'rtl') -Filter '*.v'){
        $lines+='verilog xil_defaultlib "{0}"' -f $f.FullName.Replace('\','/')
    }
    $lines+='verilog xil_defaultlib "{0}"' -f "$ipProject/capture_test.gen/sources_1/ip/adc_fifo_256x512/sim/adc_fifo_256x512.v"
    $lines+='sv xil_defaultlib "{0}"' -f (Join-Path $packageRoot 'tb/tb_record_store.sv').Replace('\','/')
    $lines+='verilog xil_defaultlib "{0}/data/verilog/src/glbl.v"' -f $vivadoRoot
    Set-Content -LiteralPath 'sources.prj' -Value $lines -Encoding UTF8
    Run-Checked 'xvlog.bat' @('-prj','sources.prj','-log','compile.log')
    Run-Checked 'xelab.bat' @('--debug','typical','--relax','-L','xpm','-L','fifo_generator_v13_2_9','-L','unisims_ver','-L','unimacro_ver','-L','secureip','xil_defaultlib.tb_record_store','xil_defaultlib.glbl','-s','record_store_sim','-log','elaborate.log')
    Run-Checked 'xsim.bat' @('record_store_sim','-runall','-log','record_store.log')
    if(!(Select-String -LiteralPath 'record_store.log' -SimpleMatch 'PASS tb_record_store: ALL TESTS' -Quiet)){throw 'Simulation did not pass'}
}finally{Pop-Location}
