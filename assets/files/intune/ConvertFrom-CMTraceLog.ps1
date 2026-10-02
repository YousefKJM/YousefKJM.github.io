function ConvertFrom-CMTraceLog {
    <# Turns IME / CMTrace-format logs into objects you can sort, filter and export #>
    param([Parameter(Mandatory)][string[]]$Path)
    $rx = '<!\[LOG\[(?<msg>[\s\S]*?)\]LOG\]!><time="(?<time>[\d:.]+)[^"]*" date="(?<date>[\d-]+)" component="(?<comp>[^"]*)"[^>]*type="(?<type>\d)" thread="(?<thread>\d+)"'
    foreach ($file in Get-ChildItem $Path) {
        $text = Get-Content $file.FullName -Raw
        foreach ($m in [regex]::Matches($text, $rx)) {
            $ts = [datetime]::ParseExact("$($m.Groups['date'].Value) $($m.Groups['time'].Value.Substring(0,12))",
                                         "M-d-yyyy HH:mm:ss.fff", [cultureinfo]::InvariantCulture)
            [pscustomobject]@{
                Time      = $ts
                Log       = $file.Name
                Component = $m.Groups['comp'].Value
                Severity  = @{ '1'='Info'; '2'='Warning'; '3'='Error' }[$m.Groups['type'].Value]
                Thread    = $m.Groups['thread'].Value
                Message   = $m.Groups['msg'].Value.Trim()
            }
        }
    }
}
# Example: one timeline across all IME logs, errors only
# ConvertFrom-CMTraceLog .\logs\*.log | Where-Object Severity -eq 'Error' | Sort-Object Time | Export-Csv timeline.csv -NoTypeInformation
