workflow Disable-AllDeployedSchedules
{
    ##Requires Az.Accounts
    ##Requires Az.Automation
    ##Requires Az.Resources

    param
    (
        [Parameter(Mandatory=$true,
        HelpMessage="comma separated strings with Resource Group Names")]
        # defined as array of strings. Example: ["rg1","rg2","rg3"]
        [string[]]$resourceGroupNames
    )
    $resourceGroupNames
    $runbookName = "Patch-MicrosoftOMSComputers"
    $report = @()
    $connectionName = "AzureRunAsConnection"
    try
    {
        # Get the connection "AzureRunAsConnection" (Uses custom role "Update Schedules")
        $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName         
        # Logging in to Azure with Service Principal
        Write-Output "Logging into Azure subscription..."
        $null = Add-AzAccount `
            -ServicePrincipal `
            -TenantId $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint `
            -ErrorAction Stop
        Write-Output "Successfully logged into Azure subscription"
    }
    catch 
    {
        throw "Error.$($_.exception.message)"
    }

    try 
    {
        ForEach -Parallel ($resourceGroupName in $resourceGroupNames)
        {
            $automationAccounts = Get-AzResource -ResourceGroupName $resourceGroupName -ResourceType "Microsoft.Automation/automationAccounts" | Select-Object Name
            ForEach -Parallel ($automationAccount in $automationAccounts)
            {
                $runbookSchedules = Get-AzAutomationScheduledRunbook -runbookName $runbookName -ResourceGroupName $resourceGroupName -automationAccountName $automationAccount.Name
                foreach ($runbookSchedule in $runbookSchedules)
                {
                    $schedule = Get-AzAutomationSchedule -Name $runbookSchedule.ScheduleName -ResourceGroupName $resourceGroupName -automationAccountName $automationAccount.Name
                    if ($schedule.IsEnabled -eq $true)
                    {
                        Write-Output "Disabling schedule $($schedule.Name)"
                        $WORKFLOW:report += InlineScript
                        {
                            $using:schedule | Set-AzAutomationSchedule -IsEnabled $false
                        }
                    }
                }
            }
        }    
    }
    catch 
    {
        throw "Error. $($_.exception.message)"
    }
    finally
    {
        if($report)
        {
            InlineScript
            {
                Write-Output "Found $($using:report.count) schedules."
                $using:report | ConvertTo-Json
            }
        }
        else
        {
            Write-Output "Nothing found!"
        }
    }    
}