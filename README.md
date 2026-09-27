# Windows Server Active Directory & Security Automation Lab

## 1. Project Overview
This lab demonstrates the deployment of a secure corporate network infrastructure from scratch. I built a virtualized environment using a Windows Server Domain Controller and a Windows 10/11 client, implemented security policies (GPOs), and automated user onboarding using PowerShell.

* **Objective:** Simulate an enterprise IT environment to practice identity management, network configuration, and security baselining.
* **Skills Demonstrated:** Networking (DHCP/DNS/Static Routing), Active Directory Management, PowerShell Scripting, Cybersecurity (Least Privilege).

---

## 2. Tools & Environment
* **Hypervisor:** Oracle VirtualBox
* **Server OS:** Windows Server 2025 (Evaluation)
* **Client OS:** Windows 11
* **Scripting Language:** PowerShell

---

## 3. Step-by-Step Implementation
        
### Step 1: Virtual Network & VM Setup
I deployed two virtual machines in VirtualBox. To ensure they could communicate securely without exposing them to the public internet, I configured them on an isolated internal network.
* Configured a **NAT Network / Internal Network** in VirtualBox.
* Assigned a static IP address to the Windows Server (`192.168.10.10`).
* Verified connectivity by successfully pinging the server from the client machine.

![alt text](images/Screenshot%202026-09-27%20000923.png)

### Step 2: Active Directory Installation & Domain Promotion
Next, I installed the Active Directory Domain Services (AD DS) role on the server and promoted it to a Domain Controller for the domain `[hartt.local]`.
* Installed AD DS via Server Manager.
* Set up DNS to resolve local domain queries.

![alt text](images/Screenshot%202026-09-27%20005504.png)

### Step 3: Designing the OU Structure
I created an Organizational Unit (OU) structure to mimic a real corporate hierarchy. This allows for clean object management and targeted security policies.
* Created a parent OU named `Corporate_Users`.
* Created sub-OUs for `IT`, `HR`, and `Finance`.

![alt text](images/Screenshot%202026-09-27%20013556.png)
![alt text](images/Screenshot%202026-09-27%20014119.png)

### Step 4: Automating User Onboarding via PowerShell
Instead of manually creating accounts, I wrote a PowerShell script to parse a corporate CSV file and automatically generate 50 user profiles with standardized usernames, secure initial passwords, and assigned department OUs. The script also includes logic to email each new user their credentials directly rather than storing passwords in a log file, reducing the exposure of sensitive data at rest. In this lab enviroment email delivery was implemented using Powershells's Send-MailMessage cmdlet but was not connected to a live SMTP relay, since setting up a mail server was outside the scope of this project: in a production enviroment, this would intergrate with the organization's existing mail infrastructure or a secure credntial-delivery ststem.

```powershell
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
```

![alt text](images/Screenshot%202026-09-27%20150532.png)
![alt text](images/Screenshot%202026-09-27%20175129.png)
![alt text](images/Screenshot%202026-09-27%20175631.png)

### Step 5: Hardening the Environment with GPOs
To satisfy corporate security compliance (aligning with Security+ principles), I implemented Group Policy Objects (GPOs) across the domain:
* Enforced password history and complex 12-character minimum passwords.
* Disabled USB storage devices to prevent data exfiltration.
* Blocked local administrator account usage on client workstations.

![alt text](images/Screenshot%202026-09-27%20161912.png)
![alt text](images/Screenshot%202026-09-27%20163108.png)
![alt text](images/Screenshot%202026-09-27%20175757.png)

---


### 6. Key Takeaways & Lessons Learned
* **Automation Efficiency:** Learned how a simple PowerShell script can save dozens of manual entry hours and prevent human typing errors.
* **Network Troubleshooting:** Resolved a DNS conflict early in the lab by ensuring the client VM pointed directly to the Domain Controller's IP address for DNS resolution.
* **Security Baselines:** Gained hands-on experience applying the concept of "Least Privilege" using Active Directory GPOs.
* **Production Security & Secret Management:** While this script safely generates randomized per-user passwords in memory, running an automation script in a production enterprise environment requires strict protection of administrative credentials. To scale this securely, I would eliminate any future risk of hardcoded or exposed session tokens by integrating the script with the `Microsoft.PowerShell.SecretManagement` module or an enterprise vault (like Azure Key Vault) to retrieve high-privilege credentials dynamically at runtime.

