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