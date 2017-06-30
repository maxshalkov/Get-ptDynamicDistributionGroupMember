function Get-ptDynamicDistributionGroupMember{
<#
    .SYNOPSIS
        Вывод членов динамической группы

    .DESCRIPTION
        Возвращает список членов динамической группы

    .PARAMETER Name
        Alias (наименование) динамической группы рассылки

    .NOTES
        Author:  maxshalkov

    .EXAMPLE
        Get-ptDynamicDistributionGroupMember -Name "Dyn_Group"
#>

[CmdletBinding()]
param(
    [parameter(Mandatory=$true)]
    [system.string]$Name
)

begin{

    $Domain = $env:USERDNSDOMAIN -split "\." # or other domain

    $Searcher = [ADSISearcher]"(&(objectclass=group)(cn=psconfig))"  
    $Searcher.SearchRoot = "LDAP://DC=$($Domain[0]),DC=$($Domain[1])"
    $Searcher.PropertiesToLoad.Add("info") | Out-Null
    $psconfig_path = ($Searcher.FindAll().properties.info -split "\n")[0].trim()


    if (-not ($psconfig = Get-Content $psconfig_path -ErrorAction SilentlyContinue | ConvertFrom-Json)){
        throw "__pterror: Файл глобальных настроек недоступен"
    }

    $CommandName = "Get-DynamicDistributionGroup","Get-Recipient"

    if (-not (Test-Connection $psconfig.mailserver -Quiet)){
        throw "__pterror: $($psconfig.mailserver) недоступен"
    }

    $SessionProperties = @{
        ConfigurationName = 'Microsoft.Exchange'
        ConnectionUri     = "http://$($psconfig.mailserver)/powershell"
        Authentication    = 'Kerberos'
    }
    $Session = New-PSSession @SessionProperties 
} 

process{
    Import-PSSession $Session -CommandName $CommandName -AllowClobber | Out-Null

    if (($FTE = Get-DynamicDistributionGroup $Name -ErrorAction SilentlyContinue -DomainController $psconfig.PDC).isvalid){
        Get-Recipient -RecipientPreviewFilter $FTE.RecipientFilter -DomainController $psconfig.PDC
    } else {
        Remove-PSSession $Session
        throw "__pterror: Не удалось выполнить операцию, поскольку объект $Name не найден"
    }
}

end{
    Remove-PSSession $Session
}

}