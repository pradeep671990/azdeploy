<# 

This script contains all of the functions used by the main deployment script. 

#>

#Azure Region Acronyms list - Used for building RG and individual resouce names
$azureRegionAcronyms = @{
    "eastus"             = "USE";
    "eastus2"            = "USE2";
    "centralus"          = "USC";
    "northcentralus"     = "USNC";
    "southcentralus"     = "USSC";
    "westcentralus"      = "USWC";
    "westus"             = "USW";
    "southeastasia"      = "SGE";
    "eastasia"           = "EA";
    "australiaeast"      = "AUE";
    "australiasoutheast" = "AUSE";
    "chinaeast"          = "CNE";
    "chinanorth"         = "CNN";
    "centralindia"       = "INC";
    "westindia"          = "INW";
    "southindia"         = "INS";
    "japaneast"          = "JPE";
    "japanwest"          = "JPW";
    "koreacentral"       = "KRC";
    "koreasouth"         = "KRS";
    "australiacentral1"  = "AUC1";
    "australiacentral2"  = "AUC2";
    "northeurope"        = "IENE";
    "westeurope"         = "NLWE";
    "francecentral"      = "FRC";
    "francesouth"        = "FRS";
    "ukwest"             = "GBW";
    "uksouth"            = "GBS";
    "germanycentral"     = "DEC";
    "germanynortheast"   = "DENE";
    "germanynorth"       = "GN";
    "germanywestcentral" = "GWC";
    "switzerlandnorth"   = "CHN";
    "switzerlandwest"    = "CHW";
}

#Environment abbreviateions - Used for building RG and individual resource names
$environmentAbbreviations = @{
    "dev"  = "DV";
    "uat"  = "UT";
    "prod" = "PR";
    "dr"   = "DR";
}

#Function to build Resource Group names per the AP standard
function Build-ResourceGroupName() {
    $segmentA = "AP-AZ-" + $Environment.ToUpper()
    $segmentB = $azureRegionAcronyms[$ResourceGroupLocation]
    $segmentC = $ProjectCodeName
    $segmentD = "RG"

    return [string]::Join('-', $segmentA, $segmentB, $segmentC, $segmentD)
}

# Function to build all other Azure resource names per the AP standard
function Build-ResourceName([int]$sequenceNumber, [string]$tla, [string]$suffix = "", [switch]$lowerCase, [switch]$allowHyphens) {
    if ($allowHyphens) {
        $separator = '-'
    }
    else {
        $separator = ''
    }
    $segmentA = "AP" + $azureRegionAcronyms[$ResourceGroupLocation]
    $segmentB = $ProjectResourceIdentifier
    $segmentC = $environmentAbbreviations[$Environment]
    $segmentD = $tla
    if ($sequenceNumber -eq 0) {
        $name = [string]::Join($separator, $segmentA, $segmentB, $segmentC, $SegmentD, $suffix)
    }
    else {
        $segmentE = $sequenceNumber.ToString("D2")
        $name = [string]::Join($separator, $segmentA, $segmentB, $segmentC, $segmentD, $segmentE, $suffix)
    }

    if ($lowerCase) {
        $name = $name.ToLower()
    }

    return $name
}

# Function to generate a secure password for all VMs
function New-Password {
    [OutputType([SecureString])]
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, Position = 0)]
        [string]$Template = "I16",
    
        [hashtable]$CustomCharacterSet = @{}
    )
    begin {
        $CharacterSets = [System.Collections.Generic.Dictionary[char, char[]]]::new()
        @{
            [char]'a' = [char[]]"abcdefghijklmnopqrstuvwxyz0123456789"
            [char]'A' = [char[]]"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
            [char]'U' = [char[]]"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
            [char]'d' = [char[]]"0123456789"
            [char]'h' = [char[]]"0123456789abcdef"
            [char]'H' = [char[]]"0123456789ABCDEF"
            [char]'l' = [char[]]"abcdefghijklmnopqrstuvwxyz"
            [char]'L' = [char[]]"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
            [char]'u' = [char[]]"ABCDEFGHIJKLMNOPQRSTUVWXYZ"
            [char]'v' = [char[]]"aeiou"
            [char]'V' = [char[]]"AEIOUaeiou"
            [char]'Z' = [char[]]"AEIOU"
            [char]'c' = [char[]]"bcdfghjklmnpqrstvwxyz"
            [char]'C' = [char[]]"BCDFGHJKLMNPQRSTVWXYZbcdfghjklmnpqrstvwxyz"
            [char]'z' = [char[]]"BCDFGHJKLMNPQRSTVWXYZ"
            [char]'p' = [char[]]",.;:"
            [char]'b' = [char[]]"()[]{}<>"
            [char]'s' = [char[]]"!`"#$%&'()*+,-./:;<=>?@[\]^_``{|}~"
            [char]'S' = [char[]]"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!`"#$%&'()*+,-./:;<=>?@[\]^_``{|}~"
            [char]'i' = [char[]]"!#%^&*<>?~"
            [char]'I' = [char[]]"ABCDEFGHIJKLMNPQRSTUVWXYZabcdefghijklmnpqrstuvwxyz123456789!#%^&*"
        }.GetEnumerator().ForEach{ $CharacterSets.Add($_.Key, $_.Value) }

        $CustomCharacterSet.GetEnumerator().ForEach{ $CharacterSets.Add($_.Key, $_.Value) }

        # This returns a RNGCryptoServiceProvider
        $cryptoRNG = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    }

    process {
        # Create the return object
        $securePassword = [System.Security.SecureString]::new()

        # Expand the template
        $Template = [regex]::replace($Template, "(.)(\d+)", { param($match) $match.Groups[1].Value * [int]($match.Groups[2].Value) })

        Write-Verbose "Template: $Template"

        $b = [byte[]]0
        for ($c = 0; $c -lt $Template.Length; $c++) {
            $securePassword.AppendChar($(
                    if ($Template[$c] -eq '\') {
                        $Template[(++$c)]
                    }
                    else {
                        $cryptoRNG.GetBytes($b)
                        $char = $Template[$c]
                        if ($Set = $CharacterSets[$char]) {
                            $Index = [int]$b[0] % $Set.Length
                            $Set[$Index]
                        }
                        else {
                            $char
                        }
                    }
                ))
        }

        return $securePassword
    }
}
