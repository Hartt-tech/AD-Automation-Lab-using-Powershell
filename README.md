# Windows Server Active Directory & Security Automation Lab

## 1. Project Overview
This lab demonstrates the deployment of a secure corporate network infrastructure from scratch. I built a virtualized environment using a Windows Server Domain Controller and a Windows 10/11 client, implemented security policies (GPOs), and automated user onboarding using PowerShell.

* **Objective:** Simulate an enterprise IT environment to practice identity management, network configuration, and security baselining.
* **Skills Demonstrated:** Networking (Static Routing), Active Directory Management, PowerShell Scripting, Cybersecurity (Least Privilege).

---

## 2. Tools & Environment
* **Hypervisor:** Oracle VirtualBox
* **Server OS:** Windows Server 2025 (Evaluation)
* **Client OS:** Windows 11 Pro
* **Scripting Language:** PowerShell

---

## 3. Step-by-Step Implementation
        
### Step 1: Virtual Network & VM Setup
I deployed two virtual machines in VirtualBox. To ensure they could communicate securely without exposing them to the public internet, I configured them on an isolated internal network.
* Configured a **Internal Network** in VirtualBox.
* Assigned a static IP address to the Windows Server (`192.168.10.10`).
* Verified connectivity by successfully pinging the server from the client machine.

![alt text](images/Screenshot%202026-09-27%20000923.png)

### Step 2: Active Directory Installation & Domain Promotion
Next, I installed the Active Directory Domain Services (AD DS) role on the server and promoted it to a Domain Controller for the domain `hartt.local`.
* Installed AD DS via Server Manager.
* Set up DNS to resolve local domain queries.

![alt text](images/Screenshot%202026-09-27%20005504.png)

### Step 3: Designing the OU Structure
I created an Organizational Unit (OU) structure to mimic a real corporate hierarchy. This allows for clean object management and targeted security policies.
* Created a parent OU named `Corp_Users`.
* Created a parent OU named `Corp_Workstations`.
* Created sub-OUs for `IT`, `HR`, and `Finance`.

![alt text](images/Screenshot%202026-09-27%20013556.png)
![alt text](images/Screenshot%202026-09-27%20014119.png)

### Step 4: Generating Sample Data
Running this script once generates a fresh NewHires.csv with 50 unique dummy employees, randomly distributed across the Finance, HR, and IT departments. The main automateduser.ps1 script then requires no changes to process it, since it simply loops through however many rows the CSV contains.

```powershell
$FirstNames = "James","Mary","John","Patricia","Robert","Jennifer","Michael","Linda","William","Elizabeth",
              "David","Barbara","Richard","Susan","Joseph","Jessica","Thomas","Sarah","Charles","Karen",
              "Chris","Nancy","Daniel","Lisa","Matthew","Betty","Anthony","Margaret","Mark","Sandra",
              "Donald","Ashley","Steven","Kimberly","Paul","Emily","Andrew","Donna","Joshua","Michelle",
              "Kenneth","Dorothy","Kevin","Carol","Brian","Amanda","George","Melissa","Edward","Deborah"

$LastNames = "Smith","Johnson","Williams","Brown","Jones","Garcia","Miller","Davis","Rodriguez","Martinez",
             "Hernandez","Lopez","Gonzalez","Wilson","Anderson","Thomas","Taylor","Moore","Jackson","Martin",
             "Lee","Perez","Thompson","White","Harris","Sanchez","Clark","Ramirez","Lewis","Robinson",
             "Walker","Young","Allen","King","Wright","Scott","Torres","Nguyen","Hill","Flores",
             "Green","Adams","Nelson","Baker","Hall","Rivera","Campbell","Mitchell","Carter","Roberts"

$Departments = "Finance","HR","IT"
$JobTitles = @{
    "Finance" = "Accountant"
    "HR"      = "HR Specialist"
    "IT"      = "IT Technician"
}

$DummyUsers = for ($i = 0; $i -lt 50; $i++) {
    $Dept = $Departments | Get-Random
    [PSCustomObject]@{
        FirstName = $FirstNames[$i]
        LastName  = $LastNames[$i]
        Department = $Dept
        JobTitle   = $JobTitles[$Dept]
    }
}

$DummyUsers | Export-Csv -Path ".\NewHires.csv" -NoTypeInformation
```

### Step 5: Automating User Onboarding via PowerShell

