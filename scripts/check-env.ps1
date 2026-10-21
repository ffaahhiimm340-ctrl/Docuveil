# Reports which Docuveil dev tools are present on this Windows machine.
$tools = 'git','gh','flutter','dart','py','python','node','docker','tesseract','psql','java'
foreach ($t in $tools) {
    $c = Get-Command $t -ErrorAction SilentlyContinue
    if ($c) { "{0,-10} {1}" -f $t, $c.Source } else { "{0,-10} MISSING" -f $t }
}
if (Get-Command py -ErrorAction SilentlyContinue) { py -0p }
Get-PSDrive C | ForEach-Object { "Free disk GB: {0}" -f [math]::Round($_.Free / 1GB, 1) }
"RAM GB: {0}" -f [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
