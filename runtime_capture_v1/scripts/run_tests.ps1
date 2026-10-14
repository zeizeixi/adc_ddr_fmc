param(
    [string]$VivadoBin='./local_inputs/bin',
    [Parameter(Mandatory=$true)][string]$WorkDir,
    [switch]$ReuseGeneratedIP,
    [switch]$FullLength
)
$ErrorActionPreference='Stop'
$packageRoot=Split-Path -Parent $PSScriptRoot
if(Test-Path -LiteralPath $WorkDir){
    if(!$ReuseGeneratedIP){throw 'Use a fresh test directory or explicitly select -ReuseGeneratedIP'}
} else {New-Item -ItemType Directory -Path $WorkDir | Out-Null}
$testRoot=(Resolve-Path -LiteralPath $WorkDir).Path
function Run-Checked([string]$toolName,[string[]]$toolArgs){
    & (Join-Path $VivadoBin $toolName) @toolArgs
    if($LASTEXITCODE -ne 0){throw "$toolName failed: $LASTEXITCODE"}
}
Push-Location -LiteralPath $testRoot
try {
    $ipProject=(Join-Path $testRoot 'ip_project').Replace('\','/')
    $genScript=(Join-Path $PSScriptRoot 'create_sim_ip.tcl').Replace('\','/')
    if(!$ReuseGeneratedIP){Run-Checked 'vivado.bat' @('-mode','batch','-notrace','-source',$genScript,'-tclargs',$ipProject)}
    $lines=@()
    foreach($f in Get-ChildItem -LiteralPath (Join-Path $packageRoot 'rtl') -Filter '*.v'){
        if($f.Name -ne 'adc_ddr_fbg484_top.v'){$lines+='verilog xil_defaultlib "{0}"' -f $f.FullName.Replace('\','/')}
    }
    $lines+='verilog xil_defaultlib "{0}"' -f "$ipProject/capture_test.gen/sources_1/ip/adc_fifo_256x512/sim/adc_fifo_256x512.v"
    $lines+='sv xil_defaultlib "{0}"' -f (Join-Path $packageRoot 'tb/tb_runtime.sv').Replace('\','/')
    $lines+='verilog xil_defaultlib "{0}"' -f (Join-Path (Split-Path -Parent $VivadoBin) 'data/verilog/src/glbl.v').Replace('\','/')
    Set-Content -LiteralPath 'sources.prj' -Value $lines -Encoding UTF8
    Run-Checked 'xvlog.bat' @('-prj','sources.prj','-log','compile.log')
    Run-Checked 'xelab.bat' @('--debug','typical','--relax','-L','fifo_generator_v13_2_9','-L','unisims_ver','-L','unimacro_ver','-L','secureip','xil_defaultlib.tb_runtime','xil_defaultlib.glbl','-s','runtime_sim','-log','elaborate.log')
    $simArgs=@('runtime_sim','-runall','-log','runtime.log')
    if($FullLength){$simArgs+=@('-testplusarg','FULL_LENGTH')}
    Run-Checked 'xsim.bat' $simArgs
    if(!(Select-String -LiteralPath 'runtime.log' -SimpleMatch 'PASS tb_runtime: ALL TESTS' -Quiet)){throw 'Simulation did not report PASS'}
} finally {Pop-Location}