Instead of manually creating accounts, I wrote a PowerShell script to parse a corporate CSV file and automatically generate 50 user profiles with standardized usernames, secure initial passwords, and assigned department OUs. The script also includes logic to email each new user their credentials directly rather than storing passwords in a log file, reducing the exposure of sensitive data at rest. In this lab environment email delivery was implemented using PowerShell's Send-MailMessage cmdlet but was not connected to a live SMTP relay, since setting up a mail server was outside the scope of this project: in a production environment, this would integrate with the organization's existing mail infrastructure or a secure credential-delivery system.


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
![alt text](images/Screenshot%202026-09-27%20201816.png)
![alt text](images/Screenshot%202026-09-27%20202112.png)
![alt text](images/Screenshot%202026-09-27%20175129.png)
![alt text](images/Screenshot%202026-09-27%20175631.png)

#### Known Limitations & Next Steps
This script was built as a lab project, so I documented where it would need hardening before production use:

* **Duplicate usernames are not de-duplicated.** Usernames are built from first initial plus last name, so two employees like "John Smith" and "Jane Smith" would both produce `jsmith`. In the current version, the second account fails with a "name already in use" error, which the try/catch block catches and reports without stopping the rest of the batch. A production version would append a number (`jsmith2`) or check for existing accounts first.
* **Password complexity is not fully guaranteed.** `GeneratePassword(12, 3)` guarantees length and a minimum number of symbols, but not that every character category appears. Random 12-character passwords almost always satisfy the domain's complexity requirement, but if one didn't, account creation would fail and be reported. A production version would validate each password against the policy before use.
* **Credential delivery is not live.** Email delivery is implemented but not connected to an SMTP relay in this lab. Microsoft has also marked `Send-MailMessage` as obsolete, so a production version would use a modern mail API or a secure credential-delivery system instead.
* **No persistent audit log.** Results are printed to the console only. A production version would write a timestamped log of accounts created and failures (without passwords) for accountability.


### Step 6: Hardening the Environment with GPOs
To satisfy corporate security compliance (aligning with Security+ principles), I implemented three separate Group Policy Objects (GPOs) across the domain, each scoped intentionally rather than applied as one blanket policy:

* **Password Policy - Corp Compliance** (linked domain-wide): Enforced a 24-password history and complex 12-character minimum passwords. This was applied domain-wide since strong password requirements are appropriate for all systems, including the domain controller itself.
* **USB Restriction Policy** (linked domain-wide): Disabled all Removable Storage classes (deny all access) to prevent data exfiltration via USB drives and block the introduction of malware through removable media. Also applied domain-wide for the same reasoning as above.
* **Disable Local Administrator Account** (linked to the `Corp_Workstations` OU only): Disabled the built-in local Administrator account, forcing all administrative access through named, auditable domain accounts. This policy was deliberately scoped to client workstations rather than the whole domain, to avoid unintended impact on the domain controller.

Each policy was implemented as its own GPO rather than combined into one, allowing each to be independently managed, tested, and troubleshot without affecting the others.

**Verification:** After linking each GPO, I ran `gpupdate /force` and `gpresult /r` to confirm the policies applied. On the domain controller, only the two domain-wide GPOs applied, while the workstation-scoped Local Administrator policy correctly did not, confirming the scoping works as designed. On the Windows 11 client, which sits in the `Corp_Workstations` OU, all three policies applied.

![alt text](images/Screenshot%202026-09-27%20161912.png)
![alt text](images/Screenshot%202026-09-27%20163108.png)
![alt text](images/Screenshot%202026-09-27%20175757.png)
![alt text](images/Screenshot%202026-09-27%20204506.png)

---


## 4. Key Takeaways & Lessons Learned
* **Automation Efficiency:** Learned how a simple PowerShell script can save dozens of manual entry hours and prevent human typing errors.
* **Network Troubleshooting:** Resolved a DNS conflict early in the lab by ensuring the client VM pointed directly to the Domain Controller's IP address for DNS resolution.
* **Security Baselines:** Gained hands-on experience applying the concept of "Least Privilege" using Active Directory GPOs.
* **Production Security & Secret Management:** While this script safely generates randomized per-user passwords in memory, running an automation script in a production enterprise environment requires strict protection of administrative credentials. To scale this securely, I would eliminate any future risk of hardcoded or exposed session tokens by integrating the script with the `Microsoft.PowerShell.SecretManagement` module or an enterprise vault (like Azure Key Vault) to retrieve high-privilege credentials dynamically at runtime.

