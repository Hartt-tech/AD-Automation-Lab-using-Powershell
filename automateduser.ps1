<#
.SYNOPSIS
    Automates new-hire onboarding by creating AD user accounts from a CSV file.
.DESCRIPTION
    Reads employee data from a CSV, generates standardized usernames and secure
    passwords, assigns accounts to the correct department OU, creates the AD
    account, and emails credentials to each new user.
.NOTES
    Author: Tyler Hartt
    Date: September 27th 2026
#>

Import-Module ActiveDirectory
Add-Type -AssemblyName System.Web

# Load new hire data
$Users = Import-Csv -Path ".\NewHires.csv"

# Map departments to their corresponding OU
$OUMap = @{
    "Finance" = "OU=Finance,OU=Corp_Users,DC=hartt,DC=local"
    "HR"      = "OU=HR,OU=Corp_Users,DC=hartt,DC=local"
    "IT"      = "OU=IT,OU=Corp_Users,DC=hartt,DC=local"
}

foreach ($User in $Users) {

    # Generate standardized username (first initial + last name)
    $Username = ($User.FirstName.Substring(0,1) + $User.LastName).ToLower()

    # Generate a secure random password
    $Password = [System.Web.Security.Membership]::GeneratePassword(12, 3)
    $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force

    # Look up the correct OU based on department
    $TargetOU = $OUMap[$User.Department]

    if (-not $TargetOU) {
        Write-Host "Skipping $($User.FirstName) $($User.LastName): no matching OU for department '$($User.Department)'" -ForegroundColor Red
        continue
    }

    # Create the AD account
    try {
        New-ADUser -Name "$($User.FirstName) $($User.LastName)" `
            -SamAccountName $Username `
            -UserPrincipalName "$Username@hartt.local" `
            -GivenName $User.FirstName `
            -Surname $User.LastName `
            -Title $User.JobTitle `
            -Path $TargetOU `
            -AccountPassword $SecurePassword `
            -ChangePasswordAtLogon $true `
            -Enabled $true `
            -ErrorAction Stop

        Write-Host "Created account for $($User.FirstName) $($User.LastName) -> Username: $Username -> OU: $TargetOU" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to create account for $($User.FirstName) $($User.LastName): $($_.Exception.Message)" -ForegroundColor Red
        continue
    }

    # Email the new credentials to the user
    # NOTE: Requires a configured SMTP relay. In production, this would integrate
    # with the organization's mail server or a secure credential delivery system.
    $EmailBody = @"
Hello $($User.FirstName),

Your new account has been created.

Username: $Username
Temporary Password: $Password

You will be required to change this password at first login.
"@

    try {
        Send-MailMessage -To "$Username@hartt.local" `
            -From "admin@hartt.local" `
            -Subject "Your New Account Credentials" `
            -Body $EmailBody `
            -SmtpServer "your-smtp-server" `
            -ErrorAction Stop
    }
    catch {
        Write-Host "Account created for $Username, but email failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}