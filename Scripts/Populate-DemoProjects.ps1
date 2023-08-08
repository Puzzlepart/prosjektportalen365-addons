Param(
    [Parameter(Mandatory = $false)][string]$Url = "https://puzzlepart.sharepoint.com/sites/GROMgoderelasjonerogmiljiskolen"
)

function ConvertPSObjectToHashtable {
    param (
        [Parameter(ValueFromPipeline)]
        $InputObject
    )

    process {
        if ($null -eq $InputObject) { return $null }

        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            $collection = @(
                foreach ($object in $InputObject) { ConvertPSObjectToHashtable $object }
            )

            Write-Output -NoEnumerate $collection
        }
        elseif ($InputObject -is [psobject]) {
            $hash = @{}

            foreach ($property in $InputObject.PSObject.Properties) {
                $hash[$property.Name] = ConvertPSObjectToHashtable $property.Value
            }

            $hash
        }
        else {
            $InputObject
        }
    }
}
if ($null -eq (Get-Command Set-PnPTraceLog -ErrorAction SilentlyContinue)) {
    Write-Host "You have to load the PnP.PowerShell module before running this script!" -ForegroundColor Red
    exit 0
}
if ($null -eq (Get-Command Get-GPT3Completion -ErrorAction SilentlyContinue)) {
    Write-Host "You have to load the PowerShellAI module before running this script!" -ForegroundColor Red
    exit 0
}
if ($null -eq $env:OpenAIKey) {
    Write-Host "You have to set the OpenAIKey environment variable (`$env:OpenAIKey`) before running this script!" -ForegroundColor Red
    exit 0
}



$ErrorActionPreference = "Stop"
Set-PnPTraceLog -Off

Connect-PnPOnline -Url $Url -Interactive

$Site = Get-PnPSite
$Web = Get-PnPWeb
$SiteTitle = $Web.Title

$ctx = Get-PnPContext
$ctx.Load($ctx.Web.CurrentUser)
$ctx.ExecuteQuery()
$CurrentUserEmail = $ctx.Web.CurrentUser.Email

$TargetLists = @(#"Interessentregister",
    "Prosjektleveranser",
    "Kommunikasjonsplan",
    "Prosjektlogg",
    "Usikkerhet",
    "Endringsanalyse",
    "Gevinstanalyse og gevinstrealiseringsplan")

$TargetLists | ForEach-Object {
    $List = Get-PnPList -Identity $_
    $ListTitle = $List.Title
    
    Write-Host "Generating suggestions for '$ListTitle' items for '$SiteTitle'"

    $Fields = Get-PnPField -List $ListTitle | Where-Object { $_.InternalName -eq "Title" -or $_.InternalName.StartsWith("Gt") }

    $FieldPrompt = ""
    $Fields | ForEach-Object { 
        $FieldPromptValue =  "'$($_.Title)' (Internt navn '$($_.InternalName)'"
        if ($_.Description) {
            $FieldPromptValue += ", beskrivelse av input: '$($_.Description)'"
        }

        if ($_.TypeAsString -eq "DateTime") {
            $FieldPromptValue += ", datoformat: yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fffffffK"
        } elseif ($_.TypeAsString -eq "Boolean") {
            $FieldPromptValue += ", verdi 'Ja' eller 'Nei'"
        } elseif ($_.TypeAsString -eq "User" -or $_.TypeAsString -eq "UserMulti") {
            $FieldPromptValue += ", verdi skal være '$CurrentUserEmail'"
        } elseif ($_.TypeAsString -eq "Choice" -or $_.TypeAsString -eq "MultiChoice") {
            if ($_.Choices) {
                $FieldPromptValue += ", valg: '$($_.Choices -join ", ")'"
            }
        } elseif ($_.TypeAsString -eq "TaxonomyFieldType" -or $_.TypeAsString -eq "TaxonomyFieldTypeMulti") {
            return
        } elseif ($_.TypeAsString -eq "Lookup" -or $_.TypeAsString -eq "LookupMulti" ) {
            return
        }

        $FieldPromptValue += "),"
        $FieldPrompt += $FieldPromptValue
    }
    $FieldPrompt = $FieldPrompt.TrimEnd(",")

    $Prompt = "Gi meg eksempler på $ListTitle for et prosjekt som heter '$SiteTitle'. Feltene er følgende: $FieldPrompt. Verdien i tittel-feltet skal være unikt. Returner elementene som en ren json array. Bruk internnavnene på feltene i JSON-objektet. Begrens antall elementer slik at total lengde på JSON-objektet ikke overstiger 2048 tegn."
    $AIResults = Get-GPT3Completion -prompt $Prompt -max_tokens 2048

    if (Test-Json -Json $AIResults) {
        $Items = ConvertFrom-Json ($AIResults.Trim())
    
    
        $Items | ForEach-Object {
            Write-Host "Creating list item '$($_.Title)' for list '$ListTitle'"
            $HashtableValues = ConvertPSObjectToHashtable -InputObject $_
            $Item = Add-PnPListItem -List $ListTitle -Values $HashtableValues
        }
    } else {
        Write-Host "The AI did not return valid JSON." -ForegroundColor Red
    }
}