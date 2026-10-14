param(
    [Parameter(Mandatory=$true)][string]$VivadoBin,
    [Parameter(Mandatory=$true)][string]$WorkDir
)
# Windows runner: direct xvlog/xelab/xsim avoids the host launch_simulation path issue.
# WorkDir must be a fresh writable directory; no existing project is overwritten.
$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent $PSScriptRoot
if (Test-Path -LiteralPath $WorkDir) { throw 'WorkDir already exists; choose a fresh directory.' }
New-Item -ItemType Directory -Path $WorkDir | Out-Null
$testRoot = (Resolve-Path -LiteralPath $WorkDir).Path
$ipProject = (Join-Path $testRoot 'ip_project').Replace('\','/')
$genScript = (Join-Path $PSScriptRoot 'create_sim_ip.tcl').Replace('\','/')
function Invoke-Checked([string]$toolName, [string[]]$toolArgs) {
    & (Join-Path $VivadoBin $toolName) @toolArgs
    if ($LASTEXITCODE -ne 0) { throw "$toolName failed: $LASTEXITCODE" }
}
Push-Location -LiteralPath $testRoot
try {
    Invoke-Checked 'vivado.bat' @('-mode','batch','-notrace','-source',$genScript,'-log','generate.log','-journal','generate.jou','-tclargs',$ipProject)
    $generatedWrapper = Join-Path $ipProject 'capture_test.gen/sources_1/ip/adc_fifo_256x512/sim/adc_fifo_256x512.v'
    $prjLines = @()
    foreach ($source in Get-ChildItem -LiteralPath (Join-Path $packageRoot 'rtl') -Filter '*.v') {
        $prjLines += 'verilog xil_defaultlib "{0}"' -f $source.FullName.Replace('\','/')
    }
    foreach ($source in Get-ChildItem -LiteralPath (Join-Path $packageRoot 'tb') -Filter '*.sv') {
        $prjLines += 'sv xil_defaultlib "{0}"' -f $source.FullName.Replace('\','/')
    }
    $prjLines += 'verilog xil_defaultlib "{0}"' -f $generatedWrapper.Replace('\','/')
    $glbl = Join-Path (Split-Path -Parent $VivadoBin) 'data/verilog/src/glbl.v'
    $prjLines += 'verilog xil_defaultlib "{0}"' -f $glbl.Replace('\','/')
    Set-Content -LiteralPath 'sources.prj' -Value $prjLines -Encoding UTF8
    Invoke-Checked 'xvlog.bat' @('-prj','sources.prj','-log','compile.log')
    # Vivado 2023.2 FIFO Generator 13.2 revision 9. Adjust if using a different release.
    foreach ($testName in @('tb_capture','tb_overflow')) {
        $snapshot = $testName + '_sim'
        Invoke-Checked 'xelab.bat' @('--debug','typical','--relax','-L','fifo_generator_v13_2_9','-L','unisims_ver','-L','unimacro_ver','-L','secureip',"xil_defaultlib.$testName",'xil_defaultlib.glbl','-s',$snapshot,'-log',"${testName}_elab.log")
        Invoke-Checked 'xsim.bat' @($snapshot,'-runall','-log',"${testName}.log")
        if (-not (Select-String -LiteralPath "${testName}.log" -SimpleMatch "PASS $testName" -Quiet)) {
            throw "$testName did not report PASS. Inspect its simulation log."
        }
    }
    Write-Output 'PASS: both ADC/FIFO tests completed.'
} finally { Pop-Location }
