# Khởi tạo Oh My Posh với theme mặc định (jandedobbeleer)
oh-my-posh init pwsh --config 'https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/atomic.omp.json' | Invoke-Expression

# Cấu hình PSReadLine cho tính năng Auto-suggestions
Import-Module PSReadLine

# Bật gợi ý lệnh dựa trên lịch sử (History)
Set-PSReadLineOption -PredictionSource History

# Hiển thị gợi ý trên cùng một dòng (InlineView) mờ ảo
Set-PSReadLineOption -PredictionViewStyle InlineView

# Sử dụng phím mũi tên phải (RightArrow) để chấp nhận gợi ý
Set-PSReadLineKeyHandler -Key RightArrow -Function ForwardChar

Register-ArgumentCompleter -Native -CommandName terraform -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    $env:COMP_LINE = $commandAst.ToString()
    terraform | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    Remove-Item Env:\COMP_LINE
}